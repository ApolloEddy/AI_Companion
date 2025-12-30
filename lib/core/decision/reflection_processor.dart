// ReflectionProcessor - 内心反思处理器
//
// 设计原理：
// - 阶段三：在回复前进行内部思考
// - 动态调整对话风格，避免重复模式
// - 生成回复策略指导

import 'dart:convert';
import 'dart:async';
import '../perception/perception_processor.dart';
import '../service/llm_service.dart';
import '../model/user_profile.dart';
import '../policy/prohibited_patterns.dart';
import '../config/config_registry.dart';

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
  final String? innerMonologue;  // 内心独白
  final Map<String, double>? emotionShift; // 情绪偏移 (valence/arousal)
  final String? microEmotion; // 【新增】微情绪 (jealousy_mild, pride_hidden, disappointed)
  final String? pacingStrategy; // 【Phase 1】节奏策略: single_shot, burst, hesitant
  final String? topicDepth; // 【Phase 1】话题深度: factual, emotional, abstract
  
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
    this.innerMonologue,
    this.emotionShift,
    this.microEmotion,
    this.pacingStrategy,
    this.topicDepth,
  });

  /// 基于配置的快速反思结果 (重构版)
  factory ReflectionResult.fromRules(
    PerceptionResult perception, 
    List<String> userDislikedPatterns,
  ) {
    final config = ConfigRegistry.instance;
    
    // 根据感知的需求标签查找策略配置
    final needId = config.getNeedIdByLabel(perception.underlyingNeed);
    final strategyConfig = config.getNeedStrategy(needId ?? 'chat');
    
    String strategy;
    String tone;
    double length;
    bool emoji;
    List<String> hints = [];
    
    if (strategyConfig != null) {
      strategy = strategyConfig.strategy;
      tone = strategyConfig.tone;
      length = strategyConfig.recommendedLength;
      emoji = strategyConfig.useEmoji;
      hints = List.from(strategyConfig.hints);
    } else {
      // 默认策略 (闲聊解闷)
      strategy = '轻松自然，随意聊聊';
      tone = '轻松自然';
      length = 0.5;
      emoji = perception.surfaceEmotion.valence > 0.3;
      hints = ['自然对话', '不要太正式'];
    }

    // 话题终止逻辑增强
    // 1. 根据感知意图
    if (perception.conversationIntent == '结束对话') {
      length = 0.2;
      strategy = '礼貌收尾，不要再开启新话题';
      hints = ['简短回应', '不要追问', '可以不回复'];
    }
    
    // 2. 根据消息长度和内容（干聊/敷衍检测）
    if (perception.confidence > 0.6 && perception.underlyingNeed == '闲聊解闷' && 
        perception.surfaceEmotion.arousal < 0.4 && 
        perception.conversationIntent == '延续上文') {
       // 如果发现用户回复很敷衍且能量低，主动收缩话题
       strategy = '话题已尽，自然收尾';
       length = 0.3;
       hints.add('避免追问');
       hints.add('自然结束');
    }

    return ReflectionResult(
      shouldAskQuestion: (perception.conversationIntent != '结束对话' && 
                         perception.underlyingNeed == '寻求建议') && 
                         perception.confidence > 0.6,
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
      innerMonologue: '基于规则生成的快速反思',
      microEmotion: null, // 规则模式不生成微情绪
      pacingStrategy: 'single_shot', // 规则模式默认单句
      topicDepth: 'emotional', // 规则模式默认有情商回复
    );
  }

  factory ReflectionResult.fromJson(Map<String, dynamic> json) {
    // 处理 emotion_shift
    Map<String, double>? shift;
    final rawShift = json['emotion_shift'];
    if (rawShift is Map) {
      shift = {
        'valence': (rawShift['valence'] ?? 0.0).toDouble(),
        'arousal': (rawShift['arousal'] ?? 0.0).toDouble(),
      };
    }

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
      innerMonologue: _cleanXmlTags(json['inner_monologue'] ?? '思考完成'),
      emotionShift: shift,
      microEmotion: json['micro_emotion']?.toString(), // 【新增】解析微情绪
      pacingStrategy: json['pacing_strategy']?.toString() ?? 'single_shot',
      topicDepth: json['topic_depth']?.toString() ?? 'emotional',
    );
  }

  /// 格式化为策略指导
  String toStrategyGuide() {
    final lines = <String>[];
    lines.add('【本次回复策略】');
    lines.add('· 核心策略：$responseStrategy');
    lines.add('· 状态要求：$emotionalTone | 长度${_lengthDescription()} | ${shouldAskQuestion ? "允许提问" : "避免反问"}');
    
    if (contentHints.isNotEmpty) {
      lines.add('· 内容建议：${contentHints.join('、')}');
    }
    if (avoidPatterns.isNotEmpty) {
      lines.add('· 绝对禁止：${avoidPatterns.take(3).join('、')} (严禁出现)');
    }
    return lines.join('\n');
  }

  String _lengthDescription() {
    if (recommendedLength < 0.3) return '极简（一两句话）';
    if (recommendedLength < 0.5) return '简短';
    if (recommendedLength < 0.7) return '适中';
    return '详细';
  }

  /// 清理 XML 标签 (多策略版: 适配流式传输场景)
  /// 
  /// 处理场景：
  /// 1. 完整标签: <thought>, </thought>, <strategy attr="...">
  /// 2. 流式残留起始标签: <thou, <stra (末尾不完整)
  /// 3. 流式残留闭合标签: ght>, tegy> (开头不完整)
  /// 4. 单独的标签碎片: </, >, </
  static String _cleanXmlTags(String text) {
    var cleaned = text;
    
    // 1. 移除完整的 XML 标签 (含属性)
    cleaned = cleaned.replaceAll(RegExp(r'</?[a-zA-Z][a-zA-Z0-9]*(?:\s+[^>]*)?>'), '');
    
    // 2. 移除末尾残留的起始不完整标签 (流式场景): <thou, <stra
    cleaned = cleaned.replaceAll(RegExp(r'</?[a-zA-Z]{1,10}$'), '');
    
    // 3. 移除开头残留的闭合不完整标签: ght>, tegy>
    cleaned = cleaned.replaceAll(RegExp(r'^[a-zA-Z]{1,10}>'), '');
    
    // 4. 移除开头的单独 > 或 />
    cleaned = cleaned.replaceAll(RegExp(r'^/?>'), '');
    
    // 5. 移除末尾的单独 < 或 </
    cleaned = cleaned.replaceAll(RegExp(r'</?$'), '');
    
    return cleaned.trim();
  }
}

