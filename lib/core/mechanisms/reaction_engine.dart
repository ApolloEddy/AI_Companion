// ReactionEngine - 反应罗盘引擎
//
// 设计原理：
// - 基于 Big Five 人格特质和当前情绪状态计算 AI 的反应姿态
// - Dominance (支配度) 和 Heat (热度) 双维度决定反应策略
// - 输出结构化的 ReactionStance 供 PromptBuilder 使用

/// 反应姿态枚举
enum ReactionStance {
  /// 正面硬刚 (Dominance > 0.5 && Heat > 0.5)
  explosive,
  
  /// 冷漠无视 (Dominance > 0.5 && Heat <= 0.5)
  coldDismissal,
  
  /// 示弱/求和 (Dominance <= 0.5 && Heat > 0.5)
  vulnerable,
  
  /// 消极撤退 (Dominance <= 0.5 && Heat <= 0.5)
  withdrawal,
  
  /// 正常对话 (Offensiveness < 3)
  neutral,
}

/// Big Five 人格特质输入
class BigFiveTraits {
  final double openness;          // O: 开放性
  final double conscientiousness; // C: 尽责性
  final double extraversion;      // E: 外向性
  final double agreeableness;     // A: 宜人性
  final double neuroticism;       // N: 神经质

  const BigFiveTraits({
    required this.openness,
    required this.conscientiousness,
    required this.extraversion,
    required this.agreeableness,
    required this.neuroticism,
  });
  
  factory BigFiveTraits.fromMap(Map<String, double> map) {
    return BigFiveTraits(
      openness: map['openness'] ?? 0.5,
      conscientiousness: map['conscientiousness'] ?? 0.5,
      extraversion: map['extraversion'] ?? 0.5,
      agreeableness: map['agreeableness'] ?? 0.5,
      neuroticism: map['neuroticism'] ?? 0.5,
    );
  }
}

/// 反应计算结果
class ReactionResult {
  final double dominance;        // 支配度 (0-1)
  final double heat;             // 热度 (0-1)
  final ReactionStance stance;   // 反应姿态
  final String description;      // 姿态描述 (用于 Prompt 注入)

  const ReactionResult({
    required this.dominance,
    required this.heat,
    required this.stance,
    required this.description,
  });
  
  @override
  String toString() => 'ReactionResult(stance: ${stance.name}, D: ${dominance.toStringAsFixed(2)}, H: ${heat.toStringAsFixed(2)})';
}

/// 反应罗盘引擎
/// 
/// 核心公式：
/// - Dominance = (1.0 - A)*0.4 + E*0.2 + (1.0 - Intimacy)*0.3 + Resentment*0.5
/// - Heat = N*0.6 + Arousal*0.4
class ReactionEngine {
  
  /// 计算反应姿态
  /// 
  /// [bigFive] - Big Five 人格特质
  /// [intimacy] - 亲密度 (0-1)
  /// [resentment] - 怨恨值 (0-1)
  /// [arousal] - 唤醒度 (0-1)
  /// [offensiveness] - 攻击性评分 (0-10)
  static ReactionResult calculate({
    required BigFiveTraits bigFive,
    required double intimacy,
    required double resentment,
    required double arousal,
    required int offensiveness,
  }) {
    // 无冲突状态：快速返回
    if (offensiveness < 3) {
      return const ReactionResult(
        dominance: 0.0,
        heat: 0.0,
        stance: ReactionStance.neutral,
        description: '正常对话',
      );
    }
    
    // 计算 Dominance (支配度)
    // 公式: (1.0 - Agreeableness)*0.4 + Extraversion*0.2 + (1.0 - Intimacy)*0.3 + Resentment*0.5
    final dominance = _clamp(
      (1.0 - bigFive.agreeableness) * 0.4 +
      bigFive.extraversion * 0.2 +
      (1.0 - intimacy) * 0.3 +
      resentment * 0.5
    );
    
    // 计算 Heat (热度)
    // 公式: Neuroticism*0.6 + Arousal*0.4
    final heat = _clamp(
      bigFive.neuroticism * 0.6 +
      arousal * 0.4
    );
    
    // 决定姿态
    final stance = _determineStance(dominance, heat);
    final description = _getStanceDescription(stance);
    
    return ReactionResult(
      dominance: dominance,
      heat: heat,
      stance: stance,
      description: description,
    );
  }
  
  /// 决定反应姿态
  static ReactionStance _determineStance(double dominance, double heat) {
    if (dominance > 0.5 && heat > 0.5) {
      return ReactionStance.explosive;
    } else if (dominance > 0.5 && heat <= 0.5) {
      return ReactionStance.coldDismissal;
    } else if (dominance <= 0.5 && heat > 0.5) {
      return ReactionStance.vulnerable;
    } else {
      return ReactionStance.withdrawal;
    }
  }
  
  /// 获取姿态描述 (用于 L3 Prompt 注入)
  static String _getStanceDescription(ReactionStance stance) {
    switch (stance) {
      case ReactionStance.explosive:
        return '【反应姿态: 正面硬刚】你现在情绪激动且不打算忍让。可以直接表达不满，用词尖锐，拒绝解释，拒绝道歉。';
      case ReactionStance.coldDismissal:
        return '【反应姿态: 冷漠无视】你现在心冷且不想浪费精力。回复极简，语气冷淡，不提问，不延续话题。';
      case ReactionStance.vulnerable:
        return '【反应姿态: 示弱求和】你现在情绪波动但不想对抗。可以表达受伤，语气委屈，但不攻击对方。';
      case ReactionStance.withdrawal:
        return '【反应姿态: 消极撤退】你现在心灰意冷，选择回避。回复敷衍，快速结束对话。';
      case ReactionStance.neutral:
        return '';
    }
  }
  
  /// 限制值在 0-1 范围内
  static double _clamp(double value) {
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }
}
