// PromptBuilder - L3/L4 分层 Prompt 构建器
//
// 设计原理：
// - L3 (Intent/Decision): 将用户消息+记忆+画像 → 结构化意图 JSON
// - L4 (Expression): 将 L3 意图+V-A状态 → 微信风格口语化输出
// - 代词锚定: L3 使用第三人称思考，L4 映射回第二人称表达
// - 确保输出格式一致性

import '../settings_loader.dart'; // 【新增】
import '../model/user_profile.dart';
import '../perception/perception_processor.dart';
import '../decision/reflection_processor.dart';
import '../policy/prohibited_patterns.dart';

/// L3 意图结果 - 结构化的决策输出
class L3IntentResult {
  final String innerMonologue;      // 内心独白
  final String responseStrategy;    // 回复策略
  final String emotionalTone;       // 情绪基调
  final double recommendedLength;   // 建议长度 (0-1)
  final bool useEmoji;              // 是否使用表情
  final bool shouldAskQuestion;     // 是否提问
  final String? microEmotion;       // 微情绪
  final Map<String, double>? emotionShift; // 情绪偏移

  const L3IntentResult({
    required this.innerMonologue,
    required this.responseStrategy,
    this.emotionalTone = '平和',
    this.recommendedLength = 0.5,
    this.useEmoji = false,
    this.shouldAskQuestion = false,
    this.microEmotion,
    this.emotionShift,
  });

  /// 从 JSON 解析
  factory L3IntentResult.fromJson(Map<String, dynamic> json) {
    return L3IntentResult(
      innerMonologue: json['inner_monologue'] ?? json['innerMonologue'] ?? '',
      responseStrategy: json['response_strategy'] ?? json['responseStrategy'] ?? '',
      emotionalTone: json['emotional_tone'] ?? json['emotionalTone'] ?? '平和',
      recommendedLength: (json['recommended_length'] ?? json['recommendedLength'] ?? 0.5).toDouble(),
      useEmoji: json['use_emoji'] ?? json['useEmoji'] ?? false,
      shouldAskQuestion: json['should_ask_question'] ?? json['shouldAskQuestion'] ?? false,
      microEmotion: json['micro_emotion'] ?? json['microEmotion'],
      emotionShift: json['emotion_shift'] != null 
          ? Map<String, double>.from(json['emotion_shift'].map((k, v) => MapEntry(k, (v as num).toDouble())))
          : null,
    );
  }

  /// 降级：从规则生成
  factory L3IntentResult.fallback({String userMessage = ''}) {
    final length = userMessage.length;
    return L3IntentResult(
      innerMonologue: '（快速响应模式）',
      responseStrategy: '自然回应',
      emotionalTone: '平和',
      recommendedLength: length > 50 ? 0.6 : 0.4,
      useEmoji: false,
      shouldAskQuestion: false,
    );
  }

  /// 格式化为策略指导（供 L4 使用）
  String toStrategyGuide() {
    return '''
内心独白：$innerMonologue
回复策略：$responseStrategy
情绪基调：$emotionalTone
建议长度：${_lengthDescription(recommendedLength)}
${microEmotion != null ? '微情绪：$microEmotion' : ''}
'''.trim();
  }

  static String _lengthDescription(double length) {
    if (length < 0.3) return '极简';
    if (length < 0.5) return '简短';
    if (length < 0.7) return '适中';
    return '详细';
  }
}

/// Prompt 构建器 - L3/L4 分层架构
class PromptBuilder {
  
  // ==================== L3: Intent/Decision Layer ====================
  
  /// L3 意图生成 Prompt
  /// 
  /// 输入: 用户消息 + 记忆 + 画像 + V-A状态
  /// 输出: JSON 格式 {inner_monologue, response_strategy, ...}
  /// 
  /// 【代词锚定】思考对象使用第三人称（他/她），禁止使用"你"
  static String buildL3IntentPrompt({
    required String userMessage,
    required String userName,
    required String memories,
    required UserProfile userProfile,
    required double valence,
    required double arousal,
    required String personaName,
    String? lastAiResponse,
  }) {
    final template = SettingsLoader.prompt.systemPrompts['l3_intent'];
    if (template == null || template.isEmpty) {
      // Fallback if template missing
      return 'Critical Error: L3 Intent Prompt template missing.';
    }

    final genderLower = userProfile.gender?.toLowerCase() ?? '';
    final isMale = genderLower == 'male' || genderLower == 'man' || genderLower == '男';
    final userGender = isMale ? '他' : '她';
    final emotionDesc = _getEmotionDescription(valence, arousal);
    
    // 注入参数
    return template
        .replaceAll('{personaName}', personaName)
        .replaceAll('{userName}', userName)
        .replaceAll('{userGender}', userGender)
        .replaceAll('{valence}', valence.toStringAsFixed(2))
        .replaceAll('{arousal}', arousal.toStringAsFixed(2))
        .replaceAll('{emotionDesc}', emotionDesc)
        .replaceAll('{userOccupation}', userProfile.occupation.isNotEmpty ? '职业: ${userProfile.occupation}' : '')
        .replaceAll('{userMajor}', userProfile.major != null && userProfile.major!.isNotEmpty ? '专业: ${userProfile.major}' : '')
        .replaceAll('{memories}', memories)
        .replaceAll('{lastAiResponse}', lastAiResponse ?? '（这是对话开始）')
        .replaceAll('{userMessage}', userMessage);
  }

