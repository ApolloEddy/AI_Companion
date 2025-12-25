// ReflectionProcessor - 内心反思处理器
//
// 设计原理：
// - 阶段三：在回复前进行内部思考
// - 动态调整对话风格，避免重复模式
// - 生成回复策略指导

import 'dart:convert';
import 'perception_processor.dart';
import '../service/llm_service.dart';
import '../model/user_profile.dart';
import '../policy/prohibited_patterns.dart';

/// 反思结果
class ReflectionResult {
  final bool shouldAskQuestion;
  final String? questionReason;
  final String responseStrategy;
  final List<String> avoidPatterns;
  final String emotionalTone;
  final List<String> contentHints;
  final double recommendedLength;  // 0.0(极短) ~ 1.0(详细)
  final bool useEmoji;
  final DateTime timestamp;

  const ReflectionResult({
    required this.shouldAskQuestion,
    this.questionReason,
    required this.responseStrategy,
    required this.avoidPatterns,
    required this.emotionalTone,
    required this.contentHints,
    required this.recommendedLength,
    required this.useEmoji,
    required this.timestamp,
  });

  /// 基于规则的快速反思结果
  factory ReflectionResult.fromRules(
    PerceptionResult perception, 
    List<String> userDislikedPatterns,
  ) {
    // 基于感知结果决定策略
    String strategy;
    String tone;
    double length;
    bool emoji;
    List<String> hints = [];

    switch (perception.underlyingNeed) {
      case '倾诉宣泄':
        strategy = '专注倾听，表达理解，不急于给建议';
        tone = '温暖共情';
        length = 0.4;
        emoji = false;
        hints = ['表达理解', '简单回应', '不要追问太多'];
        break;
      case '寻求建议':
        strategy = '提供具体可行的想法';
        tone = '理性支持';
        length = 0.7;
        emoji = false;
        hints = ['给出具体建议', '但不要说教'];
        break;
      case '陪伴安慰':
        strategy = '温暖共情，少讲道理';
        tone = '温柔安慰';
        length = 0.5;
        emoji = true;
        hints = ['表达关心', '不要过度', '适当陪伴'];
        break;
      case '分享喜悦':
        strategy = '分享快乐，表达为对方高兴';
        tone = '开心活泼';
        length = 0.5;
        emoji = true;
        hints = ['表达祝贺', '分享喜悦'];
        break;
      default:  // 闲聊解闷
        strategy = '轻松自然，随意聊聊';
        tone = '轻松自然';
        length = 0.5;
        emoji = perception.surfaceEmotion.valence > 0.3;
        hints = ['自然对话', '不要太正式'];
    }

    // 结束意图时缩短回复
    if (perception.conversationIntent == '结束对话') {
      length = 0.2;
      hints = ['简短回应', '不要追问', '可以不回复'];
    }

    return ReflectionResult(
      shouldAskQuestion: perception.conversationIntent != '结束对话' && 
                         perception.underlyingNeed == '寻求建议',
      questionReason: null,
      responseStrategy: strategy,
      avoidPatterns: [
        ...userDislikedPatterns,
        ...ProhibitedPatterns.getAvoidanceGuide().split('\n').where((l) => l.startsWith('-')),
      ],
      emotionalTone: tone,
      contentHints: hints,
      recommendedLength: length,
      useEmoji: emoji,
      timestamp: DateTime.now(),
    );
  }

  factory ReflectionResult.fromJson(Map<String, dynamic> json) {
    return ReflectionResult(
      shouldAskQuestion: json['should_ask_question'] ?? false,
      questionReason: json['question_reason'],
      responseStrategy: json['response_strategy'] ?? '自然对话',
      avoidPatterns: (json['avoid_patterns'] as List?)?.cast<String>() ?? [],
      emotionalTone: json['emotional_tone'] ?? '平和',
      contentHints: (json['content_hints'] as List?)?.cast<String>() ?? [],
      recommendedLength: (json['recommended_length'] ?? 0.5).toDouble(),
      useEmoji: json['use_emoji'] ?? false,
      timestamp: DateTime.now(),
    );
  }

  /// 格式化为策略指导
  String toStrategyGuide() {
    final lines = <String>[];
    lines.add('【回复策略】$responseStrategy');
    lines.add('【情绪基调】$emotionalTone');
    lines.add('【推荐长度】${_lengthDescription()}');
    if (shouldAskQuestion && questionReason != null) {
      lines.add('【可以提问】$questionReason');
    } else if (!shouldAskQuestion) {
      lines.add('【不要提问】本次回复避免反问');
    }
    if (contentHints.isNotEmpty) {
      lines.add('【内容方向】${contentHints.join('、')}');
    }
    if (avoidPatterns.isNotEmpty) {
      lines.add('【避免模式】${avoidPatterns.take(3).join('、')}');
    }
    return lines.join('\n');
  }

