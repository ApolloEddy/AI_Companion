import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';

/// 气泡颜色管理器
class BubbleColorProvider extends ChangeNotifier {
  // 默认颜色
  Color _userBubbleColor = const Color(0xFF95EC69); // 微信绿
  Color _aiBubbleColor = Colors.white;
  
  Color get userBubbleColor => _userBubbleColor;
  Color get aiBubbleColor => _aiBubbleColor;
  
  // 预设颜色选项
  static const List<Color> presetColors = [
    Color(0xFF95EC69), // 微信绿
    Color(0xFF1AAD19), // 深绿
    Color(0xFF1890FF), // 蓝色
    Color(0xFF722ED1), // 紫色
    Color(0xFFEB2F96), // 粉色
    Color(0xFFFA8C16), // 橙色
    Color(0xFFF5222D), // 红色
    Color(0xFF52C41A), // 青绿
    Colors.white,
    Color(0xFFF0F0F0), // 浅灰
    Color(0xFF2D2D2D), // 深灰
    Color(0xFF1E1E1E), // 黑色
  ];

  BubbleColorProvider() {
    _loadColors();
  }

  Future<void> _loadColors() async {
    final prefs = await SharedPreferences.getInstance();
    
    final userColorValue = prefs.getInt(AppConfig.userBubbleColorKey);
    if (userColorValue != null) {
      _userBubbleColor = Color(userColorValue);
    }
    
    final aiColorValue = prefs.getInt(AppConfig.aiBubbleColorKey);
    if (aiColorValue != null) {
      _aiBubbleColor = Color(aiColorValue);
    }
    
    notifyListeners();
  }

  Future<void> setUserBubbleColor(Color color) async {
    _userBubbleColor = color;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConfig.userBubbleColorKey, color.toARGB32());
  }

  Future<void> setAiBubbleColor(Color color) async {
    _aiBubbleColor = color;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConfig.aiBubbleColorKey, color.toARGB32());
  }

  Future<void> resetToDefault() async {
    _userBubbleColor = const Color(0xFF95EC69);
    _aiBubbleColor = Colors.white;
    notifyListeners();
    
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConfig.userBubbleColorKey);
    await prefs.remove(AppConfig.aiBubbleColorKey);
  }
}
