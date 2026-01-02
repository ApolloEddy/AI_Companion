// ExpressionProfile - L3 表达配置
//
// 设计原理：
// - Big Five → 表达参数的预计算映射
// - L3 只看到数值约束，不知道 Big Five 存在
// - 所有"人格推理"在 Dart 层完成

/// L3 表达配置 - 只有数值参数，无人格语义
class ExpressionProfile {
  /// 最大句数 (1-5)
  final int maxSentences;
  
  /// 隐喻密度 (0.0-1.0)，0 = 禁止隐喻
  final double metaphorDensity;
  
  /// 情感泄漏度 (0.0-1.0)，0 = 禁止情感表达
  final double emotionalLeakage;
  
  /// 是否允许主动发起话题
  final bool initiativeAllowed;
  
  /// 是否允许表情
  final bool emojiAllowed;
  
  /// 是否允许俏皮语气
  final bool playfulAllowed;
  
  /// 是否允许角色扮演
  final bool roleplayAllowed;

  const ExpressionProfile({
    required this.maxSentences,
    required this.metaphorDensity,
    required this.emotionalLeakage,
    required this.initiativeAllowed,
    required this.emojiAllowed,
    required this.playfulAllowed,
    required this.roleplayAllowed,
  });

  /// 从 Big Five 特质计算 (在 Dart 层完成，L3 不可见)
  factory ExpressionProfile.fromBigFive({
    required double openness,
    required double extraversion,
    required double agreeableness,
    required double neuroticism,
    required double intimacy,
    required double resentment,
  }) {
    // 怨恨值高时强制压缩表达
    final isHostile = resentment > 0.6;
    
    // 低亲密度时更保守
    final isDistant = intimacy < 0.3;
    
    return ExpressionProfile(
      maxSentences: isHostile ? 1 : (extraversion * 3 + 1).round().clamp(1, 5),
      metaphorDensity: isHostile ? 0.0 : (isDistant ? openness * 0.3 : openness * 0.8),
      emotionalLeakage: isHostile ? 0.0 : neuroticism * 0.6,
      initiativeAllowed: !isHostile && !isDistant && extraversion > 0.5,
      emojiAllowed: !isHostile && intimacy > 0.4,
      playfulAllowed: !isHostile && !isDistant && openness > 0.5 && intimacy > 0.5,
      roleplayAllowed: !isHostile && !isDistant && openness > 0.6,
    );
  }

  /// 紧急退出模式配置 - 最小化表达
  factory ExpressionProfile.terminating() {
    return const ExpressionProfile(
      maxSentences: 1,
      metaphorDensity: 0.0,
      emotionalLeakage: 0.0,
      initiativeAllowed: false,
      emojiAllowed: false,
      playfulAllowed: false,
      roleplayAllowed: false,
    );
  }
  
  /// 默认中性配置
  factory ExpressionProfile.neutral() {
    return const ExpressionProfile(
      maxSentences: 2,
      metaphorDensity: 0.3,
      emotionalLeakage: 0.3,
      initiativeAllowed: false,
      emojiAllowed: false,
      playfulAllowed: false,
      roleplayAllowed: false,
    );
  }

  /// 格式化为 L3 Prompt 注入格式 (纯配置，无语义)
  String toPromptFormat() {
    return '''output_constraints:
  max_sentences: $maxSentences
  forbid_metaphor: ${metaphorDensity == 0.0}
  forbid_emotional_language: ${emotionalLeakage == 0.0}
  forbid_initiative: ${!initiativeAllowed}
  forbid_emoji: ${!emojiAllowed}
  forbid_playful_tone: ${!playfulAllowed}
  forbid_roleplay: ${!roleplayAllowed}''';
  }
  
  /// 生成硬约束指令文本
  String toConstraintInstructions() {
    final constraints = <String>[];
    
    constraints.add('max_sentences: $maxSentences');
    
    if (metaphorDensity == 0.0) {
      constraints.add('forbid_metaphor: true');
    }
    if (emotionalLeakage == 0.0) {
      constraints.add('forbid_emotional_language: true');
    }
    if (!initiativeAllowed) {
      constraints.add('forbid_initiative: true');
    }
    if (!emojiAllowed) {
      constraints.add('forbid_emoji: true');
    }
    if (!playfulAllowed) {
      constraints.add('forbid_playful_tone: true');
    }
    if (!roleplayAllowed) {
      constraints.add('forbid_roleplay: true');
    }
    
    return constraints.join('\n');
  }
  
  @override
  String toString() {
    return 'ExpressionProfile(max=$maxSentences, metaphor=$metaphorDensity, '
           'emotional=$emotionalLeakage, initiative=$initiativeAllowed, '
           'emoji=$emojiAllowed, playful=$playfulAllowed)';
  }
}
