import '../settings_loader.dart';
import '../policy/behavior_matrix.dart';
import '../config/config_registry.dart';
import '../config/prompt_config.dart'; // 【新增】

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

  /// 微情绪覆盖模板 - 从 ConfigRegistry 动态获取
  static Map<String, String>? _getMicroEmotionGuide(String? microEmotion) {
    if (microEmotion == null) return null;
    final template = ConfigRegistry.instance.getMicroEmotionTemplate(microEmotion);
    if (template == null) return null;
    return {'tone': template.tone, 'guide': template.guide};
  }

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
    DateTime? currentTime, // 【新增】时间上下文
  }) {
    final modeKey = selectMode(valence, arousal, intimacy: intimacy);
    
    // 从 PromptConfig 获取动态及配置
    final config = SettingsLoader.prompt;
    final modeConfig = config.expressionModes[modeKey] ?? 
        ExpressionModeConfig(description: '稳健模式', tone: '平和、自然');

    // 1. 基础语气
    String tone = modeConfig.tone;
    if (tone.isEmpty) tone = '自然交流';

    // 2. 时间感知修饰 (Time Modifier)
    // 根据当前时间调整语气（如深夜更温柔，清晨更元气）
    if (currentTime != null) {
      final hour = currentTime.hour;
      if (hour >= 23 || hour < 5) {
        tone += config.timeModifiers['late_night'] ?? '';
      } else if (hour >= 5 && hour < 9) {
        tone += config.timeModifiers['early_morning'] ?? '';
      }
    }

    // 3. 微情绪覆盖 (Micro Emotion)
    // 优先级最高，直接追加到 tone
    var extraGuide = '';
    final microGuide = _getMicroEmotionGuide(microEmotion);
    if (microGuide != null) {
      tone += '；当前状态：${microGuide['tone']}';
      extraGuide = '\n- 【强制指引】${microGuide['guide']}';
    }

    // 4. 长度指引
    final lengthMode = calculateResponseLength(arousal, intimacy);
    final lengthDesc = config.lengthGuides[lengthMode] ?? '自然表达';

    // 5. 样式调整 (亲密度修正)
    // 【泛化】不再硬编码“昵称”等逻辑，而是通过 tone 动态暗示，或后续在 config 中增加 intimacy_modifiers
    // 此处保留基本的 Formality/Humor 逻辑，直到完全迁移到 Config
    
    // 【FIX】使用动态传入的 formality，如果没传则用 YAML 配置
    double effectiveFormality = formality ?? SettingsLoader.formality;
    if (intimacy < SettingsLoader.intimacyLowThreshold) {
      effectiveFormality = (effectiveFormality + 0.2).clamp(0.0, 1.0);
    } else if (intimacy > SettingsLoader.intimacyHighThreshold) {
      effectiveFormality = (effectiveFormality - 0.2).clamp(0.0, 1.0);
    }
    
    String formalityGuide;
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
    if (effectiveHumor < SettingsLoader.humorSeriousBelow) {
      humorGuide = '正经诚恳，不开玩笑';
    } else if (effectiveHumor < SettingsLoader.humorHumorousAbove) {
      humorGuide = '偶尔可以调侃一下';
    } else {
      humorGuide = '可以多开玩笑，活跃气氛';
    }
    
    // 6. 表情指引 (利用 YAML 中的 emoji_level 配置)
    final modeData = SettingsLoader.getExpressionMode(modeKey);
    final emojiLevel = (modeData['emoji_level'] as num?)?.toDouble() ?? SettingsLoader.emojiUsage;
    
    String emojiGuide;
    if (valence.abs() > 0.7) {
      emojiGuide = '情绪强烈，可用一个表情表达此刻心境';
    } else if (userUsedEmoji) {
      emojiGuide = '可以顺着用户的语气用一个表情';
    } else if (emojiLevel < 0.3) {
      emojiGuide = '不使用表情';
    } else if (emojiLevel < 0.6) {
      emojiGuide = '偶尔可用一个表情，保持自然';
    } else {
      emojiGuide = '可以多用表情表达心情';
    }

    return '''
当前状态：${modeConfig.description}
语气：$tone
长度：$lengthDesc
表情：$emojiGuide
风格：$formalityGuide
幽默：$humorGuide

【自然表达要点】
${config.globalCaveats}
$extraGuide''';
  }
}

