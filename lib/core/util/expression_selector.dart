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
    
    String emojiGuide;
    if (emojiLevel < 0.3) {
      emojiGuide = '基本不用表情';
    } else if (emojiLevel < 0.5) {
      emojiGuide = '偶尔用一个表情点缀就好';
    } else if (emojiLevel < 0.7) {
      emojiGuide = '可以用表情，但别每句都加';
    } else {
      emojiGuide = '可以活泼点用表情';
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
      formalityGuide = '完全口语化，像和好朋友聊天';
    } else if (formality < 0.6) {
      formalityGuide = '自然聊天，不用太正式';
    } else {
      formalityGuide = '稍微客气一点';
    }
    
    final description = modeConfig['description']?.toString() ?? '温暖关怀';
    final tone = modeConfig['tone']?.toString() ?? '柔和、体贴';
    
    return '''
当前状态：$description
语气：$tone
长度：${lengthGuide[lengthMode]}
表情：$emojiGuide
风格：$formalityGuide

【自然表达要点】
- 回复长度不固定，根据内容自然决定
- 不要每次都是"感叹+评论+问题"的套路
- 有时只需要简单回应，不必深入展开''';
  }
}

