// PromptBuilder - L2/L3 分层 Prompt 构建器
//
// 设计原理：
// - L2 (Decision): 将用户消息+记忆+画像 → 结构化意图 JSON
// - L3 (Expression): 将 L2 意图+V-A状态 → 微信风格口语化输出
// - 代词锚定: L2 使用第三人称思考，L3 映射回第二人称表达
// - 确保输出格式一致性

import '../settings_loader.dart'; // 【新增】
import '../model/user_profile.dart';
import '../perception/perception_processor.dart';
import '../decision/reflection_processor.dart';
import '../policy/prohibited_patterns.dart';


/// L2 决策结果 - 结构化的决策输出
class L2DecisionResult {
  final String innerMonologue;      // 内心独白
  final String responseStrategy;    // 回复策略
  final String emotionalTone;       // 情绪基调
  final double recommendedLength;   // 建议长度 (0-1)
  final bool useEmoji;              // 是否使用表情
  final bool shouldAskQuestion;     // 是否提问
  final String? microEmotion;       // 微情绪
  final Map<String, double>? emotionShift; // 情绪偏移
  final String pacingStrategy;      // 【Phase 1】节奏策略
  final String topicDepth;          // 【Phase 1】话题深度
  
  const L2DecisionResult({
    required this.innerMonologue,
    required this.responseStrategy,
    this.emotionalTone = '平和',
    this.recommendedLength = 0.5,
    this.useEmoji = false,
    this.shouldAskQuestion = false,
    this.microEmotion,
    this.emotionShift,
    this.pacingStrategy = 'single_shot',
    this.topicDepth = 'emotional',
  });

  /// 从 JSON 解析
  factory L2DecisionResult.fromJson(Map<String, dynamic> json) {
    return L2DecisionResult(
      innerMonologue: json['inner_monologue'] ?? json['innerMonologue'] ?? '', // 【L2修复】尝试从 JSON 中提取 inner_monologue 字段
      responseStrategy: json['response_strategy'] ?? json['responseStrategy'] ?? '',
      emotionalTone: json['emotional_tone'] ?? json['emotionalTone'] ?? '平和',
      recommendedLength: (json['recommended_length'] ?? json['recommendedLength'] ?? 0.5).toDouble(),
      useEmoji: json['use_emoji'] ?? json['useEmoji'] ?? false,
      shouldAskQuestion: json['should_ask_question'] ?? json['shouldAskQuestion'] ?? false,
      microEmotion: json['micro_emotion'] ?? json['microEmotion'],
      emotionShift: json['emotion_shift'] != null 
          ? Map<String, double>.from(json['emotion_shift'].map((k, v) => MapEntry(k, (v as num).toDouble())))
          : null,
      pacingStrategy: json['pacing_strategy'] ?? json['pacingStrategy'] ?? 'single_shot',
      topicDepth: json['topic_depth'] ?? json['topicDepth'] ?? 'emotional',
    );
  }

  /// 降级：从规则生成
  factory L2DecisionResult.fallback({String userMessage = ''}) {
    final length = userMessage.length;
    return L2DecisionResult(
      innerMonologue: '（快速响应模式）',
      responseStrategy: '自然回应',
      emotionalTone: '平和',
      recommendedLength: length > 50 ? 0.6 : 0.4,
      useEmoji: false,
      shouldAskQuestion: false,
      pacingStrategy: length > 30 ? 'burst' : 'single_shot',
      topicDepth: 'factual',
    );
  }

  /// 格式化为策略指导（供 L3 使用）
  /// 【Phase 6 更新】采用 "Inner Monologue: ... | Strategy: ..." 格式
  String toStrategyGuide() {
    final monologuePart = innerMonologue.isNotEmpty ? innerMonologue : '（无明确思考）';
    final strategyPart = responseStrategy.isNotEmpty ? responseStrategy : '自然回应';
    return 'Inner Monologue: $monologuePart | Strategy: $strategyPart';
  }
}

/// Prompt 构建器 - L2/L3 分层架构
class PromptBuilder {
  
  // ==================== 工具方法 ====================
  
  /// 【L2/L3 重构】生成 Raw Big Five 数值字符串
  /// 
  /// 格式: "O:0.80, C:0.30, E:0.60, A:0.70, N:0.40"
  /// 设计原理: L2 消费精准数值，节省 Token 且逻辑友好
  static String formatBigFiveMetrics({
    required double openness,
    required double conscientiousness,
    required double extraversion,
    required double agreeableness,
    required double neuroticism,
  }) {
    return 'O:${openness.toStringAsFixed(2)}, '
           'C:${conscientiousness.toStringAsFixed(2)}, '
           'E:${extraversion.toStringAsFixed(2)}, '
           'A:${agreeableness.toStringAsFixed(2)}, '
           'N:${neuroticism.toStringAsFixed(2)}';
  }
  
