import 'package:flutter/material.dart';
import '../../core/provider/intimacy_color_provider.dart';

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
    
    // 【Research-Grade】 情绪决定强调色和混合逻辑
    final accentColor = _getAccentColorByEmotion();
    
    // 动态生成三色渐变
    final colors = [
      baseColor,
      Color.lerp(baseColor, accentColor, 0.5)!,
      accentColor.withValues(alpha: 0.8),
    ];
    
    // 唤起度影响渐变方向 (0.5平缓 -> 1.0激进)
    final alignEnd = Alignment(
      1.0, 
      1.0 + (arousal - 0.5) * 2 // 动态调整 Y 轴倾斜
    );

    return AnimatedContainer(
      duration: const Duration(milliseconds: 2000),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: alignEnd,
          colors: colors,
          stops: const [0.0, 0.6, 1.0], // 非线性分布增加层次感
        ),
      ),
    );
  }

  /// 亲密度决定背景基调 - 使用统一的 IntimacyColorProvider
  /// 【UI审计】颜色过渡: 灰色(负)→蓝色(低)→粉色(中高)→紫色(极高)
  Color _getBaseColorByIntimacy() {
    // 使用 IntimacyColorProvider 获取基础色
    final baseColor = IntimacyColorProvider.getIntimacyColor(intimacy);
    
    if (isDarkMode) {
      // 暗色模式: 降低亮度和保持低饱和度
      final hsl = HSLColor.fromColor(baseColor);
      return hsl.withLightness((hsl.lightness * 0.25).clamp(0.05, 0.2))
                .withSaturation((hsl.saturation * 0.6).clamp(0.1, 0.5))
                .toColor();
    } else {
      // 亮色模式: 使用淡化版本
      return IntimacyColorProvider.getBackgroundTint(intimacy, isDark: false)
                .withOpacity(0.3); // 确保足够淡
    }
  }

  /// 情绪决定强调色 (Shift)
  Color _getAccentColorByEmotion() {
    // 根据 Valence 选择色相倾向
    // Valence < 0 (负面): 偏冷/暗 (Blue, Violet, Grey)
    // Valence > 0 (正面): 偏暖/亮 (Orange, Yellow, Cyan)
    
    HSLColor baseHsl;
    
    if (valence > 0.5) {
      baseHsl = HSLColor.fromColor(Colors.orangeAccent); // 兴奋/快乐
    } else if (valence > 0) {
      baseHsl = HSLColor.fromColor(Colors.cyanAccent);   // 平静/愉悦
    } else if (valence > -0.5) {
      baseHsl = HSLColor.fromColor(Colors.blueGrey);     // 低落/无聊
    } else {
      baseHsl = HSLColor.fromColor(Colors.deepPurpleAccent); // 焦虑/痛苦
    }
    
    // 根据 Arousal 调整饱和度和亮度
    // Arousal 高 -> 饱和度高
    // Arousal 低 -> 饱和度低，亮度适中
    
    final saturation = (0.3 + arousal * 0.4).clamp(0.0, 1.0); // 0.3 - 0.7
    final lightness = isDarkMode 
        ? (0.15 + arousal * 0.15).clamp(0.0, 0.4) // 暗色模式下保持低亮度
        : (0.85 + arousal * 0.1).clamp(0.8, 0.95); // 亮色模式下保持高亮度
        
    return baseHsl.withSaturation(saturation).withLightness(lightness).toColor();
  }
}
