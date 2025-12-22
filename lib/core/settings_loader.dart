import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

/// 动态设置加载器 - 从 YAML 文件读取配置
class SettingsLoader {
  static Map<String, dynamic>? _personaSettings;
  static Map<String, dynamic>? _emotionSettings;
  static Map<String, dynamic>? _timeSettings;
  static Map<String, dynamic>? _responseSettings;
  
  static bool _isLoaded = false;
  
  static Future<void> loadAll() async {
    if (_isLoaded) return;
    
    _personaSettings = await _loadYaml('assets/settings/persona_settings.yaml');
    _emotionSettings = await _loadYaml('assets/settings/emotion_settings.yaml');
    _timeSettings = await _loadYaml('assets/settings/time_settings.yaml');
    _responseSettings = await _loadYaml('assets/settings/response_settings.yaml');
    
    _isLoaded = true;
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
      _getDouble(_personaSettings, ['intimacy_effects', 'low_threshold'], 0.3);
  
  static double get intimacyHighThreshold => 
      _getDouble(_personaSettings, ['intimacy_effects', 'high_threshold'], 0.7);
  
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
  
  static double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
