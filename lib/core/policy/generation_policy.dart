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
  // 默认参数值 (来自阿里云官方示例)
  static const double _defaultTemperature = 0.7;
  static const double _defaultTopP = 0.8;
  static const int _defaultMaxTokens = 4096;  // 【升级】提升至 4096 以支持更长的响应

  // 【UI映射】静态 getter 供 UI 层读取默认参数
  static double get defaultTemperature => _defaultTemperature;
  static double get defaultTopP => _defaultTopP;
  static int get defaultMaxTokens => _defaultMaxTokens;

  // 【审计修复】情绪阈值常量化，提高可读性
  static const double _extremeNegativeValence = -0.6;
  static const double _negativeValence = -0.3;
  static const double _extremeHighArousal = 0.8;
  static const double _highArousal = 0.7;
  static const double _lowArousal = 0.3;

  // 权重配置
  final double memoryWeight;      // 记忆在 prompt 中的权重
  final double personaWeight;     // 人格在 prompt 中的权重
  final int maxHistoryMessages;   // 发送给 LLM 的最大历史消息数

  GenerationPolicy({
    this.memoryWeight = 0.3,
    this.personaWeight = 0.5,
    this.maxHistoryMessages = 15,  // 从 10 提升到 15 以利用增加的上下文窗口
  });

  /// 从 SettingsLoader 创建 (读取 YAML 配置)
  /// 【审计修复】移除硬编码值，使用类默认值
  factory GenerationPolicy.fromSettings() {
    return GenerationPolicy(
      memoryWeight: 0.3,  // 可扩展：从 YAML 读取
      personaWeight: 0.5,
      // maxHistoryMessages 使用类默认值 15
    );
  }

  /// 根据对话上下文获取参数
  /// 
  /// 策略逻辑：
  /// - 【关键】极端负面情绪 → 强制极短回复 (max_tokens=20)
  /// - 【关键】极高唤醒度 → 高 temperature 模拟快速/混乱表达
  /// - 高唤醒度 → 降低 temperature (回复更聚焦)
  /// - 低亲密度 → 降低 max_tokens (回复更简短)
  /// - 主动消息 → 使用较低 temperature (更稳定)
  GenerationParams getParams(ConversationContext context) {
    double temperature = _defaultTemperature;
    double topP = _defaultTopP;
    int maxTokens = _defaultMaxTokens;
    double presencePenalty = 0.0;

    // ========== 【关键】极端情绪时的强制参数 ==========
    
    // 极端负面情绪 (愤怒/冷漠): 强制极短回复
    // 物理约束 AI 只能回复 "哦。" "嗯。" "随便。" 等
    if (context.emotionValence < _extremeNegativeValence) {
      maxTokens = 20;
      temperature = 0.6;  // 更确定性的短回复
      presencePenalty = 0.3;  // 避免重复
    }
    // 负面情绪: 较短回复
    else if (context.emotionValence < _negativeValence) {
      maxTokens = (maxTokens * 0.5).round().clamp(50, 256);
    }
    
    // 极高唤醒度 (兴奋/激动): 高随机性模拟快速/混乱表达
    if (context.emotionArousal > _extremeHighArousal) {
      temperature = 1.1;  // 更随机的回复
      maxTokens = (maxTokens * 1.3).round().clamp(256, _defaultMaxTokens);
    }
    // 高唤醒度: 稍微聚焦
    else if (context.emotionArousal > _highArousal) {
      temperature = (temperature - 0.1).clamp(0.5, 1.0);
    } 
    // 低唤醒度: 稍微放松
    else if (context.emotionArousal < _lowArousal) {
      temperature = (temperature + 0.05).clamp(0.5, 1.0);
    }

    // ========== 亲密度调整 ==========
    
    // 低亲密度时回复更简短（但不覆盖极端情绪的设置）
    if (context.emotionValence >= _extremeNegativeValence) {
      if (context.intimacy < SettingsLoader.intimacyLowThreshold) {
        maxTokens = (maxTokens * 0.7).round();
      } else if (context.intimacy > SettingsLoader.intimacyHighThreshold) {
        maxTokens = (maxTokens * 1.2).round().clamp(512, _defaultMaxTokens);
      }
    }

    // ========== 主动消息使用更稳定的参数 ==========
    if (context.isProactiveMessage) {
      temperature = 0.7;
      maxTokens = 256;
    }

    return GenerationParams(
      temperature: temperature,
      topP: topP,
      maxTokens: maxTokens,
      presencePenalty: presencePenalty,
    );
  }

  /// 获取应发送给 LLM 的历史消息数量
  /// 
  /// 策略：
  /// - 高亲密度：最多 20 条历史（充分利用上下文）
  /// - 默认：15 条历史
  int getHistoryCount(ConversationContext context) {
    // 高亲密度时可发送更多历史
    if (context.intimacy > SettingsLoader.intimacyHighThreshold) {
      return maxHistoryMessages + 5;  // 最多 20 条
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
