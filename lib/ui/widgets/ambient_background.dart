import 'package:flutter/material.dart';

/// AmbientBackground - 情绪驱动的动态渐变背景
///
/// 【Research-Grade】升级：
/// - 融合 亲密度 (Intimacy) 作为基调 (Base Tone)
/// - 融合 情绪 (Emotion) 作为动态变化 (Dynamics)
/// - 高亲密度 = 温暖/明亮；情绪 = 色相偏移
class AmbientBackground extends StatelessWidget {
  final double valence; // -1.0 (负面) 到 1.0 (正面)
  final double arousal; // 0.0 (平静) 到 1.0 (兴奋)
  final double intimacy; // 0.0 (疏远) 到 1.0 (亲密)
  final bool isDarkMode;

  const AmbientBackground({
    super.key,
    this.valence = 0.0,
    this.arousal = 0.5,
    this.intimacy = 0.3,
    this.isDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    // 【Research-Grade】 亲密度决定基调颜色
    final baseColor = _getBaseColorByIntimacy();
    
    // 【Research-Grade】 情绪决定偏移和对比
    final colors = _applyEmotionDynamics(baseColor);
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 2000),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
    );
  }

  /// 亲密度决定背景基调
  Color _getBaseColorByIntimacy() {
    if (isDarkMode) {
      if (intimacy > 0.7) return const Color(0xFF2D1B28); // 暖紫黑
      if (intimacy > 0.4) return const Color(0xFF1B1B2D); // 深蓝蓝
      return const Color(0xFF0D1117); // 极其冷淡的深色
    } else {
      if (intimacy > 0.7) return const Color(0xFFFFF5F8); // 温润淡粉
      if (intimacy > 0.4) return const Color(0xFFF5F8FF); // 清新淡蓝
      return const Color(0xFFF6F8FA); // 灰白
    }
  }

  /// 融合情绪动态
  List<Color> _applyEmotionDynamics(Color base) {
    final hsl = HSLColor.fromColor(base);
    
    // 效价 (Valence) 决定色相偏移
    // 正面(+): 移向黄色/橙色；负面(-): 移向蓝色/紫色
    double hueShift = valence * 20.0; // 最大偏移 20 度
    
    // 唤起度 (Arousal) 决定对比和饱和度
    double saturationShift = (arousal - 0.5) * 0.2;
    double lightnessShift = (arousal - 0.5) * 0.05;

    final primary = hsl.withHue((hsl.hue + hueShift).clamp(0.0, 360.0))
        .withSaturation((hsl.saturation + saturationShift).clamp(0.0, 1.0))
        .withLightness((hsl.lightness + lightnessShift).clamp(0.0, 1.0))
        .toColor();

    final secondary = hsl.withHue((hsl.hue - hueShift).clamp(0.0, 360.0))
        .withSaturation((hsl.saturation - saturationShift).clamp(0.0, 1.0))
        .withLightness((hsl.lightness - lightnessShift).clamp(0.0, 1.0))
        .toColor();

    return [primary, secondary];
  }
}
