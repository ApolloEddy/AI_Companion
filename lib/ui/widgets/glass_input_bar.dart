import 'dart:ui';
import 'package:flutter/material.dart';

/// GlassInputBar - 玻璃拟态浮动输入框
///
/// 设计原理：
/// - 使用 BackdropFilter 实现毛玻璃效果
/// - 渐变发送按钮增强视觉层次
/// - 浮动设计与背景自然融合
/// - 【新增】自适应尺寸基于屏幕宽度
class GlassInputBar extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onSend;
  final bool isDarkMode;

  const GlassInputBar({
    super.key,
    required this.controller,
    required this.onSend,
    this.isDarkMode = false,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    
    // 自适应尺寸计算
    final isCompact = screenWidth < 400;  // 小屏手机
    final isLarge = screenWidth > 800;    // 桌面/平板
    
    final horizontalPadding = isLarge ? 24.0 : (isCompact ? 8.0 : 12.0);
    final borderRadius = isLarge ? 32.0 : (isCompact ? 22.0 : 28.0);
    final fontSize = isLarge ? 15.0 : (isCompact ? 14.0 : 15.0);
    final buttonSize = isLarge ? 42.0 : (isCompact ? 36.0 : 40.0);
    final iconSize = isLarge ? 22.0 : (isCompact ? 18.0 : 20.0);
    
    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding, vertical: isCompact ? 6 : 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: isCompact ? 4 : 6, vertical: isCompact ? 4 : 6),
              decoration: BoxDecoration(
                color: isDarkMode
                    ? Colors.white.withOpacity(0.08)
                    : Colors.white.withOpacity(0.7),
                borderRadius: BorderRadius.circular(borderRadius),
                border: Border.all(
                  color: isDarkMode
                      ? Colors.white.withOpacity(0.12)
                      : Colors.white.withOpacity(0.8),
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDarkMode ? 0.3 : 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SizedBox(width: isCompact ? 8 : 12),
                  // 输入框
                  Expanded(
                    child: TextField(
                      controller: controller,
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => onSend(),
                      style: TextStyle(
                        color: isDarkMode ? Colors.white : Colors.black87,
                        fontSize: fontSize,
                      ),
                      decoration: InputDecoration(
                        hintText: '发送消息...',
                        hintStyle: TextStyle(
                          color: isDarkMode 
                              ? Colors.white.withOpacity(0.5)
                              : Colors.black45,
                          fontSize: fontSize,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(vertical: isCompact ? 8 : 10),
                      ),
                    ),
                  ),
                  SizedBox(width: isCompact ? 6 : 8),
                  // 渐变发送按钮
                  _buildGradientSendButton(buttonSize, iconSize),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildGradientSendButton(double size, double iconSize) {
    return GestureDetector(
      onTap: onSend,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [
              Color(0xFF07C160), // 微信绿
              Color(0xFF00A67E), // 深青绿
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(size / 2),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF07C160).withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(
          Icons.arrow_upward_rounded,
          color: Colors.white,
          size: iconSize,
        ),
      ),
    );
  }
}
