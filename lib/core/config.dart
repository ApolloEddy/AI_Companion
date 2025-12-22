import 'secrets.dart';

class AppConfig {
  static const String apiKeyKey = 'qwen_api_key';
  // 从 secrets.dart 读取默认 Key (该文件被 git 忽略)
  static String get defaultApiKey => Secrets.dashScopeApiKey;
  
  static const String apiUrl = 'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions';
  static const String model = 'qwen-max';
  
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
