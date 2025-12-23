import 'dart:math';
import '../settings_loader.dart';

/// 回复格式化器 - 使用动态 YAML 配置
class ResponseFormatter {
  
  /// 格式化回复
  static List<Map<String, dynamic>> formatResponse(
    String rawResponse, {
    double arousal = 0.5,
  }) {
    final separator = SettingsLoader.separator;
    final maxSingleLength = SettingsLoader.maxSingleLength;
    
    // 1. 先按分隔符分割
    List<String> rawParts;
    if (rawResponse.contains(separator)) {
      rawParts = rawResponse
          .split(separator)
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList();
    } else {
      rawParts = [rawResponse.trim()];
    }
    
    // 限制最大分条数
    if (rawParts.length > SettingsLoader.maxParts) {
      rawParts = rawParts.take(SettingsLoader.maxParts).toList();
    }
    
    // 2. 动态调整最大长度
    final modifier = 1.0 - (arousal - 0.5) * 0.8;
    final dynamicMax = (maxSingleLength * modifier.clamp(0.4, 1.6)).round();
    
    // 3. 智能分割
    final List<String> finalParts = [];
    for (final part in rawParts) {
      if (part.length > dynamicMax) {
        finalParts.addAll(_smartSplit(part, dynamicMax));
      } else {
        finalParts.add(part);
      }
    }
    
    final limitedParts = finalParts.take(SettingsLoader.maxParts).toList();
    
    // 4. 计算延迟
    final List<Map<String, dynamic>> messages = [];
    final random = Random();
    
    for (int i = 0; i < limitedParts.length; i++) {
      final content = limitedParts[i];
      if (content.isEmpty) continue;
      
      double delay;
      if (i == 0) {
        final baseDelay = SettingsLoader.firstDelayBase;
        final typingDelay = content.length / SettingsLoader.typingSpeed * 60;
        final arousalMod = 1.0 - arousal * SettingsLoader.arousalFactor;
        delay = (baseDelay + typingDelay * 0.1) * arousalMod;
        delay = delay.clamp(SettingsLoader.firstDelayMin, SettingsLoader.firstDelayMax);
      } else {
        final baseInterval = SettingsLoader.intervalBase;
        final randomExtra = SettingsLoader.intervalRandomMin + 
            random.nextDouble() * (SettingsLoader.intervalRandomMax - SettingsLoader.intervalRandomMin);
        final charDelay = content.length * SettingsLoader.perCharDelay;
        delay = baseInterval + randomExtra + charDelay;
      }
      
      messages.add({
        'content': content,
        'delay': delay,
      });
    }
    
    return messages;
  }
  
  static List<String> _smartSplit(String text, int maxLength) {
    final chunks = <String>[];
    
    final lines = text.contains('\n') 
        ? text.split('\n').where((l) => l.trim().isNotEmpty).toList()
        : [text];
    
    for (final line in lines) {
      if (line.length <= maxLength) {
        chunks.add(line.trim());
        continue;
      }
      
      final sentencePattern = RegExp(r'([。！？!?～~]+)');
      final parts = line.split(sentencePattern);
      
      final sentences = <String>[];
      String temp = '';
      for (final part in parts) {
        if (sentencePattern.hasMatch(part)) {
          temp += part;
          if (temp.trim().isNotEmpty) sentences.add(temp.trim());
          temp = '';
        } else {
          if (temp.isNotEmpty && temp.trim().isNotEmpty) sentences.add(temp.trim());
          temp = part;
        }
      }
      if (temp.trim().isNotEmpty) sentences.add(temp.trim());
      
      String current = '';
      for (final sent in sentences) {
        if (current.length + sent.length <= maxLength) {
          current += sent;
        } else {
          if (current.isNotEmpty) chunks.add(current);
          
          if (sent.length > maxLength) {
            final commaParts = sent.split(RegExp(r'[，,、]'));
            for (final cp in commaParts) {
              if (cp.length > maxLength) {
                for (int i = 0; i < cp.length; i += maxLength) {
                  chunks.add(cp.substring(i, min(i + maxLength, cp.length)));
                }
              } else if (cp.trim().isNotEmpty) {
                chunks.add(cp.trim());
              }
            }
            current = '';
          } else {
            current = sent;
          }
        }
      }
      if (current.isNotEmpty) chunks.add(current);
    }
    
    return chunks.where((c) => c.isNotEmpty).toList();
  }
  
  static String getSplitInstruction() {
    final separator = SettingsLoader.separator;
    return '''
【回复格式与分条指引】
请完全模仿微信/QQ的聊天节奏，严禁发送长篇大论。你必须主动将长回复拆分为多个短气泡。
拆分方法：
1. 强制分隔符：在想切分的地方插入 "$separator"（强烈推荐）。
2. 自然换行：使用换行符也会被切分。

错误示例：
"哈哈真的吗，那你当时一定很尴尬吧，快详细说说！"（太长，不自然）

正确示例：
"哈哈，真的吗？$separator那你当时一定很尴尬吧！😆$separator快详细说说！"

请根据语意自然切分，让对话像流水一样顺畅。''';
  }
}
