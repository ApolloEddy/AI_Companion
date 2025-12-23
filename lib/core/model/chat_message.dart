/// 聊天消息模型 - 支持 JSON 序列化以持久化存储
class ChatMessage {
  final String content;
  final bool isUser;
  final DateTime time;
  final String id; // 唯一标识符
  
  ChatMessage({
    required this.content, 
    required this.isUser, 
    required this.time,
    String? id,
  }) : id = id ?? '${time.millisecondsSinceEpoch}_${isUser ? 'u' : 'a'}';

  /// 从 JSON Map 创建
  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      content: json['content'] ?? '',
      isUser: json['isUser'] ?? false,
      time: DateTime.tryParse(json['time'] ?? '') ?? DateTime.now(),
      id: json['id'],
    );
  }

  /// 转换为 JSON Map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'isUser': isUser,
      'time': time.toIso8601String(),
    };
  }
}
