import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';
import 'config/prompt_config.dart'; // 【新增】

/// 动态设置加载器 - 从 YAML 文件读取配置
class SettingsLoader {
  static Map<String, dynamic>? _personaSettings;
  static Map<String, dynamic>? _emotionSettings;
  static Map<String, dynamic>? _intimacySettings; // 【新增】
  static Map<String, dynamic>? _timeSettings;
  static Map<String, dynamic>? _responseSettings;
  static Map<String, dynamic>? _memorySettings;
  static Map<String, dynamic>? _factSchemaSettings;
  
  static bool _isLoaded = false;
  
  static Future<void> loadAll() async {
    if (_isLoaded) return;
    
    _personaSettings = await _loadYaml('assets/settings/persona_settings.yaml');
    _emotionSettings = await _loadYaml('assets/settings/emotion_settings.yaml');
    _intimacySettings = await _loadYaml('assets/settings/intimacy_settings.yaml'); // 【新增】
    _timeSettings = await _loadYaml('assets/settings/time_settings.yaml');
    _responseSettings = await _loadYaml('assets/settings/response_settings.yaml');
    _memorySettings = await _loadYaml('assets/settings/memory_settings.yaml');
    _factSchemaSettings = await _loadYaml('assets/settings/fact_schema.yaml');
    
    // 【新增】加载 Prompt 模板配置
    _promptConfig = await _loadPromptConfig();
    
    _isLoaded = true;
  }
  
  /// 加载人格工厂模板 (用于首次启动)
  /// 
  /// 返回 default_persona.yaml 中的 persona 配置
  /// 此方法独立于 loadAll，可单独调用
  static Future<Map<String, dynamic>> loadPersonaTemplate() async {
    final yaml = await _loadYaml('assets/settings/default_persona.yaml');
    return yaml['persona'] as Map<String, dynamic>? ?? {};
  }
  
  static Future<Map<String, dynamic>> _loadYaml(String path) async {
    try {
      final content = await rootBundle.loadString(path);
      final yamlMap = loadYaml(content);
      return _convertYaml(yamlMap);
    } catch (e) {
      print('Failed to load $path: $e');
      return {};
    }
  }
  
  /// 转换 YAML 为标准 Dart Map，保留原始值类型
  static dynamic _convertYaml(dynamic yaml) {
    if (yaml is YamlMap) {
      return Map<String, dynamic>.fromEntries(
        yaml.entries.map((e) => MapEntry(e.key.toString(), _convertYaml(e.value)))
      );
    } else if (yaml is YamlList) {
      return yaml.map((e) => _convertYaml(e)).toList();
    } else {
      // 直接返回原始值（int, double, String, bool, null）
      return yaml;
    }
  }
  
  // ========== Persona Settings ==========
  
  static double get formality => 
      _getDouble(_personaSettings, ['language_style', 'formality'], 0.3);
  
  static double get verbosity => 
      _getDouble(_personaSettings, ['language_style', 'verbosity'], 0.5);
  
  static double get emojiUsage => 
      _getDouble(_personaSettings, ['language_style', 'emoji_usage'], 0.6);
  
  static double get humor => 
      _getDouble(_personaSettings, ['language_style', 'humor'], 0.5);
  
  static double get shortThreshold => 
      _getDouble(_personaSettings, ['response_length', 'short_threshold'], 0.3);
  
  static double get detailedThreshold => 
      _getDouble(_personaSettings, ['response_length', 'detailed_threshold'], 0.6);
  
  static double get intimacyLowThreshold => 
      _getDouble(_intimacySettings, ['thresholds', 'low'], 0.3);
  
  static double get intimacyHighThreshold => 
      _getDouble(_intimacySettings, ['thresholds', 'high'], 0.7);
  
  // 【P2-1 新增】表达阈值配置
  static double get formalityCasualBelow => 
      _getDouble(_personaSettings, ['language_style', 'thresholds', 'casual_below'], 0.3);
  
  static double get formalityFormalAbove => 
      _getDouble(_personaSettings, ['language_style', 'thresholds', 'formal_above'], 0.6);
  
  static double get humorSeriousBelow => 
      _getDouble(_personaSettings, ['language_style', 'thresholds', 'serious_below'], 0.3);
  
  static double get humorHumorousAbove => 
      _getDouble(_personaSettings, ['language_style', 'thresholds', 'humorous_above'], 0.6);
  
  static Map<String, dynamic> getExpressionMode(String mode) {
    final modes = _personaSettings?['expression']?['modes'];
    if (modes == null || modes is! Map) return _defaultExpressionMode;
    final modeData = modes[mode];
    if (modeData == null || modeData is! Map) return _defaultExpressionMode;
    // 确保返回的是标准 Map
    return Map<String, dynamic>.from(modeData);
  }
  
