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

  void _scrollToBottom({bool force = false}) {
    if (_scrollController.hasClients && (force || _shouldScrollToBottom)) {
      // 强制更新 shouldScrollToBottom 状态
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final aiName = engine.personaConfig['name'] ?? 'April';
    
    // 消息更新时自动滚动到底部
    if (engine.messages.isNotEmpty && _shouldScrollToBottom) {
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
        title: engine.isLoading 
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(aiName),
                const SizedBox(width: 8),
                Text(
                  '正在输入...',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            )
          : Text(aiName),
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
                  // 始终可用的发送按钮，支持连续发送多条消息
                  IconButton(
                    icon: const Icon(
                      Icons.send_rounded, 
                      color: Color(0xFF07C160), 
                      size: 32
                    ),
                    onPressed: () => _send(context),
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
