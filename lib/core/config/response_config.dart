/// 回复格式强类型配置
/// 对应 assets/settings/response_settings.yaml
class ResponseConfig {
  // 分割配置
  final String separator;
  final int maxParts;
  final int maxSingleLength;

  // 时间配置 - 首条延迟
  final double firstDelayBase;
  final double typingSpeed;
  final double arousalFactor;
  final double firstDelayMin;
  final double firstDelayMax;

  // 时间配置 - 分条间隔
  final double intervalBase;
  final double intervalRandomMin;
  final double intervalRandomMax;
  final double perCharDelay;

  // 情感影响
  final double highArousalThreshold;
  final double splitProbabilityBonus;

  // Meltdown 配置
  final String meltdownStrategy;
  final String meltdownMonologue;
  final List<String> meltdownResponses;

  const ResponseConfig({
    this.separator = '|||',
    this.maxParts = 5,
    this.maxSingleLength = 100,
    this.firstDelayBase = 0.5,
    this.typingSpeed = 80,
    this.arousalFactor = 0.3,
    this.firstDelayMin = 0.3,
    this.firstDelayMax = 3.0,
    this.intervalBase = 0.8,
    this.intervalRandomMin = 0.2,
    this.intervalRandomMax = 0.8,
    this.perCharDelay = 0.02,
    this.highArousalThreshold = 0.6,
    this.splitProbabilityBonus = 0.3,
    this.meltdownStrategy = 'collapse',
    this.meltdownMonologue = '（情绪崩溃中，无法正常思考）',
    this.meltdownResponses = const ['......', '我不想说话了'],
  });

  factory ResponseConfig.fromYaml(Map<String, dynamic> yaml) {
    final splitting = yaml['splitting'] as Map<String, dynamic>? ?? {};
    final timing = yaml['timing'] as Map<String, dynamic>? ?? {};
    final firstDelay = timing['first_delay'] as Map<String, dynamic>? ?? {};
    final interval = timing['interval'] as Map<String, dynamic>? ?? {};
    final emotionEffects = yaml['emotion_effects'] as Map<String, dynamic>? ?? {};

    return ResponseConfig(
      separator: splitting['separator']?.toString() ?? '|||',
      maxParts: _toInt(splitting['max_parts']) ?? 5,
      maxSingleLength: _toInt(splitting['max_single_length']) ?? 100,
      firstDelayBase: _toDouble(firstDelay['base']) ?? 0.5,
      typingSpeed: _toDouble(firstDelay['typing_speed']) ?? 80,
      arousalFactor: _toDouble(firstDelay['arousal_factor']) ?? 0.3,
      firstDelayMin: _toDouble(firstDelay['min']) ?? 0.3,
      firstDelayMax: _toDouble(firstDelay['max']) ?? 3.0,
      intervalBase: _toDouble(interval['base']) ?? 0.8,
      intervalRandomMin: _toDouble(interval['random_min']) ?? 0.2,
      intervalRandomMax: _toDouble(interval['random_max']) ?? 0.8,
      perCharDelay: _toDouble(interval['per_char']) ?? 0.02,
      highArousalThreshold: _toDouble(emotionEffects['high_arousal_threshold']) ?? 0.6,
      splitProbabilityBonus: _toDouble(emotionEffects['split_probability_bonus']) ?? 0.3,
      meltdownStrategy: emotionEffects['meltdown_strategy']?.toString() ?? 'collapse',
      meltdownMonologue: emotionEffects['meltdown_monologue']?.toString() ?? '（情绪崩溃中，无法正常思考）',
      meltdownResponses: _toStringList(emotionEffects['meltdown_responses']) ?? const ['......', '我不想说话了'],
    );
  }

  static double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static int? _toInt(dynamic value) {
    if (value is int) return value;
    if (value is double) return value.toInt();
    return null;
  }

  static List<String>? _toStringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return null;
  }
}
