/// 行为矩阵 - 将多维状态映射到具体表达模式
/// 
/// 设计原理：
/// - 消除硬编码的 if/else
/// - 支持无限维度的参数扩展 (Valence, Arousal, Intimacy 等)
/// - 通过“得分系统”找到最匹配的规则
class BehaviorMatrix {
  final List<BehaviorRule> _rules;

  BehaviorMatrix(this._rules);

  /// 根据当前状态查找匹配的模式
  String match(Map<String, double> state) {
    BehaviorRule? bestRule;
    double highestScore = -1.0;

    for (final rule in _rules) {
      if (rule.isMatch(state)) {
        // 规则越细致（维度越多），分值越高
        final score = rule.specificity;
        if (score > highestScore) {
          highestScore = score;
          bestRule = rule;
        }
      }
    }

    return bestRule?.mode ?? 'warm';
  }

  /// 默认推荐矩阵 (符合当前逻辑)
  factory BehaviorMatrix.defaultMatrix() {
    return BehaviorMatrix([
      BehaviorRule('excited', {
        'valence': Range(0.3, 1.0),
        'arousal': Range(0.5, 1.0),
      }),
      BehaviorRule('playful', {
        'valence': Range(0.3, 1.0),
        'arousal': Range(0.0, 0.5),
      }),
      BehaviorRule('empathetic', {
        'valence': Range(-1.0, -0.2),
        'arousal': Range(0.0, 0.5),
      }),
      BehaviorRule('calm', {
        'valence': Range(-0.2, 0.3),
        'arousal': Range(0.0, 0.4),
      }),
      BehaviorRule('formal_polite', {
        'valence': Range(-1.0, 1.0),
        'arousal': Range(0.0, 1.0),
        'intimacy': Range(0.0, 0.3), // 亲密度低时保持礼貌
      }),
      BehaviorRule('intimate_warm', {
        'valence': Range(0.4, 1.0),
        'arousal': Range(0.0, 1.0),
        'intimacy': Range(0.8, 1.0), // 极高亲密度的专属模式
      }),
      BehaviorRule('warm', {
        'valence': Range(-1.0, 1.0),
        'arousal': Range(0.0, 1.0),
      }),
    ]);
  }
}

class BehaviorRule {
  final String mode;
  final Map<String, Range> criteria;

  BehaviorRule(this.mode, this.criteria);

  /// 规则精确度（即包含多少个维度约束）
  double get specificity => criteria.length.toDouble();

  bool isMatch(Map<String, double> state) {
    for (final entry in criteria.entries) {
      final key = entry.key;
      final range = entry.value;
      final value = state[key];
      
      if (value == null || !range.contains(value)) {
        return false;
      }
    }
    return true;
  }
}

class Range {
  final double min;
  final double max;

  const Range(this.min, this.max);

  bool contains(double value) => value >= min && value <= max;
}
