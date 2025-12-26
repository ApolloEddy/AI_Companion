import 'package:flutter/material.dart';

/// UI 自适应布局适配器
/// 
/// 设计原理：
/// - 统一协调字号、气泡宽度、输入框尺寸
/// - 基于屏幕宽度的三级适配：Compact (手机), Standard (大屏手机/平板), Large (桌面)
class UIAdapter {
  final BuildContext context;
  late final double screenWidth;
  late final double screenHeight;
  
  UIAdapter(this.context) {
    screenWidth = MediaQuery.of(context).size.width;
    screenHeight = MediaQuery.of(context).size.height;
  }

  // 布局断点
  bool get isCompact => screenWidth < 450;
  bool get isLarge => screenWidth > 900;
  bool get isStandard => !isCompact && !isLarge;

  // --- 字体大小协调 ---
  
  double get titleFontSize => isLarge ? 20.0 : (isCompact ? 17.0 : 18.0);
  double get bodyFontSize => isLarge ? 16.0 : (isCompact ? 14.5 : 15.0);
  double get smallFontSize => isLarge ? 13.0 : (isCompact ? 11.0 : 12.0);
  double get tinyFontSize => isCompact ? 10.0 : 11.0;

  // --- 聊天气泡协调 ---
  
  double get bubblePadding => isLarge ? 15.0 : (isCompact ? 10.0 : 12.0);
  double get bubbleRadius => isLarge ? 20.0 : (isCompact ? 15.0 : 18.0);
  double get bubbleMaxWidth => screenWidth * (isLarge ? 0.6 : (isCompact ? 0.82 : 0.75));
  double get avatarSize => isLarge ? 36.0 : (isCompact ? 30.0 : 34.0);

  // --- 输入框协调 ---
  
  double get inputBarHeight => isLarge ? 56.0 : (isCompact ? 48.0 : 52.0);
  double get inputFontSize => bodyFontSize;
  double get inputBarRadius => isLarge ? 28.0 : (isCompact ? 22.0 : 26.0);
  double get inputBarSidePadding => isLarge ? 24.0 : (isCompact ? 10.0 : 16.0);
  double get sendButtonSize => isLarge ? 44.0 : (isCompact ? 38.0 : 42.0);

  // --- 侧边栏协调 ---
  
  double get sidebarWidth => isLarge ? 320.0 : 280.0;
}
