// FactStore - 核心事实存储
//
// 设计原理：
// - 存储永不遗忘的关键用户信息
// - 每次 System Prompt 构建时自动注入
// - 支持从对话中自动学习和手动设置
// - 【新增】混合提取：正则守门 + LLM 精确提取

import 'dart:convert';
import '../settings_loader.dart';
import '../service/llm_service.dart';
import '../service/database_helper.dart';

/// 核心事实存储 - 确保 AI 永不遗忘的关键信息
class FactStore {
  static const String _storageKey = 'fact_store_data';

  // 预定义的核心事实 Key (Canonical Keys)
  static const String keyUserName = 'user_name';
  static const String keyUserRole = 'role';
  static const String keyUserGoal = 'goal';
  static const String keyImportantDate = 'important_date';
  static const String keyUserLocation = 'location';
  static const String keyUserAge = 'age';
  static const String keyUserPreference = 'preference'; 
  
  // 严格分类 Key
  static const String keyCurrentStatus = 'current_status'; // 状态 (加班/生病等)
  static const String keyOccupation = 'occupation';       // 职业 (警校/经侦等)
  static const String keyOrigin = 'origin';               // 籍贯 (山西/晋北等)

  final DatabaseHelper _dbHelper;
  LLMService? _llmService;
  
  void setLLMService(LLMService service) {
    _llmService = service;
  }

  // 核心事实存储 (内存缓存)
  final Map<String, FactEntry> _facts = {};

  FactStore(this._dbHelper);

  /// 初始化并加载数据
  Future<void> init() async {
    await _load();
  }

  /// 从持久化存储加载
  Future<void> _load() async {
    final rows = await _dbHelper.queryAll('facts');
    _facts.clear();
    
    for (final row in rows) {
      final key = row['key'] as String;
      _facts[key] = FactEntry(
        value: row['value'] ?? '',
        source: FactSource.values[row['source'] ?? 1],
        confidence: (row['importance'] ?? 0.8).toDouble(),
        updatedAt: DateTime.tryParse(row['timestamp'] ?? '') ?? DateTime.now(),
      );
    }
    
    // 加载后尝试迁移
    await _migrateLegacyData();
  }
  
  /// 脏数据清洗与迁移
  /// 
  /// 解决历史版本中"重复事实"的问题，强制合并到 Canonical Keys
  Future<void> _migrateLegacyData() async {
    bool refined = false;
    final keysToRemove = <String>[];
    
    // 1. 扫描所有事实，寻找特定关键词
    final validFacts = _facts.entries.toList()
      ..sort((a, b) => a.value.updatedAt.compareTo(b.value.updatedAt)); // 按时间排序，保留最新的

    for (final entry in validFacts) {
      final val = entry.value.value;
      final key = entry.key;
      
      // 规则 A: 加班/代码 -> current_status
      if (val.contains('加班') || val.contains('代码') || val.contains('牛马') || val.contains('debug') || val.contains('coding')) {
        _facts[keyCurrentStatus] = entry.value; // 覆盖为最新
        if (key != keyCurrentStatus) keysToRemove.add(key);
        refined = true;
      }
      
      // 规则 B: 警校/学生/经侦 -> occupation
      else if (val.contains('警校') || val.contains('学生') || val.contains('经侦')) {
        _facts[keyOccupation] = entry.value;
        if (key != keyOccupation && key != keyUserRole) keysToRemove.add(key);
        refined = true;
      }
      
      // 规则 C: 山西/晋北 -> origin
      else if (val.contains('山西') || val.contains('晋北')) {
        _facts[keyOrigin] = entry.value;
        if (key != keyOrigin && key != keyUserLocation) keysToRemove.add(key);
        refined = true;
      }
    }
    
    // 2. 删除旧的冗余 Key
    for (final k in keysToRemove) {
      _facts.remove(k);
    }
    
    if (refined) {
      print('[FactStore] Data migration completed. Cleared duplicates.');
      // 迁移不需要全量保存，因为 setFact 和 removeFact 已经是增量保存了
      // 但为了确保状态一致，我们可以执行一次全量同步或依赖已有的逻辑
    }
  }

  /// 全量保存 (仅在迁移等特殊情况使用)
  Future<void> _saveAll() async {
    // 实际生产中应尽量避免全量覆盖，SQL 下可以用事务
    for (final entry in _facts.entries) {
      await _dbSaveFact(entry.key, entry.value);
    }
  }

