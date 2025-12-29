// InputSanitizer - 用户输入清洗工具
//
// 设计原理：
// - 防止 Prompt 注入攻击
// - 转义可能破坏 Prompt 结构的特殊字符
// - 保持用户输入的可读性

/// 输入清洗器 - 防止 Prompt 注入
class InputSanitizer {
  /// Prompt 分隔符列表（需要转义的危险字符序列）
  static const List<String> _dangerousDelimiters = [
    '"""',      // Python 多行字符串
    "'''",      // Python 多行字符串
    '```',      // Markdown 代码块
    '===',      // 常见分隔符
    '---',      // Markdown 分隔线
    '<|',       // 某些模型的特殊标记
    '|>',       // 某些模型的特殊标记
  ];

  /// XML 标签模式（阻止用户注入假指令）
  static final RegExp _xmlTagPattern = RegExp(
    r'<\s*/?(?:thought|strategy|system|assistant|user|instruction)\s*>',
    caseSensitive: false,
  );

  /// 清洗用户输入
  ///
  /// 1. 转义危险分隔符
  /// 2. 移除可能的 XML 指令标签
  /// 3. 限制最大长度
  static String sanitize(String input, {int maxLength = 10000}) {
    if (input.isEmpty) return input;

    var sanitized = input;

    // 1. 转义危险分隔符
    for (final delimiter in _dangerousDelimiters) {
      sanitized = sanitized.replaceAll(
        delimiter,
        delimiter.split('').join('\u200B'), // 零宽空格分隔
      );
    }

    // 2. 移除 XML 指令标签（替换为安全文本）
    sanitized = sanitized.replaceAllMapped(_xmlTagPattern, (match) {
      return '[用户输入: ${match.group(0)}]';
    });

    // 3. 限制长度
    if (sanitized.length > maxLength) {
      sanitized = '${sanitized.substring(0, maxLength)}...(内容过长已截断)';
    }

    return sanitized;
  }

  /// 快速检测是否包含危险内容
  static bool containsDangerousContent(String input) {
    if (_xmlTagPattern.hasMatch(input)) return true;
    for (final delimiter in _dangerousDelimiters) {
      if (input.contains(delimiter)) return true;
    }
    return false;
  }

  /// 清洗 LLM 输出以防止回显攻击
  static String sanitizeOutput(String output) {
    // 移除潜在的系统指令泄露
    var sanitized = output;
    
    // 移除以 "System:" 或 "Instructions:" 开头的行
    sanitized = sanitized.replaceAll(
      RegExp(r'^(System|Instructions|Prompt):.*$', multiLine: true),
      '',
    );

    return sanitized.trim();
  }
}
