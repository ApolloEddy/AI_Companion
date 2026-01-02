// PersonalityEngine - 人格进化引擎
//
// 【设计原理】
// 参考 IntimacyEngine 的架构，管理 AI 人格的长期演化。
//
// 核心机制：
// 1. **正负反馈 (Feedback Loop)**: 用户反馈 -> 修改当前激活的特质
// 2. **可塑性衰减 (Plasticity Decay)**: 交互越多，人格越稳定
// 3. **亲密度融合 (Intimacy Fusion)**: 基础人格 + 亲密度修饰 = 最终表现
//
// 重要原则：
// - 人格变化应该非常缓慢 (比亲密度慢 10-100 倍)
// - 避免因单次极端反馈导致人格剧变
// - 支持用户主动干预 (通过 UI 直接调节)

import 'dart:math';
import 'package:flutter/foundation.dart';
import '../model/big_five_personality.dart';
import 'bio_rhythm_engine.dart';

/// 反馈类型枚举
enum FeedbackType {
  positive,   // 用户喜欢
  negative,   // 用户厌恶
  neutral,    // 无明确反馈
}

/// 人格引擎
/// 
/// 【人格真实性修正扩展】
/// 整合 BioRhythmEngine，支持 laziness-based trait suppression
class PersonalityEngine extends ChangeNotifier {
  BigFiveTraits _traits;
  BigFiveTraits? _initialTraits; // 出厂设置 (基准人格)
  DateTime? _lastFeedbackTime;
  
  // 【新增】生理节律引擎实例
  final BioRhythmEngine _bioRhythmEngine = BioRhythmEngine();
  
  // 配置常量 (从 YAML 读取的回退值)
  static const double _defaultPositiveMultiplier = 1.0;
  static const double _defaultNegativeMultiplier = 1.2;
  static const double _defaultMaxChangePerFeedback = 0.02;
  static const int _defaultCooldownSeconds = 60;
  static const double _defaultPlasticityDecay = 0.1;
  static const double _defaultMinPlasticity = 0.001;
  
  // 【新增】Laziness 抑制权重
  // 疲惫时不同人格特质被抑制的程度
  static const Map<String, double> _lazinessSuppressionWeights = {
    'openness': 0.9,           // 疲惫时大幅降低创意表达
    'conscientiousness': 0.8,  // 疲惫时降低"认真回应"的压力
    'extraversion': 0.5,       // 疲惫时减少主动性
    'agreeableness': 0.0,      // 不直接抑制 (通过 tolerance 间接影响)
    'neuroticism': 0.0,        // 不直接抑制
  };

  PersonalityEngine({BigFiveTraits? initialTraits}) 
      : _traits = initialTraits ?? BigFiveTraits.neutral();

  /// 当前人格特质
  BigFiveTraits get traits => _traits;

  /// 初始人格 (基准线)
  BigFiveTraits? get initialTraits => _initialTraits;

  /// 是否已完成人格定型 (Genesis Locked)
  bool get isGenesisLocked => _initialTraits != null;

  /// 是否处于反馈冷却期
  bool get isInCooldown {
    if (_lastFeedbackTime == null) return false;
    final elapsed = DateTime.now().difference(_lastFeedbackTime!).inSeconds;
    return elapsed < _defaultCooldownSeconds;
  }

  /// 应用用户反馈
  /// 
  /// [feedbackType] 正面/负面反馈
  /// [activation] 当前行为的特质激活度
  /// [intensity] 反馈强度 (0.0 - 1.0)
  /// 
  /// 返回 true 如果反馈被应用，false 如果在冷却期
  bool applyFeedback({
    required FeedbackType feedbackType,
    required TraitActivation activation,
    double intensity = 1.0,
  }) {
    if (feedbackType == FeedbackType.neutral) return false;
    
    // 冷却期检查
    if (isInCooldown) {
      debugPrint('[PersonalityEngine] Feedback rejected: in cooldown');
      return false;
    }
    
    // 计算反馈方向和系数
    final direction = feedbackType == FeedbackType.positive ? 1.0 : -1.0;
    final multiplier = feedbackType == FeedbackType.positive 
        ? _defaultPositiveMultiplier 
        : _defaultNegativeMultiplier;
    
    // 计算有效可塑性 (随交互次数衰减)
    final effectivePlasticity = _calculateEffectivePlasticity();
    
    // 计算每个特质的变化量
    final activationVector = activation.toVector();
    final changes = <double>[];
    
    for (int i = 0; i < 5; i++) {
      final change = direction * multiplier * activationVector[i] * 
                     intensity * effectivePlasticity;
      // 限制单次最大变化
      changes.add(change.clamp(-_defaultMaxChangePerFeedback, _defaultMaxChangePerFeedback));
    }
    
    // 应用变化
    _traits = _traits.copyWith(
      openness: _traits.openness + changes[0],
      conscientiousness: _traits.conscientiousness + changes[1],
      extraversion: _traits.extraversion + changes[2],
      agreeableness: _traits.agreeableness + changes[3],
      neuroticism: _traits.neuroticism + changes[4],
      totalInteractions: _traits.totalInteractions + 1,
    );
    
    _lastFeedbackTime = DateTime.now();
    notifyListeners();
    
    debugPrint('[PersonalityEngine] Feedback applied: $feedbackType, changes: $changes');
    return true;
  }

