// PromptAssembler - 纯 Prompt 组装器
//
// 设计原理：
// - 【纯组装】只负责字符串拼接，不做任何策略决策
// - 所有输入内容由调用方（ConversationEngine）提前决定
// - 替代原有混合逻辑的 PromptBuilder

import 'prompt_snapshot.dart';

/// Prompt 组装器 - 纯字符串拼接，无策略决策
class PromptAssembler {
  
  /// System Prompt 模板
  static const String _systemTemplate = '''{persona_header}

【当前状态】
{current_state}

【记忆信息】
{memories}

【表达指引】
{expression_guide}

{response_format}

{behavior_rules}''';

  /// 组装 System Prompt
  /// 
  /// 所有参数均由调用方决定（ConversationEngine 协调各模块获取）
  /// 此方法仅做字符串拼接，不访问任何外部服务或配置
  static PromptAssembleResult assemble({
    required String personaHeader,     // 来自 PersonaPolicy.formatForSystemPrompt()
    required String currentState,      // 来自 ConversationEngine 组合
    required String memories,          // 来自 MemoryManager
    required String expressionGuide,   // 来自 ExpressionSelector
    required String responseFormat,    // 来自 ResponseFormatter
    required String behaviorRules,     // 来自 PersonaPolicy.getBehaviorConstraints()
  }) {
    final systemPrompt = _systemTemplate
        .replaceAll('{persona_header}', personaHeader)
        .replaceAll('{current_state}', currentState)
        .replaceAll('{memories}', memories.isNotEmpty ? memories : '（暂无记忆）')
        .replaceAll('{expression_guide}', expressionGuide)
        .replaceAll('{response_format}', responseFormat)
        .replaceAll('{behavior_rules}', behaviorRules);

    return PromptAssembleResult(
      systemPrompt: systemPrompt,
      components: {
        'personaHeader': personaHeader,
        'currentState': currentState,
        'memories': memories,
        'expressionGuide': expressionGuide,
        'responseFormat': responseFormat,
        'behaviorRules': behaviorRules,
      },
    );
  }

  /// 组装历史消息列表 (用于 API 请求)
  /// 
  /// 将 UI 消息转换为 API 格式
  static List<Map<String, String>> assembleHistoryMessages(
    List<dynamic> messages, {
    required int maxCount,
    required int excludeLastN, // 排除最后 N 条（通常是当前用户消息）
  }) {
    final List<Map<String, String>> result = [];
    
    // 计算实际要处理的消息范围
    final endIndex = messages.length - excludeLastN;
    if (endIndex <= 0) return result;
    
    final startIndex = (endIndex - maxCount).clamp(0, endIndex);
    
    for (int i = startIndex; i < endIndex; i++) {
      final m = messages[i];
      result.add({
        'role': m.isUser ? 'user' : 'assistant',
        'content': m.content,
      });
    }
    
    return result;
  }

  /// 构建当前状态描述
  /// 
  /// 纯组装方法，所有数据由调用方提供
  static String buildCurrentState({
    required String emotionDescription,  // 来自 EmotionEngine
    required String relationshipDescription,  // 来自 PersonaPolicy
    required String timeContext,  // 来自 TimeAwareness
    String? absenceAcknowledge,  // 可选：久未联系提示
    String? lateNightReminder,   // 可选：深夜关心提示
  }) {
    final lines = <String>[];
    
    lines.add(emotionDescription);
    lines.add('与对方关系：$relationshipDescription');
    lines.add('当前时段：$timeContext');
    
    if (absenceAcknowledge != null && absenceAcknowledge.isNotEmpty) {
      lines.add(absenceAcknowledge);
    }
    
    if (lateNightReminder != null && lateNightReminder.isNotEmpty) {
      lines.add(lateNightReminder);
    }
    
    return lines.join('\n');
  }
}
