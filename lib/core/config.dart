import 'secrets.dart';

/// 可用的 Qwen 模型列表
class QwenModel {
  final String id;        // API 模型 ID
  final String name;      // 显示名称
  final String desc;      // 描述
  final bool hasFreeQuota; // 是否有免费额度

  const QwenModel({
    required this.id,
    required this.name,
    required this.desc,
    this.hasFreeQuota = false,
  });
}

class AppConfig {
  static const String apiKeyKey = 'qwen_api_key';
  static const String modelKey = 'selected_model';  // 新增：保存选中的模型
  
  // 从 secrets.dart 读取默认 Key (该文件被 git 忽略)
  static String get defaultApiKey => Secrets.dashScopeApiKey;
  
  static const String apiUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
  static const String defaultModel = 'qwen-turbo';  // 默认使用有免费额度的模型
  
  /// 可用的 Qwen 模型列表（5个免费/有免费额度的模型）
  static const List<QwenModel> availableModels = [
    QwenModel(
      id: 'qwen-turbo',
      name: 'Qwen Turbo',
      desc: '速度快，免费额度充足',
      hasFreeQuota: true,
    ),
    QwenModel(
      id: 'qwen-plus',
      name: 'Qwen Plus',
      desc: '平衡性能，有免费额度',
      hasFreeQuota: true,
    ),
    QwenModel(
      id: 'qwen-max',
      name: 'Qwen Max',
      desc: '最强性能，少量免费额度',
      hasFreeQuota: true,
    ),
    QwenModel(
      id: 'qwen3-8b',
      name: 'Qwen3 8B',
      desc: '开源模型，性能均衡',
      hasFreeQuota: true,
    ),
    QwenModel(
      id: 'qwq-32b-preview',
      name: 'QwQ 32B',
      desc: '推理增强模型',
      hasFreeQuota: true,
    ),
  ];
  
  static const String memoryKey = 'chat_memories';
  static const String personaKey = 'persona_state';
  static const String chatHistoryKey = 'chat_history_v1';
  static const String themeKey = 'app_theme';
  
  // 气泡颜色配置
  static const String userBubbleColorKey = 'user_bubble_color';
  static const String aiBubbleColorKey = 'ai_bubble_color';
  
  // Token 统计
  static const String tokenCountKey = 'token_count';
}
