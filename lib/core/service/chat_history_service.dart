import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/chat_message.dart';
import '../config.dart';

/// 聊天历史服务 - 管理消息持久化和分页加载
class ChatHistoryService {
  final SharedPreferences prefs;
  
  // 每页消息数量
  static const int pageSize = 50;
  
  // 内存中的完整历史（懒加载）
  List<ChatMessage>? _allMessages;
  
  ChatHistoryService(this.prefs);
  
  /// 加载最近的 N 条消息（用于初始显示）
  Future<List<ChatMessage>> loadRecentMessages({int count = 50}) async {
    final all = await _loadAllMessages();
    if (all.length <= count) {
      return List.from(all);
    }
    return all.sublist(all.length - count);
  }
  
  /// 加载更早的消息（向前分页）
  /// [beforeIndex] - 当前最早消息的索引
  /// 返回更早的消息列表
  Future<List<ChatMessage>> loadOlderMessages(int currentOldestIndex, {int count = 30}) async {
    final all = await _loadAllMessages();
    
    if (currentOldestIndex <= 0) {
      return []; // 没有更早的消息了
    }
    
    final startIndex = (currentOldestIndex - count).clamp(0, currentOldestIndex);
    return all.sublist(startIndex, currentOldestIndex);
  }
  
  /// 检查是否有更早的消息
  Future<bool> hasOlderMessages(int currentOldestIndex) async {
    return currentOldestIndex > 0;
  }
  
  /// 获取总消息数
  Future<int> getTotalCount() async {
    final all = await _loadAllMessages();
    return all.length;
  }
  
  /// 添加新消息
  Future<void> addMessage(ChatMessage message) async {
    final all = await _loadAllMessages();
    all.add(message);
    await _saveAllMessages(all);
  }
  
  /// 批量添加消息
  Future<void> addMessages(List<ChatMessage> messages) async {
    final all = await _loadAllMessages();
    all.addAll(messages);
    await _saveAllMessages(all);
  }
  
  /// 清空所有历史
  Future<void> clearAll() async {
    _allMessages = [];
    await prefs.remove(AppConfig.chatHistoryKey);
  }
  
  /// 获取指定消息在总历史中的索引
  int getGlobalIndex(ChatMessage message) {
    if (_allMessages == null) return -1;
    return _allMessages!.indexWhere((m) => m.id == message.id);
  }
  
  // ========== Private Methods ==========
  
  Future<List<ChatMessage>> _loadAllMessages() async {
    if (_allMessages != null) {
      return _allMessages!;
    }
    
    final jsonStr = prefs.getString(AppConfig.chatHistoryKey);
    if (jsonStr == null || jsonStr.isEmpty) {
      _allMessages = [];
      return _allMessages!;
    }
    
    try {
      final List<dynamic> jsonList = jsonDecode(jsonStr);
      _allMessages = jsonList
          .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      print('Failed to load chat history: $e');
      _allMessages = [];
    }
    
    return _allMessages!;
  }
  
  Future<void> _saveAllMessages(List<ChatMessage> messages) async {
    _allMessages = messages;
    
    // 限制最大存储数量（防止无限增长）
    const maxStoredMessages = 1000;
    if (messages.length > maxStoredMessages) {
      messages = messages.sublist(messages.length - maxStoredMessages);
      _allMessages = messages;
    }
    
    final jsonList = messages.map((m) => m.toJson()).toList();
    await prefs.setString(AppConfig.chatHistoryKey, jsonEncode(jsonList));
  }
}