/// 内心反思处理器
class ReflectionProcessor {
  final LLMService _llmService;
  
  ReflectionProcessor(this._llmService);

  Stream<String> streamReflect({
    required PerceptionResult perception,
    required UserProfile userProfile,
    required String lastAiResponse,
    required List<String> recentFeedbackSignals,
    required Completer<ReflectionResult> resultCompleter,
    required String userMessage,
    String model = 'qwen-max', // 【可配置】内心独白模型
  }) async* {
    final prompt = _buildReflectionPrompt(
      perception,
      userProfile,
      lastAiResponse,
      recentFeedbackSignals,
      userMessage,
    );

    String fullResponse = '';
    bool inThought = false;
    bool finishedThought = false;

    try {
      await for (final chunk in _llmService.streamComplete(
        systemPrompt: prompt,
        userMessage: '请开始你的思考。',
        model: model, // 使用传入的模型
        temperature: 0.75,
        maxTokens: 1200,
      )) {
        fullResponse += chunk;
        
        // 简单的流式 XML 提取独白
        if (!finishedThought) {
          if (fullResponse.contains('<thought>')) {
            inThought = true;
          }
          if (fullResponse.contains('</thought>')) {
            inThought = false;
            finishedThought = true;
            // 提取独白内容并输出最后一部分
            final thoughtMatch = RegExp(r'<thought>([\s\S]*?)</thought>').firstMatch(fullResponse);
            if (thoughtMatch != null) {
              // yield thoughtMatch.group(1)?.trim() ?? '';
              // 实际上流式输出时，这里需要更精细的处理，但目前简化为只 yield chunk
              yield chunk.replaceAll('<thought>', '').replaceAll('</thought>', '');
            }
          } else if (inThought) {
            yield chunk.replaceAll('<thought>', '');
          }
        }
      }

      // 整体解析
      final thoughtMatch = RegExp(r'<thought>([\s\S]*?)</thought>').firstMatch(fullResponse);
      final strategyMatch = RegExp(r'<strategy>([\s\S]*?)</strategy>').firstMatch(fullResponse);

      final monologue = thoughtMatch?.group(1)?.trim() ?? '思考完成';
      final strategyJson = strategyMatch?.group(1)?.trim() ?? '{}';
      final json = _parseJsonResponse(strategyJson);
      
      final result = ReflectionResult.fromJson({
        ...json,
        'inner_monologue': monologue,
      });
      
      resultCompleter.complete(result);
    } catch (e) {
      print('[ReflectionProcessor] Stream reflection failed: $e');
      final fallback = ReflectionResult.fromRules(
        perception,
        userProfile.preferences.dislikedPatterns,
      );
      resultCompleter.complete(fallback);
      yield '（陷入了沉思...）';
    }
  }

