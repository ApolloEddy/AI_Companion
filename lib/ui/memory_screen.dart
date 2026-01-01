import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_engine.dart';
import '../core/memory/fact_store.dart';
import 'widgets/success_dialog.dart';

/// MemoryManagerScreen - 用户记忆管理界面
/// 
/// 【Phase 2】用户可以查看、确认、拒绝 AI 推断的事实
/// 设计风格：沿用 settings_screen.dart 的 Amber/Cozy 主题
class MemoryManagerScreen extends StatefulWidget {
  const MemoryManagerScreen({super.key});

  @override
  State<MemoryManagerScreen> createState() => _MemoryManagerScreenState();
}

class _MemoryManagerScreenState extends State<MemoryManagerScreen> {
  static const accentColor = Color(0xFFFFB74D);
  
  @override
  Widget build(BuildContext context) {
    final engine = context.watch<AppEngine>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final facts = engine.factStore.getAllFacts();
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
      appBar: _buildAppBar(isDark),
      body: facts.isEmpty 
          ? _buildEmptyState(isDark)
          : _buildFactList(facts, engine, isDark),
    );
  }

  PreferredSizeWidget _buildAppBar(bool isDark) {
    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            color: isDark 
                ? Colors.black.withValues(alpha: 0.3)
                : Colors.white.withValues(alpha: 0.7),
          ),
        ),
      ),
      title: Hero(
        tag: 'memory_title',
        child: Text(
          '记忆管理',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
      actions: [
        IconButton(
          icon: const Icon(Icons.help_outline),
          tooltip: '帮助',
          onPressed: () => _showHelpDialog(isDark),
        ),
      ],
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.memory_outlined,
            size: 64,
            color: isDark ? Colors.white24 : Colors.black26,
          ),
          const SizedBox(height: 16),
          Text(
            '暂无记忆数据',
            style: TextStyle(
              fontSize: 18,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '与 AI 对话时，系统会自动学习你的信息',
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFactList(Map<String, FactEntry> facts, AppEngine engine, bool isDark) {
    final sortedEntries = facts.entries.toList()
      ..sort((a, b) {
        // 按状态排序：verified > active > rejected
        final statusOrder = {FactStatus.verified: 0, FactStatus.active: 1, FactStatus.rejected: 2};
        final statusCompare = statusOrder[a.value.status]!.compareTo(statusOrder[b.value.status]!);
        if (statusCompare != 0) return statusCompare;
        // 同状态按时间降序
        return b.value.updatedAt.compareTo(a.value.updatedAt);
      });
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: sortedEntries.length,
      itemBuilder: (context, index) {
        final entry = sortedEntries[index];
        return _buildFactCard(entry.key, entry.value, engine, isDark);
      },
    );
  }

  Widget _buildFactCard(String key, FactEntry fact, AppEngine engine, bool isDark) {
    final statusColor = _getStatusColor(fact.status);
    final statusLabel = _getStatusLabel(fact.status);
    final isRejected = fact.status == FactStatus.rejected;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252229) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isRejected 
              ? Colors.red.withValues(alpha: 0.3)
              : (isDark ? accentColor.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.2)),
        ),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Opacity(
        opacity: isRejected ? 0.6 : 1.0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题行：类型 + 状态标签
              Row(
                children: [
                  Icon(
                    _getFactIcon(key),
                    size: 18,
                    color: accentColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getFactLabel(key),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // 事实内容
              Text(
                fact.value,
                style: TextStyle(
                  fontSize: 16,
                  color: isDark ? Colors.white : Colors.black87,
                  decoration: isRejected ? TextDecoration.lineThrough : null,
                ),
              ),
              
              const SizedBox(height: 8),
              
              // 元信息行
              Row(
                children: [
                  Icon(
                    Icons.access_time,
                    size: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _formatTime(fact.updatedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(
                    Icons.psychology_outlined,
                    size: 12,
                    color: isDark ? Colors.white38 : Colors.black38,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '置信度 ${(fact.confidence * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 12),
              
              // 操作按钮行
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (fact.status != FactStatus.verified)
                    _buildActionButton(
                      icon: Icons.check_circle_outline,
                      label: '确认',
                      color: Colors.green,
                      onTap: () => _verifyFact(engine, key),
                    ),
                  if (fact.status != FactStatus.rejected) ...[
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.cancel_outlined,
                      label: '拒绝',
                      color: Colors.red,
                      onTap: () => _rejectFact(engine, key),
                    ),
                  ],
                  if (fact.status == FactStatus.rejected) ...[
                    const SizedBox(width: 8),
                    _buildActionButton(
                      icon: Icons.restore,
                      label: '恢复',
                      color: Colors.blue,
                      onTap: () => _activateFact(engine, key),
                    ),
                  ],
                  const SizedBox(width: 8),
                  _buildActionButton(
                    icon: Icons.delete_outline,
                    label: '删除',
                    color: Colors.grey,
                    onTap: () => _deleteFact(engine, key),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // 操作方法
  Future<void> _verifyFact(AppEngine engine, String key) async {
    await engine.factStore.verifyFact(key);
    setState(() {});
    SuccessDialog.show(context, '已确认：此信息将被优先保留');
  }

  Future<void> _rejectFact(AppEngine engine, String key) async {
    await engine.factStore.rejectFact(key);
    setState(() {});
    SuccessDialog.show(context, '已拒绝：此信息将不再出现在 AI 上下文中');
  }

  Future<void> _activateFact(AppEngine engine, String key) async {
    await engine.factStore.activateFact(key);
    setState(() {});
    SuccessDialog.show(context, '已恢复');
  }

  Future<void> _deleteFact(AppEngine engine, String key) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认删除'),
        content: const Text('删除后将无法恢复，确定要删除吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    
    if (confirm == true) {
      await engine.factStore.removeFact(key);
      setState(() {});
      SuccessDialog.show(context, '已删除');
    }
  }



  void _showHelpDialog(bool isDark) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.help_outline, color: accentColor),
            SizedBox(width: 8),
            Text('记忆管理说明'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('• 活跃：AI 会在对话中使用此信息'),
            SizedBox(height: 8),
            Text('• 已确认：你已验证此信息正确，AI 不会覆盖'),
            SizedBox(height: 8),
            Text('• 已拒绝：此信息不会出现在 AI 上下文中'),
            SizedBox(height: 16),
            Text('提示：确认正确的信息可以让 AI 更好地记住你'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('了解了'),
          ),
        ],
      ),
    );
  }

  // 辅助方法
  Color _getStatusColor(FactStatus status) {
    switch (status) {
      case FactStatus.active:
        return Colors.blue;
      case FactStatus.verified:
        return Colors.green;
      case FactStatus.rejected:
        return Colors.red;
    }
  }

  String _getStatusLabel(FactStatus status) {
    switch (status) {
      case FactStatus.active:
        return '活跃';
      case FactStatus.verified:
        return '已确认';
      case FactStatus.rejected:
        return '已拒绝';
    }
  }

  IconData _getFactIcon(String key) {
    if (key.contains('occupation') || key.contains('role')) return Icons.work_outline;
    if (key.contains('origin') || key.contains('location')) return Icons.location_on_outlined;
    if (key.contains('status')) return Icons.flag_outlined;
    if (key.contains('goal')) return Icons.track_changes_outlined;
    if (key.contains('preference')) return Icons.favorite_outline;
    if (key.contains('name')) return Icons.person_outline;
    if (key.contains('age')) return Icons.cake_outlined;
    return Icons.info_outline;
  }

  String _getFactLabel(String key) {
    if (key.contains('occupation') || key.contains('role')) return '身份/职业';
    if (key.contains('origin') || key.contains('location')) return '籍贯/所在地';
    if (key.contains('current_status')) return '当前状态';
    if (key.contains('goal')) return '目标';
    if (key.contains('preference')) return '偏好';
    if (key.contains('name')) return '姓名';
    if (key.contains('age')) return '年龄';
    return key;
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes}分钟前';
    if (diff.inDays < 1) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return '${time.month}/${time.day}';
  }
}
