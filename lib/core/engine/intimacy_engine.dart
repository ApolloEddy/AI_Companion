// IntimacyEngine - 亲密度连续态模型引擎
//
// 设计原理：
// - 替代离散亲密度等级，实现数学驱动的连续状态模型
// - 非线性增长公式：ΔI = Q × E × T × B(I)
// - 负反馈机制：不直接扣减，而是降低增长系数 + 增加回归概率
// - 时间冷却：控制增长速率的时间因子
//
// 公式说明：
// - InteractionQuality (Q): 交互质量分数 (0.5~1.5)
// - EmotionMultiplier (E): 情绪影响因子 = 1 + valence × 0.3
// - TimeFactor (T): 时间冷却因子 = max(0.2, 1 - hoursSinceLastInteraction × 0.05)
// - BandFunction B(I): 递减边际收益 = (1 - I)^0.5 × baseCoefficient

import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../settings_loader.dart';

/// 亲密度状态快照
class IntimacyState {
  final double intimacy;          // 当前亲密度 (0~1)
  final double growthCoefficient; // 增长系数 (受负反馈影响)
  final double growthEfficiency;  // 当前增长效率 (用于 UI 显示)
  final DateTime? coolingUntil;   // 冷却期结束时间
  final DateTime lastInteraction; // 最后交互时间
  final int totalInteractions;    // 总交互次数

  const IntimacyState({
    required this.intimacy,
    required this.growthCoefficient,
    required this.growthEfficiency,
    this.coolingUntil,
    required this.lastInteraction,
    required this.totalInteractions,
  });

  /// 是否处于冷却期
  bool get isCooling => coolingUntil != null && DateTime.now().isBefore(coolingUntil!);

  /// 冷却剩余时间（分钟）
  int get coolingRemainingMinutes {
    if (coolingUntil == null) return 0;
    final remaining = coolingUntil!.difference(DateTime.now());
    return remaining.isNegative ? 0 : remaining.inMinutes;
  }

  Map<String, dynamic> toMap() {
    return {
      'intimacy': intimacy,
      'growthCoefficient': growthCoefficient,
      'growthEfficiency': growthEfficiency,
      'coolingUntil': coolingUntil?.toIso8601String(),
      'lastInteraction': lastInteraction.toIso8601String(),
      'totalInteractions': totalInteractions,
    };
  }
}

/// 亲密度引擎 - 连续态数学模型
class IntimacyEngine {
  // ========== 核心状态变量 ==========
  double _intimacy = 0.1;           // 当前亲密度
  double _growthCoefficient = 1.0;  // 增长系数 (1.0 = 正常)
  DateTime? _coolingUntil;          // 冷却期结束时间
  DateTime _lastInteraction = DateTime.now();
  int _totalInteractions = 0;

  // ========== 配置常量 ==========
  static const double _minIntimacy = 0.05;
  static const double _maxIntimacy = 1.0;
  
  // 增长配置
  static const double _baseGrowthCoefficient = 0.02;
  static const double _diminishingPower = 0.5;
  static const double _maxGrowthPerInteraction = 0.05;

  // 冷却配置
  static const double _coolingFactorPerHour = 0.05;
  static const double _minTimeFactor = 0.2;
  static const double _negativeEventMultiplier = 0.1;

  // 回归配置
  static const double _baseRegressionRatePerHour = 0.001;
  static const double _negativeSeverityMultiplier = 0.5;

  final SharedPreferences prefs;
  static const String _storageKey = 'intimacy_engine_state';

  IntimacyEngine(this.prefs) {
    _load();
  }

  // ========== 属性访问 ==========

  double get intimacy => _intimacy;
  double get growthCoefficient => _growthCoefficient;
  DateTime get lastInteraction => _lastInteraction;
  int get totalInteractions => _totalInteractions;
  bool get isCooling => _coolingUntil != null && DateTime.now().isBefore(_coolingUntil!);

  /// 获取当前状态快照
  IntimacyState get currentState => IntimacyState(
    intimacy: _intimacy,
    growthCoefficient: _growthCoefficient,
    growthEfficiency: _calculateGrowthEfficiency(),
    coolingUntil: _coolingUntil,
    lastInteraction: _lastInteraction,
    totalInteractions: _totalInteractions,
  );

