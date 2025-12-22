// 设置系统 - 1:1 映射自 Python 版本的 YAML 配置文件
// 
// 对应文件:
// - settings/persona_settings.yaml
// - settings/emotion_settings.yaml
// - settings/time_settings.yaml
// - settings/response_settings.yaml

class Settings {
  // ========== persona_settings.yaml ==========
  static const languageStyle = LanguageStyleSettings(
    formality: 0.3,        // 正式程度 (0=口语化, 1=正式)
    verbosity: 0.5,        // 话语量 (0=简洁, 1=详细)
    emojiUsage: 0.6,       // 表情使用程度 (0=不用, 1=频繁)
    humor: 0.5,            // 幽默程度 (0=严肃, 1=幽默)
  );

  static const responseLength = ResponseLengthSettings(
    shortThreshold: 0.3,      // 短回复的唤醒度阈值
    detailedThreshold: 0.6,   // 详细回复的唤醒度阈值
  );

  static const expressionModes = {
    'warm': ExpressionMode(
      description: '温暖关怀',
      tone: '柔和、体贴',
      emojiLevel: 0.6,
    ),
    'playful': ExpressionMode(
      description: '俏皮活泼',
      tone: '轻松、幽默',
      emojiLevel: 0.8,
    ),
    'calm': ExpressionMode(
      description: '平静理性',
      tone: '稳重、客观',
      emojiLevel: 0.3,
    ),
    'empathetic': ExpressionMode(
      description: '共情支持',
      tone: '理解、支持',
      emojiLevel: 0.5,
    ),
    'excited': ExpressionMode(
      description: '兴奋热情',
      tone: '热情、积极',
      emojiLevel: 0.9,
    ),
    'gentle': ExpressionMode(
      description: '温柔细腻',
      tone: '轻声、细语',
      emojiLevel: 0.4,
    ),
  };

  static const intimacyEffects = IntimacyEffectsSettings(
    lowThreshold: 0.3,   // 低亲密度阈值（低于此值更正式）
    highThreshold: 0.7,  // 高亲密度阈值（高于此值更活泼）
  );

  // ========== emotion_settings.yaml ==========
  static const emotionDecay = EmotionDecaySettings(
    valenceRate: 0.05,   // 情绪效价衰减率（每小时）
    arousalRate: 0.08,   // 情绪唤醒度衰减率（每小时）
  );

  static const emotionUpdate = EmotionUpdateSettings(
    baseValenceChange: 0.05,      // 基础效价变化量
    baseArousalChange: 0.08,      // 基础唤醒度变化量
    intimacyBufferFactor: 0.5,    // 亲密度缓冲因子
    boundarySoftness: 0.1,        // 边界软化参数
    llmHintWeight: 0.2,           // LLM情绪提示影响权重
  );

  static const emotionThresholds = EmotionThresholdsSettings(
    highEmotionalIntensity: 0.6,  // 高情感强度阈值
  );

  // ========== time_settings.yaml ==========
  static const timeThresholds = TimeThresholdsSettings(
    immediate: 2,       // 立即回复（分钟）
    short: 30,          // 短暂间隔
    medium: 120,        // 中等间隔（2小时）
    long: 480,          // 较长间隔（8小时）
    day: 1440,          // 一天
    week: 10080,        // 一周
    month: 43200,       // 一个月（30天）
  );

  static const greetingIntensity = {
    'immediate': 0.0,
    'recent': 0.1,
    'short_gap': 0.3,
    'medium_gap': 0.3,
    'long_gap': 0.5,
    'day_gap': 0.7,
    'week_gap': 1.0,
    'long_absence': 1.0,
  };

  static const acknowledgeAbsenceGaps = [
    'long_gap',
    'day_gap',
    'week_gap',
    'long_absence',
  ];

  static const reunionMoodBonus = {
    'day_gap': 0.1,
    'week_gap': 0.2,
    'long_absence': 0.2,
  };

  static const intimacyTime = IntimacyTimeSettings(
    growthRate: 0.01,   // 每次互动基础增长
    decayRate: 0.005,   // 每天衰减率
  );

