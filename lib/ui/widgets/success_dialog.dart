import 'dart:async';
import 'package:flutter/material.dart';

/// 通用成功提示弹窗 (带动画)
class SuccessDialog extends StatelessWidget {
  final String message;

  const SuccessDialog({super.key, required this.message});

  /// 显示静态方法
  static void show(BuildContext context, String message, {Duration? duration}) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) {
        // 自动关闭
        Future.delayed(duration ?? const Duration(milliseconds: 1200), () {
          if (context.mounted && Navigator.canPop(context)) {
            Navigator.of(context).pop();
          }
        });
        return SuccessDialog(message: message);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark 
              ? const Color(0xFF2A2A2A) 
              : Colors.white,
          borderRadius: BorderRadius.circular(20), // 圆角加大
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 1.0),
              duration: const Duration(milliseconds: 500), // 动画稍慢更有质感
              curve: Curves.elasticOut,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: value,
                  child: Container(
                    width: 72, // 增大图标区域
                    height: 72,
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center( // 确保图标居中
                      child: Icon(
                        Icons.check_rounded,
                        color: Colors.green,
                        size: 48, // 增大图标
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              message,
              style: TextStyle(
                fontSize: 16, // 增大字体
                fontWeight: FontWeight.w600,
                color: Theme.of(context).brightness == Brightness.dark 
                    ? Colors.white.withValues(alpha: 0.9) 
                    : Colors.black.withValues(alpha: 0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
