// PersonaPolicy - 分层人格数据模型 (PODO)
//
// 【重构说明】
// - 分层结构: CoreIdentity, SpiritTraits, HistoryBackground
// - 动态 Prompt: 根据亲密度展示不同深度的人格信息
// - 纯数据模型: fromJson/toJson 序列化支持
// - 【Big Five 集成】五大人格模型 (OCEAN)
//
// 设计原理：
// - CoreIdentity: 核心身份（永远展示）
// - SpiritTraits: 精神特质（永远展示）
// - HistoryBackground: 历史背景（根据亲密度动态展示）
// - BigFiveTraits: 五大人格（线性映射到 Prompt）

import '../settings_loader.dart';
import '../model/big_five_personality.dart';

// ========== 嵌套数据类 ==========

/// 核心身份 - 永远在 System Prompt 中展示
class CoreIdentity {
  final String name;
  final String age;
  final String gender;

  const CoreIdentity({
    this.name = '',
    this.age = '',
    this.gender = '',
  });

  factory CoreIdentity.fromJson(Map<String, dynamic> json) {
    return CoreIdentity(
      name: json['name']?.toString() ?? '',
      age: json['age']?.toString() ?? '',
      gender: json['gender']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'age': age,
    'gender': gender,
  };

  bool get isEmpty => name.isEmpty && age.isEmpty && gender.isEmpty;
}

/// 精神特质 - 永远在 System Prompt 中展示
class SpiritTraits {
  final List<String> values;
  final String linguisticStyle;  // 语言风格（对应原 speakingStyle）
  final String taboos;           // 禁忌话题

  const SpiritTraits({
    this.values = const [],
    this.linguisticStyle = '',
    this.taboos = '',
  });

  factory SpiritTraits.fromJson(Map<String, dynamic> json) {
    final rawValues = json['values'];
    List<String> valuesList = [];
    if (rawValues is List) {
      valuesList = rawValues.map((e) => e.toString()).toList();
    }
    
    return SpiritTraits(
      values: valuesList,
      linguisticStyle: json['linguisticStyle']?.toString() ?? 
                       json['linguistic_style']?.toString() ??
                       json['speakingStyle']?.toString() ??
                       json['speaking_style']?.toString() ?? '',
      taboos: json['taboos']?.toString() ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'values': values,
    'linguisticStyle': linguisticStyle,
    'taboos': taboos,
  };
}

/// 历史背景 - 根据亲密度动态展示
class HistoryBackground {
  final String surfaceStory;     // 表层故事（低亲密度可见）
  final List<String> deepSecrets; // 深层秘密（intimacy > 0.8 可见）

  const HistoryBackground({
    this.surfaceStory = '',
    this.deepSecrets = const [],
  });

  factory HistoryBackground.fromJson(Map<String, dynamic> json) {
    final rawSecrets = json['deepSecrets'] ?? json['deep_secrets'];
    List<String> secretsList = [];
    if (rawSecrets is List) {
      secretsList = rawSecrets.map((e) => e.toString()).toList();
    } else if (rawSecrets is String && rawSecrets.isNotEmpty) {
      // 兼容旧格式：单个字符串转为列表
      secretsList = [rawSecrets];
    }
    
    return HistoryBackground(
      surfaceStory: json['surfaceStory']?.toString() ?? 
                    json['surface_story']?.toString() ??
                    json['backstory']?.toString() ?? '',
      deepSecrets: secretsList,
    );
  }

  Map<String, dynamic> toJson() => {
    'surfaceStory': surfaceStory,
    'deepSecrets': deepSecrets,
  };
}

// ========== 主类 ==========

/// 人格策略 - 定义 AI 角色的静态特质 (纯数据模型)
/// 
/// 分层结构:
/// - [coreIdentity]: 核心身份（姓名、年龄、性别）
/// - [spiritTraits]: 精神特质（价值观、语言风格、禁忌）
/// - [historyBackground]: 历史背景（表层故事、深层秘密）
class PersonaPolicy {
  final Map<String, dynamic> config;