  /// 单个事实保存到数据库
  Future<void> _dbSaveFact(String key, FactEntry entry) async {
    await _dbHelper.insert('facts', {
      'key': key,
      'value': entry.value,
      'source': entry.source.index,
      'timestamp': entry.updatedAt.toIso8601String(),
      'importance': entry.confidence,
    });
  }

  /// 设置事实 (自动路由到 Canonical Keys)
  Future<void> setFact(
    String key,
    String value, {
    FactSource source = FactSource.inferred,
    double confidence = 0.8,
  }) async {
    // 写入时的自动归类逻辑
    String targetKey = key;
    
    if (value.contains('加班') || value.contains('代码') || value.contains('牛马') ||
        value.contains('debug') || value.contains('coding') || value.contains('项目') ||
        value.contains('上班') || value.contains('搬砖') || value.contains('上线')) {
      targetKey = keyCurrentStatus;
    }
    else if (value.contains('警校') || value.contains('经侦')) targetKey = keyOccupation;
    else if (value.contains('山西') || value.contains('晋北')) targetKey = keyOrigin;

    final entry = FactEntry(
      value: value,
      source: source,
      confidence: confidence,
      updatedAt: DateTime.now(),
    );
    _facts[targetKey] = entry;
    
    // 异步保存到数据库
    await _dbSaveFact(targetKey, entry);
    print('[FactStore] Set fact: $targetKey = $value (routed from $key)');
  }

  /// 获取事实值
  String? getFact(String key) => _facts[key]?.value;

  /// 获取事实条目
  FactEntry? getFactEntry(String key) => _facts[key];

  /// 获取所有事实
  Map<String, FactEntry> getAllFacts() => Map.unmodifiable(_facts);

  /// 删除事实
  Future<void> removeFact(String key) async {
    _facts.remove(key);
    await _dbHelper.delete('facts', 'key', key);
  }

  /// 清空所有事实
  Future<void> clearAll() async {
    _facts.clear();
    await _dbHelper.clearTable('facts');
  }

  /// 格式化为 System Prompt
  /// 
  /// [maxLength] 输出最大字符数，防止 Token 超限
  String formatForSystemPrompt({double minConfidence = 0.6, int maxLength = 500}) {
    return deduplicateAndSummarize(minConfidence: minConfidence, maxLength: maxLength);
  }

  /// 【重构】去重并摘要 (严格 Schema 模式)
  /// 
  /// 输出格式："用户是{occupation}，来自{origin}。当前状态：{current_status}。偏好：{preferences}"
  /// 
  /// 添加 maxLength 参数，控制输出长度
  String deduplicateAndSummarize({double minConfidence = 0.6, int maxLength = 500}) {
    final parts = <String>[];

    // 1. 基础身份 (高优先)
    final name = _facts[keyUserName]?.value;
    final occupation = _facts[keyOccupation]?.value ?? _facts[keyUserRole]?.value;
    final origin = _facts[keyOrigin]?.value ?? _facts[keyUserLocation]?.value;
    
    String identity = '用户';
    if (name != null) identity += '身份：$name';
    if (occupation != null) identity += '是$occupation'; 
    if (origin != null) identity += '，来自$origin';
    
    if (identity != '用户') {
      parts.add(identity);
    }
    
    // 2. 当前状态 (中优先) - 过滤过期状态
    final statusEntry = _facts[keyCurrentStatus];
    if (statusEntry != null && !statusEntry.isExpired(keyCurrentStatus)) {
      parts.add('当前状态：${statusEntry.value}');
    }
    
    // 3. 目标 (中优先)
    final goal = _facts[keyUserGoal]?.value;
    if (goal != null) {
      parts.add('目标是$goal');
    }
    
    // 4. 偏好 (低优先，可能被截断)
    final preferences = _facts.entries
        .where((e) => e.key.startsWith('preference') || e.key == keyUserPreference)
        .map((e) => e.value.value)
        .toSet()
        .take(5)  // 限制偏好数量
        .join('；');
        
    if (preferences.isNotEmpty) {
      parts.add('偏好：$preferences');
    }

    if (parts.isEmpty) return '（暂无已知信息）';
    
    // 【P1-1 核心】长度控制
    String result = parts.join('。') + '。';
    if (result.length > maxLength) {
      // 智能截断：保留高优先信息
      result = result.substring(0, maxLength - 3) + '...';
    }
    
    return result;
  }

