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

  @override
  Widget build(BuildContext context) {
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
            
            // 日间主题
            theme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF07C160),
                brightness: Brightness.light,
              ),
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFFF5F5F5),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFFEDEDED),
                foregroundColor: Colors.black,
                elevation: 0,
              ),
            ),
            
            // 夜间主题
            darkTheme: ThemeData(
              colorScheme: ColorScheme.fromSeed(
                seedColor: const Color(0xFF1AAD19),
                brightness: Brightness.dark,
              ),
              useMaterial3: true,
              scaffoldBackgroundColor: const Color(0xFF1E1E1E),
              appBarTheme: const AppBarTheme(
                backgroundColor: Color(0xFF2D2D2D),
                foregroundColor: Colors.white,
                elevation: 0,
              ),
            ),
            
            home: const MainScreen(),
          );
        },
      ),
    );
  }
}