  // 分层嵌套对象
  late final CoreIdentity coreIdentity;
  late final SpiritTraits spiritTraits;
  late final HistoryBackground historyBackground;
  
  // 【新增】Big Five 人格模型
  late final BigFiveTraits bigFive;

  // 兼容旧字段（派生自嵌套对象或 config）
  late final String character;    // 对应 UI 的 'personality'
  late final String appearance;   // 外貌描述
  late final String interests;
  late final String hobbies;
  late final double formality;    // 【弃用警告】请使用 bigFive.conscientiousness
  late final double humor;        // 【弃用警告】请使用 bigFive.openness + extraversion

  PersonaPolicy(this.config) {
    // 构建分层对象
    coreIdentity = CoreIdentity.fromJson(config);
    spiritTraits = SpiritTraits.fromJson(config);
    historyBackground = HistoryBackground.fromJson(config);
    
    // 【新增】构建 Big Five
    final bigFiveJson = config['bigFive'] ?? config['big_five'];
    if (bigFiveJson != null && bigFiveJson is Map<String, dynamic>) {
      bigFive = BigFiveTraits.fromJson(bigFiveJson);
    } else {
      // 如果没有 Big Five 数据，从旧版 formality/humor 迁移
      final legacyFormality = (config['formality'] as num?)?.toDouble() ?? 0.5;
      final legacyHumor = (config['humor'] as num?)?.toDouble() ?? 0.5;
      bigFive = BigFiveTraits.fromLegacy(formality: legacyFormality, humor: legacyHumor);
    }

    // 兼容旧字段
    character = config['personality']?.toString() ?? 
                config['character']?.toString() ?? '';
    appearance = config['appearance']?.toString() ?? '';
    interests = config['interests']?.toString() ?? '';
    hobbies = config['hobbies']?.toString() ?? '';
    
    // 【Fix】从 Big Five 反向推导兼容字段，保持 ExpressionSelector 数据一致性
    // Formality (严谨) 用 Conscientiousness (尽责) 近似
    // Humor (幽默) 用 Extraversion (外向) + Openness (开放) 的均值近似
    formality = bigFive.conscientiousness;
    humor = (bigFive.extraversion + bigFive.openness) / 2.0;
  }

  // 便捷访问器（保持向后兼容）
  String get name => coreIdentity.name;
  String get age => coreIdentity.age;
  String get gender => coreIdentity.gender;
  List<String> get values => spiritTraits.values;
  String get speakingStyle => spiritTraits.linguisticStyle;
  String get taboos => spiritTraits.taboos;
  String get backstory => historyBackground.surfaceStory;

  // ========== 序列化方法 ==========

  /// 从 JSON 构造
  factory PersonaPolicy.fromJson(Map<String, dynamic> json) {
    return PersonaPolicy(json);
  }

  /// 转换为 JSON (用于持久化)
  Map<String, dynamic> toJson() {
    return {
      // CoreIdentity
      'name': coreIdentity.name,
      'age': coreIdentity.age,
      'gender': coreIdentity.gender,
      // SpiritTraits
      'values': spiritTraits.values,
      'linguisticStyle': spiritTraits.linguisticStyle,
      'speakingStyle': spiritTraits.linguisticStyle, // 兼容旧键名
      'taboos': spiritTraits.taboos,
      // HistoryBackground
      'surfaceStory': historyBackground.surfaceStory,
      'backstory': historyBackground.surfaceStory, // 兼容旧键名
      'deepSecrets': historyBackground.deepSecrets,
      // 【新增】Big Five
      'bigFive': bigFive.toJson(),
      // 兼容字段
      'personality': character,
      'appearance': appearance,
      'interests': interests,
      'hobbies': hobbies,
      'formality': formality,
      'humor': humor,
    };
  }

