// MemoryManager - 智能记忆管理 (SQLite 版本)
//
// 设计原理：
// - 使用 SQLite 替代 SharedPreferences 解决大规模数据性能问题
// - 支持分页加载，启动时仅加载最近 N 条
// - 保持 API 向后兼容

import 'package:sqflite/sqflite.dart';
import '../service/database_helper.dart';
import '../settings_loader.dart';
import '../policy/generation_policy.dart';

/// 记忆条目
class MemoryEntry {
  final int? id;
  final String content;
  final DateTime timestamp;
  final double importance;

  const MemoryEntry({
    this.id,
    required this.content,
    required this.timestamp,
    this.importance = 0.5,
  });

  Map<String, dynamic> toMap() => {
    'content': content,
    'timestamp': timestamp.toIso8601String(),
    'importance': importance,
  };

  factory MemoryEntry.fromMap(Map<String, dynamic> map) {
    return MemoryEntry(
      id: map['id'] as int?,
      content: map['content'] ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      importance: (map['importance'] ?? 0.5).toDouble(),
    );
  }

  /// JSON 序列化方法（别名）
  Map<String, dynamic> toJson() => toMap();

  factory MemoryEntry.fromJson(Map<String, dynamic> json) =>
      MemoryEntry.fromMap(json);
}

/// 记忆管理器 - SQLite 版本
class MemoryManager {
  final DatabaseHelper _dbHelper;

  // 内存缓存 - 仅保留最近的工作记忆
  List<MemoryEntry> _workingMemory = [];
  
  // 缓存的总记忆数量
  int _totalCount = 0;
  
  // 工作记忆最大容量
  static const int _workingMemoryCapacity = 100;

  MemoryManager(this._dbHelper);

  /// 异步初始化 - 加载工作记忆
  Future<void> init() async {
    await _loadWorkingMemory();
    await _refreshTotalCount();
    print('[MemoryManager] Initialized with $_totalCount total memories, ${_workingMemory.length} in working memory');
  }

  /// 获取记忆数量
  int get count => _totalCount;

  /// 加载工作记忆（最近 N 条）
  Future<void> _loadWorkingMemory() async {
    final db = await _dbHelper.database;
    final results = await db.query(
      'memory_entries',
      orderBy: 'timestamp DESC',
      limit: _workingMemoryCapacity,
    );
    _workingMemory = results.map((r) => MemoryEntry.fromMap(r)).toList();
    // 反转以保持时间顺序（最旧在前）
    _workingMemory = _workingMemory.reversed.toList();
  }

  /// 刷新总记忆数量
  Future<void> _refreshTotalCount() async {
    final db = await _dbHelper.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM memory_entries');
    _totalCount = Sqflite.firstIntValue(result) ?? 0;
  }

  // ========== 智能检索 ==========

  /// 获取相关记忆 (由 Policy 控制策略)
  String getRelevantMemories(
    String query,
    GenerationPolicy policy,
    ConversationContext context,
  ) {
    if (_workingMemory.isEmpty) return '（暂无记忆）';

    final maxItems = policy.getMaxMemoryItems(context);

    // 从工作记忆中获取最近 N 条
    final recent = _workingMemory.length > maxItems
        ? _workingMemory.sublist(_workingMemory.length - maxItems)
        : _workingMemory;

    return recent.map((e) => e.content).join('\n');
  }

  /// 简化版获取 (向后兼容)
  String getRelevantContext(String query) {
    if (_workingMemory.isEmpty) return '（暂无记忆）';

    final recent = _workingMemory.length > 10
        ? _workingMemory.sublist(_workingMemory.length - 10)
        : _workingMemory;
    return recent.map((e) => e.content).join('\n');
  }

  /// 获取所有记忆内容（向后兼容，仅工作记忆）
  List<String> getAllMemories() => _workingMemory.map((e) => e.content).toList();

  /// 获取所有记忆条目（完整数据，仅工作记忆）
  List<MemoryEntry> getAllMemoryEntries() => List.unmodifiable(_workingMemory);

  // ========== 摘要机制 ==========

