// RuleEngine - 轻量级规则引擎
//
// 设计原理：
// - 评估 YAML 中定义的条件字符串
// - 支持基本比较操作符和逻辑运算
// - 替代代码中的硬编码 if-else 逻辑
// - 【Phase 3】增加表达式缓存以避免重复解析

/// 解析后的表达式节点（抽象语法树）
abstract class _ExprNode {
  bool evaluate(Map<String, dynamic> context);
}

/// 比较表达式节点
class _CompareNode extends _ExprNode {
  final String left;
  final String right;
  final String op;

  _CompareNode(this.left, this.op, this.right);

  @override
  bool evaluate(Map<String, dynamic> context) {
    final leftValue = _resolveValue(left, context);
    final rightValue = _resolveValue(right, context);
    return _compare(leftValue, rightValue, op);
  }

  static dynamic _resolveValue(String token, Map<String, dynamic> context) {
    token = token.trim();

    // 处理 abs() 函数
    if (token.startsWith('abs(') && token.endsWith(')')) {
      final inner = token.substring(4, token.length - 1);
      final value = _resolveValue(inner, context);
      if (value is num) {
        return value.abs();
      }
      return 0;
    }

    // 处理字符串字面量
    if ((token.startsWith("'") && token.endsWith("'")) ||
        (token.startsWith('"') && token.endsWith('"'))) {
      return token.substring(1, token.length - 1);
    }

    // 处理数字
    final num? number = num.tryParse(token);
    if (number != null) return number;

    // 处理布尔值
    if (token == 'true') return true;
    if (token == 'false') return false;
    if (token == 'null') return null;

    // 处理上下文变量
    if (context.containsKey(token)) {
      return context[token];
    }

    // 处理嵌套属性 (如 "user.intimacy")
    if (token.contains('.')) {
      final parts = token.split('.');
      dynamic value = context;
      for (final part in parts) {
        if (value is Map && value.containsKey(part)) {
          value = value[part];
        } else {
          return null;
        }
      }
      return value;
    }

    return token;
  }

  static bool _compare(dynamic left, dynamic right, String op) {
    // 处理 null
    if (left == null || right == null) {
      if (op == '==') return left == right;
      if (op == '!=') return left != right;
      return false;
    }

    // 字符串比较
    if (left is String || right is String) {
      final leftStr = left.toString();
      final rightStr = right.toString();
      switch (op) {
        case '==':
          return leftStr == rightStr;
        case '!=':
          return leftStr != rightStr;
        default:
          return false;
      }
    }

    // 数值比较
    if (left is num && right is num) {
      switch (op) {
        case '>':
          return left > right;
        case '<':
          return left < right;
        case '>=':
          return left >= right;
        case '<=':
          return left <= right;
        case '==':
          return left == right;
        case '!=':
          return left != right;
      }
    }

    // 布尔比较
    if (left is bool && right is bool) {
      switch (op) {
        case '==':
          return left == right;
        case '!=':
          return left != right;
      }
    }

    return false;
  }
}

/// AND 表达式节点
class _AndNode extends _ExprNode {
  final List<_ExprNode> children;

  _AndNode(this.children);

  @override
  bool evaluate(Map<String, dynamic> context) {
    return children.every((c) => c.evaluate(context));
  }
}

/// OR 表达式节点
class _OrNode extends _ExprNode {
  final List<_ExprNode> children;

  _OrNode(this.children);

  @override
  bool evaluate(Map<String, dynamic> context) {
    return children.any((c) => c.evaluate(context));
  }
}

/// 常量节点
class _ConstNode extends _ExprNode {
  final bool value;

  _ConstNode(this.value);

  @override
  bool evaluate(Map<String, dynamic> context) => value;
}

/// 规则引擎 - 评估条件表达式（带缓存）
class RuleEngine {
  /// 表达式缓存 - 避免重复解析
  static final Map<String, _ExprNode> _cache = {};

  /// 缓存命中计数（用于调试）
  static int _cacheHits = 0;
  static int _cacheMisses = 0;

  /// 获取缓存统计
  static String get cacheStats => 'hits: $_cacheHits, misses: $_cacheMisses, size: ${_cache.length}';

  /// 清空缓存
  static void clearCache() {
    _cache.clear();
    _cacheHits = 0;
    _cacheMisses = 0;
  }

  /// 评估条件是否满足
  ///
  /// [condition] 条件表达式，如 "intimacy > 0.7 && valence > 0"
  /// [context] 上下文变量，如 {"intimacy": 0.8, "valence": 0.5}
  ///
  /// 支持的操作符：
  /// - 比较: >, <, >=, <=, ==, !=
  /// - 逻辑: && (AND), || (OR)
  /// - 函数: abs()
  static bool evaluate(String? condition, Map<String, dynamic> context) {
    if (condition == null || condition.isEmpty) {
      return true; // 空条件默认为真
    }

    try {
      // 检查缓存
      final trimmed = condition.trim();
      _ExprNode? node = _cache[trimmed];
      
      if (node != null) {
        _cacheHits++;
      } else {
        _cacheMisses++;
        node = _parse(trimmed);
        _cache[trimmed] = node;
      }

      return node.evaluate(context);
    } catch (e) {
      print('[RuleEngine] 条件评估失败: $condition, 错误: $e');
      return false;
    }
  }

  /// 解析表达式为 AST
  static _ExprNode _parse(String expr) {
    // 处理 OR 运算符 (优先级最低)
    if (expr.contains('||')) {
      final parts = _splitByOperator(expr, '||');
      if (parts.length > 1) {
        return _OrNode(parts.map((p) => _parse(p.trim())).toList());
      }
    }

    // 处理 AND 运算符
    if (expr.contains('&&')) {
      final parts = _splitByOperator(expr, '&&');
      if (parts.length > 1) {
        return _AndNode(parts.map((p) => _parse(p.trim())).toList());
      }
    }

    // 处理括号
    if (expr.startsWith('(') && expr.endsWith(')')) {
      return _parse(expr.substring(1, expr.length - 1));
    }

    // 处理比较表达式
    return _parseComparison(expr);
  }

  /// 按操作符分割，考虑括号嵌套
  static List<String> _splitByOperator(String expr, String operator) {
    final result = <String>[];
    int depth = 0;
    int start = 0;

    for (int i = 0; i < expr.length - operator.length + 1; i++) {
      if (expr[i] == '(') {
        depth++;
      } else if (expr[i] == ')') {
        depth--;
      } else if (depth == 0 && expr.substring(i, i + operator.length) == operator) {
        result.add(expr.substring(start, i));
        start = i + operator.length;
        i += operator.length - 1;
      }
    }
    result.add(expr.substring(start));
    return result;
  }

  /// 解析比较表达式
  static _ExprNode _parseComparison(String expr) {
    // 支持的比较操作符
    final operators = ['>=', '<=', '!=', '==', '>', '<'];

    for (final op in operators) {
      final index = expr.indexOf(op);
      if (index != -1) {
        final left = expr.substring(0, index).trim();
        final right = expr.substring(index + op.length).trim();
        return _CompareNode(left, op, right);
      }
    }

    // 布尔变量
    if (expr.trim() == 'true') return _ConstNode(true);
    if (expr.trim() == 'false') return _ConstNode(false);

    // 未知表达式，返回 false
    return _ConstNode(false);
  }
}