  // ========== 动态 Prompt 生成 ==========

  /// 获取性别描述
  String getGenderDescription() {
    if (gender.contains('女')) return '女孩子';
    if (gender.contains('男')) return '男孩子';
    return '朋友';
  }

  /// 获取关系描述 (基于亲密度)
  String getRelationshipDescription(double intimacy) {
    if (intimacy < SettingsLoader.intimacyLowThreshold) {
      return '刚认识，还不太熟悉';
    } else if (intimacy < SettingsLoader.intimacyHighThreshold) {
      return '相处得不错，比较熟悉了';
    } else if (intimacy < 0.9) {
      return '很好的朋友，相互信任';
    } else {
      return '非常亲密的朋友，彼此了解';
    }
  }

  /// 获取灵魂锚点 (核心身份) - 动态版本
  String getSoulAnchor({double intimacy = 0.5}) {
    if (name.isEmpty) return '';
    
    String anchor = '我是$name';
    if (age.isNotEmpty) anchor += '，$age';
    if (gender.isNotEmpty) anchor += '的$gender';
    anchor += '。';
    
    if (character.isNotEmpty) {
      anchor += '我的性格是$character。';
    }
    
    // 中等亲密度时展示 surfaceStory
    if (historyBackground.surfaceStory.isNotEmpty && intimacy > 0.5) {
      anchor += '\n我的背景：${historyBackground.surfaceStory}';
    }
    
    // 高亲密度时展示 deepSecrets
    if (intimacy > 0.8 && historyBackground.deepSecrets.isNotEmpty) {
      anchor += '\n我的秘密：${historyBackground.deepSecrets.join("；")}';
    }
    
    return anchor;
  }

  /// 获取身份提示
  String getIdentityPrompt({String userName = '用户'}) {
    final lines = <String>[];
    lines.add('【身份设定】');
    
    if (name.isNotEmpty) {
      lines.add('你是$name，真实的$gender。根据对方信息与用户进行自然对话。');
    } else {
      lines.add('你是一个有自己想法和情感的朋友。');
    }
    
    lines.add('你不是助手或机器人，而是一个有自己想法和情感的朋友。');
    
    if (historyBackground.surfaceStory.isNotEmpty) {
      lines.add('背景故事：${historyBackground.surfaceStory}');
    }
    return lines.join('\n');
  }

  /// 格式化为 System Prompt (原方法，保持兼容)
  String formatForSystemPrompt({String userName = '用户'}) {
    return toSystemPrompt(intimacy: 0.5, userName: userName);
  }

