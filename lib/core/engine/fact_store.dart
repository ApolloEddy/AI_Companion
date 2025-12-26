// FactStore - 核心事实存储
//
// 设计原理：
// - 存储永不遗忘的关键用户信息
// - 每次 System Prompt 构建时自动注入
// - 支持从对话中自动学习和手动设置
// - 【新增】混合提取：正则守门 + LLM 精确提取

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../settings_loader.dart';
import '../service/llm_service.dart';

/// 核心事实存储 - 确保 AI 永不遗忘的关键信息
class FactStore {
  static const String _storageKey = 'fact_store_data';

  // 预定义的核心事实 Key
  static const String keyUserName = 'user_name';
  static const String keyUserRole = 'role';
  static const String keyUserGoal = 'goal';
  static const String keyImportantDate = 'important_date';
  static const String keyUserLocation = 'location';
  static const String keyUserAge = 'age';
  static const String keyUserPreference = 'preference'; // 新增：偏好

  final SharedPreferences _prefs;
  
  // 【新增】可选的 LLM 服务，用于精确事实提取
  LLMService? _llmService;
  
  /// 设置 LLM 服务（用于混合提取模式）
  void setLLMService(LLMService service) {
    _llmService = service;
  }

  // 核心事实存储
  final Map<String, FactEntry> _facts = {};

  FactStore(this._prefs) {
    _load();
  }

  /// 从持久化存储加载
  void _load() {
    final json = _prefs.getString(_storageKey);
    if (json != null && json.isNotEmpty) {
      try {
        final data = jsonDecode(json) as Map<String, dynamic>;
        for (final entry in data.entries) {
          _facts[entry.key] = FactEntry.fromJson(entry.value);
        }
      } catch (e) {
        print('[FactStore] Load error: $e');
      }
    }
  }

  /// 保存到持久化存储
  Future<void> _save() async {
    final data = _facts.map((k, v) => MapEntry(k, v.toJson()));
    await _prefs.setString(_storageKey, jsonEncode(data));
  }

  /// 设置事实
  Future<void> setFact(
    String key,
    String value, {
    FactSource source = FactSource.inferred,
    double confidence = 0.8,
  }) async {
    _facts[key] = FactEntry(
      value: value,
      source: source,
      confidence: confidence,
      updatedAt: DateTime.now(),
    );
    await _save();
    print('[FactStore] Set fact: $key = $value (source: $source)');
  }

  /// 获取事实值
  String? getFact(String key) {
    return _facts[key]?.value;
  }

  /// 获取事实条目（包含元数据）
  FactEntry? getFactEntry(String key) {
    return _facts[key];
  }

  /// 获取所有事实
  Map<String, FactEntry> getAllFacts() {
    return Map.unmodifiable(_facts);
  }

  /// 删除事实
  Future<void> removeFact(String key) async {
    _facts.remove(key);
    await _save();
  }

  /// 清空所有事实
  Future<void> clearAll() async {
    _facts.clear();
    await _save();
  }

  /// 格式化为 System Prompt 注入内容
  ///
  /// 只注入高置信度的事实
  String formatForSystemPrompt({double minConfidence = 0.6}) {
    final lines = <String>[];

    // 按预定义顺序输出核心事实
    final orderedKeys = [
      keyUserName,
      keyUserRole,
      keyUserGoal,
      keyImportantDate,
      keyUserLocation,
      keyUserAge,
      keyUserPreference,
    ];

    for (final key in orderedKeys) {
      final entry = _facts[key];
      if (entry != null && entry.confidence >= minConfidence) {
        lines.add('${_getFactLabel(key)}：${entry.value}');
      }
    }

    // 输出其他自定义事实
    for (final entry in _facts.entries) {
      if (!orderedKeys.contains(entry.key) &&
          entry.value.confidence >= minConfidence) {
        lines.add('${entry.key}：${entry.value.value}');
      }
    }

    if (lines.isEmpty) {
      return '（暂无已知信息）';
    }

    return lines.join('\n');
  }

  /// 获取事实标签
  String _getFactLabel(String key) {
    switch (key) {
      case keyUserName:
        return '用户姓名';
      case keyUserRole:
        return '身份/职业';
      case keyUserGoal:
        return '当前目标';
      case keyImportantDate:
        return '重要日期';
      case keyUserLocation:
        return '所在地';
      case keyUserAge:
        return '年龄';
      case keyUserPreference:
        return '偏好';
      default:
        return key;
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

    // 【优化】使用合并的正则表达式进行单次扫描
    // 构建: (keyword1|keyword2|...) 模式
    final preferenceKeywords = SettingsLoader.preferenceKeywords;
    if (preferenceKeywords.isNotEmpty) {
      // 【关键】按长度降序排序，确保长词优先匹配（如"不喜欢"先于"喜欢"）
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
    
    // 【混合提取】如果检测到偏好关键词且有 LLM 服务，使用 LLM 精确提取
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
  
  /// 【新增】使用 LLM 精确提取用户事实
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
