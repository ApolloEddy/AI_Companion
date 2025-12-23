import 'dart:math';
import '../settings_loader.dart';

/// 回复格式化器 - 使用动态 YAML 配置
class ResponseFormatter {
  
  static final Random _random = Random();
  
  /// 格式化回复
  static List<Map<String, dynamic>> formatResponse(
    String rawResponse, {
    double arousal = 0.5,
  }) {
    final separator = SettingsLoader.separator;
    final maxSingleLength = SettingsLoader.maxSingleLength;
    
    // 1. 多级分割：先按分隔符，再按换行
    List<String> rawParts = _multiLevelSplit(rawResponse, separator);
    
    // 限制最大分条数
    if (rawParts.length > SettingsLoader.maxParts) {
      rawParts = rawParts.take(SettingsLoader.maxParts).toList();
    }
    
    // 2. 动态调整最大长度
    final modifier = 1.0 - (arousal - 0.5) * 0.8;
    final dynamicMax = (maxSingleLength * modifier.clamp(0.4, 1.6)).round();
    
    // 3. 智能分割长句
    final List<String> splitParts = [];
    for (final part in rawParts) {
      if (part.length > dynamicMax) {
        splitParts.addAll(_smartSplit(part, dynamicMax));
      } else {
        splitParts.add(part);
      }
    }
    
    // 4. 随机合并短句（打破固定条数）
    final mergedParts = _randomMergeShortParts(splitParts, dynamicMax);
    
    final limitedParts = mergedParts.take(SettingsLoader.maxParts).toList();
    
    // 5. 标点符号优化处理
    final processedParts = _processPunctuation(limitedParts);
    
    // 6. 计算延迟
    final List<Map<String, dynamic>> messages = [];
    
    for (int i = 0; i < processedParts.length; i++) {
      final content = processedParts[i];
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
            _random.nextDouble() * (SettingsLoader.intervalRandomMax - SettingsLoader.intervalRandomMin);
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
  
  /// 多级分割：先按分隔符，再按换行
  static List<String> _multiLevelSplit(String text, String separator) {
    List<String> parts = [];
    
    // 第一级：按分隔符分割
    if (text.contains(separator)) {
      parts = text.split(separator).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    } else {
      parts = [text.trim()];
    }
    
    // 第二级：将每个部分按换行再分割
    final List<String> result = [];
    for (final part in parts) {
      if (part.contains('\n')) {
        final lines = part.split('\n').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
        result.addAll(lines);
      } else {
        result.add(part);
      }
    }
    
    return result;
  }
  
  /// 随机合并短句，打破固定条数
  /// 有一定概率将相邻的短句合并成一条
  static List<String> _randomMergeShortParts(List<String> parts, int maxLength) {
    if (parts.length <= 1) return parts;
    
    final List<String> result = [];
    int i = 0;
    
    while (i < parts.length) {
      String current = parts[i];
      
      // 如果当前是短句（不到30字），有40%概率和下一句合并
      while (i < parts.length - 1 && 
             current.length < 30 && 
             _random.nextDouble() < 0.4) {
        final next = parts[i + 1];
        // 合并后不能太长
        if (current.length + next.length + 1 <= maxLength) {
          // 用空格或逗号连接
          current = '$current ${next}';
          i++;
        } else {
          break;
        }
      }
      
      result.add(current.trim());
      i++;
    }
    
    return result;
  }
  
  /// 处理标点符号分布
  static List<String> _processPunctuation(List<String> parts) {
    return parts.map((part) {
      var text = part.trim();
      if (text.isEmpty) return text;
      text = _normalizeEnding(text);
      return text;
    }).where((s) => s.isNotEmpty).toList();
  }
  
  /// 规范化结尾标点 - 删除句号，保留其他
  static String _normalizeEnding(String text) {
    if (text.isEmpty) return text;
    
    final lastChar = text[text.length - 1];
    const removableEndings = ['。', '.'];
    
    // 表情符号结尾，保留
    if (text.codeUnitAt(text.length - 1) > 0x1F600) {
      return text;
    }
    
    // 句号结尾，删除
    if (removableEndings.contains(lastChar)) {
      return text.substring(0, text.length - 1).trimRight();
    }
    
    return text;
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
      
      // 按句末标点分割
      final sentencePattern = RegExp(r'([。！？!?～~]+(?:\s*[\u{1F300}-\u{1F9FF}])?)(?=\s*|$)', unicode: true);
      final sentences = _splitBySentences(line, sentencePattern);
      
      if (sentences.length > 1) {
        String current = '';
        for (final sent in sentences) {
          if (current.isEmpty) {
            current = sent;
          } else if (current.length + sent.length <= maxLength) {
            current += sent;
          } else {
            if (current.isNotEmpty) chunks.add(current.trim());
            current = sent;
          }
        }
        if (current.isNotEmpty) chunks.add(current.trim());
      } else {
        _splitByComma(line, maxLength, chunks);
      }
    }
    
    return chunks.where((c) => c.isNotEmpty).toList();
  }
  
  static List<String> _splitBySentences(String text, RegExp pattern) {
    final sentences = <String>[];
    int lastEnd = 0;
    
    for (final match in pattern.allMatches(text)) {
      final sentence = text.substring(lastEnd, match.end).trim();
      if (sentence.isNotEmpty) {
        sentences.add(sentence);
      }
      lastEnd = match.end;
    }
    
    if (lastEnd < text.length) {
      final remaining = text.substring(lastEnd).trim();
      if (remaining.isNotEmpty) {
        sentences.add(remaining);
      }
    }
    
    return sentences;
  }
  
  static void _splitByComma(String text, int maxLength, List<String> chunks) {
    final commaParts = text.split(RegExp(r'[，,、]'));
    
    String current = '';
    for (int i = 0; i < commaParts.length; i++) {
      final part = commaParts[i].trim();
      if (part.isEmpty) continue;
      
      final withComma = i < commaParts.length - 1 ? '$part，' : part;
      
      if (current.isEmpty) {
        current = withComma;
      } else if (current.length + withComma.length <= maxLength) {
        current += withComma;
      } else {
        chunks.add(current.trim());
        current = withComma;
      }
    }
    
    if (current.isNotEmpty) {
      chunks.add(current.trim());
    }
  }
  
  static String getSplitInstruction() {
    final separator = SettingsLoader.separator;
    return '''
【回复格式】
像发微信一样聊天，不要写长段落。想分条发就用 "$separator" 分隔，换行也会自动分条。

【重要】回复条数要自然随机：
- 有时只回一个词："嗯"、"哈哈"、"好的"
- 有时两三句话
- 偶尔可以多聊几句，但不要每次都是固定三条或五条
- 根据话题自然决定，不要刻意凑数

示例A（简短回应）：
"收到"

示例B（自然两条）：
"哈哈真的假的$separator也太巧了吧"

示例C（稍多一些）：
"昨天那个事啊$separator我后来想了想$separator确实是我考虑不周"

示例D（完整表达）：
"其实我觉得$separator这件事没有对错$separator主要看你自己怎么想$separator我支持你的决定"

【禁止】：
- 禁止每次都固定发3条或5条
- 禁止机械地用"嗯$separator然后$separator所以"这种套路
- 禁止每句话都加表情
''';
  }
}

