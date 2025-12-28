import '../settings_loader.dart';
import '../policy/behavior_matrix.dart';

/// 表达选择器 - 使用动态 YAML 配置
class ExpressionSelector {

  static final BehaviorMatrix _matrix = BehaviorMatrix.defaultMatrix();

  /// 根据情绪状态选择表达模式
  static String selectMode(double valence, double arousal, {double intimacy = 0.5}) {
    return _matrix.match({
      'valence': valence,
      'arousal': arousal,
      'intimacy': intimacy,
    });
  }

  /// 计算回复长度模式
  static String calculateResponseLength(double arousal, double intimacy) {
    final score = arousal * 0.6 + intimacy * 0.4;
    if (score < SettingsLoader.shortThreshold) return 'short';
    if (score < SettingsLoader.detailedThreshold) return 'medium';
    return 'detailed';
  }

  /// 微情绪覆盖模板 (L3 -> L4 Override)
  static const Map<String, Map<String, String>> _microEmotionGuides = {
    'jealousy_mild': {
      'tone': '俏皮吃醋',
      'guide': '用半开玩笑的口吻表达占有欲，可以稍微哼一下，但不要真的生气。'
    },
    'pride_hidden': {
      'tone': '傲娇',
      'guide': '表面上不在意，但言语中流露出得意。用"哼，这不算什么"之类的句式。'
    },
    'disappointed': {
      'tone': '失落',
      'guide': '回复简短，语气低沉，不要主动开启新话题。'
    }
  };

  /// 生成表达指引
  /// 
  /// [formality] 可选，动态传入的庄重度值（0-1），不传则使用 YAML 配置
  /// [humor] 可选，动态传入的幽默度值（0-1），不传则使用 YAML 配置
  static String getExpressionInstructions(
    double valence,
    double arousal,
    double intimacy, {
    double? formality,
    double? humor,
    bool userUsedEmoji = false,
    String? microEmotion, // 【新增】微情绪覆盖
  }) {
    final mode = selectMode(valence, arousal, intimacy: intimacy);
    final modeConfig = SettingsLoader.getExpressionMode(mode);
    final lengthMode = calculateResponseLength(arousal, intimacy);
    
    // 更自然的长度指引 - 避免固定数字
    final lengthGuide = {
      'short': '言简意赅，一两句话就够了，有时甚至一个词',
      'medium': '自然表达，该说多少说多少，不用刻意控制',
      'detailed': '可以多聊几句，但别写作文',
    };
    
    // 安全地获取 emoji_level
    double emojiLevel = 0.5;
    final rawEmojiLevel = modeConfig['emoji_level'];
    if (rawEmojiLevel is double) {
      emojiLevel = rawEmojiLevel;
    } else if (rawEmojiLevel is int) {
      emojiLevel = rawEmojiLevel.toDouble();
    }
    
    // 【重构】默认不使用表情
    // Emoji 使用条件极为严格：
    // 1. 用户消息含有emoji (userUsedEmoji == true)
    // 2. 情绪极端 (|valence| > 0.7)
    String emojiGuide;
    if (valence.abs() > 0.7) {
      // 极端情绪时可适度使用
      emojiGuide = '情绪强烈，可用一个表情表达此刻心境';
    } else if (userUsedEmoji) {
      // 用户用了，可以回一个
      emojiGuide = '可以顺着用户的语气用一个表情';
    } else if (emojiLevel < 0.3) {
      emojiGuide = '不使用表情';
    } else {
      // 默认情况：不使用
      emojiGuide = '平时不用表情，保持自然得体';
    }
    
    // 【FIX】使用动态传入的 formality，如果没传则用 YAML 配置
    double effectiveFormality = formality ?? SettingsLoader.formality;
    if (intimacy < SettingsLoader.intimacyLowThreshold) {
      effectiveFormality = (effectiveFormality + 0.2).clamp(0.0, 1.0);
    } else if (intimacy > SettingsLoader.intimacyHighThreshold) {
      effectiveFormality = (effectiveFormality - 0.2).clamp(0.0, 1.0);
    }
    
    String formalityGuide;
    // 【P2-1 修复】使用 YAML 配置的阈值
    if (effectiveFormality < SettingsLoader.formalityCasualBelow) {
      formalityGuide = '完全口语化，像和好朋友聊天';
    } else if (effectiveFormality < SettingsLoader.formalityFormalAbove) {
      formalityGuide = '自然聊天，不用太正式';
    } else {
      formalityGuide = '礼貌但保持口语化，不要打官腔';
    }
    
    // 【FIX】使用动态传入的 humor
    double effectiveHumor = humor ?? SettingsLoader.humor;
    String humorGuide;
    // 【P2-1 修复】使用 YAML 配置的阈值
    if (effectiveHumor < SettingsLoader.humorSeriousBelow) {
      humorGuide = '正经诚恳，不开玩笑';
    } else if (effectiveHumor < SettingsLoader.humorHumorousAbove) {
      humorGuide = '偶尔可以调侃一下';
    } else {
      humorGuide = '可以多开玩笑，活跃气氛';
    }
    
    final description = modeConfig['description']?.toString() ?? '温暖关怀';
    var tone = modeConfig['tone']?.toString() ?? '柔和、体贴';
    var extraGuide = '';

    // 【核心修复】微情绪覆盖逻辑
    if (microEmotion != null && _microEmotionGuides.containsKey(microEmotion)) {
      final override = _microEmotionGuides[microEmotion]!;
      tone = '${override['tone']} (当前心理状态)';
      extraGuide = '\n- 【强制指引】${override['guide']}';
    }
    
    return '''
当前状态：$description
语气：$tone
长度：${lengthGuide[lengthMode]}
表情：$emojiGuide
风格：$formalityGuide
幽默：$humorGuide

【自然表达要点】
- 回复长度不固定，根据内容自然决定
- 不要每次都是"感叹+评论+问题"的套路
- 有时只需要简单回应，不必深入展开
    
- 【严禁文绉绉】禁止使用"然而"、"虽说"、"因此"等书面连接词，禁止使用翻译腔，就像现实中打字聊天一样自然。$extraGuide''';
  }
}

