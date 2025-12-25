// FeedbackAnalyzer - 用户反馈信号分析器
//
// 设计原理：
// - 从用户行为推断隐含反馈
// - 识别不满信号，学习对话偏好
// - 支持历史反馈累积和模式识别

import '../model/user_profile.dart';

/// 反馈类型
enum FeedbackType {
  engaged,        // 投入
  disengaged,     // 不投入
  annoyed,        // 烦躁
  satisfied,      // 满意
  confused,       // 困惑
  wantToEnd,      // 想结束
  neutral,        // 中性
}

/// 反馈信号
class FeedbackSignal {
  final FeedbackType type;
  final double intensity;      // 0.0 ~ 1.0
  final String? context;
  final DateTime timestamp;
  final String? triggerMessage; // 触发该反馈的 AI 消息

  FeedbackSignal({
    required this.type,
    required this.intensity,
    this.context,
    DateTime? timestamp,
    this.triggerMessage,
  }) : timestamp = timestamp ?? DateTime.now();

  @override
  String toString() {
    return '${type.name}(${(intensity * 100).toInt()}%): ${context ?? ""}';
  }
}

/// 反馈分析器
class FeedbackAnalyzer {
  final List<FeedbackSignal> _recentSignals = [];
  static const int _maxSignals = 20;

  /// 从用户行为推断反馈
  FeedbackSignal inferFromBehavior({
    required String userMessage,
    required String? previousAiResponse,
    required Duration responseDelay,
    required int userMessageLength,
    required int aiMessageLength,
  }) {
    FeedbackType type = FeedbackType.neutral;
    double intensity = 0.5;
    String? context;

    // === 分析用户消息内容 ===
    
    // 1. 极短回复可能表示不满或想结束
    if (userMessageLength <= 3) {
      final shortReplies = ['嗯', '哦', '好', '行', '知道', 'ok', '。'];
      if (shortReplies.any((r) => userMessage.trim().toLowerCase() == r)) {
        type = FeedbackType.wantToEnd;
        intensity = 0.6;
        context = '极短回复，可能想结束对话';
      }
    }

    // 2. 明确的负面反馈
    final annoyedKeywords = ['别问了', '烦', '够了', '不想说', '算了', '无语'];
    if (annoyedKeywords.any((k) => userMessage.contains(k))) {
      type = FeedbackType.annoyed;
      intensity = 0.9;
      context = '明确表达不满';
    }

    // 3. 积极反馈
    final positiveKeywords = ['哈哈', '笑死', '好棒', '谢谢', '懂我', '说得对'];
    if (positiveKeywords.any((k) => userMessage.contains(k))) {
      type = FeedbackType.satisfied;
      intensity = 0.8;
      context = '积极反馈';
    }

    // 4. 投入程度（基于消息长度比）
    if (previousAiResponse != null && aiMessageLength > 0) {
      final lengthRatio = userMessageLength / aiMessageLength;
      if (lengthRatio > 1.5) {
        // 用户回复比 AI 长很多，说明很投入
        type = FeedbackType.engaged;
        intensity = 0.7;
        context = '用户回复详细，很投入';
      } else if (lengthRatio < 0.2 && userMessageLength < 10) {
        // 用户回复很短，可能不投入
        type = FeedbackType.disengaged;
        intensity = 0.6;
        context = '用户回复简短';
      }
    }

    // 5. 响应延迟分析
    if (responseDelay.inMinutes > 30) {
      // 长时间未回复后发无关话题
      if (type == FeedbackType.neutral) {
        type = FeedbackType.disengaged;
        intensity = 0.5;
        context = '较长时间后才回复';
      }
    } else if (responseDelay.inSeconds < 10) {
      // 秒回可能表示很投入（除非是极短回复）
      if (type == FeedbackType.neutral && userMessageLength > 10) {
        type = FeedbackType.engaged;
        intensity = 0.6;
        context = '快速回复，较投入';
      }
    }

    // 6. 困惑检测
    final confusedKeywords = ['啥意思', '什么意思', '不懂', '？？', '没明白'];
    if (confusedKeywords.any((k) => userMessage.contains(k))) {
      type = FeedbackType.confused;
      intensity = 0.7;
      context = '用户表示困惑';
    }

    final signal = FeedbackSignal(
      type: type,
      intensity: intensity,
      context: context,
      triggerMessage: previousAiResponse,
    );

    _addSignal(signal);
    return signal;
  }

