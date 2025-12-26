// AnalysisService - 用户意图与情绪分析服务
//
// 设计原理：
// - 在生成最终回复前执行快速 LLM 调用
// - 提取用户意图、情绪分数和关键话题
// - 用于动态调整 System Prompt 行为
//
// 约束：
// - 使用低 token 输出限制（快速响应）
// - 低 temperature（确定性输出）

import 'dart:convert';
import '../service/llm_service.dart';

/// 分析结果
class AnalysisResult {
  /// 用户意图：闲聊/求助/倾诉/分享/结束
  final String intent;
  
  /// 情绪分数：1-5（1最低落，5最积极）
  final int emotionScore;
  
  /// 提取的话题关键词
  final List<String> topics;
  
  /// 是否适合提问
  final bool shouldAskQuestion;
  
  /// 检测到的潜在需求
  final String? underlyingNeed;
  
  const AnalysisResult({
    required this.intent,
    required this.emotionScore,
    this.topics = const [],
    this.shouldAskQuestion = true,
    this.underlyingNeed,
  });
  
  /// 默认结果（分析失败时使用）
  factory AnalysisResult.defaultResult() => const AnalysisResult(
    intent: '闲聊',
    emotionScore: 3,
    topics: [],
    shouldAskQuestion: true,
  );
  
  /// 用户情绪是否低落
  bool get isLowMood => emotionScore < 3;
  
  /// 用户情绪是否积极
  bool get isPositiveMood => emotionScore >= 4;
  
  @override
  String toString() {
    return 'AnalysisResult(intent:$intent, emotion:$emotionScore, topics:$topics, askQ:$shouldAskQuestion)';
  }
}

/// 用户意图与情绪分析服务
class AnalysisService {
  final LLMService _llm;
  
  /// 是否启用分析（可配置关闭以节省 token）
  bool enabled = true;
  
  AnalysisService(this._llm);
  
  /// 分析用户消息
  /// 
  /// 执行快速 LLM 调用，提取意图和情绪
  /// 如果分析失败或禁用，返回默认结果
  Future<AnalysisResult> analyze(String userMessage, {
    List<String> recentContext = const [],
  }) async {
    if (!enabled || userMessage.trim().isEmpty) {
      return AnalysisResult.defaultResult();
    }
    
    try {
      // 构建上下文
      String contextStr = '';
      if (recentContext.isNotEmpty) {
        contextStr = '\n最近对话:\n${recentContext.take(3).join('\n')}';
      }
      
      final response = await _llm.completeWithSystem(
        systemPrompt: _analysisPrompt,
        userMessage: '分析以下用户消息:$contextStr\n\n用户: $userMessage',
        maxTokens: 100,  // 限制输出，快速响应
        temperature: 0.2, // 低随机性，确定性输出
      );
      
      return _parseResponse(response);
    } catch (e) {
      print('[AnalysisService] Error: $e');
      return AnalysisResult.defaultResult();
    }
  }
  
  /// 分析提示词
  static const String _analysisPrompt = '''你是一个情感分析助手。分析用户消息并返回JSON格式结果。

分析维度：
1. intent: 用户意图，选择一个：闲聊/求助/倾诉/分享/结束/问候
2. emotion: 情绪分数1-5（1=非常低落/沮丧，3=平静/中性，5=非常开心/兴奋）
3. topics: 关键话题词（最多3个）
4. askQuestion: 是否适合提问（true/false），如果用户在倾诉或情绪低落时设为false
5. need: 潜在需求（可选）：陪伴/建议/倾听/鼓励/信息

只返回JSON，不要其他文字：
{"intent":"...","emotion":3,"topics":["..."],"askQuestion":true,"need":"..."}''';
  
  /// 解析 LLM 响应
  AnalysisResult _parseResponse(String response) {
    try {
      // 提取 JSON 部分
      final jsonMatch = RegExp(r'\{[^}]+\}').firstMatch(response);
      if (jsonMatch == null) {
        return AnalysisResult.defaultResult();
      }
      
      final json = jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
      
      return AnalysisResult(
        intent: json['intent'] as String? ?? '闲聊',
        emotionScore: (json['emotion'] as num?)?.toInt() ?? 3,
        topics: (json['topics'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ?? [],
        shouldAskQuestion: json['askQuestion'] as bool? ?? true,
        underlyingNeed: json['need'] as String?,
      );
    } catch (e) {
      print('[AnalysisService] Parse error: $e');
      return AnalysisResult.defaultResult();
    }
  }
  
  /// 根据分析结果生成动态行为规则
  /// 
  /// 注入到 System Prompt 的 behavior_rules 部分
  String generateDynamicRules(AnalysisResult analysis) {
    final rules = <String>[];
    
    // 情绪低落时的特殊规则
    if (analysis.emotionScore < 3) {
      rules.add('【重要】用户情绪较低，专注倾听和安慰，避免提问和建议');
      rules.add('使用温暖、关心的语气');
      rules.add('不要试图立即解决问题');
    }
    
    // 根据意图调整
    switch (analysis.intent) {
      case '倾诉':
        rules.add('用户需要倾诉，给予共情回应，不要打断或急于给建议');
        break;
      case '求助':
        rules.add('用户在寻求帮助，可以提供具体建议');
        break;
      case '结束':
        rules.add('用户想结束对话，简短回应，不要追问');
        break;
      case '分享':
        rules.add('用户在分享好消息，表达真诚的开心和祝贺');
        break;
    }
    
    // 根据潜在需求调整
    if (analysis.underlyingNeed != null) {
      switch (analysis.underlyingNeed) {
        case '陪伴':
          rules.add('用户需要陪伴，保持对话但不要太活跃');
          break;
        case '倾听':
          rules.add('用户需要被倾听，多用"嗯"、"我理解"等回应');
          break;
        case '鼓励':
          rules.add('用户需要鼓励，给予真诚的支持和肯定');
          break;
      }
    }
    
    // 是否应该提问
    if (!analysis.shouldAskQuestion) {
      rules.add('本轮回复不要向用户提问');
    }
    
    if (rules.isEmpty) {
      return '';
    }
    
    return '\n【动态调整】\n${rules.join('\n')}';
  }
}