  String _lengthDescription() {
    if (recommendedLength < 0.3) return '极简（一两句话）';
    if (recommendedLength < 0.5) return '简短';
    if (recommendedLength < 0.7) return '适中';
    return '详细';
  }
}

/// 内心反思处理器
class ReflectionProcessor {
  final LLMService _llmService;
  
  ReflectionProcessor(this._llmService);

  /// 执行完整的内心反思
  Future<ReflectionResult> reflect({
    required PerceptionResult perception,
    required UserProfile userProfile,
    required String lastAiResponse,
    required List<String> recentFeedbackSignals,
  }) async {
    final prompt = _buildReflectionPrompt(
      perception: perception,
      userProfile: userProfile,
      lastAiResponse: lastAiResponse,
      recentFeedbackSignals: recentFeedbackSignals,
    );

    try {
      final response = await _llmService.completeWithSystem(
        systemPrompt: prompt,
        userMessage: '请进行内心思考，输出 JSON 格式的回复策略。',
        model: 'qwen-turbo',
        temperature: 0.4,
        maxTokens: 400,
      );

      final json = _parseJsonResponse(response);
      return ReflectionResult.fromJson(json);
    } catch (e) {
      print('[ReflectionProcessor] Reflection failed: $e');
      // 降级到规则基础反思
      return ReflectionResult.fromRules(
        perception,
        userProfile.preferences.dislikedPatterns,
      );
    }
  }

  /// 快速反思（不调用 LLM）
  ReflectionResult quickReflect({
    required PerceptionResult perception,
    required UserProfile userProfile,
  }) {
    return ReflectionResult.fromRules(
      perception,
      userProfile.preferences.dislikedPatterns,
    );
  }

  /// 构建反思 Prompt
  String _buildReflectionPrompt({
    required PerceptionResult perception,
    required UserProfile userProfile,
    required String lastAiResponse,
    required List<String> recentFeedbackSignals,
  }) {
    return '''
【第三阶段：内心反思】

在回复用户之前，你需要进行内心思考。这个思考过程用户不可见。

=== 阶段一感知结果 ===
${perception.toContextDescription()}

=== 用户偏好 ===
用户明确不喜欢：${userProfile.preferences.dislikedPatterns.join('、')}
用户倾向风格：${userProfile.preferences.preferredStyles.join('、')}

=== 最近反馈信号 ===
${recentFeedbackSignals.isEmpty ? '（暂无）' : recentFeedbackSignals.join('\n')}

=== 上一条 AI 回复 ===
"$lastAiResponse"

--- 开始内心思考 ---

1. 用户的需求是「${perception.underlyingNeed}」，我应该：
   - 倾诉宣泄 → 专注倾听，不急于给建议
   - 寻求建议 → 提供具体可行的想法
   - 陪伴安慰 → 温暖共情，少讲道理
   - 闲聊解闷 → 轻松自然，不要太严肃

2. 用户讨厌「${userProfile.preferences.dislikedPatterns.join('、')}」，我必须避免

3. 我上一次回复是："$lastAiResponse"
   - 这次应该换个方式/角度
   - 避免模式化的开头

4. 思考回复策略...

=== 输出格式 ===
必须输出有效的 JSON：
{
  "should_ask_question": false,
  "question_reason": null,
  "response_strategy": "...",
  "avoid_patterns": ["..."],
  "emotional_tone": "...",
  "content_hints": ["..."],
  "recommended_length": 0.5,
  "use_emoji": false
}
''';
  }

  /// 解析 JSON 响应
  Map<String, dynamic> _parseJsonResponse(String response) {
    var jsonStr = response.trim();
    
    final codeBlockMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(jsonStr);
    if (codeBlockMatch != null) {
      jsonStr = codeBlockMatch.group(1)?.trim() ?? jsonStr;
    }
    
    final startIndex = jsonStr.indexOf('{');
    final endIndex = jsonStr.lastIndexOf('}');
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      jsonStr = jsonStr.substring(startIndex, endIndex + 1);
    }
    
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      print('[ReflectionProcessor] JSON parse failed: $e');
      return {};
    }
  }
}