  /// 如果记忆过多，进行简单摘要
  String summarizeIfNeeded(List<String> memories, int maxTokens) {
    if (memories.isEmpty) return '（暂无记忆）';

    int estimatedTokens = 0;
    final selected = <String>[];

    for (int i = memories.length - 1; i >= 0 && estimatedTokens < maxTokens; i--) {
      final mem = memories[i];
      final tokens = (mem.length / 1.5).ceil();
      if (estimatedTokens + tokens <= maxTokens) {
        selected.insert(0, mem);
        estimatedTokens += tokens;
      } else {
        break;
      }
    }

    if (selected.isEmpty && memories.isNotEmpty) {
      final last = memories.last;
      final maxChars = (maxTokens * 1.5).round();
      selected.add(
        last.length > maxChars ? '${last.substring(0, maxChars)}...' : last,
      );
    }

    return selected.join('\n');
  }

  // ========== 添加记忆 ==========

  /// 添加记忆
  Future<void> addMemory(String content, {double importance = 0.5}) async {
    if (content.trim().isEmpty) return;

    // 重要性阈值过滤
    final threshold = SettingsLoader.memoryImportanceThreshold;
    if (importance < threshold) {
      print('[MemoryManager] Filtered low-importance memory');
      return;
    }

    // 去重检查（在工作记忆中检查）
    if (_workingMemory.any((m) => m.content == content)) return;

    final entry = MemoryEntry(
      content: content,
      timestamp: DateTime.now(),
      importance: importance,
    );

    // 写入 SQLite
    final db = await _dbHelper.database;
    await db.insert('memory_entries', entry.toMap());

    // 更新工作记忆
    _workingMemory.add(entry);
    if (_workingMemory.length > _workingMemoryCapacity) {
      _workingMemory.removeAt(0);
    }

    // 更新总数
    _totalCount++;

    // 限制总数（在数据库中清理旧记忆）
    final maxMemories = SettingsLoader.maxMemoriesPerUser;
    if (_totalCount > maxMemories) {
      await _pruneOldMemories(maxMemories);
    }
  }

  /// 批量添加记忆
  Future<void> addMemories(List<String> contents, {double importance = 0.5}) async {
    for (final content in contents) {
      await addMemory(content, importance: importance);
    }
  }

  /// 清理旧记忆，保留最近 N 条
  Future<void> _pruneOldMemories(int keepCount) async {
    final db = await _dbHelper.database;
    
    // 获取要保留的最小 ID
    final result = await db.rawQuery('''
      SELECT id FROM memory_entries 
      ORDER BY timestamp DESC 
      LIMIT 1 OFFSET ?
    ''', [keepCount - 1]);
    
    if (result.isNotEmpty) {
      final minIdToKeep = result.first['id'] as int;
      await db.delete(
        'memory_entries',
        where: 'id < ?',
        whereArgs: [minIdToKeep],
      );
      await _refreshTotalCount();
      print('[MemoryManager] Pruned old memories, kept $keepCount');
    }
  }

  // ========== 管理操作 ==========

  /// 清除所有记忆
  Future<void> clearAll() async {
    final db = await _dbHelper.database;
    await db.delete('memory_entries');
    _workingMemory.clear();
    _totalCount = 0;
  }

  /// 重新加载
  Future<void> reload() async {
    await _loadWorkingMemory();
    await _refreshTotalCount();
  }

  /// 删除特定记忆
  Future<void> removeMemory(String content) async {
    final db = await _dbHelper.database;
    await db.delete('memory_entries', where: 'content = ?', whereArgs: [content]);
    _workingMemory.removeWhere((m) => m.content == content);
    await _refreshTotalCount();
  }

  /// 获取最近 N 条记忆
  List<String> getRecentMemories(int count) {
    if (_workingMemory.isEmpty) return [];
    final start = (_workingMemory.length - count).clamp(0, _workingMemory.length);
    return _workingMemory.sublist(start).map((e) => e.content).toList();
  }

  /// 获取最近 N 条记忆条目（完整数据）
  List<MemoryEntry> getRecentMemoryEntries(int count) {
    if (_workingMemory.isEmpty) return [];
    final start = (_workingMemory.length - count).clamp(0, _workingMemory.length);
    return _workingMemory.sublist(start);
  }

  /// 从深层记忆检索（语义搜索预留接口）
  Future<List<MemoryEntry>> searchDeepMemories(String query, {int limit = 20}) async {
    final db = await _dbHelper.database;
    // 简单的关键词匹配搜索
    final results = await db.query(
      'memory_entries',
      where: 'content LIKE ?',
      whereArgs: ['%$query%'],
      orderBy: 'timestamp DESC',
      limit: limit,
    );
    return results.map((r) => MemoryEntry.fromMap(r)).toList();
  }
}