  // ========== 持久化 ==========

  void _load() {
    final str = prefs.getString(_storageKey);
    if (str != null) {
      try {
        final data = jsonDecode(str);
        _intimacy = (data['intimacy'] ?? 0.1).toDouble();
        _growthCoefficient = (data['growthCoefficient'] ?? 1.0).toDouble();
        _totalInteractions = data['totalInteractions'] ?? 0;
        
        final coolingStr = data['coolingUntil'];
        if (coolingStr != null) {
          _coolingUntil = DateTime.tryParse(coolingStr);
        }
        
        final lastStr = data['lastInteraction'];
        if (lastStr != null) {
          _lastInteraction = DateTime.tryParse(lastStr) ?? DateTime.now();
        }
      } catch (e) {
        print('[IntimacyEngine] Load failed, using defaults: $e');
      }
    }
  }

  Future<void> save() async {
    final data = {
      'intimacy': _intimacy,
      'growthCoefficient': _growthCoefficient,
      'coolingUntil': _coolingUntil?.toIso8601String(),
      'lastInteraction': _lastInteraction.toIso8601String(),
      'totalInteractions': _totalInteractions,
    };
    await prefs.setString(_storageKey, jsonEncode(data));
  }

  // ========== 核心算法：非线性增长 ==========

  /// 更新亲密度
  /// 
  /// 公式: ΔI = Q × E × T × B(I)
  /// - Q: interactionQuality (0.5~1.5)
  /// - E: emotionMultiplier = 1 + valence × 0.3
  /// - T: timeFactor = max(0.2, 1 - hoursSinceLastInteraction × 0.05)
  /// - B(I): bandFunction = (1 - I)^0.5 × baseCoefficient × growthCoefficient
  Future<void> updateIntimacy({
    required double interactionQuality,
    required double emotionValence,
  }) async {
    // 如果处于冷却期，增长效率大幅降低
    double coolingPenalty = isCooling ? 0.3 : 1.0;

    // 计算各因子
    double Q = interactionQuality.clamp(0.5, 1.5);
    double E = 1.0 + emotionValence.clamp(-1.0, 1.0) * 0.3;
    double T = _calculateTimeFactor();
    double B = _calculateBandFunction();

    // 最终增长量
    double deltaI = Q * E * T * B * coolingPenalty;
    deltaI = deltaI.clamp(0, _maxGrowthPerInteraction);

    _intimacy = (_intimacy + deltaI).clamp(_minIntimacy, _maxIntimacy);
    _lastInteraction = DateTime.now();
    _totalInteractions++;

    // 增长系数缓慢恢复
    if (_growthCoefficient < 1.0) {
      _growthCoefficient = (_growthCoefficient + 0.01).clamp(0.1, 1.0);
    }

    print('[IntimacyEngine] Updated: intimacy=$_intimacy, deltaI=$deltaI, '
          'Q=$Q, E=$E, T=$T, B=$B');

    await save();
  }

  /// 计算时间冷却因子
  /// 
  /// T = max(0.2, 1 - hoursSinceLastInteraction × 0.05)
  /// 长时间不互动后，增长速率降低
  double _calculateTimeFactor() {
    final hoursPassed = DateTime.now().difference(_lastInteraction).inMinutes / 60.0;
    final factor = 1.0 - hoursPassed * _coolingFactorPerHour;
    return factor.clamp(_minTimeFactor, 1.0);
  }

  /// 计算递减边际收益函数
  /// 
  /// B(I) = (1 - I)^0.5 × baseCoefficient × growthCoefficient
  /// 亲密度越高，增长越慢
  double _calculateBandFunction() {
    return pow(1.0 - _intimacy, _diminishingPower) * 
           _baseGrowthCoefficient * 
           _growthCoefficient;
  }

  /// 计算当前增长效率 (用于 UI 显示)
  double _calculateGrowthEfficiency() {
    double T = _calculateTimeFactor();
    double B = _calculateBandFunction();
    double coolingPenalty = isCooling ? 0.3 : 1.0;
    return T * B * coolingPenalty * 100; // 转为百分比
  }

  // ========== 负反馈机制 ==========

