import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import '../model/chat_message.dart';

/// 聊天记录导出服务
class ChatExportService {
  
  /// 导出为 JSON 格式
  static Future<String> exportAsJson(List<ChatMessage> messages) async {
    final data = {
      'exportTime': DateTime.now().toIso8601String(),
      'messageCount': messages.length,
      'messages': messages.map((m) => {
        'sender': m.isUser ? 'user' : 'ai',
        'content': m.content,
        'time': m.time.toIso8601String(),
        'id': m.id,
      }).toList(),
    };
    
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    return await _saveToFile(jsonStr, 'chat_export.json');
  }
  
  /// 导出为 TXT 格式（纯文本聊天记录）
  static Future<String> exportAsTxt(List<ChatMessage> messages, String aiName) async {
    final buffer = StringBuffer();
    buffer.writeln('=== 聊天记录导出 ===');
    buffer.writeln('导出时间: ${_formatDateTime(DateTime.now())}');
    buffer.writeln('消息数量: ${messages.length}');
    buffer.writeln('');
    buffer.writeln('=' * 40);
    buffer.writeln('');
    
    for (final msg in messages) {
      final sender = msg.isUser ? '我' : aiName;
      final time = _formatDateTime(msg.time);
      buffer.writeln('[$time] $sender:');
      buffer.writeln(msg.content);
      buffer.writeln('');
    }
    
    return await _saveToFile(buffer.toString(), 'chat_export.txt');
  }
  
  /// 导出为 CSV 格式（Excel 可打开）
  static Future<String> exportAsCsv(List<ChatMessage> messages) async {
    final buffer = StringBuffer();
    // CSV 头部（带 BOM 确保 Excel 正确识别 UTF-8）
    buffer.write('\uFEFF');
    buffer.writeln('时间,发送者,内容');
    
    for (final msg in messages) {
      final time = _formatDateTime(msg.time);
      final sender = msg.isUser ? '用户' : 'AI';
      // 转义 CSV 内容中的引号和换行
      final content = msg.content
          .replaceAll('"', '""')
          .replaceAll('\n', ' ')
          .replaceAll('\r', '');
      buffer.writeln('"$time","$sender","$content"');
    }
    
    return await _saveToFile(buffer.toString(), 'chat_export.csv');
  }
  
  /// 保存文件到下载目录
  static Future<String> _saveToFile(String content, String filename) async {
    Directory? directory;
    
    if (Platform.isAndroid) {
      // Android: 使用外部存储的 Download 目录
      directory = Directory('/storage/emulated/0/Download');
      if (!await directory.exists()) {
        directory = await getExternalStorageDirectory();
      }
    } else if (Platform.isIOS) {
      directory = await getApplicationDocumentsDirectory();
    } else {
      // Windows/其他: 使用文档目录
      directory = await getApplicationDocumentsDirectory();
    }
    
    if (directory == null) {
      throw Exception('无法获取存储目录');
    }
    
    // 添加时间戳避免覆盖
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final ext = filename.split('.').last;
    final baseName = filename.replaceAll('.$ext', '');
    final finalFilename = '${baseName}_$timestamp.$ext';
    
    final file = File('${directory.path}/$finalFilename');
    await file.writeAsString(content, encoding: utf8);
    
    return file.path;
  }
  
  /// 格式化日期时间
  static String _formatDateTime(DateTime dt) {
    final year = dt.year;
    final month = dt.month.toString().padLeft(2, '0');
    final day = dt.day.toString().padLeft(2, '0');
    final hour = dt.hour.toString().padLeft(2, '0');
    final minute = dt.minute.toString().padLeft(2, '0');
    final second = dt.second.toString().padLeft(2, '0');
    return '$year-$month-$day $hour:$minute:$second';
  }
}