  /// 执行完整的内心反思 (向后兼容)
  Future<ReflectionResult> reflect({
    required PerceptionResult perception,
    required UserProfile userProfile,
    required String lastAiResponse,
    required List<String> recentFeedbackSignals,
    required String userMessage,
    String model = 'qwen-max', // 【可配置】内心独白模型
  }) async {
    final prompt = _buildReflectionPrompt(
      perception,
      userProfile,
      lastAiResponse,
      recentFeedbackSignals,
      userMessage,
    );

    try {
      final response = await _llmService.completeWithSystem(
        systemPrompt: prompt,
        userMessage: '请进行内心思考。',
        model: model, // 使用传入的模型
        temperature: 0.75,
        maxTokens: 1200,
      );

      final thoughtMatch = RegExp(r'<thought>([\s\S]*?)</thought>').firstMatch(response);
      final strategyMatch = RegExp(r'<strategy>([\s\S]*?)</strategy>').firstMatch(response);

      final monologue = thoughtMatch?.group(1)?.trim() ?? '思考完成';
      final strategyJson = strategyMatch?.group(1)?.trim() ?? response;
      
      final json = _parseJsonResponse(strategyJson);
      return ReflectionResult.fromJson({
        ...json,
        'inner_monologue': monologue,
      });
    } catch (e) {
      print('[ReflectionProcessor] Reflection failed: $e');
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

  /// 核心步骤：构建流式反思 Prompt (配置驱动版)
  String _buildReflectionPrompt(
    PerceptionResult perception,
    UserProfile userProfile,
    String lastAiResponse,
    List<String> recentFeedbackSignals,
    String userMessage,
  ) {
    final config = ConfigRegistry.instance;
    
    // 1. 获取系统人设
    final systemPersona = config.getPromptTemplate('reflection_persona');
    
    // 2. 组装禁忌思维提示
    var prohibitedPrompt = config.getPromptTemplate('prohibited_patterns_prompt');
    prohibitedPrompt = prohibitedPrompt.replaceAll(
      '{prohibited_patterns}', 
      config.prohibitedPatternsForPrompt
    );
    
    // 3. 获取输出格式
    final outputFormat = config.getPromptTemplate('reflection_output_format');
    
    // 4. 组装关系背景
    var relationshipStatus = '正在熟悉的朋友';
    if (userProfile.relationship.intimacy > 0.8) {
      relationshipStatus = '非常亲密的朋友，无话不谈但各自独立';
    } else if (userProfile.relationship.intimacy > 0.5) {
      relationshipStatus = '较好的朋友，彼此信任';
    }
    
    var relationshipContext = config.getPromptTemplate('relationship_context_prompt');
    relationshipContext = relationshipContext
      .replaceAll('{relationship_status}', relationshipStatus)
      .replaceAll('{disliked_patterns}', userProfile.preferences.dislikedPatterns.isEmpty ? '暂无已知' : userProfile.preferences.dislikedPatterns.join('、'))
      .replaceAll('{last_ai_response}', lastAiResponse.length > 50 ? '${lastAiResponse.substring(0, 50)}...' : lastAiResponse)
      .replaceAll('{recent_feedback}', recentFeedbackSignals.isEmpty ? '暂无' : recentFeedbackSignals.join(' | '));

    // 5. 组装心理反应规则 (动态注入检测到的社交事件)
    var psychologicalRules = config.getPromptTemplate('psychological_rules_prompt');
    psychologicalRules = psychologicalRules.replaceAll(
      '{social_events}', 
      perception.socialEvents.isEmpty ? '无' : perception.socialEvents.join(', ')
    );
    
    // 动态生成规则描述 (基于 YAML 配置)
    final rulesDesc = config.microEmotionRules.map((rule) {
      return '- 如果检测到 ${rule.triggerEvent}${rule.condition != null ? " 且满足 ${rule.condition}" : ""}:\n'
             '  内心想法: "${rule.innerThought}" / 策略: "${rule.strategy}" / micro_emotion: "${rule.microEmotion}"';
    }).join('\n');
    
    psychologicalRules = psychologicalRules.replaceAll('{reaction_rules}', rulesDesc);

    return '''$systemPersona

$prohibitedPrompt

$outputFormat

=== 用户的实际消息 ===
"$userMessage"

=== 感知分析结果 ===
- 情绪状态：${perception.surfaceEmotion.label} (valence: ${perception.surfaceEmotion.valence.toStringAsFixed(2)})
- 深层需求：${perception.underlyingNeed}
- 对话意图：${perception.conversationIntent}
${perception.subtextInference != null ? '- 潜台词推断：${perception.subtextInference}' : ''}

$psychologicalRules

$relationshipContext

【情绪引导】
你当前的情绪：Valence ${perception.surfaceEmotion.valence.toStringAsFixed(2)}, Arousal ${perception.surfaceEmotion.arousal.toStringAsFixed(2)}。
如果这句话让你情绪变化，请在 emotion_shift 中给出偏移(-0.2 到 0.2)。

现在，针对他说的"""
$userMessage
"""进行你的内心思考。''';
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
