import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_engine.dart';
import 'chat_bubble.dart';
import 'settings_screen.dart';
import 'app_drawer.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _shouldScrollToBottom = true;
  
  // 打字指示器动画
  late AnimationController _typingController;
  late Animation<double> _typingAnimation;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    
    _typingController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);
    
    _typingAnimation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _typingController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _controller.dispose();
    _typingController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients &&
        _scrollController.position.pixels < 100) {
      final engine = context.read<AppEngine>();
      if (engine.hasMoreHistory && !engine.isLoadingHistory) {
        final beforeCount = engine.messages.length;
        engine.loadMoreHistory().then((_) {
          final afterCount = engine.messages.length;
          final addedCount = afterCount - beforeCount;
          if (addedCount > 0 && _scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.pixels + addedCount * 80.0
            );
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

  void _scrollToBottom() {
    if (_scrollController.hasClients && _shouldScrollToBottom) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent + 100,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<AppEngine>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    if (engine.messages.isNotEmpty && _shouldScrollToBottom && !engine.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
    }

    return Scaffold(
      drawer: const AppDrawer(),
      
      appBar: AppBar(
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () => Scaffold.of(context).openDrawer(),
          ),
        ),
        title: Text(engine.personaConfig['name'] ?? '小悠'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
          )
        ],
      ),
      
      body: Column(
        children: [
          Expanded(
            child: Container(
              color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF0F0F0),
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.all(16),
                itemCount: engine.messages.length + 
                    (engine.hasMoreHistory ? 1 : 0) + 
                    (engine.isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  // 顶部加载历史指示器
                  if (engine.hasMoreHistory && index == 0) {
                    return _buildLoadMoreIndicator(engine);
                  }
                  
                  final msgIndex = engine.hasMoreHistory ? index - 1 : index;
                  
                  // 底部打字指示器
                  if (engine.isLoading && msgIndex == engine.messages.length) {
                    return _buildTypingIndicator(isDark);
                  }
                  
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
          ),
             
          // 输入栏
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
               color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFFF5F5F7),
               border: Border(top: BorderSide(color: isDark ? Colors.white12 : Colors.black12)),
               boxShadow: [
                 BoxShadow(
                   color: isDark ? Colors.black26 : Colors.black12,
                   blurRadius: 4,
                   offset: const Offset(0, -2),
                 ),
               ],
            ),
            child: SafeArea(
              top: false,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF3D3D3D) : Colors.white,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: TextField(
                        controller: _controller,
                        style: TextStyle(color: isDark ? Colors.white : Colors.black),
                        decoration: InputDecoration(
                          hintText: '发送消息...',
                          hintStyle: TextStyle(color: isDark ? Colors.grey : Colors.black45),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        maxLines: 4,
                        minLines: 1,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(context),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedScale(
                    scale: engine.isLoading ? 0.8 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: IconButton(
                      icon: Icon(
                        engine.isLoading ? Icons.hourglass_empty : Icons.send_rounded, 
                        color: const Color(0xFF07C160), 
                        size: 32
                      ),
                      onPressed: engine.isLoading ? null : () => _send(context),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
              child: const Text(
                '加载更多历史',
                style: TextStyle(color: Colors.grey),
              ),
            ),
    );
  }

  Widget _buildTypingIndicator(bool isDark) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            backgroundColor: isDark ? const Color(0xFF3D3D3D) : Colors.white,
            child: Text('AI', style: TextStyle(color: isDark ? Colors.white70 : Colors.green)),
          ),
          const SizedBox(width: 8),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D2D2D) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: isDark ? Colors.black26 : Colors.black12,
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) => 
                AnimatedBuilder(
                  animation: _typingAnimation,
                  builder: (context, child) {
                    return Container(
                      margin: EdgeInsets.only(left: i == 0 ? 0 : 4),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: Color.lerp(
                          Colors.grey.shade400,
                          const Color(0xFF07C160),
                          _typingAnimation.value * (1 - i * 0.2),
                        ),
                        shape: BoxShape.circle,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _send(BuildContext context) {
    final text = _controller.text;
    if (text.trim().isEmpty) return;
    
    _shouldScrollToBottom = true;
    context.read<AppEngine>().sendMessage(text);
    _controller.clear();
    
    // 让键盘保持打开，方便连续输入
    FocusScope.of(context).unfocus();
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted) FocusScope.of(context).requestFocus(FocusNode());
    });
  }
}