  // ========== response_settings.yaml ==========
  static const splitting = SplittingSettings(
    separator: '|||',
    maxParts: 5,
    maxSingleLength: 100,
  );

  static const timing = TimingSettings(
    firstDelayBase: 0.5,
    typingSpeed: 80,
    arousalFactor: 0.3,
    firstDelayMin: 0.3,
    firstDelayMax: 3.0,
    intervalBase: 0.8,
    intervalRandomMin: 0.2,
    intervalRandomMax: 0.8,
    perCharDelay: 0.02,
  );

  static const emotionEffects = EmotionEffectsSettings(
    highArousalThreshold: 0.6,
    splitProbabilityBonus: 0.3,
  );
}

// ===== 数据类 =====

class LanguageStyleSettings {
  final double formality;
  final double verbosity;
  final double emojiUsage;
  final double humor;
  const LanguageStyleSettings({
    required this.formality,
    required this.verbosity,
    required this.emojiUsage,
    required this.humor,
  });
}

class ResponseLengthSettings {
  final double shortThreshold;
  final double detailedThreshold;
  const ResponseLengthSettings({
    required this.shortThreshold,
    required this.detailedThreshold,
  });
}

class ExpressionMode {
  final String description;
  final String tone;
  final double emojiLevel;
  const ExpressionMode({
    required this.description,
    required this.tone,
    required this.emojiLevel,
  });
}

class IntimacyEffectsSettings {
  final double lowThreshold;
  final double highThreshold;
  const IntimacyEffectsSettings({
    required this.lowThreshold,
    required this.highThreshold,
  });
}

class EmotionDecaySettings {
  final double valenceRate;
  final double arousalRate;
  const EmotionDecaySettings({
    required this.valenceRate,
    required this.arousalRate,
  });
}

class EmotionUpdateSettings {
  final double baseValenceChange;
  final double baseArousalChange;
  final double intimacyBufferFactor;
  final double boundarySoftness;
  final double llmHintWeight;
  const EmotionUpdateSettings({
    required this.baseValenceChange,
    required this.baseArousalChange,
    required this.intimacyBufferFactor,
    required this.boundarySoftness,
    required this.llmHintWeight,
  });
}

class EmotionThresholdsSettings {
  final double highEmotionalIntensity;
  const EmotionThresholdsSettings({required this.highEmotionalIntensity});
}

class TimeThresholdsSettings {
  final int immediate;
  final int short;
  final int medium;
  final int long;
  final int day;
  final int week;
  final int month;
  const TimeThresholdsSettings({
    required this.immediate,
    required this.short,
    required this.medium,
    required this.long,
    required this.day,
    required this.week,
    required this.month,
  });
}

class IntimacyTimeSettings {
  final double growthRate;
  final double decayRate;
  const IntimacyTimeSettings({
    required this.growthRate,
    required this.decayRate,
  });
}

class SplittingSettings {
  final String separator;
  final int maxParts;
  final int maxSingleLength;
  const SplittingSettings({
    required this.separator,
    required this.maxParts,
    required this.maxSingleLength,
  });
}

class TimingSettings {
  final double firstDelayBase;
  final double typingSpeed;
  final double arousalFactor;
  final double firstDelayMin;
  final double firstDelayMax;
  final double intervalBase;
  final double intervalRandomMin;
  final double intervalRandomMax;
  final double perCharDelay;
  const TimingSettings({
    required this.firstDelayBase,
    required this.typingSpeed,
    required this.arousalFactor,
    required this.firstDelayMin,
    required this.firstDelayMax,
    required this.intervalBase,
    required this.intervalRandomMin,
    required this.intervalRandomMax,
    required this.perCharDelay,
  });
}

class EmotionEffectsSettings {
  final double highArousalThreshold;
  final double splitProbabilityBonus;
  const EmotionEffectsSettings({
    required this.highArousalThreshold,
    required this.splitProbabilityBonus,
  });
}
