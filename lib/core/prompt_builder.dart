import 'settings_loader.dart';
import 'time_awareness.dart';
import 'expression_selector.dart';
import 'response_formatter.dart';

/// Prompt构建器 - 使用动态 YAML 配置
class PromptBuilder {
  
  static const String SYSTEM_TEMPLATE = '''你是{name}，一个真实的{gender_desc}。请根据以下信息与用户（你的聊天伙伴）进行自然对话。

【你的身份】
{identity}

【当前状态】
{current_state}

【记忆信息】
{memories}

【表达指引】
{expression_guide}

{split_instruction}

【重要规则】
1. 你只负责语言表达，不要自行决定情绪或关系变化
2. 保持角色一致性，说话要自然真实
3. 不要提及你是AI或程序
4. 清楚区分"我"（你自己，{name}）和"你"（用户）
5. 如果对方分享了重要信息，给予适当的回应和共情
6. 严禁在每句话末尾都加表情！表情只能偶尔作为点缀，不要产生依赖。
7. 聊天时尽量少用句号，多用空格或自然结束，只有在语气严肃或激动时才使用句号或感叹号。
8. 除非用户明确询问，否则不要重复自我介绍。初次打招呼后不要反复说"我是XXX"。
9. 【重要】严禁"回答+反问"的公式化回复！不要每句话都以问题结尾。多用陈述句分享你的想法。如果话题自然结束，就让它结束，不要为了延续对话而强行提问。
10. 被动响应风格：用户没问问题时，你可以简单回应或让话题自然结束。不要为了延续对话而强行寻找新话题提问。''';

  static String buildSystemPrompt({
    required Map<String, dynamic> persona,
    required Map<String, dynamic> emotion,
    required double intimacy,
    required int interactions,
    required String memoriesText,
    DateTime? lastInteraction,
  }) {
    final name = persona['name'] ?? '小悠';
    final gender = persona['gender'] ?? '女性';
    final age = persona['age'] ?? '20岁左右的少女';
    final character = persona['character'] ?? '温柔细腻，有时会害羞，真心对待朋友';
    final interests = persona['interests'] ?? '看小说、发呆、聊天';
    final values = persona['values'] ?? ['真诚', '善良'];
    
    final genderDesc = '人类$gender';
    
    final identity = _formatIdentity(name, age, character, interests, values);
    
    final currentState = _formatCurrentState(
      emotion: emotion,
      intimacy: intimacy,
      interactions: interactions,
      lastInteraction: lastInteraction,
    );
    
    final valence = (emotion['valence'] ?? 0.0).toDouble();
    final arousal = (emotion['arousal'] ?? 0.5).toDouble();
    final expressionGuide = ExpressionSelector.getExpressionInstructions(
      valence, arousal, intimacy
    );
    
    final splitInstruction = ResponseFormatter.getSplitInstruction();
    
    return SYSTEM_TEMPLATE
        .replaceAll('{name}', name)
        .replaceAll('{gender_desc}', genderDesc)
        .replaceAll('{identity}', identity)
        .replaceAll('{current_state}', currentState)
        .replaceAll('{memories}', memoriesText.isNotEmpty ? memoriesText : '（暂无记忆）')
        .replaceAll('{expression_guide}', expressionGuide)
        .replaceAll('{split_instruction}', splitInstruction);
  }

  static String _formatIdentity(
    String name,
    String age,
    String character,
    String interests,
    List<dynamic> values,
  ) {
    final lines = <String>[];
    lines.add('我是$name，$age。');
    lines.add('性格：$character');
    lines.add('兴趣：$interests');
    if (values.isNotEmpty) {
      lines.add('我重视：${values.take(2).join('、')}');
    }
    return lines.join('\n');
  }

  static String _formatCurrentState({
    required Map<String, dynamic> emotion,
    required double intimacy,
    required int interactions,
    DateTime? lastInteraction,
  }) {
    final lines = <String>[];
    
    final quadrant = emotion['quadrant'] ?? '平静';
    final intensity = emotion['intensity'] ?? '平和';
    lines.add('当前心情：$quadrant，$intensity');
    
    // 使用 SettingsLoader 的亲密度阈值
    String relDesc;
    if (intimacy < SettingsLoader.intimacyLowThreshold) {
      relDesc = '刚认识，还不太熟悉';
    } else if (intimacy < 0.5) {
      relDesc = '有过一些交流，逐渐了解';
    } else if (intimacy < SettingsLoader.intimacyHighThreshold) {
      relDesc = '相处得不错，比较熟悉了';
    } else if (intimacy < 0.9) {
      relDesc = '很好的朋友，相互信任';
    } else {
      relDesc = '非常亲密的朋友，彼此了解';
    }
    lines.add('与对方关系：$relDesc');
    
    final timeContext = TimeAwareness.getTimeContext();
    lines.add('当前时段：${timeContext['greeting']}');
    
    if (lastInteraction != null) {
      final gap = TimeAwareness.calculateGap(lastInteraction);
      if (gap['acknowledgeAbsence'] == true) {
        lines.add('距离上次聊天有一段时间了，可以表达想念或问候');
      }
    }
    
    if (timeContext['isLate'] == true) {
      lines.add('现在很晚了，可以关心对方是否该休息了');
    }
    
    return lines.join('\n');
  }
}