  // ==================== L4: Expression Layer ====================

  /// L4 表达合成 Prompt
  /// 
  /// 输入: L3 意图结果 + V-A状态 + 人格上下文
  /// 输出: 微信风格口语化回复
  /// 
  /// 【代词锚定】L3中的"他/她"映射回"你"
  static String buildL4ExpressionPrompt({
    required L3IntentResult l3Result,
    required String userName,
    required String personaName,
    required String personaDescription,
    required double valence,
    required double arousal,
    required String relationshipDescription,
    required String behaviorRules,
    required UserProfile userProfile,
  }) {
    final template = SettingsLoader.prompt.systemPrompts['l4_expression'];
    if (template == null || template.isEmpty) {
      return 'Critical Error: L4 Expression Prompt template missing.';
    }

    final genderLower = userProfile.gender?.toLowerCase() ?? '';
    final isMale = genderLower == 'male' || genderLower == 'man' || genderLower == '男';
    final userGender = isMale ? '他' : '她';
    final avoidanceGuide = ProhibitedPatterns.getAvoidanceGuide();
    final userDislikedGuide = userProfile.preferences.dislikedPatterns.isNotEmpty
        ? '\n用户明确不喜欢：${userProfile.preferences.dislikedPatterns.join('、')}'
        : '';
    
    return template
        .replaceAll('{personaName}', personaName)
        .replaceAll('{personaDescription}', personaDescription)
        .replaceAll('{userName}', userName)
        .replaceAll('{userGender}', userGender)
        .replaceAll('{strategyGuide}', l3Result.toStrategyGuide())
        .replaceAll('{valence}', valence.toStringAsFixed(2))
        .replaceAll('{valenceLabel}', _getValenceLabel(valence))
        .replaceAll('{arousal}', arousal.toStringAsFixed(2))
        .replaceAll('{arousalLabel}', _getArousalLabel(arousal))
        .replaceAll('{relationshipDescription}', relationshipDescription)
        .replaceAll('{emotionalTone}', l3Result.emotionalTone)
        .replaceAll('{lengthDescription}', _lengthDescription(l3Result.recommendedLength))
        .replaceAll('{emojiUsage}', l3Result.useEmoji ? '可以偶尔使用' : '不使用')
        .replaceAll('{askQuestion}', l3Result.shouldAskQuestion ? '可以提问' : '避免提问')
        .replaceAll('{behaviorRules}', behaviorRules)
        .replaceAll('{avoidanceGuide}', avoidanceGuide)
        .replaceAll('{userDislikedGuide}', userDislikedGuide);
  }

  // ==================== Legacy Methods (向后兼容) ====================

  /// 阶段四：情感合成 Prompt (向后兼容)
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
    final template = SettingsLoader.prompt.systemPrompts['memory_extraction'];
    if (template == null || template.isEmpty) return '';

    return template
        .replaceAll('{nickname}', currentProfile.nickname)
        .replaceAll('{occupation}', currentProfile.occupation.isEmpty ? '（未知）' : currentProfile.occupation)
        .replaceAll('{knownContext}', currentProfile.lifeContexts.isEmpty ? '（暂无）' : currentProfile.lifeContexts.map((c) => c.content).join('；'))
        .replaceAll('{conversationContent}', conversationContent);
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
    final template = SettingsLoader.prompt.systemPrompts['simplified'];
    if (template == null || template.isEmpty) return '';

    final identityContext = userProfile.getIdentityAnchor();
    
    return template
        .replaceAll('{personaHeader}', personaHeader)
        .replaceAll('{currentTime}', currentTime)
        .replaceAll('{emotionDescription}', emotionDescription)
        .replaceAll('{relationshipDescription}', relationshipDescription)
        .replaceAll('{identityContext}', identityContext.isNotEmpty ? '【对方身份】\n$identityContext\n' : '')
        .replaceAll('{memories}', memories)
        .replaceAll('{avoidanceGuide}', ProhibitedPatterns.getAvoidanceGuide())
        .replaceAll('{behaviorRules}', behaviorRules);
  }

  // ==================== Helper Methods ====================

  static String _getEmotionDescription(double valence, double arousal) {
    if (valence > 0.5 && arousal > 0.6) return '兴奋愉悦';
    if (valence > 0.3 && arousal < 0.5) return '平静满足';
    if (valence < -0.5 && arousal > 0.6) return '烦躁焦虑';
    if (valence < -0.3 && arousal < 0.4) return '低落消沉';
    if (arousal > 0.7) return '高度活跃';
    if (arousal < 0.3) return '疲惫慵懒';
    return '平和稳定';
  }

  static String _getValenceLabel(double valence) {
    if (valence > 0.5) return '愉悦';
    if (valence > 0.0) return '略正面';
    if (valence > -0.5) return '略负面';
    return '低落';
  }

  static String _getArousalLabel(double arousal) {
    if (arousal > 0.7) return '高活力';
    if (arousal > 0.4) return '适中';
    return '低活力';
  }
}

// ==================== 向后兼容别名 ====================

/// 向后兼容：StagePrompts 别名
typedef StagePrompts = PromptBuilder;
