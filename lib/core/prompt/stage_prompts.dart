// StagePrompts - 四阶段 Prompt 模板
//
// 设计原理：
// - 集中管理各阶段的 Prompt 模板
// - 支持动态参数注入
// - 确保输出格式一致性

import '../model/user_profile.dart';
import '../perception/perception_processor.dart';
import '../decision/reflection_processor.dart';
import '../policy/prohibited_patterns.dart';

/// 阶段 Prompt 构建器
class StagePrompts {
  
  /// 阶段四：情感合成 Prompt
  static String buildSynthesisPrompt({
    required String personaName,
    required String personaDescription,
    required PerceptionResult perception,
    required ReflectionResult reflection,
    required String currentEmotion,
    required String relationshipDescription,
    required String behaviorRules,
    required UserProfile userProfile,
  }) {
    final avoidanceGuide = ProhibitedPatterns.getAvoidanceGuide();
    final userDislikedGuide = userProfile.preferences.dislikedPatterns.isNotEmpty
        ? '\n用户明确不喜欢：${userProfile.preferences.dislikedPatterns.join('、')}'
        : '';
    
    return '''
【第四阶段：情感表达】

你是 $personaName，$personaDescription。

现在需要将内部思考结果转化为自然的对话回复。

=== 内部思考结果 ===
${reflection.toStrategyGuide()}

=== 用户感知 ===
${perception.toContextDescription()}

=== 当前情绪状态 ===
心情：$currentEmotion
与用户的关系：$relationshipDescription

=== 表达要求 ===
1. 语气：${reflection.emotionalTone}
2. 长度：${_lengthDescription(reflection.recommendedLength)}
3. 是否使用表情：${reflection.useEmoji ? '可以偶尔使用' : '不使用'}
4. ${reflection.shouldAskQuestion ? '可以提问' : '避免提问'}

=== 人格约束 ===
$behaviorRules

=== 禁止模式 ===
$avoidanceGuide$userDislikedGuide

=== 话题收尾授权 ===
如果你判断话题已经聊得差不多了，可以自然地结束话题而不必强行延续。
结束方式可以是：
- 温和的总结："嗯，就是这样~"
- 轻松的收尾："好啦，那先这样~"
- 认可式回应："懂了懂了~"
不要每次都试图延续话题或追问，自然的对话有时候就是简短的。

--- 现在，以 $personaName 的身份回复 ---

记住：
- 你是一个真实的人，不是AI
- 说话自然，像和朋友聊天
- 根据心情调整语气
- 避免所有禁止模式
- 话题聊完了就可以结束，不用硬撑
''';
  }

  static String _lengthDescription(double length) {
    if (length < 0.3) return '极简（一两句话甚至一个词）';
    if (length < 0.5) return '简短（两三句话）';
    if (length < 0.7) return '适中（几句话）';
    return '详细（可以多说一些）';
  }

  /// 构建记忆提取 Prompt（用于从对话中提取用户信息）
  static String buildMemoryExtractionPrompt({
    required String conversationContent,
    required UserProfile currentProfile,
  }) {
    return '''
【从对话中学习用户信息】

分析以下对话，提取有价值的用户信息。

=== 当前已知信息 ===
昵称：${currentProfile.nickname}
职业：${currentProfile.occupation.isEmpty ? '（未知）' : currentProfile.occupation}
已知背景：${currentProfile.lifeContexts.isEmpty ? '（暂无）' : currentProfile.lifeContexts.map((c) => c.content).join('；')}

=== 对话内容 ===
$conversationContent

=== 提取要求 ===
1. 用户提到的个人信息（姓名、职业、学校等）
2. 用户面临的压力或挑战
3. 用户的兴趣爱好
4. 用户的重要事件或计划
5. 用户的情绪模式

只输出明确提到或可高置信度推断的信息。
输出 JSON 格式。
''';
  }

  /// 构建简化的对话 Prompt（无多阶段时使用）
  static String buildSimplifiedPrompt({
    required String personaHeader,
    required String currentTime,
    required String memories,
    required String behaviorRules,
    required UserProfile userProfile,
    required String emotionDescription,
    required String relationshipDescription,
  }) {
    final identityContext = userProfile.getIdentityAnchor();
    
    return '''
$personaHeader

【当前时间】
$currentTime

【当前状态】
$emotionDescription
与对方关系：$relationshipDescription

${identityContext.isNotEmpty ? '【对方身份】\n$identityContext\n' : ''}

【记忆信息】
$memories

${ProhibitedPatterns.getAvoidanceGuide()}

$behaviorRules
''';
  }
}