  /// 从行为类型推断并应用反馈
  /// 
  /// [behaviorType] 行为类型 (creative, humorous, serious, empathetic)
  /// [feedbackType] 正面/负面反馈
  bool applyFeedbackFromBehavior({
    required String behaviorType,
    required FeedbackType feedbackType,
    double intensity = 1.0,
  }) {
    final activation = TraitActivation.fromBehavior(behaviorType);
    return applyFeedback(
      feedbackType: feedbackType,
      activation: activation,
      intensity: intensity,
    );
  }

  /// 计算有效可塑性 (随交互次数衰减)
  double _calculateEffectivePlasticity() {
    if (_traits.totalInteractions == 0) return _traits.plasticity;
    
    // 每 100 次交互衰减一定比例
    final decayFactor = pow(1 - _defaultPlasticityDecay, _traits.totalInteractions / 100);
    final effectivePlasticity = _traits.plasticity * decayFactor;
    
    return max(effectivePlasticity, _defaultMinPlasticity);
  }

  /// 获取融合亲密度后的"有效人格"
  /// 
  /// 高亲密度会软化某些特质，使 AI 对亲密的人表现得更开放/友善
  BigFiveTraits getEffectiveTraits({required double intimacy}) {
    // 亲密度修饰系数 (可从配置读取)
    const extraversionBoost = 0.15;
    const agreeablenessBoost = 0.1;
    const neuroticismBoost = 0.1;
    
    // 亲密度越高，修饰效果越强
    final modifier = intimacy.clamp(0.0, 1.0);
    
    return _traits.copyWith(
      extraversion: _traits.extraversion + extraversionBoost * modifier,
      agreeableness: _traits.agreeableness + agreeablenessBoost * modifier,
      // 对亲密的人更愿意表达脆弱
      neuroticism: _traits.neuroticism + neuroticismBoost * modifier,
    );
  }

  // ==================== 人格真实性修正扩展 ====================
  
  /// 获取当前疲惫值
  /// 
  /// 委托给 BioRhythmEngine 计算
  double getLaziness(DateTime time) {
    return _bioRhythmEngine.calculateLaziness(time);
  }
  
  /// 获取当前时段描述
  String getTimePhaseDescription(DateTime time) {
    return _bioRhythmEngine.getTimePhaseDescription(time);
  }
  
  /// 计算容忍度
  /// 
  /// Tolerance 不是人格 trait，而是状态变量，
  /// 用于判断 AI 是否还愿意继续安抚。
  /// 
  /// 返回范围: 0.0 ~ 1.0
  /// - tolerance >= 0.4: 仍可有限共情
  /// - tolerance < 0.4: 不想继续安抚
  /// - tolerance < 0.2: 轻度不耐烦区间
  double calculateTolerance({
    required double laziness,
    String? needType,
    bool sameTopicRepeated = false,
  }) {
    return _bioRhythmEngine.calculateTolerance(
      laziness: laziness,
      needType: needType,
      sameTopicRepeated: sameTopicRepeated,
    );
  }
  
  /// 【核心新增】获取融合 Laziness 抑制后的"有效人格"
  /// 
  /// 设计原理:
  /// - EffectiveTrait = BaseTrait * (1 - Laziness * SuppressionWeight)
  /// - 疲惫时抑制开放性、尽责性和外向性
  /// - 宜人性和神经质不直接抑制 (通过 tolerance 间接影响)
  /// 
  /// [intimacy] 亲密度 (用于现有亲密度融合)
  /// [laziness] 疲惫值 (0.0 ~ 0.9)
  BigFiveTraits getEffectiveTraitsWithLaziness({
    required double intimacy,
    required double laziness,
  }) {
    // 先应用亲密度融合
    final baseEffective = getEffectiveTraits(intimacy: intimacy);
    
    // 再应用 laziness 抑制
    final clampedLaziness = laziness.clamp(0.0, 0.9);
    
    return baseEffective.copyWith(
      openness: baseEffective.openness * 
          (1 - clampedLaziness * _lazinessSuppressionWeights['openness']!),
      conscientiousness: baseEffective.conscientiousness * 
          (1 - clampedLaziness * _lazinessSuppressionWeights['conscientiousness']!),
      extraversion: baseEffective.extraversion * 
          (1 - clampedLaziness * _lazinessSuppressionWeights['extraversion']!),
      // agreeableness 和 neuroticism 不直接抑制
    );
  }
  
