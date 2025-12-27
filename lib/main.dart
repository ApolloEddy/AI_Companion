import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/app_engine.dart';
import 'core/provider/theme_provider.dart';
import 'core/provider/bubble_color_provider.dart';
import 'ui/main_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// 获取平台特定的字体族
  String? _getFontFamily() {
    if (Platform.isWindows) {
      return 'Microsoft YaHei';  // Windows 使用微软雅黑
    }
    return null;  // Android/iOS 使用系统默认字体
  }

  @override
  Widget build(BuildContext context) {
    final fontFamily = _getFontFamily();
    
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AppEngine()..init()),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => BubbleColorProvider()),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'AI Companion',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            
            // 日间主题 - 奶油暖白高对比度
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF2E7D32),
                brightness: Brightness.light,
                primary: const Color(0xFF1B5E20),        // 深森林绿主色
                secondary: const Color(0xFF558B2F),      // 草绿辅助色
                surface: const Color(0xFFFFFBF5),        // 奶油白背景
                onSurface: const Color(0xFF1A1A1A),      // 纯黑文字
                onSurfaceVariant: const Color(0xFF37474F), // 深蓝灰次要文字
              ),
              useMaterial3: true,
              fontFamily: fontFamily,
              scaffoldBackgroundColor: const Color(0xFFFFFBF5), // 奶油白
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFFF5F0E8),       // 暖米色
                foregroundColor: Color(0xFF1A1A1A),
                elevation: 0,
                titleTextStyle: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              textTheme: const TextTheme(
                displayLarge: TextStyle(color: Color(0xFF1A1A1A), fontSize: 32),
                displayMedium: TextStyle(color: Color(0xFF1A1A1A), fontSize: 28),
                titleLarge: TextStyle(color: Color(0xFF1A1A1A), fontSize: 20, fontWeight: FontWeight.w600),
                titleMedium: TextStyle(color: Color(0xFF1A1A1A), fontSize: 16, fontWeight: FontWeight.w500),
                bodyLarge: TextStyle(color: Color(0xFF1A1A1A), fontSize: 16),
                bodyMedium: TextStyle(color: Color(0xFF2D2D2D), fontSize: 14),
                bodySmall: TextStyle(color: Color(0xFF424242), fontSize: 13),
                labelLarge: TextStyle(color: Color(0xFF1A1A1A), fontSize: 14, fontWeight: FontWeight.w500),
              ),
              cardTheme: const CardThemeData(
                color: Color(0xFFFFFDF8),
                elevation: 2,
                shadowColor: Color(0x1A000000),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
              ),
            ),

            
            // 夜间主题 - 温暖舒适风格 (Cozy/Warm AI Companion)
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFFFB74D),     // 琥珀色种子
                brightness: Brightness.dark,
                primary: const Color(0xFFFFB74D),       // 温暖琥珀主色
                secondary: const Color(0xFFFFCC80),     // 浅琥珀辅助色
                surface: const Color(0xFF1C1B1F),       // 深紫灰背景
                onSurface: const Color(0xFFE8E0D5),     // 暖白色文字
                onSurfaceVariant: const Color(0xFFB8AFA6), // 次要暖灰文字
              ),
              useMaterial3: true,
              fontFamily: fontFamily,
              scaffoldBackgroundColor: const Color(0xFF16141A), // 深海军蓝紫
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF1E1C22),
                foregroundColor: Color(0xFFE8E0D5),
                elevation: 0,
              ),
              textTheme: const TextTheme(
                bodyLarge: TextStyle(color: Color(0xFFE8E0D5)),
                bodyMedium: TextStyle(color: Color(0xFFD4C8BC)),
                bodySmall: TextStyle(color: Color(0xFFB8AFA6)),
              ),
              cardTheme: const CardThemeData(
                color: Color(0xFF252229),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(16)),
                ),
              ),
            ),

            
            home: const MainScreen(),
          );
        },
      ),
    );
  }
}

