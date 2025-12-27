import 'package:uuid/uuid.dart';

/// 聊天消息模型 - 支持 JSON 序列化以持久化存储
class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime time;
  final String id; // 唯一标识符
  final String? fullPrompt; // 此次生成使用的完整 Prompt
  final int? tokensUsed;    // 此次生成消耗的 Token 数
  
  ChatMessage({
    required this.content, 
    required this.isUser, 
    required this.time,
    String? id,
    this.fullPrompt,
    this.tokensUsed,
  }) : id = id ?? const Uuid().v4();

  /// 从 JSON Map 创建
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // 兼容 SQLite 的 int (1/0) 和 JSON 的 bool
    final rawIsUser = json['is_user'] ?? json['isUser'];
    final bool isUserBool = rawIsUser is int 
        ? rawIsUser == 1 
        : (rawIsUser as bool? ?? false);

    return ChatMessage(
      content: json['content'] ?? '',
      isUser: isUserBool,
      time: DateTime.tryParse(json['time'] ?? '') ?? DateTime.now(),
      id: json['id'],
      fullPrompt: json['fullPrompt'] ?? json['full_prompt'],
      tokensUsed: json['tokensUsed'] ?? json['tokens_used'],
    );
  }

  /// 转换为 JSON Map (适配 SQLite Schema)
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'is_user': isUser ? 1 : 0, // SQLite 需要 int
      'time': time.toIso8601String(),
      'full_prompt': fullPrompt,
      'tokens_used': tokensUsed,
    };
  }
}
