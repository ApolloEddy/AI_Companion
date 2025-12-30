import 'package:flutter/material.dart';

/// 亲密度颜色提供者
/// 
/// 根据亲密度值动态计算颜色：
/// - 负亲密度: 灰色
/// - 低亲密度 (0-30%): 蓝色
/// - 中高亲密度 (30-70%): 粉色
/// - 高亲密度 (70-95%): 渐变到亮紫色
/// - 极高亲密度 (95%+): 暧昧亮紫色
class IntimacyColorProvider {
  /// 根据亲密度获取主色调
  /// 
  /// [intimacy] 范围: -1.0 到 1.0 (通常 0.0 到 1.0)
  static Color getIntimacyColor(double intimacy) {
    if (intimacy < 0) {
      return Colors.grey; // 负亲密度
    } else if (intimacy < 0.3) {
      // 低亲密度: 蓝色区间
      return Color.lerp(Colors.blueGrey, Colors.blueAccent, intimacy / 0.3)!;
    } else if (intimacy < 0.7) {
      // 中亲密度: 蓝到粉渐变
      final t = (intimacy - 0.3) / 0.4;
      return Color.lerp(Colors.blueAccent, Colors.pinkAccent, t)!;
    } else if (intimacy < 0.95) {
      // 高亲密度: 粉到紫渐变
      final t = (intimacy - 0.7) / 0.25;
      return Color.lerp(Colors.pinkAccent, const Color(0xFFDA70D6), t)!; // Orchid
    } else {
      // 极高亲密度 (95%+): 暧昧亮紫色
      return const Color(0xFFDA70D6); // Orchid Purple
    }
  }
  
  /// 获取用于背景的淡化版颜色
  /// 
  /// [isDark] 是否为暗色主题
  static Color getBackgroundTint(double intimacy, {bool isDark = false}) {
    final baseColor = getIntimacyColor(intimacy);
    return baseColor.withValues(alpha: isDark ? 0.08 : 0.05);
  }
  
  /// 获取进度条颜色（较深）
  static Color getProgressColor(double intimacy) {
    return getIntimacyColor(intimacy);
  }
  
  /// 获取进度条背景颜色（较浅）
  static Color getProgressBackgroundColor(double intimacy, {bool isDark = false}) {
    return getIntimacyColor(intimacy).withValues(alpha: isDark ? 0.2 : 0.15);
  }

  /// 获取用于进度条的渐变颜色列表 (左深右浅)
  /// 
  /// 返回 [baseColor, lighterColor]
  static List<Color> getGradientColors(double intimacy) {
    final baseColor = getIntimacyColor(intimacy);
    final hsl = HSLColor.fromColor(baseColor);
    // 右侧颜色增加亮度，形成发光感
    final rightColor = hsl.withLightness((hsl.lightness + 0.15).clamp(0.0, 1.0)).toColor();
    return [baseColor, rightColor];
  }
}