  /// 添加信号到历史
  void _addSignal(FeedbackSignal signal) {
    _recentSignals.add(signal);
    if (_recentSignals.length > _maxSignals) {
      _recentSignals.removeAt(0);
    }
  }

  /// 获取最近的反馈信号
  List<FeedbackSignal> getRecentSignals([int count = 5]) {
    final start = (_recentSignals.length - count).clamp(0, _recentSignals.length);
    return _recentSignals.sublist(start);
  }

  /// 获取最近的负面信号
  List<FeedbackSignal> getRecentNegativeSignals([int count = 3]) {
    return _recentSignals
        .where((s) => s.type == FeedbackType.annoyed || 
                      s.type == FeedbackType.disengaged ||
                      s.type == FeedbackType.wantToEnd)
        .toList()
        .reversed
        .take(count)
        .toList();
  }

  /// 计算整体情绪分数
  double getOverallSentiment() {
    if (_recentSignals.isEmpty) return 0.5;

    double score = 0.5;
    for (final signal in _recentSignals) {
      switch (signal.type) {
        case FeedbackType.satisfied:
        case FeedbackType.engaged:
          score += signal.intensity * 0.1;
          break;
        case FeedbackType.annoyed:
          score -= signal.intensity * 0.2;
          break;
        case FeedbackType.disengaged:
        case FeedbackType.wantToEnd:
          score -= signal.intensity * 0.1;
          break;
        case FeedbackType.confused:
          score -= signal.intensity * 0.05;
          break;
        case FeedbackType.neutral:
          break;
      }
    }

    return score.clamp(0.0, 1.0);
  }

  /// 检测是否应该调整风格
  StyleAdjustmentHint getStyleAdjustmentHint() {
    final recentNegative = getRecentNegativeSignals();
    
    if (recentNegative.isEmpty) {
      return StyleAdjustmentHint.none;
    }

    // 如果最近有明确的烦躁信号
    if (recentNegative.any((s) => s.type == FeedbackType.annoyed && s.intensity > 0.7)) {
      return StyleAdjustmentHint.beMoreCareful;
    }

    // 如果连续出现想结束的信号
    final recentThree = getRecentSignals(3);
    if (recentThree.where((s) => s.type == FeedbackType.wantToEnd).length >= 2) {
      return StyleAdjustmentHint.shortenResponse;
    }

    // 如果有困惑信号
    if (recentNegative.any((s) => s.type == FeedbackType.confused)) {
      return StyleAdjustmentHint.clarifyMore;
    }

    return StyleAdjustmentHint.slightlyAdjust;
  }

  /// 识别可能需要添加到禁止模式的行为
  List<String> identifyPatternToAvoid() {
    final patterns = <String>[];
    
    for (final signal in _recentSignals) {
      if (signal.type == FeedbackType.annoyed && signal.triggerMessage != null) {
        // 分析触发烦躁的 AI 消息
        final msg = signal.triggerMessage!;
        
        // 检测重复提问
        if (RegExp(r'\?.*\?').hasMatch(msg)) {
          patterns.add('连续提问');
        }
        
        // 检测过长回复
        if (msg.length > 200) {
          patterns.add('回复过长');
        }
      }
    }

    return patterns.toSet().toList();
  }

  /// 格式化最近反馈为描述文本
  List<String> formatRecentFeedbackForPrompt() {
    final recent = getRecentSignals(3);
    return recent.map((s) => s.toString()).toList();
  }

  /// 清空历史
  void clear() {
    _recentSignals.clear();
  }
}

/// 风格调整提示
enum StyleAdjustmentHint {
  none,             // 无需调整
  slightlyAdjust,   // 轻微调整
  shortenResponse,  // 缩短回复
  beMoreCareful,    // 更加谨慎
  clarifyMore,      // 更清晰
}
