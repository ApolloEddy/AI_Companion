// PromptLogger - Prompt 日志存储服务
//
// 设计原理：
// - 记录每条消息对应的 L1/L2/L3 层 Prompt
// - 支持按 message_id 查询历史 Prompt
// - 用于调试和 UI 展示

import 'database_helper.dart';

/// Prompt 日志条目
class PromptLogEntry {
  final int id;
  final String messageId;
  final String layer; // 'L1' | 'L2' | 'L3'
  final String promptContent;
  final String? responseContent;
  final DateTime timestamp;

  PromptLogEntry({
    required this.id,
    required this.messageId,
    required this.layer,
    required this.promptContent,
    this.responseContent,
    required this.timestamp,
  });

  factory PromptLogEntry.fromMap(Map<String, dynamic> map) {
    return PromptLogEntry(
      id: map['id'] as int,
      messageId: map['message_id'] as String,
      layer: map['layer'] as String,
      promptContent: map['prompt_content'] as String,
      responseContent: map['response_content'] as String?,
      timestamp: DateTime.tryParse(map['timestamp'] ?? '') ?? DateTime.now(),
    );
  }
}

/// Prompt 日志记录器
class PromptLogger {
  final DatabaseHelper _db;
  
  // 临时缓存，用于在消息生成期间暂存 prompt（因为 message_id 在生成后才可用）
  final Map<String, List<_TempPromptLog>> _pendingLogs = {};

  PromptLogger(this._db);

  /// 记录 Prompt (立即写入数据库)
  Future<void> logPrompt({
    required String messageId,
    required String layer,
    required String promptContent,
    String? responseContent,
  }) async {
    await _db.insert('prompt_logs', {
      'message_id': messageId,
      'layer': layer,
      'prompt_content': promptContent,
      'response_content': responseContent,
      'timestamp': DateTime.now().toIso8601String(),
    });
    print('[PromptLogger] Logged $layer prompt for message: $messageId');
  }
  
  /// 暂存 Prompt (用于消息生成期间，message_id 未确定时)
  void stagePrompt({
    required String sessionKey,
    required String layer,
    required String promptContent,
    String? responseContent,
  }) {
    _pendingLogs.putIfAbsent(sessionKey, () => []);
    _pendingLogs[sessionKey]!.add(_TempPromptLog(
      layer: layer,
      promptContent: promptContent,
      responseContent: responseContent,
    ));
  }
  
  /// 提交暂存的 Prompts (当 message_id 可用时调用)
  Future<void> commitStagedPrompts(String sessionKey, String messageId) async {
    final staged = _pendingLogs.remove(sessionKey);
    if (staged == null || staged.isEmpty) return;
    
    for (final log in staged) {
      await logPrompt(
        messageId: messageId,
        layer: log.layer,
        promptContent: log.promptContent,
        responseContent: log.responseContent,
      );
    }
  }
  
  /// 清除暂存的 Prompts (用于失败或取消的情况)
  void clearStagedPrompts(String sessionKey) {
    _pendingLogs.remove(sessionKey);
  }

  /// 查询指定消息的所有 Prompt 日志
  Future<List<PromptLogEntry>> getPromptsForMessage(String messageId) async {
    final db = await _db.database;
    final results = await db.query(
      'prompt_logs',
      where: 'message_id = ?',
      whereArgs: [messageId],
      orderBy: 'id ASC',
    );
    return results.map((row) => PromptLogEntry.fromMap(row)).toList();
  }
  
  /// 查询最近一条消息的 Prompt 日志
  Future<List<PromptLogEntry>> getLatestPrompts() async {
    final db = await _db.database;
    // 先找到最新的 message_id
    final latestMessage = await db.rawQuery('''
      SELECT message_id FROM prompt_logs 
      ORDER BY timestamp DESC 
      LIMIT 1
    ''');
    
    if (latestMessage.isEmpty) return [];
    
    final messageId = latestMessage.first['message_id'] as String;
    return getPromptsForMessage(messageId);
  }

  /// 清空所有 Prompt 日志
  Future<void> clearAll() async {
    await _db.clearTable('prompt_logs');
  }
}

/// 临时 Prompt 日志 (用于暂存)
class _TempPromptLog {
  final String layer;
  final String promptContent;
  final String? responseContent;

  _TempPromptLog({
    required this.layer,
    required this.promptContent,
    this.responseContent,
  });
}
