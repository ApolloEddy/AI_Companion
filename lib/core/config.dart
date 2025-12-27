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
  
  /// 可用的 Qwen 模型列表 (4个核心模型)
  /// 
  /// 按能力从高到低排列:
  /// - qwen3-max: 复杂多步骤任务，顶级推理能力
  /// - qwen-plus: 平衡效果与成本，通用场景
  /// - qwen-flash: 低延迟、高性价比，简单任务（原 qwen-flush 应为此）
  /// - qwen-turbo: 低成本基础任务
  static const List<QwenModel> availableModels = [
    QwenModel(
      id: 'qwen3-max',
      name: 'Qwen3 Max',
      desc: '顶级推理能力，复杂多步骤任务',
      hasFreeQuota: true,
    ),
    QwenModel(
      id: 'qwen-plus',
      name: 'Qwen Plus',
      desc: '平衡效果与成本，通用场景',
      hasFreeQuota: true,
    ),
    QwenModel(
      id: 'qwen-flash',
      name: 'Qwen Flash',
      desc: '低延迟、高性价比，简单任务',
      hasFreeQuota: true,
    ),
    QwenModel(
      id: 'qwen-turbo',
      name: 'Qwen Turbo',
      desc: '低成本基础任务',
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
  
  // 内心独白模型
  static const String monologueModelKey = 'monologue_model';
  static const String defaultMonologueModel = 'qwen-max';
  
  // 头像设置
  static const String userAvatarKey = 'user_avatar_path';
  static const String aiAvatarKey = 'ai_avatar_path';
}