  // ==================== L2: Decision Layer (Original L3) ====================
  
  /// L2 决策生成 Prompt (原 L3)
  /// 
  /// 输入: 用户消息 + 记忆 + 画像 + V-A状态 + 怨恨值 + 认知偏差 + Big Five 指标
  /// 输出: JSON 格式 {inner_monologue, response_strategy, ...}
  /// 
  /// 【代词锚定】思考对象使用第三人称（他/她），禁止使用"你"
  /// 【L2/L3 重构】L2 消费精准数值
  static String buildL2DecisionPrompt({
    required String userMessage,
    required String userName,
    required String memories,
    required UserProfile userProfile,
    required double valence,
    required double arousal,
    required double resentment,
    required String personaName,
    String? lastAiResponse,
    String cognitiveBiases = '',
    String bigFiveMetrics = '', // 【L2/L3 重构】Raw Big Five 数值
    double intimacy = 0.5,       // 【L2/L3 重构】亲密度数值
  }) {
    final template = SettingsLoader.prompt.systemPrompts['l2_decision'];
    if (template == null || template.isEmpty) {
      return 'Critical Error: L2 Decision Prompt template missing.';
    }

    final genderLower = userProfile.gender?.toLowerCase() ?? '';
    final isMale = genderLower == 'male' || genderLower == 'man' || genderLower == '男' || genderLower == '男性';
    final userGender = isMale ? '他' : '她';
    final emotionDesc = _getEmotionDescription(valence, arousal);
    
    // 注入参数
    return template
        .replaceAll('{personaName}', personaName)
        .replaceAll('{userName}', userName)
        .replaceAll('{userGender}', userGender)
        .replaceAll('{valence}', valence.toStringAsFixed(2))
        .replaceAll('{arousal}', arousal.toStringAsFixed(2))
        .replaceAll('{resentment}', resentment.toStringAsFixed(2))
        .replaceAll('{cognitiveBiases}', cognitiveBiases)
        .replaceAll('{emotionDesc}', emotionDesc)
        .replaceAll('{userOccupation}', userProfile.occupation.isNotEmpty ? '职业: ${userProfile.occupation}' : '')
        .replaceAll('{userMajor}', userProfile.major != null && userProfile.major!.isNotEmpty ? '专业: ${userProfile.major}' : '')
        .replaceAll('{memories}', memories)
        .replaceAll('{lastAiResponse}', lastAiResponse ?? '（这是对话开始）')
        .replaceAll('{userMessage}', userMessage)
        .replaceAll('{bigFiveMetrics}', bigFiveMetrics) // 【L2/L3 重构】Big Five 数值
        .replaceAll('{intimacy}', intimacy.toStringAsFixed(2)); // 【L2/L3 重构】亲密度
  }

  // ==================== L3: Expression Layer (Original L4) ====================

  /// 【Phase 6 新增】获取时间修饰符
  /// 
  /// 根据当前时间返回对应的语气后缀
  static String _getTimeModifier(DateTime now) {
    final hour = now.hour;
    if (hour >= 23 || hour < 5) {
      // 深夜模式 (23:00 - 05:00)
      return SettingsLoader.prompt.timeModifiers['late_night'] ?? '';
    } else if (hour >= 5 && hour < 9) {
      // 清晨模式 (05:00 - 09:00)
      return SettingsLoader.prompt.timeModifiers['early_morning'] ?? '';
    }
    return '';
  }

  /// 【Phase 6 新增】获取 single_shot 尾部指令
  /// 
  /// 当 pacing_strategy 为 single_shot 时，返回强制合并消息的指令
  static String _getPacingInstruction(String pacingStrategy) {
    if (pacingStrategy == 'single_shot') {
      return '\n[SYSTEM INSTRUCTION] Detected single_shot mode. DO NOT split messages. Merge content into one paragraph.';
    }
    return '';
  }

