// PromptAssembler - 纯 Prompt 组装器
//
// 设计原理：
// - 纯组装：只负责字符串拼接，不做任何策略决策
// - 所有输入内容由调用方（ConversationEngine）提前决定
// - 替代原有混合逻辑的 PromptBuilder

import 'prompt_snapshot.dart';

/// Prompt 组装器 - 纯字符串拼接，无策略决策
class PromptAssembler {
  
  /// System Prompt 模板
  /// System Prompt 模板 (Architecture 2.0)
  /// 仅包含静态设定和长期记忆，动态思维和策略移至尾部
  static const String _systemTemplate = '''{persona_header}
---
【核心事实与记忆】
- 事实：{core_facts}
- 记忆：{memories}
{relationship_goal}
【当前上下文】
- 时间：{current_time}
- 状态：{current_state}

{few_shots}

【表达与行为指引】
{expression_guide}

{behavior_rules}

{response_format}''';

  /// 组装 System Prompt
  static PromptAssembleResult assemble({
    required String personaHeader,     // 来自 PersonaPolicy.formatForSystemPrompt()
    required String currentTime,       // 来自 _formatCurrentTime()
    required String currentState,      // 来自 ConversationEngine 组合
    required String memories,          // 来自 MemoryManager
    required String expressionGuide,   // 来自 ExpressionSelector
    required String responseFormat,    // 来自 ResponseFormatter
    required String behaviorRules,     // 来自 PersonaPolicy.getBehaviorConstraints()
    String coreFacts = '',             // 来自 FactStore.formatForSystemPrompt()
    String fewShots = '',              // 【新增】Few-Shot 示例预留接口
    String relationshipGoal = '',      // 【新增】用户期望的关系目标
  }) {
    // 格式化关系目标（如果存在）
    final relationshipGoalText = relationshipGoal.isNotEmpty 
        ? '\n【关系期望】用户期望与你发展为: $relationshipGoal' 
        : '';
    
    final systemPrompt = _systemTemplate
        .replaceAll('{persona_header}', personaHeader)
        .replaceAll('{core_facts}', coreFacts.isNotEmpty ? coreFacts : '（暂无已知信息）')
        .replaceAll('{current_time}', currentTime)
        .replaceAll('{current_state}', currentState)
        .replaceAll('{memories}', memories.isNotEmpty ? memories : '（暂无记忆）')
        .replaceAll('{few_shots}', fewShots)
        .replaceAll('{expression_guide}', expressionGuide)
        .replaceAll('{response_format}', responseFormat)
        .replaceAll('{behavior_rules}', behaviorRules)
        .replaceAll('{relationship_goal}', relationshipGoalText);

    return PromptAssembleResult(
      systemPrompt: systemPrompt,
      components: {
        'personaHeader': personaHeader,
        'coreFacts': coreFacts,
        'currentTime': currentTime,
        'currentState': currentState,
        'memories': memories,
        'expressionGuide': expressionGuide,
        'responseFormat': responseFormat,
        'behaviorRules': behaviorRules,
        'fewShots': fewShots,
      },
    );
  }
  
  /// 组装尾部注入内容 (Tail Injection)
  /// 
  /// 包括：
  /// 1. 当前策略 (Strategy)
  /// 2. 内心独白 (Monologue)
  /// 3. 用户感知 (Perception)
  /// 
  /// 这些内容紧贴 User Input 之后，利用 Recency Bias 强化执行
  static String assembleTailInjection({
    required String strategy,
    required String monologue,
    String? perception,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('\n[系统指令]');
    
    if (perception != null && perception.isNotEmpty) {
      buffer.writeln('【用户感知】$perception');
    }
    
    if (monologue.isNotEmpty) {
      buffer.writeln('【你的思考】$monologue');
    }
    
    if (strategy.isNotEmpty) {
      buffer.writeln('【执行策略】$strategy');
    }
    
    buffer.writeln('请基于以上思考和策略回复用户：');
    return buffer.toString();
  }

  /// 组装历史消息列表 (用于 API 请求)
  /// 
  /// 将 UI 消息转换为 API 格式
  /// 
  /// [injectTimestamps] 是否注入时间前缀（用于 LLM 时间感知）
  /// 格式: [MM-DD HH:mm] 内容
  static List<Map<String, String>> assembleHistoryMessages(
    List<dynamic> messages, {
    required int maxCount,
    required int excludeLastN, // 排除最后 N 条（通常是当前用户消息）
    bool injectTimestamps = true, // 是否注入时间上下文
  }) {
    final List<Map<String, String>> result = [];
    
    // 计算实际要处理的消息范围
    final endIndex = messages.length - excludeLastN;
    if (endIndex <= 0) return result;
    
    final startIndex = (endIndex - maxCount).clamp(0, endIndex);
    
    for (int i = startIndex; i < endIndex; i++) {
      final m = messages[i];
      String content = m.content;
      
      // 时间注入：为每条历史消息添加时间前缀
      // 目的：让 LLM 理解对话的时间跨度（1分钟 vs 1周的差异）
      if (injectTimestamps && m.time != null) {
        final timePrefix = _formatTimePrefix(m.time);
        content = '$timePrefix $content';
      }
      
      result.add({
        'role': m.isUser ? 'user' : 'assistant',
        'content': content,
      });
    }
    
    return result;
  }

  /// 格式化时间前缀
  /// 
  /// 格式：[月-日 时:分]
  /// 示例：[12-27 14:30]
  static String _formatTimePrefix(DateTime time) {
    final month = time.month.toString().padLeft(2, '0');
    final day = time.day.toString().padLeft(2, '0');
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '[$month-$day $hour:$minute]';
  }


  /// 构建当前状态描述
  /// 
  /// 纯组装方法，所有数据由调用方提供
  /// 使用时间叙述替代分散的时间参数
  static String buildCurrentState({
    required String emotionDescription,  // 来自 EmotionEngine
    required String relationshipDescription,  // 来自 PersonaPolicy
    required String temporalNarrative,  // 来自 TimeAwareness.getTemporalNarrative()
  }) {
    final lines = <String>[];
    
    lines.add(emotionDescription);
    lines.add('与对方关系：$relationshipDescription');
    lines.add('【时间感知】$temporalNarrative');
    
    // 注意：absenceAcknowledge 和 lateNightReminder 已整合到 temporalNarrative 中
    
    return lines.join('\n');
  }
}
