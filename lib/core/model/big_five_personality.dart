// Big Five (OCEAN) Personality Model
//
// 标准心理学五大人格模型：
// - **O**penness (开放性): 好奇心、想象力、创造力
// - **C**onscientiousness (尽责性): 自律、谨慎、条理性
// - **E**xtraversion (外向性): 社交能力、活力、健谈
// - **A**greeableness (宜人性): 友善、合作、共情
// - **N**euroticism (神经质): 情绪敏感度、焦虑倾向
//
// 【设计原理】
// - 所有维度归一化到 0.0 ~ 1.0 范围
// - 支持通过正负反馈进行微调 (PersonalityEngine)
// - 可塑性 (Plasticity) 随交互次数衰减，模拟"人格定型"

/// Big Five 人格特质模型
class BigFiveTraits {
  /// 开放性 (Openness): 0 = 传统保守, 1 = 富有创意和好奇心
  final double openness;
  
  /// 尽责性 (Conscientiousness): 0 = 随性散漫, 1 = 严谨自律
  final double conscientiousness;
  
  /// 外向性 (Extraversion): 0 = 内向安静, 1 = 外向活泼
  final double extraversion;
  
  /// 宜人性 (Agreeableness): 0 = 独立挑战, 1 = 温和顺从
  final double agreeableness;
  
  /// 神经质 (Neuroticism): 0 = 情绪稳定, 1 = 敏感易波动
  final double neuroticism;
  
  /// 可塑性 (Plasticity): 人格改变的难易程度 (随交互衰减)
  final double plasticity;
  
  /// 总交互次数 (用于可塑性衰减计算)
  final int totalInteractions;

  const BigFiveTraits({
    this.openness = 0.5,
    this.conscientiousness = 0.5,
    this.extraversion = 0.5,
    this.agreeableness = 0.5,
    this.neuroticism = 0.5,
    this.plasticity = 0.01,
    this.totalInteractions = 0,
  });

  /// 工厂默认值 (中性人格)
  factory BigFiveTraits.neutral() => const BigFiveTraits();

  /// 复制并更新
  BigFiveTraits copyWith({
    double? openness,
    double? conscientiousness,
    double? extraversion,
    double? agreeableness,
    double? neuroticism,
    double? plasticity,
    int? totalInteractions,
  }) {
    return BigFiveTraits(
      openness: (openness ?? this.openness).clamp(0.0, 1.0),
      conscientiousness: (conscientiousness ?? this.conscientiousness).clamp(0.0, 1.0),
      extraversion: (extraversion ?? this.extraversion).clamp(0.0, 1.0),
      agreeableness: (agreeableness ?? this.agreeableness).clamp(0.0, 1.0),
      neuroticism: (neuroticism ?? this.neuroticism).clamp(0.0, 1.0),
      plasticity: (plasticity ?? this.plasticity).clamp(0.0, 1.0),
      totalInteractions: totalInteractions ?? this.totalInteractions,
    );
  }

  /// 从旧版 formality/humor 迁移
  /// 
  /// 迁移映射:
  /// - Formality -> High C, Low E
  /// - Humor -> High O, High E
  factory BigFiveTraits.fromLegacy({
    required double formality,
    required double humor,
  }) {
    return BigFiveTraits(
      openness: (0.5 + humor * 0.3).clamp(0.0, 1.0),       // 幽默感 -> 开放性
      conscientiousness: (0.3 + formality * 0.5).clamp(0.0, 1.0), // 庄重感 -> 尽责性
      extraversion: (0.5 + humor * 0.2 - formality * 0.2).clamp(0.0, 1.0), // 幽默↑外向, 庄重↓外向
      agreeableness: 0.6, // 默认友善
      neuroticism: 0.4,   // 默认较稳定
    );
  }

  /// 序列化到 JSON
  Map<String, dynamic> toJson() => {
    'openness': openness,
    'conscientiousness': conscientiousness,
    'extraversion': extraversion,
    'agreeableness': agreeableness,
    'neuroticism': neuroticism,
    'plasticity': plasticity,
    'totalInteractions': totalInteractions,
  };

  /// 从 JSON 反序列化
  factory BigFiveTraits.fromJson(Map<String, dynamic> json) {
    return BigFiveTraits(
      openness: (json['openness'] as num?)?.toDouble() ?? 0.5,
      conscientiousness: (json['conscientiousness'] as num?)?.toDouble() ?? 0.5,
      extraversion: (json['extraversion'] as num?)?.toDouble() ?? 0.5,
      agreeableness: (json['agreeableness'] as num?)?.toDouble() ?? 0.5,
      neuroticism: (json['neuroticism'] as num?)?.toDouble() ?? 0.5,
      plasticity: (json['plasticity'] as num?)?.toDouble() ?? 0.01,
      totalInteractions: (json['totalInteractions'] as int?) ?? 0,
    );
  }

  /// 获取主导特质 (最高的那个维度)
  String getDominantTrait() {
    final traits = {
      'openness': openness,
      'conscientiousness': conscientiousness,
      'extraversion': extraversion,
      'agreeableness': agreeableness,
      'neuroticism': neuroticism,
    };
    return traits.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  /// 获取特质向量 (用于反馈计算)
  List<double> toVector() => [openness, conscientiousness, extraversion, agreeableness, neuroticism];

  @override
  String toString() => 'BigFive(O:${openness.toStringAsFixed(2)}, C:${conscientiousness.toStringAsFixed(2)}, E:${extraversion.toStringAsFixed(2)}, A:${agreeableness.toStringAsFixed(2)}, N:${neuroticism.toStringAsFixed(2)})';
}


/// 人格特质激活度 - 用于反馈机制
/// 
/// 表示当前行为中各特质的"激活程度"
/// 只有激活的特质会被正负反馈影响
class TraitActivation {
  final double openness;
  final double conscientiousness;
  final double extraversion;
  final double agreeableness;
  final double neuroticism;

  const TraitActivation({
    this.openness = 0.0,
    this.conscientiousness = 0.0,
    this.extraversion = 0.0,
    this.agreeableness = 0.0,
    this.neuroticism = 0.0,
  });

  /// 创意/想象行为
  factory TraitActivation.creative() => const TraitActivation(openness: 1.0);

  /// 幽默/社交行为
  factory TraitActivation.humorous() => const TraitActivation(openness: 0.6, extraversion: 0.8);

  /// 严肃/精确行为
  factory TraitActivation.serious() => const TraitActivation(conscientiousness: 0.8, extraversion: 0.2);

  /// 共情/安慰行为
  factory TraitActivation.empathetic() => const TraitActivation(agreeableness: 0.9, neuroticism: 0.4);

  /// 从行为描述推断激活度 (可扩展)
  factory TraitActivation.fromBehavior(String behaviorType) {
    switch (behaviorType) {
      case 'creative': return TraitActivation.creative();
      case 'humorous': return TraitActivation.humorous();
      case 'serious': return TraitActivation.serious();
      case 'empathetic': return TraitActivation.empathetic();
      default: return const TraitActivation();
    }
  }

  List<double> toVector() => [openness, conscientiousness, extraversion, agreeableness, neuroticism];
}