  /// 获取事实标签 (GUI 显示用)
  String _getFactLabel(String key) {
    switch (key) {
      case keyUserName: return '用户姓名';
      case keyOccupation:
      case keyUserRole: return '身份/职业';
      case keyOrigin:
      case keyUserLocation: return '籍贯/所在地';
      case keyCurrentStatus: return '当前状态';
      case keyUserGoal: return '当前目标';
      default: return key;
    }
  }

  /// 从文本中自动提取事实（简单规则匹配）
  ///
  /// 用于从对话中自动学习用户信息
  Future<List<String>> extractAndStore(String text) async {
    final extracted = <String>[];

    // 提取姓名模式
    final namePatterns = [
      RegExp(r'我(?:叫|是|名字是)\s*([^\s,，。！？]{1,10})'),
      RegExp(r'叫我\s*([^\s,，。！？]{1,10})'),
    ];

    for (final pattern in namePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final name = match.group(1)!.trim();
        if (name.isNotEmpty && name.length <= 10) {
          await setFact(keyUserName, name, source: FactSource.inferred);
          extracted.add('姓名: $name');
        }
      }
    }

    // 提取职业/身份模式
    final rolePatterns = [
      RegExp(r'我是(?:一?[名个位])?([^\s,，。！？]{1,15}(?:生|员|师|家|者))'),
      RegExp(r'我(?:在|正在)(?:准备|备考)\s*([^\s,，。！？]{1,20})'),
    ];

