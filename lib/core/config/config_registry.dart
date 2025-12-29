// ConfigRegistry - 统一配置注册表
//
// 设计原理：
// - 单例服务，统一管理所有 YAML 配置
// - 提供类型安全的访问接口
// - 支持配置热重载

import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

/// 情绪配置模型
class EmotionConfig {
  final String id;
  final String label;
  final double defaultValence;
  final double defaultArousal;

  const EmotionConfig({
    required this.id,
    required this.label,
    required this.defaultValence,
    required this.defaultArousal,
  });

  factory EmotionConfig.fromMap(Map<String, dynamic> map) {
    return EmotionConfig(
      id: map['id']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      defaultValence: (map['default_valence'] ?? 0.0).toDouble(),
      defaultArousal: (map['default_arousal'] ?? 0.5).toDouble(),
    );
  }
}

/// 需求配置模型
class NeedConfig {
  final String id;
  final String label;
  final String promptDesc;

  const NeedConfig({
    required this.id,
    required this.label,
    required this.promptDesc,
  });

  factory NeedConfig.fromMap(Map<String, dynamic> map) {
    return NeedConfig(
      id: map['id']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      promptDesc: map['prompt_desc']?.toString() ?? '',
    );
  }
}

/// 意图配置模型
class IntentConfig {
  final String id;
  final String label;

  const IntentConfig({required this.id, required this.label});

  factory IntentConfig.fromMap(Map<String, dynamic> map) {
    return IntentConfig(
      id: map['id']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
    );
  }
}

/// 社交事件配置模型
class SocialEventConfig {
  final String id;
  final String label;
  final String description;
  final List<String> keywords;
  final bool requiresContext;

  const SocialEventConfig({
    required this.id,
    required this.label,
    required this.description,
    required this.keywords,
    this.requiresContext = false,
  });

