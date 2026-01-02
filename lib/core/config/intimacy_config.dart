/// 亲密度系统强类型配置
/// 对应 assets/settings/intimacy_settings.yaml
class IntimacyConfig {
  // 初始状态
  final double initialIntimacy;
  final double initialGrowthCoefficient;

  // 增长配置
  final double baseCoefficient;
  final double diminishingPower;
  final double maxGrowthPerInteraction;

  // 冷却配置
  final double coolingFactorPerHour;
  final double minFactor;
  final double negativeEventMultiplier;
  final double baseCoolingHours;
  final double severityCoolingHours;

  // 回归配置
  final double baseRatePerHour;
  final double negativeSeverityMultiplier;
  final double minIntimacy;

  // Prompt 风格参数
  final double proactivityMin;
  final double proactivityMax;
  final double implicationRatioMin;
  final double implicationRatioMax;

  // 阈值
  final double lowThreshold;
  final double highThreshold;

  const IntimacyConfig({
    this.initialIntimacy = 0.1,
    this.initialGrowthCoefficient = 1.0,
    this.baseCoefficient = 0.02,
    this.diminishingPower = 0.5,
    this.maxGrowthPerInteraction = 0.05,
    this.coolingFactorPerHour = 0.05,
    this.minFactor = 0.2,
    this.negativeEventMultiplier = 0.1,
    this.baseCoolingHours = 2,
    this.severityCoolingHours = 6,
    this.baseRatePerHour = 0.001,
    this.negativeSeverityMultiplier = 0.5,
    this.minIntimacy = 0.05,
    this.proactivityMin = 0.3,
    this.proactivityMax = 0.9,
    this.implicationRatioMin = 0.2,
    this.implicationRatioMax = 0.8,
    this.lowThreshold = 0.3,
    this.highThreshold = 0.7,
  });

  factory IntimacyConfig.fromYaml(Map<String, dynamic> yaml) {
    final initial = yaml['initial'] as Map<String, dynamic>? ?? {};
    final growth = yaml['growth'] as Map<String, dynamic>? ?? {};
    final cooling = yaml['cooling'] as Map<String, dynamic>? ?? {};
    final regression = yaml['regression'] as Map<String, dynamic>? ?? {};
    final promptStyle = yaml['prompt_style'] as Map<String, dynamic>? ?? {};
    final thresholds = yaml['thresholds'] as Map<String, dynamic>? ?? {};

    return IntimacyConfig(
      initialIntimacy: _toDouble(initial['intimacy']) ?? 0.1,
      initialGrowthCoefficient: _toDouble(initial['growth_coefficient']) ?? 1.0,
      baseCoefficient: _toDouble(growth['base_coefficient']) ?? 0.02,
      diminishingPower: _toDouble(growth['diminishing_power']) ?? 0.5,
      maxGrowthPerInteraction: _toDouble(growth['max_growth_per_interaction']) ?? 0.05,
      coolingFactorPerHour: _toDouble(cooling['factor_per_hour']) ?? 0.05,
      minFactor: _toDouble(cooling['min_factor']) ?? 0.2,
      negativeEventMultiplier: _toDouble(cooling['negative_event_multiplier']) ?? 0.1,
      baseCoolingHours: _toDouble(cooling['base_cooling_hours']) ?? 2,
      severityCoolingHours: _toDouble(cooling['severity_cooling_hours']) ?? 6,
      baseRatePerHour: _toDouble(regression['base_rate_per_hour']) ?? 0.001,
      negativeSeverityMultiplier: _toDouble(regression['negative_severity_multiplier']) ?? 0.5,
      minIntimacy: _toDouble(regression['min_intimacy']) ?? 0.05,
      proactivityMin: _toDouble(promptStyle['proactivity_min']) ?? 0.3,
      proactivityMax: _toDouble(promptStyle['proactivity_max']) ?? 0.9,
      implicationRatioMin: _toDouble(promptStyle['implication_ratio_min']) ?? 0.2,
      implicationRatioMax: _toDouble(promptStyle['implication_ratio_max']) ?? 0.8,
      lowThreshold: _toDouble(thresholds['low']) ?? 0.3,
      highThreshold: _toDouble(thresholds['high']) ?? 0.7,
    );
  }

  static double? _toDouble(dynamic value) {
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }
}