  /// 应用负反馈
  /// 
  /// 不直接扣减亲密度，而是：
  /// 1. 降低增长系数
  /// 2. 设置冷却期
  Future<void> applyNegativeFeedback({
    required double severity, // 0~1, 严重程度
  }) async {
    severity = severity.clamp(0.0, 1.0);

    // 【Phase 7】即时扣减亲密度
    // 扣减量 = severity * 0.05 (最大扣除 0.05)
    _intimacy = (_intimacy - severity * 0.05).clamp(_minIntimacy, _maxIntimacy);

    // 降低增长系数
    double coefficientReduction = _negativeEventMultiplier * severity;
    _growthCoefficient = (_growthCoefficient - coefficientReduction).clamp(0.1, 1.0);

    // 设置冷却期: 基础 2 小时 + 严重程度 × 6 小时
    int coolingHours = (2 + severity * 6).round();
    _coolingUntil = DateTime.now().add(Duration(hours: coolingHours));

    print('[IntimacyEngine] Negative feedback applied: severity=$severity, '
          'newIntimacy=$_intimacy, newCoefficient=$_growthCoefficient, coolingHours=$coolingHours');

    await save();
  }

  // ========== 自然回归 ==========

  /// 应用自然回归
  /// 
  /// 亲密度随时间缓慢回归到稳定值
  /// 由 ConversationEngine 的 Timer 定期调用
  Future<void> applyNaturalRegression() async {
    final hoursPassed = DateTime.now().difference(_lastInteraction).inHours;
    if (hoursPassed < 1) return; // 1小时内不回归

    // 回归量 = 基础回归率 × 小时数 × (1 + 冷却期额外惩罚)
    double coolingPenalty = isCooling ? 
        (1.0 + _negativeSeverityMultiplier) : 1.0;
    double regression = _baseRegressionRatePerHour * 
                        hoursPassed.clamp(0, 24) * 
                        coolingPenalty;

    _intimacy = (_intimacy - regression).clamp(_minIntimacy, _maxIntimacy);

    // 检查冷却期是否结束
    if (_coolingUntil != null && DateTime.now().isAfter(_coolingUntil!)) {
      _coolingUntil = null;
    }

    print('[IntimacyEngine] Regression applied: hours=$hoursPassed, '
          'regression=$regression, newIntimacy=$_intimacy');

    await save();
  }

  /// 启动时的回归检查
  void applyRegressionSinceLastUpdate() {
    final hoursPassed = DateTime.now().difference(_lastInteraction).inHours;
    if (hoursPassed >= 1) {
      applyNaturalRegression();
    }
  }

  // ========== UI 数据接口 ==========

  /// 获取增长效率曲线数据 (用于稳定性监视器)
  /// 
  /// 返回不同亲密度下的增长效率
  List<Map<String, double>> getGrowthEfficiencyCurve() {
    List<Map<String, double>> curve = [];
    for (double i = 0; i <= 1.0; i += 0.1) {
      double efficiency = pow(1.0 - i, _diminishingPower) * 
                          _baseGrowthCoefficient * 
                          _growthCoefficient * 100;
      curve.add({'intimacy': i, 'efficiency': efficiency});
    }
    return curve;
  }

  /// 获取 Prompt 风格提示 (规则引擎版)
  /// 
  /// 根据亲密度计算语气风格参数
  Map<String, double> getPromptStyleHints() {
    // 主动概率: 亲密度高时更主动
    double proactivity = 0.3 + _intimacy * 0.6; // 0.3~0.9

    // 隐喻留白比: 亲密度高时可以更隐晦
    double implicationRatio = 0.2 + _intimacy * 0.6; // 0.2~0.8

    // 语言亲近度: 直接映射亲密度
    double linguisticCloseness = _intimacy;

    return {
      'proactivity': proactivity,
      'implicationRatio': implicationRatio,
      'linguisticCloseness': linguisticCloseness,
    };
  }

  // ========== 重置 ==========

  /// 重置为默认状态 (从 YAML 配置读取初始值)
  Future<void> reset() async {
    _intimacy = SettingsLoader.initialIntimacy;
    _growthCoefficient = SettingsLoader.initialGrowthCoefficient;
    _coolingUntil = null;
    _lastInteraction = DateTime.now();
    _totalInteractions = 0;
    await save();
  }
}