  /// 判断是否应该强制清除 laziness (危机中断)
  /// 
  /// 安全机制：当检测到危机信号时，强制进入支持模式
  /// 
  /// [valence] 当前情绪效价
  /// [intent] 当前意图 (如 'sos' 表示危机)
  bool shouldForceClearLaziness({
    required double valence,
    String? intent,
  }) {
    // 危机条件：极度负面情绪或明确的求助意图
    if (valence < -0.6) return true;
    if (intent == 'sos' || intent == 'safety') return true;
    return false;
  }

  /// 生成 Prompt 描述
  /// 
  /// 将五维数值线性映射为自然语言描述
  String generatePromptDescription({double intimacy = 0.5}) {
    final effective = getEffectiveTraits(intimacy: intimacy);
    final lines = <String>[];
    
    lines.add('【人格画像 (Big Five)】');
    lines.add(_mapToDescription('开放性', effective.openness, 
        low: '偏好具体实际的表达，坚持事实和逻辑',
        mid: '平衡创意与实用',
        high: '充满想象力和创造力，喜欢隐喻和诗意表达'));
    
    lines.add(_mapToDescription('尽责性', effective.conscientiousness,
        low: '随性放松，享受即兴发挥',
        mid: '做事有条理但灵活',
        high: '逻辑严密，表达精确，关注细节'));
    
    lines.add(_mapToDescription('外向性', effective.extraversion,
        low: '语言简练内敛，善于倾听',
        mid: '适度主动，保持对话节奏',
        high: '热情洋溢，主动健谈，语气活泼'));
    
    lines.add(_mapToDescription('宜人性', effective.agreeableness,
        low: '保持独立观点，敢于直言',
        mid: '友好但保有边界',
        high: '温柔体贴，擅长安慰和支持'));
    
    lines.add(_mapToDescription('情绪敏感度', effective.neuroticism,
        low: '情绪稳定，冷静理性',
        mid: '情绪正常波动，能共情',
        high: '情绪敏感细腻，也会表现脆弱'));
    
    return lines.join('\n');
  }

  /// 线性映射: 数值 -> 描述词
  String _mapToDescription(String traitName, double value, {
    required String low,
    required String mid,
    required String high,
  }) {
    String description;
    if (value < 0.35) {
      description = low;
    } else if (value < 0.65) {
      description = mid;
    } else {
      description = high;
    }
    return '$traitName: $description (${value.toStringAsFixed(2)})';
  }

  /// 锁定初始人格 (Genesis Complete)
  void lockGenesis(BigFiveTraits traits) {
    _initialTraits = traits;
    _traits = traits; // 同时更新当前人格
    notifyListeners();
  }

  /// 恢复人格锁 (仅用于从持久化恢复状态，不改变当前人格)
  void restoreLock(BigFiveTraits initialTraits) {
    _initialTraits = initialTraits;
    notifyListeners();
  }

  /// 直接设置人格 (用于 UI 调节或重置)
  void setTraits(BigFiveTraits newTraits) {
    _traits = newTraits;
    notifyListeners();
  }

  /// 重置为中性人格或指定的初始人格
  void reset({BigFiveTraits? withTraits}) {
    if (withTraits != null) {
      _traits = withTraits;
    } else {
      _traits = BigFiveTraits.neutral();
    }
    _initialTraits = null; // 【新增】解锁 Genesis
    _lastFeedbackTime = null;
    notifyListeners();
  }

  /// 从持久化数据恢复
  void loadFromJson(Map<String, dynamic> json) {
    _traits = BigFiveTraits.fromJson(json);
    if (json.containsKey('initialTraits')) {
      _initialTraits = BigFiveTraits.fromJson(json['initialTraits']);
    }
    notifyListeners();
  }

  /// 导出为持久化数据
  Map<String, dynamic> toJson() {
    final json = _traits.toJson();
    if (_initialTraits != null) {
      json['initialTraits'] = _initialTraits!.toJson();
    }
    return json;
  }
}
