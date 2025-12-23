// PromptSnapshot - Prompt 快照
//
// 设计原理：
// - 记录每次发送给 LLM 的完整 Prompt
// - 用于调试验证，解决"黑盒"问题
// - 包含时间戳、估算 token 数、各组件内容、生成参数

import 'dart:convert';
import '../service/llm_service.dart';
import '../policy/generation_policy.dart';

/// Prompt 快照 - 用于调试和验证
class PromptSnapshot {
  /// 完整的 System Prompt
  final String fullPrompt;
  
  /// 用户最新消息
  final String userMessage;
  
  /// 历史消息列表
  final List<Map<String, String>> historyMessages;
  
  /// 创建时间戳
  final DateTime timestamp;
  
  /// 估算的 token 数量
  final int estimatedTokens;
  
  /// 各组件的内容 (用于调试)
  final Map<String, String> components;
  
  /// 【新增】当前使用的生成参数 (用于验证策略是否生效)
  final GenerationParams? generationParams;

  PromptSnapshot({
    required this.fullPrompt,
    required this.userMessage,
    required this.historyMessages,
    required this.timestamp,
    required this.estimatedTokens,
    required this.components,
    this.generationParams,
  });

  /// 计算估算的 token 数
  static int calculateEstimatedTokens(
    String systemPrompt, 
    List<Map<String, String>> messages,
    String userMessage,
  ) {
    int total = LLMService.estimateTokens(systemPrompt);
    for (final msg in messages) {
      total += LLMService.estimateTokens(msg['content'] ?? '');
    }
    total += LLMService.estimateTokens(userMessage);
    return total;
  }

  /// 转换为 JSON 字符串
  String toJson() {
    return jsonEncode({
      'timestamp': timestamp.toIso8601String(),
      'estimatedTokens': estimatedTokens,
      'userMessage': userMessage,
      'historyCount': historyMessages.length,
      'components': components,
      'generationParams': generationParams?.toApiParams(),
      'fullPrompt': fullPrompt,
    });
  }

  /// 转换为 Map
  Map<String, dynamic> toMap() {
    return {
      'timestamp': timestamp.toIso8601String(),
      'estimatedTokens': estimatedTokens,
      'userMessage': userMessage,
      'historyMessages': historyMessages,
      'components': components,
      'generationParams': generationParams?.toApiParams(),
      'fullPrompt': fullPrompt,
    };
  }

  /// 打印调试信息
  void printDebugInfo() {
    print('========== PromptSnapshot ==========');
    print('Timestamp: ${timestamp.toIso8601String()}');
    print('Estimated Tokens: $estimatedTokens');
    print('User Message: $userMessage');
    print('History Count: ${historyMessages.length}');
    if (generationParams != null) {
      print('--- Generation Params ---');
      print('temperature: ${generationParams!.temperature}');
      print('maxTokens: ${generationParams!.maxTokens}');
      print('topP: ${generationParams!.topP}');
    }
    print('--- Components ---');
    components.forEach((key, value) {
      print('$key: ${value.length > 100 ? '${value.substring(0, 100)}...' : value}');
    });
    print('--- Full Prompt (truncated) ---');
    print(fullPrompt.length > 500 
        ? '${fullPrompt.substring(0, 500)}...' 
        : fullPrompt);
    print('====================================');
  }

  /// 输出简洁的日志信息
  String toLogString() {
    final paramsInfo = generationParams != null 
        ? ', temp=${generationParams!.temperature}, max=${generationParams!.maxTokens}'
        : '';
    return '[PromptSnapshot] tokens=$estimatedTokens, '
           'history=${historyMessages.length}$paramsInfo, '
           'user="${userMessage.length > 30 ? '${userMessage.substring(0, 30)}...' : userMessage}"';
  }

  @override
  String toString() => toLogString();
}

/// Prompt 组装结果
class PromptAssembleResult {
  final String systemPrompt;
  final Map<String, String> components;

  const PromptAssembleResult({
    required this.systemPrompt,
    required this.components,
  });
}