  factory SocialEventConfig.fromMap(Map<String, dynamic> map) {
    final keywords = (map['keywords'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        [];
    return SocialEventConfig(
      id: map['id']?.toString() ?? '',
      label: map['label']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
      keywords: keywords,
      requiresContext: map['requires_context'] ?? false,
    );
  }
}

/// 微情绪触发规则
class MicroEmotionRule {
  final String id;
  final String triggerEvent;
  final String? condition;
  final int priority;
  final String microEmotion;
  final String innerThought;
  final String strategy;
  final String toneOverride;

  const MicroEmotionRule({
    required this.id,
    required this.triggerEvent,
    this.condition,
    required this.priority,
    required this.microEmotion,
    required this.innerThought,
    required this.strategy,
    required this.toneOverride,
  });

  factory MicroEmotionRule.fromMap(Map<String, dynamic> map) {
    final action = map['action'] as Map? ?? {};
    return MicroEmotionRule(
      id: map['id']?.toString() ?? '',
      triggerEvent: map['trigger_event']?.toString() ?? '',
      condition: map['condition']?.toString(),
      priority: (map['priority'] ?? 0) as int,
      microEmotion: action['micro_emotion']?.toString() ?? '',
      innerThought: action['inner_thought']?.toString() ?? '',
      strategy: action['strategy']?.toString() ?? '',
      toneOverride: action['tone_override']?.toString() ?? '',
    );
  }
}

/// 需求策略配置
class NeedStrategyConfig {
  final String strategy;
  final String tone;
  final double recommendedLength;
  final bool useEmoji;
  final List<String> hints;

  const NeedStrategyConfig({
    required this.strategy,
    required this.tone,
    required this.recommendedLength,
    required this.useEmoji,
    required this.hints,
  });

  factory NeedStrategyConfig.fromMap(Map<String, dynamic> map) {
    return NeedStrategyConfig(
      strategy: map['strategy']?.toString() ?? '',
      tone: map['tone']?.toString() ?? '',
      recommendedLength: (map['recommended_length'] ?? 0.5).toDouble(),
      useEmoji: map['use_emoji'] ?? false,
      hints: (map['hints'] as List?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

/// 微情绪表达模板
class MicroEmotionTemplate {
  final String tone;
  final String guide;

  const MicroEmotionTemplate({required this.tone, required this.guide});

  factory MicroEmotionTemplate.fromMap(Map<String, dynamic> map) {
    return MicroEmotionTemplate(
      tone: map['tone']?.toString() ?? '',
      guide: map['guide']?.toString() ?? '',
    );
  }
}

/// 禁忌思维模式
class ProhibitedPatternConfig {
  final String pattern;
  final String replacement;

  const ProhibitedPatternConfig({
    required this.pattern,
    required this.replacement,
  });

  factory ProhibitedPatternConfig.fromMap(Map<String, dynamic> map) {
    return ProhibitedPatternConfig(
      pattern: map['pattern']?.toString() ?? '',
      replacement: map['replacement']?.toString() ?? '',
    );
  }
}

/// 统一配置注册表
class ConfigRegistry {
  static ConfigRegistry? _instance;
  static ConfigRegistry get instance => _instance ??= ConfigRegistry._();

  ConfigRegistry._();

  // 配置缓存
  Map<String, dynamic>? _perceptionModel;
  Map<String, dynamic>? _reactionRules;
  Map<String, dynamic>? _expressionStyles;
  Map<String, dynamic>? _promptTemplates;

  // 解析后的对象缓存
  List<EmotionConfig>? _emotions;
  List<NeedConfig>? _needs;
  List<IntentConfig>? _intents;
  List<SocialEventConfig>? _socialEvents;
  List<MicroEmotionRule>? _microEmotionRules;
  Map<String, NeedStrategyConfig>? _needStrategies;
  Map<String, MicroEmotionTemplate>? _microEmotionTemplates;
  List<ProhibitedPatternConfig>? _prohibitedPatterns;

  bool _isLoaded = false;

  /// 加载所有配置
  Future<void> loadAll() async {
    if (_isLoaded) return;

    _perceptionModel = await _loadYaml('assets/configuration/perception_model.yaml');
    _reactionRules = await _loadYaml('assets/configuration/reaction_rules.yaml');
    _expressionStyles = await _loadYaml('assets/configuration/expression_styles.yaml');
    _promptTemplates = await _loadYaml('assets/configuration/prompt_templates.yaml');

    _parseConfigs();
    _isLoaded = true;
    print('[ConfigRegistry] 配置加载完成');
  }

  /// 解析配置到类型安全对象
  void _parseConfigs() {
    // 解析感知模型
    final emotionsList = _perceptionModel?['emotions'] as List? ?? [];
    _emotions = emotionsList
        .map((e) => EmotionConfig.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    final needsList = _perceptionModel?['needs'] as List? ?? [];
    _needs = needsList
        .map((e) => NeedConfig.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    final intentsList = _perceptionModel?['intents'] as List? ?? [];
    _intents = intentsList
        .map((e) => IntentConfig.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    final eventsList = _perceptionModel?['social_events'] as List? ?? [];
    _socialEvents = eventsList
        .map((e) => SocialEventConfig.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    // 解析反应规则
    final rulesList = _reactionRules?['micro_emotion_rules'] as List? ?? [];
    _microEmotionRules = rulesList
        .map((e) => MicroEmotionRule.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    final strategiesMap = _reactionRules?['need_strategies'] as Map? ?? {};
    _needStrategies = {};
    strategiesMap.forEach((key, value) {
      _needStrategies![key.toString()] =
          NeedStrategyConfig.fromMap(Map<String, dynamic>.from(value));
    });

    final prohibitedList = _reactionRules?['prohibited_patterns'] as List? ?? [];
    _prohibitedPatterns = prohibitedList
        .map((e) => ProhibitedPatternConfig.fromMap(Map<String, dynamic>.from(e)))
        .toList();

    // 解析表达风格
    final templatesMap = _expressionStyles?['micro_emotion_templates'] as Map? ?? {};
    _microEmotionTemplates = {};
    templatesMap.forEach((key, value) {
      _microEmotionTemplates![key.toString()] =
          MicroEmotionTemplate.fromMap(Map<String, dynamic>.from(value));
    });
  }

  // ========== 感知模型访问器 ==========

  /// 获取所有情绪配置
  List<EmotionConfig> get emotions => _emotions ?? [];

  /// 根据 ID 获取情绪配置
  EmotionConfig? getEmotion(String id) {
    return _emotions?.firstWhere((e) => e.id == id,
        orElse: () => EmotionConfig(
              id: id,
              label: id,
              defaultValence: 0.0,
              defaultArousal: 0.5,
            ));
  }

  /// 根据标签获取情绪 ID
  String? getEmotionIdByLabel(String label) {
    return _emotions?.firstWhere((e) => e.label == label,
        orElse: () => EmotionConfig(
              id: 'calm',
              label: label,
              defaultValence: 0.0,
              defaultArousal: 0.5,
            )).id;
  }

  /// 获取所有情绪标签（用于 Prompt 注入）
  String get emotionLabelsForPrompt {
    return emotions.map((e) => e.label).join('/');
  }

  /// 获取所有需求配置
  List<NeedConfig> get needs => _needs ?? [];

  /// 根据 ID 获取需求配置
  NeedConfig? getNeed(String id) {
    return _needs?.firstWhere((e) => e.id == id,
        orElse: () => NeedConfig(id: id, label: id, promptDesc: ''));
  }

  /// 根据标签获取需求 ID
  String? getNeedIdByLabel(String label) {
    return _needs?.firstWhere((e) => e.label == label,
        orElse: () => NeedConfig(id: 'chat', label: label, promptDesc: '')).id;
  }

  /// 获取需求选项（用于 Prompt 注入）
  String get needOptionsForPrompt {
    return needs.map((e) => '- ${e.label}：${e.promptDesc}').join('\n     ');
  }

  /// 获取所有意图配置
  List<IntentConfig> get intents => _intents ?? [];

  /// 获取意图选项（用于 Prompt 注入）
  String get intentOptionsForPrompt {
    return intents.map((e) => '- ${e.label}').join('\n     ');
  }

  /// 获取所有社交事件配置
  List<SocialEventConfig> get socialEvents => _socialEvents ?? [];

  /// 获取社交事件描述（用于 Prompt 注入）
  String get socialEventDescriptionsForPrompt {
    return socialEvents
        .map((e) => '- ${e.id}: ${e.description}')
        .join('\n     ');
  }

  /// 获取快速分析关键词
  Map<String, List<String>> get emotionKeywords {
    final keywords = _perceptionModel?['quick_analysis']?['emotion_keywords'] as Map?;
    if (keywords == null) return {};
    final result = <String, List<String>>{};
    keywords.forEach((key, value) {
      if (value is List) {
        result[key.toString()] = value.map((e) => e.toString()).toList();
      }
    });
    return result;
  }

  /// 获取结束对话关键词
  List<String> get endConversationKeywords {
    final keywords = _perceptionModel?['quick_analysis']?['end_conversation_keywords'] as List?;
    return keywords?.map((e) => e.toString()).toList() ?? [];
  }

  // ========== 反应规则访问器 ==========

  /// 获取所有微情绪规则
  List<MicroEmotionRule> get microEmotionRules => _microEmotionRules ?? [];

  /// 根据触发事件获取规则
  List<MicroEmotionRule> getRulesByTrigger(String triggerEvent) {
    return microEmotionRules
        .where((r) => r.triggerEvent == triggerEvent)
        .toList()
      ..sort((a, b) => b.priority.compareTo(a.priority));
  }

  /// 获取需求策略
  NeedStrategyConfig? getNeedStrategy(String needId) {
    return _needStrategies?[needId];
  }

  /// 获取所有禁忌思维模式
  List<ProhibitedPatternConfig> get prohibitedPatterns => _prohibitedPatterns ?? [];

  /// 获取禁忌思维（用于 Prompt 注入）
  String get prohibitedPatternsForPrompt {
    return prohibitedPatterns
        .map((p) => 'x "${p.pattern}" -> 替换为："${p.replacement}"')
        .join('\n');
  }

  // ========== 表达风格访问器 ==========

  /// 获取微情绪表达模板
  MicroEmotionTemplate? getMicroEmotionTemplate(String microEmotion) {
    return _microEmotionTemplates?[microEmotion];
  }

  /// 获取长度规则配置
  Map<String, dynamic> get lengthRulesConfig {
    return Map<String, dynamic>.from(_expressionStyles?['length_rules'] ?? {});
  }

  /// 获取自然表达要点
  List<String> get naturalExpressionGuidelines {
    final guidelines = _expressionStyles?['natural_expression'] as List?;
    return guidelines?.map((e) => e.toString()).toList() ?? [];
  }

  /// 获取禁止书面化词汇
  List<String> get antiBookishConnectors {
    final connectors = _expressionStyles?['anti_bookish']?['forbidden_connectors'] as List?;
    return connectors?.map((e) => e.toString()).toList() ?? [];
  }

  /// 获取禁止书面化指令
  String get antiBookishInstruction {
    return _expressionStyles?['anti_bookish']?['instruction']?.toString() ?? '';
  }

  // ========== Prompt 模板访问器 ==========

  /// 获取 Prompt 模板
  String getPromptTemplate(String key) {
    return _promptTemplates?[key]?.toString() ?? '';
  }

  // ========== 私有方法 ==========

  Future<Map<String, dynamic>> _loadYaml(String path) async {
    try {
      final content = await rootBundle.loadString(path);
      final yamlMap = loadYaml(content);
      return _convertYaml(yamlMap);
    } catch (e) {
      print('[ConfigRegistry] 加载配置失败 $path: $e');
      return {};
    }
  }

  dynamic _convertYaml(dynamic yaml) {
    if (yaml is YamlMap) {
      return Map<String, dynamic>.fromEntries(
          yaml.entries.map((e) => MapEntry(e.key.toString(), _convertYaml(e.value))));
    } else if (yaml is YamlList) {
      return yaml.map((e) => _convertYaml(e)).toList();
    } else {
      return yaml;
    }
  }
}
