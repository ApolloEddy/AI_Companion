import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_engine.dart';
import '../core/provider/theme_provider.dart';
import '../core/provider/bubble_color_provider.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _characterController;
  late TextEditingController _interestsController;
  String _selectedGender = '女性';
  bool _isEditing = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _ageController = TextEditingController();
    _characterController = TextEditingController();
    _interestsController = TextEditingController();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _characterController.dispose();
    _interestsController.dispose();
    super.dispose();
  }

  void _loadPersonaFromEngine(AppEngine engine) {
    final persona = engine.personaConfig;
    _nameController.text = persona['name'] ?? '小悠';
    _ageController.text = persona['age'] ?? '';
    _characterController.text = persona['character'] ?? '';
    _interestsController.text = persona['interests'] ?? '';
    _selectedGender = persona['gender'] ?? '女性';
  }

  void _savePersona(AppEngine engine) {
    engine.updatePersonaConfig({
      'name': _nameController.text.trim().isEmpty ? '小悠' : _nameController.text.trim(),
      'age': _ageController.text.trim(),
      'gender': _selectedGender,
      'character': _characterController.text.trim(),
      'interests': _interestsController.text.trim(),
    });
    setState(() => _isEditing = false);
    // SnackBar 顶部显示，缩短时间
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('人设已保存'),
        duration: Duration(milliseconds: 800),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _formatTokenCount(int tokens) {
    if (tokens >= 1000000) {
      return '${(tokens / 1000000).toStringAsFixed(1)}M';
    } else if (tokens >= 1000) {
      return '${(tokens / 1000).toStringAsFixed(1)}K';
    }
    return tokens.toString();
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<AppEngine>();
    final themeProvider = context.watch<ThemeProvider>();
    final bubbleColors = context.watch<BubbleColorProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    final emotion = engine.isInitialized ? engine.persona.emotion : {};
    final intimacy = engine.isInitialized ? engine.persona.intimacy : 0.0;
    final interactions = engine.isInitialized ? engine.persona.interactions : 0;

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2D2D2D) : const Color(0xFF07C160),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white,
                  child: Text('AI', style: TextStyle(fontSize: 24, color: Colors.green)),
                ),
                const SizedBox(height: 12),
                Text(
                  engine.personaConfig['name'] ?? '小悠', 
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)
                ),
                Text(
                  'Token: ${_formatTokenCount(engine.totalTokensUsed)}', 
                  style: TextStyle(color: Colors.white.withAlpha(200), fontSize: 14)
                ),
              ],
            ),
          ),
          
          // ========== 人设编辑器 ==========
          ExpansionTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('人设配置'),
            initiallyExpanded: _isEditing,
            onExpansionChanged: (expanded) {
              if (expanded && !_isEditing) _loadPersonaFromEngine(engine);
              setState(() => _isEditing = expanded);
            },
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Column(
                  children: [
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: '名字', isDense: true),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _selectedGender,
                      decoration: const InputDecoration(labelText: '性别', isDense: true),
                      items: const [
                        DropdownMenuItem(value: '女性', child: Text('女性')),
                        DropdownMenuItem(value: '男性', child: Text('男性')),
                        DropdownMenuItem(value: '中性', child: Text('中性')),
                      ],
                      onChanged: (v) => setState(() => _selectedGender = v ?? '女性'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _ageController,
                      decoration: const InputDecoration(labelText: '年龄设定', isDense: true),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _characterController,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: '性格描述', isDense: true),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _interestsController,
                      decoration: const InputDecoration(labelText: '兴趣爱好', isDense: true),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _savePersona(engine),
                        child: const Text('保存人设'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const Divider(),
          
          // ========== 气泡颜色 ==========
          ExpansionTile(
            leading: const Icon(Icons.color_lens_outlined),
            title: const Text('气泡颜色'),
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('用户气泡', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    _buildColorPicker(
                      bubbleColors.userBubbleColor,
                      (c) => bubbleColors.setUserBubbleColor(c),
                    ),
                    const SizedBox(height: 16),
                    const Text('AI 气泡', style: TextStyle(fontSize: 12, color: Colors.grey)),
                    const SizedBox(height: 8),
                    _buildColorPicker(
                      bubbleColors.aiBubbleColor,
                      (c) => bubbleColors.setAiBubbleColor(c),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: () => bubbleColors.resetToDefault(),
                      child: const Text('恢复默认'),
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const Divider(),
          
          // ========== 状态信息 ==========
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('实时状态', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          _buildStatTile('情绪象限', emotion['quadrant'] ?? '平静'),
          _buildStatTile('情绪强度', emotion['intensity'] ?? '平和'),
          _buildStatTile('亲密度', '${(intimacy * 100).toStringAsFixed(0)}%'),
          _buildStatTile('互动次数', interactions.toString()),
          _buildStatTile('已用 Token', _formatTokenCount(engine.totalTokensUsed)),
          
          const Divider(),
          
          // ========== 主题切换 ==========
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text('主题设置', style: TextStyle(fontSize: 12, color: Colors.grey)),
          ),
          RadioListTile<ThemeMode>(
            title: const Text('☀️ 日间'),
            value: ThemeMode.light,
            groupValue: themeProvider.themeMode,
            onChanged: (v) => themeProvider.setTheme(v!),
            dense: true,
          ),
          RadioListTile<ThemeMode>(
            title: const Text('🌙 夜间'),
            value: ThemeMode.dark,
            groupValue: themeProvider.themeMode,
            onChanged: (v) => themeProvider.setTheme(v!),
            dense: true,
          ),
          RadioListTile<ThemeMode>(
            title: const Text('🔄 跟随系统'),
            value: ThemeMode.system,
            groupValue: themeProvider.themeMode,
            onChanged: (v) => themeProvider.setTheme(v!),
            dense: true,
          ),
          
          const Divider(),
          
          // ========== 待发送消息队列 ==========
          _buildPendingMessagesSection(engine),
          
          ListTile(
            leading: const Icon(Icons.delete_outline),
            title: const Text('清空聊天记录'),
            onTap: () {
              showDialog(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('确认清空？'),
                  content: const Text('所有聊天记录将被删除'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
                    TextButton(
                      onPressed: () {
                        engine.clearChatHistory();
                        Navigator.pop(ctx);
                        Navigator.pop(context);
                      },
                      child: const Text('确认', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildColorPicker(Color currentColor, Function(Color) onSelect) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: BubbleColorProvider.presetColors.map((color) {
        final isSelected = currentColor.toARGB32() == color.toARGB32();
        return GestureDetector(
          onTap: () => onSelect(color),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: isSelected ? Colors.blue : Colors.grey.shade300,
                width: isSelected ? 3 : 1,
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildStatTile(String label, String value) {
    return ListTile(
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      trailing: Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  /// 待发送消息队列 (主动消息)
  Widget _buildPendingMessagesSection(AppEngine engine) {
    // 获取待发送消息列表
    final pendingMessages = engine.pendingMessages;
    
    if (pendingMessages.isEmpty) {
      return const SizedBox.shrink();
    }
    
    return ExpansionTile(
      leading: const Icon(Icons.schedule_send),
      title: Row(
        children: [
          const Text('待发送消息'),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${pendingMessages.length}',
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
        ],
      ),
      initiallyExpanded: false,  // 默认收起
      children: [
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: pendingMessages.length,
          itemBuilder: (context, index) {
            final msg = pendingMessages[index];
            return ListTile(
              dense: true,
              leading: Icon(
                Icons.access_time,
                size: 18,
                color: Colors.grey.shade600,
              ),
              title: Text(
                msg.content.length > 30 
                    ? '${msg.content.substring(0, 30)}...' 
                    : msg.content,
                style: const TextStyle(fontSize: 13),
              ),
              subtitle: Text(
                _formatScheduleTime(msg.time),
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.send, size: 18),
                onPressed: () {
                  // 立即发送该消息
                  engine.sendPendingMessageNow(index);
                },
                tooltip: '立即发送',
              ),
            );
          },
        ),
        if (pendingMessages.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextButton(
              onPressed: () => engine.clearPendingMessages(),
              child: const Text('清空所有', style: TextStyle(color: Colors.red)),
            ),
          ),
      ],
    );
  }

  String _formatScheduleTime(DateTime time) {
    final now = DateTime.now();
    final diff = time.difference(now);
    
    if (diff.isNegative) {
      return '待发送';
    } else if (diff.inMinutes < 60) {
      return '${diff.inMinutes} 分钟后';
    } else if (diff.inHours < 24) {
      return '${diff.inHours} 小时后';
    } else {
      return '${time.month}/${time.day} ${time.hour}:${time.minute.toString().padLeft(2, '0')}';
    }
  }
}
