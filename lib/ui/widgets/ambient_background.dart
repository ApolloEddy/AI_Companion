import 'package:flutter/material.dart';

/// AmbientBackground - 情绪驱动的动态渐变背景
///
/// 设计原理：
/// - 根据 AI 情绪状态（Valence 效价 / Arousal 唤起度）动态调整背景色
/// - 负面情绪呈现冷色调（蓝紫），正面情绪呈现暖色调（橙粉）
/// - 唤起度影响渐变的对比度和动画速度
class AmbientBackground extends StatelessWidget {
  final double valence; // -1.0 (负面) 到 1.0 (正面)
  final double arousal; // 0.0 (平静) 到 1.0 (兴奋)
  final bool isDarkMode;

  const AmbientBackground({
    super.key,
    this.valence = 0.0,
    this.arousal = 0.5,
    this.isDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    // 计算渐变颜色基于情绪
    final colors = _getGradientColors();
    
    return AnimatedContainer(
      duration: const Duration(milliseconds: 1500),
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

  /// 根据情绪状态计算渐变颜色
  List<Color> _getGradientColors() {
    // 基础色相映射：
    // valence < 0: 蓝色/紫色系 (冷色)
    // valence > 0: 橙色/粉色系 (暖色)
    // valence = 0: 中性灰蓝色
    
    Color primaryColor;
    Color secondaryColor;
    
    if (valence < -0.3) {
      // 负面情绪：深蓝/紫色
      primaryColor = isDarkMode 
          ? const Color(0xFF1a1a2e)  // 深蓝黑
          : const Color(0xFF4a4e69);  // 灰紫
      secondaryColor = isDarkMode
          ? const Color(0xFF16213e)  // 深靛蓝
          : const Color(0xFF9a8c98);  // 淡紫灰
    } else if (valence > 0.3) {
      // 正面情绪：暖橙/粉色
      primaryColor = isDarkMode
          ? const Color(0xFF2d132c)  // 深酒红
          : const Color(0xFFf8edeb);  // 米粉
      secondaryColor = isDarkMode
          ? const Color(0xFF3d1a38)  // 深紫红
          : const Color(0xFFfcd5ce);  // 淡桃粉
    } else {
      // 中性情绪：柔和蓝灰
      primaryColor = isDarkMode
          ? const Color(0xFF1e1e2e)  // 深灰蓝
          : const Color(0xFFf0f0f5);  // 浅灰蓝
      secondaryColor = isDarkMode
          ? const Color(0xFF252536)  // 中灰蓝
          : const Color(0xFFe8e8f0);  // 淡灰
    }
    
    // 高唤起度增加颜色饱和度
    if (arousal > 0.7) {
      primaryColor = _saturateColor(primaryColor, 0.15);
      secondaryColor = _saturateColor(secondaryColor, 0.15);
    }
    
    return [primaryColor, secondaryColor];
  }

  /// 增加颜色饱和度
  Color _saturateColor(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withSaturation((hsl.saturation + amount).clamp(0.0, 1.0)).toColor();
  }
}
