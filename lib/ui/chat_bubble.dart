import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../core/models.dart';
import '../core/bubble_color_provider.dart';

class ChatBubble extends StatefulWidget {
  final ChatMessage message;
  final int index;

  const ChatBubble({super.key, required this.message, this.index = 0});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutBack),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    // 延迟启动动画，产生错落效果
    Future.delayed(Duration(milliseconds: 50 * (widget.index % 5)), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.message.content));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('已复制到剪贴板'),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 80, left: 16, right: 16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bubbleColors = context.watch<BubbleColorProvider>();
    
    Color userColor = bubbleColors.userBubbleColor;
    Color aiColor = bubbleColors.aiBubbleColor;
    
    if (isDark) {
      if (_isLightColor(userColor)) {
        userColor = _darkenColor(userColor);
      }
      if (_isLightColor(aiColor)) {
        aiColor = const Color(0xFF2D2D2D);
      }
    }
    
    final bubbleColor = isUser ? userColor : aiColor;
    final textColor = _getTextColor(bubbleColor);
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
        child: Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                CircleAvatar(
                  backgroundColor: isDark ? const Color(0xFF3D3D3D) : Colors.white,
                  child: Text('AI', style: TextStyle(color: isDark ? Colors.white70 : Colors.green)),
                ),
                const SizedBox(width: 8),
              ],
              
              GestureDetector(
                onLongPress: _copyToClipboard,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  padding: const EdgeInsets.all(12),
                  constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: isDark ? Colors.black26 : Colors.black12, 
                        blurRadius: 2, 
                        offset: const Offset(0, 1)
                      )
                    ],
                  ),
                  child: isUser 
                    ? SelectableText(
                        widget.message.content, 
                        style: TextStyle(color: textColor, fontSize: 16),
                      )
                    : MarkdownBody(
                        data: widget.message.content,
                        selectable: true,
                        styleSheet: MarkdownStyleSheet(
                          p: TextStyle(fontSize: 16, height: 1.5, color: textColor),
                        ),
                      ),
                ),
              ),
              
              if (isUser) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  backgroundColor: isDark ? const Color(0xFF3D3D3D) : const Color(0xFFE0E0E0),
                  child: Icon(Icons.person, color: isDark ? Colors.white70 : Colors.grey),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  bool _isLightColor(Color color) {
    return color.computeLuminance() > 0.5;
  }

  Color _darkenColor(Color color) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withLightness((hsl.lightness * 0.6).clamp(0.0, 1.0)).toColor();
  }

  Color _getTextColor(Color backgroundColor) {
    return backgroundColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}
