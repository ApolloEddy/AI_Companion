import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_engine.dart';
import 'chat_bubble.dart';
import 'settings_screen.dart';
import 'widgets/ambient_background.dart';
import 'widgets/glass_input_bar.dart';
import 'widgets/modern_sidebar.dart';
import 'utils/ui_adapter.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _shouldScrollToBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels < 100) {
      final engine = context.read<AppEngine>();
      if (engine.hasMoreHistory && !engine.isLoadingHistory) {
        // 【FIX】记录加载前的滚动位置和最大滚动范围
        final scrollPositionBefore = _scrollController.position.pixels;
        final maxExtentBefore = _scrollController.position.maxScrollExtent;
        
        engine.loadMoreHistory().then((_) {
          if (_scrollController.hasClients) {
            // 计算新增内容的高度差
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (_scrollController.hasClients) {
                final maxExtentAfter = _scrollController.position.maxScrollExtent;
                final addedHeight = maxExtentAfter - maxExtentBefore;
                
                // 保持相对位置：新位置 = 旧位置 + 新增高度
                _scrollController.jumpTo(scrollPositionBefore + addedHeight);
              }
            });
          }
        });
      }
    }
    
    if (_scrollController.hasClients) {
      final isAtBottom = _scrollController.position.pixels >= 
          _scrollController.position.maxScrollExtent - 100;
      _shouldScrollToBottom = isAtBottom;
    }
  }

  void _scrollToBottom({bool force = false}) {
    if (_scrollController.hasClients && (force || _shouldScrollToBottom)) {
      if (force) _shouldScrollToBottom = true;
      
      Future.delayed(const Duration(milliseconds: 50), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent + 100,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<AppEngine>();
    
    // 【FIX】等待引擎初始化完成，防止 LateInitializationError
    if (!engine.isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ui = UIAdapter(context);
    final aiName = engine.personaConfig['name'] ?? 'April';
    
    // 获取情绪状态用于背景
    final emotionMap = engine.isInitialized ? engine.emotion : {};
    final valence = (emotionMap['valence'] as num?)?.toDouble() ?? 0.0;
    final arousal = (emotionMap['arousal'] as num?)?.toDouble() ?? 0.5;
    
    // 消息更新时自动滚动到底部
    if (engine.messages.isNotEmpty && _shouldScrollToBottom) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return Scaffold(
      backgroundColor: Colors.transparent, // 【Research-Grade】透明背景以显示 AmbientBackground
      drawer: const ModernSideBar(),
      extendBodyBehindAppBar: true,
      
      // 玻璃效果 AppBar
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        flexibleSpace: ClipRRect(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              color: isDark 
                  ? Colors.black.withOpacity(0.3)
                  : Colors.white.withOpacity(0.3),
            ),
          ),
        ),
        leading: Builder(
          builder: (context) => IconButton(
            icon: Icon(Icons.menu, color: isDark ? Colors.white : Colors.black87),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: engine.isLoading 
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(aiName, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: ui.titleFontSize)),
                const SizedBox(width: 8),
                _buildTypingIndicator(isDark),
              ],
            )
          : Text(aiName, style: TextStyle(color: isDark ? Colors.white : Colors.black87, fontSize: ui.titleFontSize)),
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: isDark ? Colors.white : Colors.black87),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          )
        ],
      ),
      
      // Stack 布局：背景 -> 聊天列表 -> 输入框
      body: Stack(
        children: [
          // Layer 0: 动态渐变背景
          Positioned.fill(
            child: AmbientBackground(
              valence: valence,
              arousal: arousal,
              intimacy: engine.intimacy, // 【Research-Grade】注入亲密度
              isDarkMode: isDark,
            ),
          ),
          
          // Layer 1: 聊天消息列表
          Positioned.fill(
            child: Column(
              children: [
                // 为 AppBar 留出空间
                SizedBox(height: MediaQuery.of(context).padding.top + kToolbarHeight),
                
                Expanded(
                  child: ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(
                      left: 16, 
                      right: 16, 
                      top: 8,
                      bottom: 100, // 为底部输入框留出空间
                    ),
                    itemCount: engine.messages.length + 
                        (engine.hasMoreHistory ? 1 : 0),
                    itemBuilder: (context, index) {
                      // 顶部加载历史指示器
                      if (engine.hasMoreHistory && index == 0) {
                        return _buildLoadMoreIndicator(engine);
                      }
                      
                      final msgIndex = engine.hasMoreHistory ? index - 1 : index;
                      
                      if (msgIndex < engine.messages.length) {
                        return ChatBubble(
                          message: engine.messages[msgIndex],
                          index: msgIndex,
                        );
                      }
                      
                      return const SizedBox.shrink();
                    },
                  ),
                ),
                // 【已迁移】此处原有 ThoughtBubble 已移至侧边栏
              ],
            ),
          ),
          


          // Layer 2: 浮动玻璃输入框
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: GlassInputBar(
              controller: _controller,
              onSend: () => _send(context),
              isDarkMode: isDark,
            ),
          ),
        ],
      ),
    );
  }

  /// 构建流动波浪感输入状态指示器
  Widget _buildTypingIndicator(bool isDark) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (index) {
        return _FlowingDot(index: index, isDark: isDark);
      }),
    );
  }

  Widget _buildLoadMoreIndicator(AppEngine engine) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      alignment: Alignment.center,
      child: engine.isLoadingHistory
          ? const SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Color(0xFF07C160),
              ),
            )
          : TextButton(
              onPressed: () => engine.loadMoreHistory(),
              child: Text(
                '加载更多历史',
                style: TextStyle(color: Colors.grey.shade600),
              ),
            ),
    );
  }

  void _send(BuildContext context) {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    
    // 发送消息时强制滚动到底部
    _scrollToBottom(force: true);
    context.read<AppEngine>().sendMessage(text);
    _controller.clear();
    
    // 发送后再次滚动确保看到最新消息
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) _scrollToBottom(force: true);
    });
  }
}

/// 发光流动圆点组件
class _FlowingDot extends StatefulWidget {
  final int index;
  final bool isDark;
  const _FlowingDot({required this.index, required this.isDark});

  @override
  State<_FlowingDot> createState() => _FlowingDotState();
}

class _FlowingDotState extends State<_FlowingDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _animation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 1.0, end: 1.6).chain(CurveTween(curve: Curves.easeInOut)), 
        weight: 50
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.6, end: 1.0).chain(CurveTween(curve: Curves.easeInOut)), 
        weight: 50
      ),
    ]).animate(_controller);

    // 延迟启动以形成波浪感
    Future.delayed(Duration(milliseconds: widget.index * 200), () {
      if (mounted) _controller.repeat();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        final double value = _animation.value;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 5,
          height: 5,
          transform: Matrix4.identity()..scale(value),
          transformAlignment: Alignment.center,
          decoration: BoxDecoration(
            color: (widget.isDark ? Colors.white : const Color(0xFFD87C00))
                .withValues(alpha: 0.3 + (value - 1.0) * 0.7),
            shape: BoxShape.circle,
            boxShadow: widget.isDark && value > 1.3 ? [
              BoxShadow(
                color: Colors.white.withValues(alpha: 0.2),
                blurRadius: 4,
                spreadRadius: 1,
              )
            ] : null,
          ),
        );
      },
    );
  }
}