  static final _defaultExpressionMode = <String, dynamic>{
    'description': '温暖关怀',
    'tone': '柔和、体贴',
    'emoji_level': 0.6,
  };
  
  // ========== Emotion Settings ==========
  
  static double get valenceDecayRate => 
      _getDouble(_emotionSettings, ['decay', 'valence_rate'], 0.05);
  
  static double get arousalDecayRate => 
      _getDouble(_emotionSettings, ['decay', 'arousal_rate'], 0.08);
  
  static double get baseValenceChange => 
      _getDouble(_emotionSettings, ['update', 'base_valence_change'], 0.05);
  
  static double get baseArousalChange => 
      _getDouble(_emotionSettings, ['update', 'base_arousal_change'], 0.08);
  
  static double get intimacyBufferFactor => 
      _getDouble(_emotionSettings, ['update', 'intimacy_buffer_factor'], 0.5);
  
  static double get boundarySoftness => 
      _getDouble(_emotionSettings, ['update', 'boundary_softness'], 0.1);
  
  static double get llmHintWeight => 
      _getDouble(_emotionSettings, ['update', 'llm_hint_weight'], 0.2);
  
  static double get highEmotionalIntensity => 
      _getDouble(_emotionSettings, ['thresholds', 'high_emotional_intensity'], 0.6);

  // 【Phase 3 & 4 新增】
  static double get resentmentDecayFactor => 
      _getDouble(_emotionSettings, ['decay', 'resentment_decay_factor'], 0.95);

  static double get resentmentIncrease => 
      _getDouble(_emotionSettings, ['update', 'resentment_increase'], 0.1);

  static double get resentmentSuppressionFactor => 
      _getDouble(_emotionSettings, ['update', 'resentment_suppression_factor'], 0.8);

  static double get fatigueArousalThreshold => 
      _getDouble(_emotionSettings, ['update', 'fatigue_arousal_threshold'], 0.8);

  static double get fatigueDampeningFactor => 
      _getDouble(_emotionSettings, ['update', 'fatigue_dampening_factor'], 0.5);

  static List<String> get negativeKeywords {
    final list = _emotionSettings?['update']?['negative_keywords'];
    if (list is List) return list.map((e) => e.toString()).toList();
    return ['不', '别', '讨厌', '烦', '滚', '闭嘴'];
  }

  static double get meltdownArousalThreshold => 
      _getDouble(_emotionSettings, ['thresholds', 'meltdown_arousal'], 0.85);

  static double get meltdownValenceThreshold => 
      _getDouble(_emotionSettings, ['thresholds', 'meltdown_valence_negative'], -0.75);
  
  // ========== Time Settings ==========
  
  static int get immediateThreshold => 
      _getInt(_timeSettings, ['thresholds', 'immediate'], 2);
  
  static int get shortTimeThreshold => 
      _getInt(_timeSettings, ['thresholds', 'short'], 30);
  
  static int get mediumThreshold => 
      _getInt(_timeSettings, ['thresholds', 'medium'], 120);
  
  static int get longThreshold => 
      _getInt(_timeSettings, ['thresholds', 'long'], 480);
  
  static int get dayThreshold => 
      _getInt(_timeSettings, ['thresholds', 'day'], 1440);
  
  static int get weekThreshold => 
      _getInt(_timeSettings, ['thresholds', 'week'], 10080);
  
  static int get monthThreshold => 
      _getInt(_timeSettings, ['thresholds', 'month'], 43200);
  
  static double getGreetingIntensity(String label) {
    final intensity = _timeSettings?['greeting']?['intensity'];
    if (intensity == null || intensity is! Map) return 0.0;
    return _toDouble(intensity[label]) ?? 0.0;
  }
  
  static List<String> get acknowledgeAbsenceGaps {
    final gaps = _timeSettings?['greeting']?['acknowledge_absence'];
    if (gaps is List) return gaps.map((e) => e.toString()).toList();
    return ['long_gap', 'day_gap', 'week_gap', 'long_absence'];
  }
  
  static double getReunionMoodBonus(String label) {
    final bonus = _timeSettings?['greeting']?['reunion_mood_bonus'];
    if (bonus == null || bonus is! Map) return 0.0;
    return _toDouble(bonus[label]) ?? 0.0;
  }
  
  static double get intimacyGrowthRate => 
      _getDouble(_timeSettings, ['intimacy', 'growth_rate'], 0.01);
  
  static double get intimacyDecayRate => 
      _getDouble(_timeSettings, ['intimacy', 'decay_rate'], 0.005);
  
  // ========== Response Settings ==========
  
