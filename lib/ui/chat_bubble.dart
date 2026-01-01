import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../core/app_engine.dart';
import '../core/model/chat_message.dart';
import '../core/provider/bubble_color_provider.dart';
import 'widgets/success_dialog.dart';
import 'utils/ui_adapter.dart';

class ChatBubble extends StatefulWidget {
  final ChatMessage message;
  final int index;

  const ChatBubble({super.key, required this.message, this.index = 0});

  @override
  State<ChatBubble> createState() => _ChatBubbleState();
}

class _ChatBubbleState extends State<ChatBubble> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    // 滑动动画
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );
    
    // 淡入动画
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    
    // 弹簧缩放动画
    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller, 
        curve: const _SpringCurve(damping: 12, stiffness: 180),
      ),
    );
    
    // 延迟启动动画
    Future.delayed(Duration(milliseconds: 30 * (widget.index % 5)), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _showActionMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.copy_rounded),
              title: const Text('复制内容'),
              onTap: () {
                Navigator.pop(context);
                _copyToClipboard();
              },
            ),
            if (!widget.message.isUser && widget.message.fullPrompt != null)
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('查看交互详情'),
                subtitle: Text('Token 消耗: ${widget.message.tokensUsed ?? "未知"}'),
                onTap: () {
                  Navigator.pop(context);
                  _showDetailsDialog();
                },
              ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _showDetailsDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('交互详情'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('消息 ID', widget.message.id),
                _buildInfoRow('Token 消耗', '${widget.message.tokensUsed ?? "未知"}'),
                const SizedBox(height: 16),
                const Text('生成使用的完整 Prompt:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: SelectableText(
                    widget.message.fullPrompt ?? '无 Prompt 记录',
                    style: TextStyle(
                      fontSize: 12,
                      fontFamily: 'monospace',
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('好的'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ],
      ),
    );
  }

  void _copyToClipboard() {
    Clipboard.setData(ClipboardData(text: widget.message.content));
    Clipboard.setData(ClipboardData(text: widget.message.content));
    SuccessDialog.show(context, '已复制到剪贴板');
  }

  /// 格式化消息时间
  String _formatMessageTime(DateTime time) {
    final now = DateTime.now();
    final isToday = time.year == now.year && 
                    time.month == now.month && 
                    time.day == now.day;
    
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    
    if (isToday) {
      return '$hour:$minute';
    } else {
      return '${time.month}/${time.day} $hour:$minute';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isUser = widget.message.isUser;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ui = UIAdapter(context);
    
    final avatarSize = ui.avatarSize;
    final fontSize = ui.bodyFontSize;
    final bubblePadding = ui.bubblePadding;
    final borderRadius = ui.bubbleRadius;
    final maxWidth = ui.bubbleMaxWidth;
    final timestampFontSize = ui.tinyFontSize;
    final isCompact = ui.isCompact;
    
    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          child: Column(
            crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              // 时间戳显示
              Padding(
                padding: EdgeInsets.only(
                  left: isUser ? 0 : avatarSize + 12,
                  right: isUser ? avatarSize + 12 : 0,
                  top: isCompact ? 6 : 8,
                  bottom: 2,
                ),
                child: Text(
                  _formatMessageTime(widget.message.time),
                  style: TextStyle(
                    fontSize: timestampFontSize,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                ),
              ),
              Align(
                alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!isUser) ...[
                      _buildAvatar(isUser: false, isDark: isDark, size: avatarSize),
                      SizedBox(width: isCompact ? 6 : 8),
                    ],
                    
                    GestureDetector(
                      onLongPress: _showActionMenu,
                      child: isUser
                          ? _buildUserBubble(isDark, context.watch<BubbleColorProvider>(), fontSize, bubblePadding, borderRadius, maxWidth)
                          : _buildAiBubble(isDark, context.watch<BubbleColorProvider>(), fontSize, bubblePadding, borderRadius, maxWidth),
                    ),
                    
                    if (isUser) ...[
                      SizedBox(width: isCompact ? 6 : 8),
                      _buildAvatar(isUser: true, isDark: isDark, size: avatarSize),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 用户气泡：渐变效果
  Widget _buildUserBubble(bool isDark, BubbleColorProvider bubbleColors, double fontSize, double padding, double radius, double maxWidth) {
    final baseColor = bubbleColors.userBubbleColor;
    
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: EdgeInsets.all(padding),
      constraints: BoxConstraints(maxWidth: maxWidth),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            baseColor,
            _shiftHue(baseColor, 15),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: baseColor.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: SelectableText(
        widget.message.content, 
        style: TextStyle(
          color: _getTextColor(baseColor), 
          fontSize: fontSize,
          height: 1.4,
        ),
        contextMenuBuilder: (context, editableTextState) {
          return _buildSimplifiedContextMenu(context, editableTextState);
        },
      ),
    );
  }

  /// 构建简化的中文右键菜单（适配 Android）
  Widget _buildSimplifiedContextMenu(
    BuildContext context, 
    EditableTextState editableTextState,
  ) {
    final List<ContextMenuButtonItem> items = [];
    final selection = editableTextState.textEditingValue.selection;
    
    // 复制
    if (!selection.isCollapsed) {
      items.add(ContextMenuButtonItem(
        label: '复制',
        onPressed: () {
          editableTextState.copySelection(SelectionChangedCause.toolbar);
        },
      ));
    }
    
    // 全选
    items.add(ContextMenuButtonItem(
      label: '全选',
      onPressed: () {
        editableTextState.selectAll(SelectionChangedCause.toolbar);
      },
    ));
    
    // 分享（仅当有选中内容时）
    if (!selection.isCollapsed) {
      items.add(ContextMenuButtonItem(
        label: '分享',
        onPressed: () {
          final text = editableTextState.textEditingValue.text.substring(
            selection.start,
            selection.end,
          );
          _shareText(text);
          editableTextState.hideToolbar();
        },
      ));
    }
    
    return AdaptiveTextSelectionToolbar.buttonItems(
      anchors: editableTextState.contextMenuAnchors,
      buttonItems: items,
    );
  }

  /// 分享文本
  void _shareText(String text) {
    // 使用 Clipboard 作为简单的分享替代
    // 实际项目可以接入 share_plus 插件
    Clipboard.setData(ClipboardData(text: text));
    // 实际项目可以接入 share_plus 插件
    Clipboard.setData(ClipboardData(text: text));
    SuccessDialog.show(context, '已复制到剪贴板，可粘贴分享');
  }

  /// AI 气泡：毛玻璃效果 + 柔和阴影
  Widget _buildAiBubble(bool isDark, BubbleColorProvider bubbleColors, double fontSize, double padding, double radius, double maxWidth) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: isDark 
                ? Colors.black.withOpacity(0.3) 
                : Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: EdgeInsets.all(padding),
            constraints: BoxConstraints(maxWidth: maxWidth),
            decoration: BoxDecoration(
              color: isDark 
                  ? Colors.white.withOpacity(0.08)
                  : Colors.white.withOpacity(0.85), // 提高亮色模式不透明度以提升对比度
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: isDark 
                    ? Colors.white.withOpacity(0.1)
                    : Colors.white.withOpacity(1.0), // 亮色模式边框纯白增强轮廓
                width: 1.5,
              ),
            ),
            child: MarkdownBody(
              data: widget.message.content,
              selectable: true,
              styleSheet: MarkdownStyleSheet(
                p: TextStyle(
                  fontSize: fontSize, 
                  height: 1.5, 
                  color: isDark ? Colors.white.withOpacity(0.9) : Colors.black, // 亮色模式使用纯黑文字
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar({required bool isUser, required bool isDark, required double size}) {
    final engine = context.read<AppEngine>();
    final avatarPath = isUser ? engine.userAvatarPath : engine.aiAvatarPath;
    
    // 优先使用自定义头像
    if (avatarPath != null) {
      final file = File(avatarPath);
      if (file.existsSync()) {
        return ClipOval(
          child: Image.file(
            file,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _buildDefaultAvatar(isUser: isUser, isDark: isDark, size: size),
          ),
        );
      }
    }
    
    // 回退到默认头像
    return _buildDefaultAvatar(isUser: isUser, isDark: isDark, size: size);
  }

  /// 默认头像（无自定义头像时使用）
  /// 【UI审计】使用首字母 + 性别颜色 (Male=Blue, Female=Pink, Neutral=Yellow)
  Widget _buildDefaultAvatar({required bool isUser, required bool isDark, required double size}) {
    final engine = context.read<AppEngine>();
    final textSize = size * 0.4;
    
    // 获取名字首字母和性别
    String firstLetter;
    String? gender;
    
    if (isUser) {
      final userName = engine.userProfile.nickname.isNotEmpty 
          ? engine.userProfile.nickname 
          : '用户';
      firstLetter = userName.isNotEmpty ? userName.substring(0, 1) : 'U';
      gender = engine.userProfile.gender;
    } else {
      final aiName = engine.personaConfig['name']?.toString() ?? 'AI';
      firstLetter = aiName.isNotEmpty ? aiName.substring(0, 1) : 'A';
      gender = engine.personaConfig['gender']?.toString();
    }
    
    // 根据性别确定颜色
    final genderLower = gender?.toLowerCase() ?? '';
    Color avatarColor;
    if (genderLower == 'male' || genderLower == 'man' || genderLower == '男' || genderLower == '男性') {
      avatarColor = Colors.blueAccent;
    } else if (genderLower == 'female' || genderLower == 'woman' || genderLower == '女' || genderLower == '女性') {
      avatarColor = Colors.pinkAccent;
    } else {
      avatarColor = Colors.amber; // 中性/未知
    }
    
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: avatarColor.withOpacity(isDark ? 0.3 : 0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: avatarColor.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Center(
        child: Text(
          firstLetter,
          style: TextStyle(
            fontSize: textSize,
            fontWeight: FontWeight.bold,
            color: avatarColor,
          ),
        ),
      ),
    );
  }

  /// 色相偏移
  Color _shiftHue(Color color, double amount) {
    final hsl = HSLColor.fromColor(color);
    return hsl.withHue((hsl.hue + amount) % 360).toColor();
  }

  Color _getTextColor(Color backgroundColor) {
    return backgroundColor.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}

/// 自定义弹簧曲线
class _SpringCurve extends Curve {
  final double damping;
  final double stiffness;

  const _SpringCurve({this.damping = 10, this.stiffness = 100});

  @override
  double transform(double t) {
    // 简化的弹簧模拟
    final decay = (-damping * t).clamp(-10.0, 0.0);
    return 1 - (1 - t) * (1 + decay.abs() * 0.1) * (1 - t * 0.5);
  }
}
