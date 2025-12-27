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
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFFFB74D), // 统一使用琥珀色种子
                brightness: Brightness.light,
                primary: const Color(0xFFD87C00),       // 亮色模式下使用深琥珀色提升对比度
                secondary: const Color(0xFFE65100),     // 次要强调色
                surface: const Color(0xFFFFFBF5),        // 奶油白背景
                onSurface: Colors.black,                 // 纯黑文字
                onSurfaceVariant: Colors.black87,        // 高对比度次要文字
              ),
              fontFamily: fontFamily,
              fontFamilyFallback: const ['Microsoft YaHei', 'PingFang SC', 'sans-serif'],
              scaffoldBackgroundColor: const Color(0xFFFFFBF5),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFFF5F0E8),
                foregroundColor: Colors.black,
                elevation: 0,
                titleTextStyle: TextStyle(
                  color: Colors.black,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              textTheme: const TextTheme(
                bodyLarge: TextStyle(color: Colors.black),
                bodyMedium: TextStyle(color: Colors.black),
                bodySmall: TextStyle(color: Colors.black87),
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

            // 夜间主题 - 温暖舒适风格
            darkTheme: ThemeData(
              useMaterial3: true,
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFFFFB74D),
                brightness: Brightness.dark,
                primary: const Color(0xFFFFB74D),
                secondary: const Color(0xFFFFCC80),
                surface: const Color(0xFF1C1B1F),
                onSurface: const Color(0xFFE8E0D5),
                onSurfaceVariant: const Color(0xFFB8AFA6),
              ),
              fontFamily: fontFamily,
              fontFamilyFallback: const ['Microsoft YaHei', 'PingFang SC', 'sans-serif'],
              scaffoldBackgroundColor: const Color(0xFF16141A),
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

            builder: (context, child) {
              // 注入 AnimatedTheme 以实现主题色缓慢切换动画
              final theme = Theme.of(context);
              return AnimatedTheme(
                data: theme,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut,
                child: child!,
              );
            },
            home: const MainScreen(),
          );
        },
      ),
    );
  }
}