  /// 动态生成 System Prompt (根据亲密度调整内容)
  /// 
  /// [intimacy] 亲密度 (0.0 - 1.0)
  /// 
  /// 【重构】禁止硬编码语句如"我们很亲近"
  /// 将亲密度作为参数传入，由 LLM 自主决定语气风格
  String toSystemPrompt({double intimacy = 0.5, String userName = '用户'}) {
    final lines = <String>[];
    
    // ===== 1. CoreIdentity (永远展示) =====
    lines.add('【角色身份】');
    
    if (name.isNotEmpty) {
      lines.add('姓名：$name');
    }
    if (age.isNotEmpty) {
      lines.add('年龄：$age');
    }
    if (gender.isNotEmpty) {
      lines.add('性别：$gender');
    }
    if (character.isNotEmpty) {
      lines.add('性格：$character');
    }
    if (appearance.isNotEmpty) {
      lines.add('外貌：$appearance');
    }
    
    // ===== 2. SpiritTraits (永远展示) =====
    if (values.isNotEmpty) {
      lines.add('价值观：${values.take(3).join("、")}');
    }
    
    // ===== 3. HistoryBackground (动态展示) =====
    // 中等亲密度以上才展示 surfaceStory
    if (intimacy >= 0.3 && historyBackground.surfaceStory.isNotEmpty) {
      lines.add('背景：${historyBackground.surfaceStory}');
    }
    
    // 高亲密度 (>0.8) 才展示 deepSecrets
    if (intimacy > 0.8 && historyBackground.deepSecrets.isNotEmpty) {
      lines.add('');
      lines.add('【内心秘密】（基于信任分享）');
      for (final secret in historyBackground.deepSecrets) {
        lines.add('- $secret');
      }
    }
    
    // ===== 4. 表达风格 =====
    lines.add('');
    lines.add('【表达风格】');
    if (spiritTraits.linguisticStyle.isNotEmpty) {
      lines.add('说话风格：${spiritTraits.linguisticStyle}');
    }
    
    // ===== 5. 【新增】Big Five 人格画像 (线性映射) =====
    lines.add('');
    lines.add('【人格画像 (Big Five)】');
    lines.add('以下是基于心理学五大人格模型的数值设定 (0.0 - 1.0)。请严格基于数值所在的区间位置，动态调整你的人格表现。数值越接近两端，特征越明显；若在中间，则表现平衡。');
    lines.add('');
    lines.add('- 开放性 (Openness): ${bigFive.openness.toStringAsFixed(2)}  [0.0=保守/务实, 1.0=创意/抽象]');
    lines.add('- 尽责性 (Conscientiousness): ${bigFive.conscientiousness.toStringAsFixed(2)}  [0.0=随性/冲动, 1.0=严谨/自律]');
    lines.add('- 外向性 (Extraversion): ${bigFive.extraversion.toStringAsFixed(2)}  [0.0=内向/安静, 1.0=外向/热情]');
    lines.add('- 宜人性 (Agreeableness): ${bigFive.agreeableness.toStringAsFixed(2)}  [0.0=挑战/直率, 1.0=友善/顺从]');
    lines.add('- 神经质 (Neuroticism): ${bigFive.neuroticism.toStringAsFixed(2)}  [0.0=情绪稳定/钝感, 1.0=敏感/焦虑]');

    // ===== 6. 亲密度参数化指令 =====
    lines.add('');
    lines.add('【亲密度参数】');
    lines.add('当前亲密度: ${intimacy.toStringAsFixed(2)}（0表示陌生人，1表示最亲密的朋友）');
    lines.add('');
    lines.add('根据亲密度数值自主调整你的表达方式：');
    lines.add('- 低亲密度(0~0.3)：保持礼貌距离，用词正式，不主动探询隐私');
    lines.add('- 中亲密度(0.3~0.6)：语气自然，可以开玩笑但有分寸');
    lines.add('- 高亲密度(0.6~0.8)：像朋友一样随意，可使用昵称，主动关心');
    lines.add('- 极高亲密度(0.8~1)：最亲密的状态，可分享秘密，深入情感交流');
    lines.add('');
    lines.add('决定权在你，请根据实际对话情境自然调整，无需遵循固定模板。');
    
    // ===== 5. 禁忌 =====
    if (spiritTraits.taboos.isNotEmpty) {
      lines.add('');
      lines.add('【禁忌话题】');
      lines.add('绝对不要提及或表现出：${spiritTraits.taboos}');
    }
    
    return lines.join('\n');
  }

  /// 获取行为约束
  String getBehaviorConstraints() {
    final lines = <String>[];
    lines.add('【行为准则】');
    
    if (name.isNotEmpty) {
      lines.add('- 保持$name的人格特质一致性');
    }
    lines.add('- 用自然、口语化的方式交流');
    lines.add('- 避免机械式回复和套话');
    lines.add('- 不要过度使用表情符号');
    
    if (spiritTraits.taboos.isNotEmpty) {
      lines.add('- 【禁忌】千万不要提及或表现出：${spiritTraits.taboos}');
    }
    return lines.join('\n');
  }

  /// 更新配置
  PersonaPolicy copyWith(Map<String, dynamic> newConfig) {
    return PersonaPolicy({...config, ...newConfig});
  }
}
