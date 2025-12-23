import '../settings_loader.dart';

/// 表达选择器 - 使用动态 YAML 配置
class ExpressionSelector {

  /// 根据情绪状态选择表达模式
  static String selectMode(double valence, double arousal) {
    if (valence > 0.3 && arousal >= 0.5) return 'excited';
    if (valence > 0.3 && arousal < 0.5) return 'playful';
    if (valence < -0.2 && arousal < 0.5) return 'empathetic';
    if (valence >= -0.2 && valence <= 0.3 && arousal < 0.4) return 'calm';
    return 'warm';
  }

  /// 计算回复长度模式
  static String calculateResponseLength(double arousal, double intimacy) {
    final score = arousal * 0.6 + intimacy * 0.4;
    if (score < SettingsLoader.shortThreshold) return 'short';
    if (score < SettingsLoader.detailedThreshold) return 'medium';
    return 'detailed';
  }

  /// 生成表达指引
  static String getExpressionInstructions(
    double valence,
    double arousal,
    double intimacy,
  ) {
    final mode = selectMode(valence, arousal);
    final modeConfig = SettingsLoader.getExpressionMode(mode);
    final lengthMode = calculateResponseLength(arousal, intimacy);
    
    final lengthGuide = {
      'short': '简洁回复，1-2句话，像微信聊天一样',
      'medium': '适中长度，可以分2-3段发送',
      'detailed': '可以详细一些，分多个气泡发送',
    };
    
    // 安全地获取 emoji_level，处理可能的类型问题
    double emojiLevel = 0.5;
    final rawEmojiLevel = modeConfig['emoji_level'];
    if (rawEmojiLevel is double) {
      emojiLevel = rawEmojiLevel;
    } else if (rawEmojiLevel is int) {
      emojiLevel = rawEmojiLevel.toDouble();
    }
    
    String emojiGuide;
    if (emojiLevel < 0.3) {
      emojiGuide = '几乎不用表情';
    } else if (emojiLevel < 0.5) {
      emojiGuide = '偶尔使用表情点缀';
    } else if (emojiLevel < 0.7) {
      emojiGuide = '可以使用表情增加活力，但不要过多';
    } else {
      emojiGuide = '可以较多使用表情，保持活泼';
    }
    
    // 正式程度受亲密度影响
    double formality = SettingsLoader.formality;
    if (intimacy < SettingsLoader.intimacyLowThreshold) {
      formality = (formality + 0.2).clamp(0.0, 1.0);
    } else if (intimacy > SettingsLoader.intimacyHighThreshold) {
      formality = (formality - 0.2).clamp(0.0, 1.0);
    }
    
    String formalityGuide;
    if (formality < 0.3) {
      formalityGuide = '非常口语化，像朋友聊天';
    } else if (formality < 0.6) {
      formalityGuide = '自然口语，但保持得体';
    } else {
      formalityGuide = '稍正式一些，保持礼貌';
    }
    
    final description = modeConfig['description']?.toString() ?? '温暖关怀';
    final tone = modeConfig['tone']?.toString() ?? '柔和、体贴';
    
    return '''
表达模式：$description
语气基调：$tone
回复长度：${lengthGuide[lengthMode]}
表情使用：$emojiGuide
语言风格：$formalityGuide''';
  }
}
