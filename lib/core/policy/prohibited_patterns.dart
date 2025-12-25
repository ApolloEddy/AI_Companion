// ProhibitedPatterns - 硬编码禁止规则
//
// 设计原理：
// - 硬编码规则，不可被 LLM 输出覆盖
// - 用于检测和过滤机械化、恼人的回复模式
// - 快速止血，立即改善用户体验

/// 禁止模式检测器
class ProhibitedPatterns {
  /// 正则模式：必须避免的回复模式
  static const List<_PatternRule> _rules = [
    // === 重复提问模式 ===
    _PatternRule(
      name: 'repeated_question',
      pattern: r'(你觉得呢|是吗|对吧|你呢).*\1',
      description: '重复相同的反问',
      severity: 0.8,
    ),
    _PatternRule(
      name: 'question_chain',
      pattern: r'\?.*\?.*\?',
      description: '连续多个问号（可能是连续提问）',
      severity: 0.6,
    ),
    
    // === 无意义追问模式 ===
    _PatternRule(
      name: 'empty_followup',
      pattern: r'^那你(现在|之后|接下来)(打算|准备|计划)(怎么办|做什么|怎样)',
      description: '无意义的追问用户计划',
      severity: 0.7,
    ),
    _PatternRule(
      name: 'generic_question',
      pattern: r'^你有没有(想过|考虑过|试过)',
      description: '泛泛的建议式提问',
      severity: 0.5,
    ),
    
    // === 过度关心循环 ===
    _PatternRule(
      name: 'care_loop',
      pattern: r'(还好吗|没事吧|怎么了|你还好吗).*\1',
      description: '重复询问是否还好',
      severity: 0.8,
    ),
    _PatternRule(
      name: 'excessive_care',
      pattern: r'(别太|不要太|注意)(累|辛苦|勉强).*(别太|不要太|注意)',
      description: '过度关心词汇堆砌',
      severity: 0.6,
    ),
    
    // === 说教模式 ===
    _PatternRule(
      name: 'lecture_format',
      pattern: r'(首先|第一).*(其次|第二).*(最后|第三)',
      description: '说教式分点论述',
      severity: 0.9,
    ),
    _PatternRule(
      name: 'should_repetition',
      pattern: r'你(应该|需要|必须).*你(应该|需要|必须)',
      description: '重复"你应该"',
      severity: 0.7,
    ),
    _PatternRule(
      name: 'numbered_list',
      pattern: r'[1１][\.\、].+[2２][\.\、].+[3３][\.\、]',
      description: '数字列表格式',
      severity: 0.8,
    ),
    
    // === 机器人特征 ===
    _PatternRule(
      name: 'ai_disclosure',
      pattern: r'作为(一个|一名)?(AI|人工智能|语言模型|助手)',
      description: '暴露 AI 身份',
      severity: 1.0,
    ),
    _PatternRule(
      name: 'formal_understanding',
      pattern: r'根据(我的|您的)?理解',
      description: '过于正式的理解声明',
      severity: 0.6,
    ),
    _PatternRule(
      name: 'summary_intro',
      pattern: r'(总的来说|综上所述|总而言之)',
      description: '总结性开头',
      severity: 0.7,
    ),
    
    // === 固定开头词 ===
    _PatternRule(
      name: 'repetitive_start',
      pattern: r'^(嗯|哈哈|原来如此|这样啊)',
      description: '固定的开头词',
      severity: 0.3,  // 低严重性，仅作警告
    ),
    
    // === 公式化回答 ===
    _PatternRule(
      name: 'answer_plus_question',
      pattern: r'.{20,}\?$',  // 长回答以问号结尾
      description: '回答+反问的固定套路',
      severity: 0.4,
    ),
  ];

  /// 检查回复是否包含禁止模式
  static PatternCheckResult check(String response) {
    final violations = <PatternViolation>[];
    
    for (final rule in _rules) {
      if (RegExp(rule.pattern, caseSensitive: false).hasMatch(response)) {
        violations.add(PatternViolation(
          ruleName: rule.name,
          description: rule.description,
          severity: rule.severity,
        ));
      }
    }
    
    return PatternCheckResult(
      isClean: violations.isEmpty,
      violations: violations,
      maxSeverity: violations.isEmpty 
          ? 0.0 
          : violations.map((v) => v.severity).reduce((a, b) => a > b ? a : b),
    );
  }

  /// 尝试清理/修正回复
  static String sanitize(String response) {
    var cleaned = response;
    
    // 移除说教性的数字列表
    cleaned = cleaned.replaceAll(RegExp(r'^\d+[\.\、]\s*', multiLine: true), '');
    
    // 移除 AI 身份暴露
    cleaned = cleaned.replaceAllMapped(
      RegExp(r'作为(一个|一名)?(AI|人工智能|语言模型|助手)[，,]?\s*'),
      (m) => '',
    );
    
    // 移除总结性开头
    cleaned = cleaned.replaceAll(RegExp(r'^(总的来说|综上所述|总而言之)[，,]?\s*'), '');
    
    return cleaned.trim();
  }

  /// 获取应该避免的模式描述（用于 Prompt）
  static String getAvoidanceGuide() {
    return '''
【严格禁止的回复模式】
- 禁止重复提问（如连续问"你觉得呢？""对吧？"）
- 禁止无意义追问（如"那你接下来打算怎么办？"）
- 禁止过度关心循环（如反复问"你还好吗？"）
- 禁止说教式分点（如"首先...其次...最后..."）
- 禁止数字列表格式
- 禁止提及自己是AI
- 禁止固定套路（回答+反问）
- 禁止每句话都用相同开头（嗯/哈哈/原来如此）
''';
  }

  /// 根据用户偏好扩展禁止规则
  static List<String> getUserDislikedPatternDescriptions(List<String> userPatterns) {
    final descriptions = <String>[];
    for (final pattern in userPatterns) {
      descriptions.add('用户明确表示不喜欢：$pattern');
    }
    return descriptions;
  }
}

/// 模式规则定义
class _PatternRule {
  final String name;
  final String pattern;
  final String description;
  final double severity;  // 0.0 ~ 1.0

  const _PatternRule({
    required this.name,
    required this.pattern,
    required this.description,
    required this.severity,
  });
}

/// 模式违规记录
class PatternViolation {
  final String ruleName;
  final String description;
  final double severity;

  const PatternViolation({
    required this.ruleName,
    required this.description,
    required this.severity,
  });

  @override
  String toString() => '[$ruleName] $description (severity: $severity)';
}

/// 模式检查结果
class PatternCheckResult {
  final bool isClean;
  final List<PatternViolation> violations;
  final double maxSeverity;

  const PatternCheckResult({
    required this.isClean,
    required this.violations,
    required this.maxSeverity,
  });

  /// 是否需要重新生成
  bool get shouldRegenerate => maxSeverity >= 0.8;

  /// 是否需要警告
  bool get shouldWarn => maxSeverity >= 0.5 && maxSeverity < 0.8;

  @override
  String toString() {
    if (isClean) return 'Clean: No prohibited patterns detected';
    return 'Violations found: ${violations.map((v) => v.ruleName).join(', ')}';
  }
}
