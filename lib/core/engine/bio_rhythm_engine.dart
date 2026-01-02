// BioRhythmEngine - 生理节律引擎
//
// 【设计原理】
// 模拟人类昼夜节律，在深夜时段自然降低活力。
// 
// 核心概念：
// - Laziness (疲惫值) 是状态变量，不是人格特质
// - 使用线性插值 (lerp) 实现平滑过渡，避免状态突变
// - 所有变化都是连续、可回滚的
//
// 时间曲线：
// - 10:00–22:00 → 0.0 (完全清醒)
// - 22:00–01:00 → 0.0 → 0.9 (逐渐疲惫)
// - 01:00–05:00 → 0.9 (极度疲惫)
// - 05:00–08:00 → 0.9 → 0.0 (逐渐清醒)
// - 08:00–10:00 → 0.0 (完全清醒)

import 'dart:math' as math;

/// 生理节律引擎
/// 
/// 负责计算基于时间的疲惫值 (Laziness)
class BioRhythmEngine {
  // 时间节点 (小时)
  static const double _morningStartHour = 5.0;   // 清醒开始
  static const double _morningEndHour = 8.0;     // 完全清醒
  static const double _dayStartHour = 10.0;      // 日间开始
  static const double _eveningStartHour = 22.0;  // 疲惫开始
  static const double _nightPeakHour = 25.0;     // 凌晨1点 (视为25点)
  static const double _nightEndHour = 29.0;      // 凌晨5点 (视为29点)
  
  // 疲惫值边界
  static const double _minLaziness = 0.0;
  static const double _maxLaziness = 0.9;
  
  /// 计算当前疲惫值
  /// 
  /// [time] 当前时间
  /// 返回范围: 0.0 (完全清醒) ~ 0.9 (极度疲惫)
  /// 
  /// 设计说明：
  /// - 使用 lerp (线性插值) 确保过渡平滑
  /// - 所有返回值经过 clamp，保证不会超出范围
  double calculateLaziness(DateTime time) {
    // 将时间转换为连续的小时数 (0-30 范围，便于跨午夜计算)
    final double hour = _toNormalizedHour(time.hour, time.minute);
    
    // 判断所处时段并计算疲惫值
    if (hour >= _dayStartHour && hour < _eveningStartHour) {
      // 10:00 - 22:00: 日间清醒期
      return _minLaziness;
    } else if (hour >= _eveningStartHour && hour < _nightPeakHour) {
      // 22:00 - 01:00: 疲惫上升期 (3小时过渡)
      return _lerp(_minLaziness, _maxLaziness, 
          (hour - _eveningStartHour) / (_nightPeakHour - _eveningStartHour));
    } else if (hour >= _nightPeakHour && hour < _nightEndHour) {
      // 01:00 - 05:00: 极度疲惫期
      return _maxLaziness;
    } else if (hour >= _nightEndHour && hour < _nightEndHour + 3) {
      // 05:00 - 08:00: 清醒恢复期 (3小时过渡)
      return _lerp(_maxLaziness, _minLaziness, 
          (hour - _nightEndHour) / 3.0);
    } else {
      // 08:00 - 10:00: 完全清醒期
      return _minLaziness;
    }
  }
  
  /// 将小时和分钟转换为标准化的连续小时数
  /// 
  /// 0-8点视为 24-32 点，便于跨午夜的连续计算
  /// 这样可以用连续的数轴处理：10-22 日间，22-25 疲惫上升，25-29 极疲，29-32 恢复
  double _toNormalizedHour(int hour, int minute) {
    double h = hour + minute / 60.0;
    // 将 0-8 点映射到 24-32 点
    if (h < _morningEndHour) {
      h += 24.0;
    }
    return h;
  }
  
  /// 线性插值 (Linear Interpolation)
  /// 
  /// [a] 起始值
  /// [b] 结束值
  /// [t] 插值系数 (0.0 ~ 1.0)
  double _lerp(double a, double b, double t) {
    final clampedT = t.clamp(0.0, 1.0);
    return a + (b - a) * clampedT;
  }
  
  /// 获取当前时段的描述（用于调试和日志）
  String getTimePhaseDescription(DateTime time) {
    final hour = _toNormalizedHour(time.hour, time.minute);
    
    if (hour >= _dayStartHour && hour < _eveningStartHour) {
      return '日间清醒期';
    } else if (hour >= _eveningStartHour && hour < _nightPeakHour) {
      return '疲惫上升期';
    } else if (hour >= _nightPeakHour && hour < _nightEndHour) {
      return '极度疲惫期';
    } else if (hour >= _nightEndHour && hour < _nightEndHour + 3) {
      return '清醒恢复期';
    } else {
      return '早间清醒期';
    }
  }
  
  /// 计算容忍度 (Tolerance)
  /// 
  /// Tolerance 不是人格 trait，而是状态变量，
  /// 用于判断 AI 是否还愿意继续安抚。
  /// 
  /// [laziness] 当前疲惫值
  /// [needType] 用户需求类型 (comfort, vent 等)
  /// [sameTopicRepeated] 用户是否重复相同话题
  /// 
  /// 返回范围: 0.0 ~ 1.0
  /// - tolerance >= 0.4: 仍可有限共情
  /// - tolerance < 0.4: 不想继续安抚
  /// - tolerance < 0.2: 轻度不耐烦区间
  double calculateTolerance({
    required double laziness,
    String? needType,
    bool sameTopicRepeated = false,
  }) {
    var tolerance = 1.0 - laziness;
    
    // 情绪照护需求会消耗容忍度
    if (needType == 'comfort' || needType == 'vent') {
      tolerance -= 0.2;
    }
    
    // 重复话题会消耗容忍度
    if (sameTopicRepeated) {
      tolerance -= 0.2;
    }
    
    return tolerance.clamp(0.0, 1.0);
  }
}
