// MemoryManager - 智能记忆管理
//
// 设计原理：
// - 不再盲目注入全部历史
// - 实现简单的筛选和摘要机制
// - 记忆注入策略由 GenerationPolicy 控制

import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../policy/generation_policy.dart';

/// 记忆条目
class MemoryEntry {
  final String content;
  final DateTime timestamp;
  final double importance;  // 重要性权重 (0~1)

  const MemoryEntry({
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
      content: map['content'] ?? '',
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
      importance: (map['importance'] ?? 0.5).toDouble(),
    );
  }
}

/// 记忆管理器 - 智能筛选与摘要
class MemoryManager {
  final SharedPreferences prefs;
  
  // 内存缓存
  List<String> _memories = [];
  
  MemoryManager(this.prefs) {
    _load();
  }

  void _load() {
    _memories = prefs.getStringList(AppConfig.memoryKey) ?? [];
  }

  /// 获取所有记忆
  List<String> getAllMemories() => List.unmodifiable(_memories);

  /// 获取记忆数量
  int get count => _memories.length;

  // ========== 智能检索 ==========

  /// 获取相关记忆 (由 Policy 控制策略)
  /// 
  /// 策略：
  /// - 根据 policy 决定检索数量
  /// - 优先返回最近的记忆
  /// - 未来可扩展：关键词匹配、语义搜索
  String getRelevantMemories(String query, GenerationPolicy policy, ConversationContext context) {
    if (_memories.isEmpty) return '（暂无记忆）';

    final maxItems = policy.getMaxMemoryItems(context);
    
    // 简单策略：返回最近 N 条记忆
    final recent = _memories.length > maxItems 
        ? _memories.sublist(_memories.length - maxItems) 
        : _memories;
    
    return recent.join('\n');
  }

  /// 简化版获取 (向后兼容)
  String getRelevantContext(String query) {
    if (_memories.isEmpty) return '（暂无记忆）';
    
    final recent = _memories.length > 10 
        ? _memories.sublist(_memories.length - 10) 
        : _memories;
    return recent.join('\n');
  }

  // ========== 摘要机制 ==========

  /// 如果记忆过多，进行简单摘要
  /// 
  /// 策略：
  /// - 保留最近 N 条完整记忆
  /// - 更早的记忆压缩为摘要
  /// - 注意：这是客户端简单摘要，未来可接入 LLM 摘要
  String summarizeIfNeeded(List<String> memories, int maxTokens) {
    if (memories.isEmpty) return '（暂无记忆）';
    
    // 简单估算 token (中文约 1.5 字符/token)
    int estimatedTokens = 0;
    final selected = <String>[];
    
    // 从最新的开始选取，直到达到 token 限制
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
      // 至少保留最后一条（截断）
      final last = memories.last;
      final maxChars = (maxTokens * 1.5).round();
      selected.add(last.length > maxChars 
          ? '${last.substring(0, maxChars)}...' 
          : last);
    }
    
    return selected.join('\n');
  }

  // ========== 添加记忆 ==========

  /// 添加记忆
  /// 
  /// 可选：指定重要性权重
  Future<void> addMemory(String content, {double importance = 0.5}) async {
    if (content.trim().isEmpty) return;
    
    // 去重检查
    if (_memories.contains(content)) return;
    
    _memories.add(content);
    
    // 限制总数 (默认 100 条)
    const maxMemories = 100;
    if (_memories.length > maxMemories) {
      _memories.removeRange(0, _memories.length - maxMemories);
    }
    
    await _save();
  }

  /// 批量添加记忆
  Future<void> addMemories(List<String> contents) async {
    for (final content in contents) {
      if (content.trim().isNotEmpty && !_memories.contains(content)) {
        _memories.add(content);
      }
    }
    
    // 限制总数
    const maxMemories = 100;
    if (_memories.length > maxMemories) {
      _memories.removeRange(0, _memories.length - maxMemories);
    }
    
    await _save();
  }

  Future<void> _save() async {
    await prefs.setStringList(AppConfig.memoryKey, _memories);
  }

  // ========== 管理操作 ==========

  /// 清除所有记忆
  Future<void> clearAll() async {
    _memories.clear();
    await _save();
  }

  /// 重新加载
  void reload() {
    _load();
  }

  /// 删除特定记忆
  Future<void> removeMemory(String content) async {
    _memories.remove(content);
    await _save();
  }

  /// 获取最近 N 条记忆
  List<String> getRecentMemories(int count) {
    if (_memories.isEmpty) return [];
    final start = (_memories.length - count).clamp(0, _memories.length);
    return _memories.sublist(start);
  }
}
