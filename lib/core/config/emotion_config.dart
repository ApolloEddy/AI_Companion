/// 情绪系统强类型配置
/// 对应 assets/settings/emotion_settings.yaml
class EmotionConfig {
  // 初始状态
  final double initialValence;
  final double initialArousal;
  final double initialResentment;

  // 衰减参数
  final double valenceDecayRate;
  final double arousalDecayRate;
  final double resentmentDecayFactor;

  // 更新参数
  final double baseValenceChange;
  final double baseArousalChange;
  final double intimacyBufferFactor;
  final double boundarySoftness;
  final double llmHintWeight;
  final double resentmentIncrease;
  final double resentmentSuppressionFactor;
  final double fatigueArousalThreshold;
  final double fatigueDampeningFactor;
  final List<String> negativeKeywords;

  // 阈值
  final double highEmotionalIntensity;
  final double meltdownArousalThreshold;
  final double meltdownValenceThreshold;

  const EmotionConfig({
    this.initialValence = 0.1,
    this.initialArousal = 0.5,
    this.initialResentment = 0.0,
    this.valenceDecayRate = 0.05,
    this.arousalDecayRate = 0.08,
    this.resentmentDecayFactor = 0.95,
    this.baseValenceChange = 0.05,
    this.baseArousalChange = 0.08,
    this.intimacyBufferFactor = 0.5,
    this.boundarySoftness = 0.1,
    this.llmHintWeight = 0.2,
    this.resentmentIncrease = 0.1,
    this.resentmentSuppressionFactor = 0.8,
    this.fatigueArousalThreshold = 0.8,
    this.fatigueDampeningFactor = 0.5,
    this.negativeKeywords = const ['不', '别', '讨厌', '烦', '滚', '闭嘴'],
    this.highEmotionalIntensity = 0.6,
    this.meltdownArousalThreshold = 0.85,
    this.meltdownValenceThreshold = -0.75,
  });

  factory EmotionConfig.fromYaml(Map<String, dynamic> yaml) {
    final initial = yaml['initial'] as Map<String, dynamic>? ?? {};
    final decay = yaml['decay'] as Map<String, dynamic>? ?? {};
    final update = yaml['update'] as Map<String, dynamic>? ?? {};
    final thresholds = yaml['thresholds'] as Map<String, dynamic>? ?? {};

    return EmotionConfig(
      initialValence: _toDouble(initial['valence']) ?? 0.1,
      initialArousal: _toDouble(initial['arousal']) ?? 0.5,
      initialResentment: _toDouble(initial['resentment']) ?? 0.0,
      valenceDecayRate: _toDouble(decay['valence_rate']) ?? 0.05,
      arousalDecayRate: _toDouble(decay['arousal_rate']) ?? 0.08,
      resentmentDecayFactor: _toDouble(decay['resentment_decay_factor']) ?? 0.95,
      baseValenceChange: _toDouble(update['base_valence_change']) ?? 0.05,
      baseArousalChange: _toDouble(update['base_arousal_change']) ?? 0.08,
      intimacyBufferFactor: _toDouble(update['intimacy_buffer_factor']) ?? 0.5,
      boundarySoftness: _toDouble(update['boundary_softness']) ?? 0.1,
      llmHintWeight: _toDouble(update['llm_hint_weight']) ?? 0.2,
      resentmentIncrease: _toDouble(update['resentment_increase']) ?? 0.1,
      resentmentSuppressionFactor: _toDouble(update['resentment_suppression_factor']) ?? 0.8,
      fatigueArousalThreshold: _toDouble(update['fatigue_arousal_threshold']) ?? 0.8,
      fatigueDampeningFactor: _toDouble(update['fatigue_dampening_factor']) ?? 0.5,
      negativeKeywords: _toStringList(update['negative_keywords']) ?? const ['不', '别', '讨厌', '烦', '滚', '闭嘴'],
      highEmotionalIntensity: _toDouble(thresholds['high_emotional_intensity']) ?? 0.6,
      meltdownArousalThreshold: _toDouble(thresholds['meltdown_arousal']) ?? 0.85,
      meltdownValenceThreshold: _toDouble(thresholds['meltdown_valence_negative']) ?? -0.75,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  static List<String>? _toStringList(dynamic value) {
    if (value is List) return value.map((e) => e.toString()).toList();
    return null;
  }
}