  /// L3 表达合成 Prompt
  /// 
  /// 输入: L2 意图结果 + V-A状态 + 人格上下文 + Meltdown 覆盖
  /// 输出: 微信风格口语化回复
  /// 
  /// 【代词锚定】L2中的"他/她"映射回"你"
  /// 【人格真实性修正】新增 laziness 和 tolerance 参数
  static String buildL3ExpressionPrompt({
    required L2DecisionResult l2Result,
    required String userName,
    required String personaName,
    required String personaDescription,
    required String personaGender,
    required double valence,
    required double arousal,
    required double resentment,
    required String relationshipDescription,
    required String behaviorRules,
    required UserProfile userProfile,
    required String currentTime,
    required String memories,
    required String coreFacts,
    String meltdownOverride = '',
    double laziness = 0.0,    // 【人格真实性修正】疲惫值
    double tolerance = 1.0,   // 【人格真实性修正】容忍度
  }) {
    final template = SettingsLoader.prompt.systemPrompts['l3_expression'];
    if (template == null || template.isEmpty) {
      return 'Critical Error: L3 Expression Prompt template missing.';
    }

    final genderLower = userProfile.gender?.toLowerCase() ?? '';
    final isMale = genderLower == 'male' || genderLower == 'man' || genderLower == '男';
    final userGender = isMale ? '他' : '她';
    final avoidanceGuide = ProhibitedPatterns.getAvoidanceGuide();
    final userDislikedGuide = userProfile.preferences.dislikedPatterns.isNotEmpty
        ? '\n用户明确不喜欢：${userProfile.preferences.dislikedPatterns.join('、')}'
        : '';
    
    // 【Phase 6 新增】时间修饰符注入
    final timeModifier = _getTimeModifier(DateTime.now());
    // 【Phase 6 新增】single_shot 尾部指令
    final pacingInstruction = _getPacingInstruction(l2Result.pacingStrategy);
    
    // 【人格真实性修正】确定并获取 persona 模式指令
    final personaMode = _determinePersonaMode(laziness, tolerance);
    final personaModeInstruction = _getPersonaModeInstruction(personaMode);

    return template
        .replaceAll('{personaName}', personaName)
        .replaceAll('{personaDescription}', personaDescription)
        .replaceAll('{personaGender}', personaGender)
        .replaceAll('{userName}', userName)
        .replaceAll('{userGender}', userGender)
        .replaceAll('{meltdownOverride}', meltdownOverride)
        // .replaceAll('{strategyGuide}', l2Result.toStrategyGuide()) // 【优化】已移除，改为 Tail Injection
        .replaceAll('{currentTime}', currentTime)
        .replaceAll('{coreFacts}', coreFacts)
        .replaceAll('{memories}', memories)
        .replaceAll('{valence}', valence.toStringAsFixed(2))
        .replaceAll('{valenceLabel}', _getValenceLabel(valence))
        .replaceAll('{arousal}', arousal.toStringAsFixed(2))
        .replaceAll('{arousalLabel}', _getArousalLabel(arousal))
        .replaceAll('{resentment}', resentment.toStringAsFixed(2))
        .replaceAll('{relationshipDescription}', relationshipDescription)
        .replaceAll('{emotionalTone}', l2Result.emotionalTone)
        .replaceAll('{lengthDescription}', _lengthDescription(l2Result.recommendedLength))
        .replaceAll('{emojiUsage}', l2Result.useEmoji ? '可以偶尔使用' : '不使用')
        .replaceAll('{askQuestion}', l2Result.shouldAskQuestion ? '可以提问' : '避免提问')
        .replaceAll('{separator}', SettingsLoader.separator) // 【紧急修复】注入真实配置的分隔符
        .replaceAll('{behaviorRules}', '$behaviorRules\n$personaModeInstruction') // 【人格真实性修正】注入模式指令
        .replaceAll('{avoidanceGuide}', avoidanceGuide)
        .replaceAll('{userDislikedGuide}', userDislikedGuide)
        .replaceAll('{pacingStrategy}', l2Result.pacingStrategy)
        .replaceAll('{topicDepth}', l2Result.topicDepth)
        .replaceAll('{timeModifier}', timeModifier)
        .replaceAll('{pacingInstruction}', pacingInstruction);
  }
  
  // ==================== 人格真实性修正扩展 ====================
  
  /// 【人格真实性修正】根据 laziness 和 tolerance 确定 persona 模式
  /// 
  /// - normal: laziness ≤ 0.4
  /// - low_energy_warm: laziness > 0.4 且 tolerance ≥ 0.4
  /// - low_energy_low_tolerance: laziness > 0.6 且 tolerance < 0.4
  static String _determinePersonaMode(double laziness, double tolerance) {
    if (laziness <= 0.4) {
      return 'normal';
    } else if (laziness > 0.6 && tolerance < 0.4) {
      return 'low_energy_low_tolerance';
    } else if (tolerance >= 0.4) {
      return 'low_energy_warm';
    } else {
      return 'low_energy_warm'; // 默认回退到低能量友好模式
    }
  }
  
  /// 【人格真实性修正】获取 persona 模式对应的指令
  static String _getPersonaModeInstruction(String mode) {
    final personaModes = SettingsLoader.prompt.personaModes;
    final modeConfig = personaModes[mode];
    if (modeConfig != null && modeConfig.instruction.isNotEmpty) {
      return modeConfig.instruction;
    }
    return ''; // 正常模式无额外指令
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