  static String get separator => 
      _getString(_responseSettings, ['splitting', 'separator'], '|||');
  
  static int get maxParts => 
      _getInt(_responseSettings, ['splitting', 'max_parts'], 5);
  
  static int get maxSingleLength => 
      _getInt(_responseSettings, ['splitting', 'max_single_length'], 100);
  
  static double get firstDelayBase => 
      _getDouble(_responseSettings, ['timing', 'first_delay', 'base'], 0.5);
  
  static double get typingSpeed => 
      _getDouble(_responseSettings, ['timing', 'first_delay', 'typing_speed'], 80);
  
  static double get arousalFactor => 
      _getDouble(_responseSettings, ['timing', 'first_delay', 'arousal_factor'], 0.3);
  
  static double get firstDelayMin => 
      _getDouble(_responseSettings, ['timing', 'first_delay', 'min'], 0.3);
  
  static double get firstDelayMax => 
      _getDouble(_responseSettings, ['timing', 'first_delay', 'max'], 3.0);
  
  static double get intervalBase => 
      _getDouble(_responseSettings, ['timing', 'interval', 'base'], 0.8);
  
  static double get intervalRandomMin => 
      _getDouble(_responseSettings, ['timing', 'interval', 'random_min'], 0.2);
  
  static double get intervalRandomMax => 
      _getDouble(_responseSettings, ['timing', 'interval', 'random_max'], 0.8);
  
  static double get perCharDelay => 
      _getDouble(_responseSettings, ['timing', 'interval', 'per_char'], 0.02);
  
  static double get highArousalThreshold => 
      _getDouble(_responseSettings, ['emotion_effects', 'high_arousal_threshold'], 0.6);
  
  static double get splitProbabilityBonus => 
      _getDouble(_responseSettings, ['emotion_effects', 'split_probability_bonus'], 0.3);

  static List<String> get meltdownResponses {
    final list = _responseSettings?['emotion_effects']?['meltdown_responses'];
    if (list is List) return list.map((e) => e.toString()).toList();
    return ['......', '我不想说话了'];
  }
  
  // ========== Memory Settings ==========
  
  /// 记忆重要性阈值 (0.0-1.0)，只有超过此阈值的信息才会被存入长期记忆
  static double get memoryImportanceThreshold => 
      _getDouble(_memorySettings, ['storage', 'importance_threshold'], 0.6);
  
  /// 每个用户最大记忆条数限制
  static int get maxMemoriesPerUser => 
      _getInt(_memorySettings, ['storage', 'max_memories_per_user'], 100);
  
  /// 记忆衰减周期（天）
  static int get memoryDecayDays => 
      _getInt(_memorySettings, ['storage', 'decay_days'], 30);
  
  /// 重要性评估基础分数
  static double get memoryBaseScore => 
      _getDouble(_memorySettings, ['importance', 'base_score'], 0.3);
  
  /// 高情感价值阈值
  static double get memoryEmotionalThreshold => 
      _getDouble(_memorySettings, ['importance', 'emotional_threshold'], 0.6);
  
  /// 偏好关键词列表 - 用于提取用户偏好相关信息
  static List<String> get preferenceKeywords {
    final keywords = _memorySettings?['importance']?['preference_keywords'];
    if (keywords is List) {
      return keywords.map((e) => e.toString()).toList();
    }
    // 默认偏好关键词
    return ['喜欢', '讨厌', '最爱', '不喜欢', '偏好', '习惯', '希望', '想要'];
  }
  
  // ========== Fact Schema Settings ==========
  
  /// 获取所有事实类型定义
  static Map<String, dynamic> get factTypes {
    final types = _factSchemaSettings?['fact_types'];
    if (types is Map) return Map<String, dynamic>.from(types);
    return {};
  }
  
  /// 获取特定类型的关键词列表
  static List<String> getFactKeywords(String typeKey) {
    final typeData = factTypes[typeKey];
    if (typeData is Map && typeData['keywords'] is List) {
      return (typeData['keywords'] as List).map((e) => e.toString()).toList();
    }
    return [];
  }
  
  /// 获取所有类型的关键词映射 {keyword -> storage_key}
  /// 按关键词长度降序排序，确保长词优先匹配
  static Map<String, String> get keywordToStorageKey {
    final result = <String, String>{};
    final entries = <MapEntry<String, String>>[];
    
    for (final entry in factTypes.entries) {
      final typeData = entry.value;
      if (typeData is Map) {
        final storageKey = typeData['storage_key']?.toString() ?? entry.key;
        final keywords = typeData['keywords'];
        if (keywords is List) {
          for (final kw in keywords) {
            entries.add(MapEntry(kw.toString(), storageKey));
          }
        }
      }
    }
    
    // 按关键词长度降序排序
    entries.sort((a, b) => b.key.length.compareTo(a.key.length));
    for (final e in entries) {
      result[e.key] = e.value;
    }
    
    return result;
  }
  
