import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_engine.dart';
import '../../core/service/prompt_logger.dart';

/// Prompt Viewer Dialog - 分层展示 L1/L2/L3 Prompt
/// 
/// 使用 TabBar 切换不同认知层的 Prompt 内容
class PromptViewerDialog extends StatefulWidget {
  final String? messageId; // 可选：指定查看某条消息的 Prompt

  const PromptViewerDialog({super.key, this.messageId});

  @override
  State<PromptViewerDialog> createState() => _PromptViewerDialogState();
}

class _PromptViewerDialogState extends State<PromptViewerDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<PromptLogEntry> _prompts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPrompts();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadPrompts() async {
    final engine = context.read<AppEngine>();
    List<PromptLogEntry> prompts;
    
    if (widget.messageId != null) {
      // 查询特定消息
      prompts = await engine.promptLogger?.getPromptsForMessage(widget.messageId!) ?? [];
    } else {
      // 查询最新消息
      prompts = await engine.promptLogger?.getLatestPrompts() ?? [];
    }
    
    if (mounted) {
      setState(() {
        _prompts = prompts;
        _isLoading = false;
      });
    }
  }

  String _getPromptContent(String layer) {
    final entry = _prompts.where((p) => p.layer == layer).firstOrNull;
    return entry?.promptContent ?? '暂无 $layer 层 Prompt 记录';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accentColor = isDark ? const Color(0xFFFFB74D) : const Color(0xFFD87C00);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: MediaQuery.of(context).size.width * 0.85,
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accentColor.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: isDark ? Colors.white12 : Colors.black12,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.psychology_outlined, color: accentColor),
                  const SizedBox(width: 12),
                  Text(
                    '认知层 Prompt 查看器',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: Icon(Icons.refresh, color: accentColor),
                    onPressed: () {
                      setState(() => _isLoading = true);
                      _loadPrompts();
                    },
                    tooltip: '刷新',
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: isDark ? Colors.white54 : Colors.black45),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // TabBar
            Container(
              decoration: BoxDecoration(
                color: isDark ? Colors.black26 : Colors.grey.shade100,
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: accentColor,
                labelColor: accentColor,
                unselectedLabelColor: isDark ? Colors.white54 : Colors.black45,
                tabs: const [
                  Tab(text: 'L1 感知'),
                  Tab(text: 'L2 决策'),
                  Tab(text: 'L3 表达'),
                ],
              ),
            ),
            
            // TabBarView
            Expanded(
              child: _isLoading
                  ? Center(
                      child: CircularProgressIndicator(color: accentColor),
                    )
                  : TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPromptTab('L1', isDark),
                        _buildPromptTab('L2', isDark),
                        _buildPromptTab('L3', isDark),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromptTab(String layer, bool isDark) {
    final content = _getPromptContent(layer);
    
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? Colors.black26 : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? Colors.white10 : Colors.black12,
          ),
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            content,
            style: TextStyle(
              fontFamily: 'Consolas, Monaco, monospace',
              fontSize: 12,
              height: 1.5,
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
