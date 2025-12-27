import 'package:sqflite/sqflite.dart';
import '../model/chat_message.dart';
import '../service/database_helper.dart';

/// 聊天历史服务 - 管理消息持久化和分页加载
class ChatHistoryService {
  final DatabaseHelper _dbHelper;
  
  // 每页消息数量
  static const int pageSize = 50;
  
  ChatHistoryService(this._dbHelper);
  
  /// 加载最近的 N 条消息（用于初始显示）
  Future<List<ChatMessage>> loadRecentMessages({int count = 50}) async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      orderBy: 'time ASC', // 确保时间顺序
      limit: count,
      offset: (await getTotalCount()) > count ? (await getTotalCount()) - count : 0,
    );
    
    // 或者简单的：
    final List<Map<String, dynamic>> tail = await db.rawQuery(
      'SELECT * FROM (SELECT * FROM messages ORDER BY time DESC LIMIT ?) ORDER BY time ASC',
      [count],
    );

    return tail.map((e) => ChatMessage.fromJson(e)).toList();
  }
  
  /// 加载更早的消息（向前分页）
  Future<List<ChatMessage>> loadOlderMessages(int currentOldestIndex, {int count = 30}) async {
    // 这里的 currentOldestIndex 在 SQL 下需要基于时间或 ID 偏移
    // 简化实现：基于时间排序获取之前的记录
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> maps = await db.query(
      'messages',
      orderBy: 'time DESC',
      limit: count,
      offset: (await getTotalCount()) - currentOldestIndex, // 简单偏移
    );
    
    return maps.map((e) => ChatMessage.fromJson(e)).toList().reversed.toList();
  }
  
  /// 检查是否有更早的消息
  Future<bool> hasOlderMessages(int currentLoadedCount) async {
    final total = await getTotalCount();
    return currentLoadedCount < total;
  }
  
  /// 获取总消息数
  Future<int> getTotalCount() async {
    final db = await _dbHelper.database;
    final List<Map<String, dynamic>> x = await db.rawQuery('SELECT COUNT(*) as count FROM messages');
    return Sqflite.firstIntValue(x) ?? 0;
  }
  
  /// 添加新消息
  Future<void> addMessage(ChatMessage message) async {
    await _dbHelper.insert('messages', message.toJson());
  }
  
  /// 批量添加消息
  Future<void> addMessages(List<ChatMessage> messages) async {
    final db = await _dbHelper.database;
    await db.transaction((txn) async {
      for (final msg in messages) {
        await txn.insert('messages', msg.toJson(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }
  
  /// 清空所有历史
  Future<void> clearAll() async {
    await _dbHelper.clearTable('messages');
  }
  
  /// 获取指定消息在总历史中的索引 (SQL 下建议基于 ID 查找)
  Future<int> getGlobalIndex(String messageId) async {
    // 这是一个代价较高的操作，通常不建议在 SQL 下频繁按索引定位
    return -1; 
  }
}