  /// 获取类型描述（用于 LLM Prompt）
  static String getFactDescription(String typeKey) {
    final typeData = factTypes[typeKey];
    if (typeData is Map) {
      return typeData['description']?.toString() ?? typeKey;
    }
    return typeKey;
  }
  
  /// 获取类型过期天数
  static int getFactExpiryDays(String typeKey) {
    final typeData = factTypes[typeKey];
    if (typeData is Map && typeData['expiry_days'] is int) {
      return typeData['expiry_days'] as int;
    }
    return 90; // 默认 90 天
  }
  
  /// 获取 LLM 提取置信度阈值
  static int get llmConfidenceThreshold =>
      _getInt(_factSchemaSettings, ['llm_extraction', 'confidence_threshold'], 6);
  
  /// 获取所有类型的完整描述（用于 LLM Prompt 注入）
  static String get factTypeDescriptionsForPrompt {
    final buffer = StringBuffer();
    for (final entry in factTypes.entries) {
      final typeData = entry.value;
      if (typeData is Map) {
        final desc = typeData['description']?.toString() ?? entry.key;
        buffer.writeln('- ${entry.key}: $desc');
      }
    }
    return buffer.toString();
  }
  
  /// 获取特定类型的置信度阈值（默认使用全局阈值）
  static int getFactConfidenceThreshold(String typeKey) {
    final typeData = factTypes[typeKey];
    if (typeData is Map && typeData['confidence_threshold'] is int) {
      return typeData['confidence_threshold'] as int;
    }
    return llmConfidenceThreshold; // 回退到全局阈值
  }
  
  /// 获取特定类型的衰减率（0-1，默认 0.1）
  static double getFactDecayRate(String typeKey) {
    final typeData = factTypes[typeKey];
    if (typeData is Map) {
      final rate = typeData['decay_rate'];
      if (rate is double) return rate;
      if (rate is int) return rate.toDouble();
    }
    return 0.1; // 默认衰减率
  }
  
  /// 获取特定类型的提取正则模式列表
  static List<String> getFactPatterns(String typeKey) {
    final typeData = factTypes[typeKey];
    if (typeData is Map && typeData['patterns'] is List) {
      return (typeData['patterns'] as List).map((e) => e.toString()).toList();
    }
    return [];
  }
  
  /// 获取所有类型的正则模式（用于动态构建提取器）
  static Map<String, List<RegExp>> get allFactPatterns {
    final result = <String, List<RegExp>>{};
    for (final entry in factTypes.entries) {
      final typeData = entry.value;
      if (typeData is Map) {
        final storageKey = typeData['storage_key']?.toString() ?? entry.key;
        final patterns = typeData['patterns'];
        if (patterns is List && patterns.isNotEmpty) {
          result[storageKey] = patterns
              .map((p) {
                try {
                  return RegExp(p.toString());
                } catch (_) {
                  return null;
                }
              })
              .whereType<RegExp>()
              .toList();
        }
      }
    }
    return result;
  }
  
  /// 通过 storage_key 反查类型名
  static String? getTypeKeyByStorageKey(String storageKey) {
    for (final entry in factTypes.entries) {
      final typeData = entry.value;
      if (typeData is Map && typeData['storage_key'] == storageKey) {
        return entry.key;
      }
    }
    return null;
  }
  
  // ========== Helper Methods ==========
  
  static double _getDouble(Map<String, dynamic>? map, List<String> path, double defaultValue) {
    dynamic value = map;
    for (final key in path) {
      if (value is! Map) return defaultValue;
      value = value[key];
    }
    return _toDouble(value) ?? defaultValue;
  }
  
  static int _getInt(Map<String, dynamic>? map, List<String> path, int defaultValue) {
    dynamic value = map;
    for (final key in path) {
      if (value is! Map) return defaultValue;
      value = value[key];
    }
    if (value is int) return value;
    if (value is double) return value.toInt();
    return defaultValue;
  }
  
  static String _getString(Map<String, dynamic>? map, List<String> path, String defaultValue) {
    dynamic value = map;
    for (final key in path) {
      if (value is! Map) return defaultValue;
      value = value[key];
    }
    return value?.toString() ?? defaultValue;
  }
  // ========== Prompt Settings ==========

  static Future<PromptConfig> _loadPromptConfig() async {
    return await PromptConfig.load();
  }
  
  static PromptConfig? _promptConfig;
  static PromptConfig get prompt => _promptConfig!;

  // 在 loadAll 中添加:
  // _promptConfig = await _loadPromptConfig();

  static double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
