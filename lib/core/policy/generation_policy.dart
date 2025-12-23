// GenerationPolicy - 集中管理 LLM 生成参数
//
// 设计原理：
// - 禁止在 UI 层或 Service 层硬编码 temperature, max_tokens 等参数
// - 所有 LLM 参数集中在此类管理，支持根据场景动态调整
// - 从 YAML 配置读取默认值，运行时可根据上下文调整

import '../settings_loader.dart';

/// LLM 生成参数配置
class GenerationParams {
  final double temperature;
  final double topP;
  final int maxTokens;
  final double presencePenalty;
  final double frequencyPenalty;

  const GenerationParams({
    required this.temperature,
    required this.topP,
    required this.maxTokens,
    this.presencePenalty = 0.0,
    this.frequencyPenalty = 0.0,
  });

  /// 转换为 API 请求 body 参数
  Map<String, dynamic> toApiParams() {
    return {
      'temperature': temperature,
      'top_p': topP,
      'max_tokens': maxTokens,
      if (presencePenalty != 0.0) 'presence_penalty': presencePenalty,
      if (frequencyPenalty != 0.0) 'frequency_penalty': frequencyPenalty,
    };
  }
}

/// 对话上下文 - 用于策略决策
class ConversationContext {
  final double intimacy;          // 亲密度 (0~1)
  final double emotionValence;    // 情绪效价 (-1~1)
  final double emotionArousal;    // 情绪唤醒度 (0~1)
  final int messageLength;        // 用户消息长度
  final bool isProactiveMessage;  // 是否为主动消息
  final String? scenarioHint;     // 场景提示 (可选)

  const ConversationContext({
    required this.intimacy,
    required this.emotionValence,
    required this.emotionArousal,
    required this.messageLength,
    this.isProactiveMessage = false,
    this.scenarioHint,
  });
}

/// LLM 生成策略 - 集中管理所有生成参数
class GenerationPolicy {
  // 默认参数值 (从 YAML 读取或使用硬编码默认值)
  static const double _defaultTemperature = 0.85;
  static const double _defaultTopP = 0.9;
  static const int _defaultMaxTokens = 1024;

  // 权重配置
  final double memoryWeight;      // 记忆在 prompt 中的权重
  final double personaWeight;     // 人格在 prompt 中的权重
  final int maxHistoryMessages;   // 发送给 LLM 的最大历史消息数

  GenerationPolicy({
    this.memoryWeight = 0.3,
    this.personaWeight = 0.5,
    this.maxHistoryMessages = 10,
  });

  /// 从 SettingsLoader 创建 (读取 YAML 配置)
  factory GenerationPolicy.fromSettings() {
    return GenerationPolicy(
      memoryWeight: 0.3,  // 可扩展：从 YAML 读取
      personaWeight: 0.5,
      maxHistoryMessages: 10,
    );
  }

  /// 根据对话上下文获取参数
  /// 
  /// 策略逻辑：
  /// - 高唤醒度 → 降低 temperature (回复更聚焦)
  /// - 低亲密度 → 降低 max_tokens (回复更简短)
  /// - 主动消息 → 使用较低 temperature (更稳定)
  GenerationParams getParams(ConversationContext context) {
    double temperature = _defaultTemperature;
    double topP = _defaultTopP;
    int maxTokens = _defaultMaxTokens;

    // 根据唤醒度调整 temperature
    // 高唤醒度时回复更聚焦，降低随机性
    if (context.emotionArousal > 0.7) {
      temperature = (temperature - 0.1).clamp(0.5, 1.0);
    } else if (context.emotionArousal < 0.3) {
      temperature = (temperature + 0.05).clamp(0.5, 1.0);
    }

    // 根据亲密度调整 max_tokens
    // 低亲密度时回复更简短
    if (context.intimacy < SettingsLoader.intimacyLowThreshold) {
      maxTokens = (maxTokens * 0.7).round();
    } else if (context.intimacy > SettingsLoader.intimacyHighThreshold) {
      maxTokens = (maxTokens * 1.2).round().clamp(512, 2048);
    }

    // 主动消息使用更稳定的参数
    if (context.isProactiveMessage) {
      temperature = 0.7;
      maxTokens = 256;
    }

    return GenerationParams(
      temperature: temperature,
      topP: topP,
      maxTokens: maxTokens,
    );
  }

  /// 获取应发送给 LLM 的历史消息数量
  int getHistoryCount(ConversationContext context) {
    // 高亲密度时可发送更多历史
    if (context.intimacy > SettingsLoader.intimacyHighThreshold) {
      return maxHistoryMessages + 2;
    }
    return maxHistoryMessages;
  }

  /// 获取记忆检索的最大条数
  int getMaxMemoryItems(ConversationContext context) {
    // 基础 5 条，高亲密度增加到 8 条
    int base = 5;
    if (context.intimacy > 0.5) {
      base = 8;
    }
    return base;
  }
}