    for (final pattern in rolePatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final role = match.group(1)!.trim();
        if (role.isNotEmpty) {
          await setFact(keyUserRole, role, source: FactSource.inferred);
          extracted.add('身份: $role');
        }
      }
    }

    // 提取目标模式
    final goalPatterns = [
      RegExp(r'(?:我的目标是|我想要|我希望)\s*([^\s。！？]{1,30})'),
      RegExp(r'(?:准备|备考)\s*(\d{4}[年]?[^\s,，。！？]{1,20}考试?)'),
    ];

    for (final pattern in goalPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final goal = match.group(1)!.trim();
        if (goal.isNotEmpty) {
          await setFact(keyUserGoal, goal, source: FactSource.inferred);
          extracted.add('目标: $goal');
        }
      }
    }

    // 提取所在地模式
    final locationPatterns = [
      RegExp(r'我(?:来自|住在)\s*([^\s,，。！？]{1,10}[省市县镇区])'),
      RegExp(r'我是([^\s,，。！？]{1,10}人)'),
    ];

    for (final pattern in locationPatterns) {
      final match = pattern.firstMatch(text);
      if (match != null) {
        final location = match.group(1)!.trim();
        if (location.isNotEmpty) {
          await setFact(keyUserLocation, location, source: FactSource.inferred);
          extracted.add('所在地: $location');
        }
      }
    }

    // 使用合并的正则表达式进行单次扫描
    // 构建: (keyword1|keyword2|...) 模式
    final preferenceKeywords = SettingsLoader.preferenceKeywords;
    if (preferenceKeywords.isNotEmpty) {
      // 按长度降序排序，确保长词优先匹配（如"不喜欢"先于"喜欢"）
      final sortedKeywords = List<String>.from(preferenceKeywords)
        ..sort((a, b) => b.length.compareTo(a.length));

      // 转义关键词中的特殊正则字符
      final escapedKeywords = sortedKeywords
          .map((k) => RegExp.escape(k))
          .join('|');

      // 构建匹配包含任意关键词的句子片段的正则
      // 匹配: [非句末标点]*(关键词)[非句末标点]*
      final mergedPattern = RegExp('([^。！？]*($escapedKeywords)[^。！？]*)');

      // 单次扫描提取所有偏好相关的句子
      for (final match in mergedPattern.allMatches(text)) {
        final preference = match.group(1)?.trim();
        if (preference == null ||
            preference.isEmpty ||
            preference.length > 50) {
          continue;
        }

        // 找出匹配到的是哪个关键词
        final matchedKeyword = preferenceKeywords.firstWhere(
          (k) => preference.contains(k),
          orElse: () => 'preference',
        );

        // 存储为偏好（使用关键词作为子key）
        final factKey = 'preference_$matchedKeyword';

        // 检查是否已存在相同的偏好
        if (_facts[factKey]?.value != preference) {
          await setFact(
            factKey,
            preference,
            source: FactSource.inferred,
            confidence: 0.7,
          );
          extracted.add('偏好($matchedKeyword): $preference');
        }
      }
    }
    
    // 如果检测到偏好关键词且有 LLM 服务，使用 LLM 精确提取
    if (extracted.isNotEmpty && _llmService != null) {
      final llmFacts = await _extractFactsWithLLM(text);
      for (final fact in llmFacts) {
        if (!extracted.contains(fact)) {
          extracted.add(fact);
        }
      }
    }

    return extracted;
  }
  
  /// 使用 LLM 精确提取用户事实
  /// 
  /// 解决正则无法区分"用户喜欢"和"AI喜欢"的问题
  Future<List<String>> _extractFactsWithLLM(String text) async {
    if (_llmService == null) return [];
    
    const prompt = '''你是一个事实提取助手。从对话中提取关于【用户】的事实信息。

规则：
1. 只提取关于用户（说话者）的事实，如用户的姓名、年龄、职业、喜好、目标等。
2. 忽略关于 AI 助手的任何描述。
3. 区分"我喜欢"（用户喜好）和"你喜欢"（可能是 AI 喜好，忽略）。
4. 返回 JSON 数组格式，每个元素包含 key 和 value。

示例输入："我叫小明，今年25岁，我喜欢吃火锅"
示例输出：[{"key":"name","value":"小明"},{"key":"age","value":"25岁"},{"key":"preference_food","value":"喜欢吃火锅"}]

只返回 JSON 数组，不要其他内容。如果没有提取到任何事实，返回空数组 []。''';

    try {
      final response = await _llmService!.completeWithSystem(
        systemPrompt: prompt,
        userMessage: '提取以下文本中关于用户的事实：\n$text',
        model: 'qwen-flash', // 使用 qwen-flash
        maxTokens: 150,
        temperature: 0.1,
      );
      
      return await _parseLLMFacts(response);
    } catch (e) {
      print('[FactStore] LLM extraction error: $e');
      return [];
    }
  }
  
  /// 解析 LLM 返回的事实 JSON
  Future<List<String>> _parseLLMFacts(String response) async {
    final extracted = <String>[];
    
    try {
      // 提取 JSON 数组
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(response);
      if (jsonMatch == null) return [];
      
      final facts = jsonDecode(jsonMatch.group(0)!) as List<dynamic>;
      
      for (final fact in facts) {
        if (fact is Map<String, dynamic>) {
          final key = fact['key']?.toString();
          final value = fact['value']?.toString();
          
          if (key != null && value != null && value.isNotEmpty) {
            // 存储到 FactStore
            await setFact(key, value, source: FactSource.inferred, confidence: 0.85);
            extracted.add('$key: $value (LLM)');
          }
        }
      }
    } catch (e) {
      print('[FactStore] LLM parse error: $e');
    }
    
    return extracted;
  }
}

/// 事实来源
enum FactSource {
  manual, // 用户手动设置
  inferred, // 从对话中推断
  confirmed, // 用户确认的推断
}

/// 事实条目
class FactEntry {
  final String value;
  final FactSource source;
  final double confidence; // 置信度 0.0 ~ 1.0
  final DateTime updatedAt;

  const FactEntry({
    required this.value,
    this.source = FactSource.inferred,
    this.confidence = 0.8,
    required this.updatedAt,
  });

  /// 【P1-2 新增】检查事实是否过期
  /// 
  /// 过期规则：
  /// - current_status: 7 天过期（状态变化快）
  /// - 其他: 90 天过期（身份相对稳定）
  bool isExpired(String key) {
    final now = DateTime.now();
    final age = now.difference(updatedAt);
    
    // 状态类事实过期更快
    if (key == 'current_status' || key.startsWith('preference_')) {
      return age.inDays > 7;
    }
    
    // 核心身份类事实过期慢
    return age.inDays > 90;
  }

  Map<String, dynamic> toJson() => {
    'value': value,
    'source': source.index,
    'confidence': confidence,
    'updatedAt': updatedAt.toIso8601String(),
  };

  factory FactEntry.fromJson(Map<String, dynamic> json) {
    return FactEntry(
      value: json['value'] ?? '',
      source: FactSource.values[json['source'] ?? 0],
      confidence: (json['confidence'] ?? 0.8).toDouble(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }
}
