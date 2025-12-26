import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_engine.dart';
import '../core/config.dart';
import '../core/provider/theme_provider.dart';
import '../core/provider/bubble_color_provider.dart';
import '../core/service/chat_export_service.dart';
import 'utils/ui_adapter.dart';

/// Research-Grade Settings Screen
/// 
/// 【设计原理】
/// - 科幻研究风格 (Sci-Fi/Research)
/// - 分组卡片布局
/// - Hero 动画过渡
/// - 完整功能：主题切换、气泡颜色、用户画像、模型参数可视化
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _occupationController = TextEditingController();
  final TextEditingController _majorController = TextEditingController();
  final TextEditingController _genderController = TextEditingController();
  String _selectedModel = AppConfig.defaultModel;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    final engine = context.read<AppEngine>();
    final profile = engine.userProfile;
    
    _nicknameController.text = profile.nickname;
    _occupationController.text = profile.occupation;
    _majorController.text = profile.major ?? '';
    _genderController.text = profile.gender ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (engine.isInitialized) {
        setState(() {
          _selectedModel = engine.currentModel;
        });
      }
    });
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _nicknameController.dispose();
    _occupationController.dispose();
    _majorController.dispose();
    _genderController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<AppEngine>();
    final themeProvider = context.watch<ThemeProvider>();
    final bubbleProvider = context.watch<BubbleColorProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : const Color(0xFFF6F8FA),
      appBar: _buildAppBar(isDark),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 主题设置卡片
          _buildSectionCard(
            title: '外观设置',
            icon: Icons.palette_outlined,
            isDark: isDark,
            children: [
              _buildThemeSelector(themeProvider, isDark),
              const SizedBox(height: 16),
              _buildBubbleColorPicker(bubbleProvider, isDark),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 模型选择卡片
          _buildSectionCard(
            title: '模型基座',
            icon: Icons.model_training,
            isDark: isDark,
            children: [
              _buildModelSelector(engine, isDark),
              const SizedBox(height: 12),
              _buildModelParamsVisualizer(engine, isDark),
            ],
          ),
          
          const SizedBox(height: 16),

          // 用户画像卡片
          _buildSectionCard(
            title: '用户画像 (PROFILE)',
            icon: Icons.person_outline,
            isDark: isDark,
            children: [
              _buildUserProfileEditor(engine, isDark),
            ],
          ),

          const SizedBox(height: 16),
          
          // 聊天记录卡片
          _buildSectionCard(
            title: '数据管理',
            icon: Icons.storage_outlined,
            isDark: isDark,
            children: [
              _buildExportButtons(engine),
              const SizedBox(height: 12),
              _buildClearHistoryButton(),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // API 配置卡片
          _buildSectionCard(
            title: 'API 配置',
            icon: Icons.key_outlined,
            isDark: isDark,
            children: [
              _buildApiKeyInput(engine, isDark),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // 版本信息
          _buildVersionInfo(engine, isDark),
        ],
      ),
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
        tag: 'settings_title',
        child: Text(
          '系统设置',
          style: TextStyle(
            color: isDark ? Colors.white : Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      iconTheme: IconThemeData(color: isDark ? Colors.white : Colors.black87),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
        ),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: Colors.cyan),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildThemeSelector(ThemeProvider themeProvider, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '主题模式',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            _buildThemeChip('浅色', ThemeMode.light, themeProvider, isDark),
            const SizedBox(width: 8),
            _buildThemeChip('深色', ThemeMode.dark, themeProvider, isDark),
            const SizedBox(width: 8),
            _buildThemeChip('跟随系统', ThemeMode.system, themeProvider, isDark),
          ],
        ),
      ],
    );
  }

  Widget _buildThemeChip(String label, ThemeMode mode, ThemeProvider provider, bool isDark) {
    final isSelected = provider.themeMode == mode;
    return GestureDetector(
      onTap: () => provider.setTheme(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.cyan.withValues(alpha: 0.2)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? Colors.cyan : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? Colors.cyan : (isDark ? Colors.white70 : Colors.black54),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildBubbleColorPicker(BubbleColorProvider bubbleProvider, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '气泡颜色',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('我的消息', style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38)),
            const SizedBox(width: 8),
            ...BubbleColorProvider.presetColors.take(6).map((color) => 
              _buildColorDot(color, bubbleProvider.userBubbleColor == color, () {
                bubbleProvider.setUserBubbleColor(color);
              }),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildColorDot(Color color, bool isSelected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected ? Colors.white : Colors.transparent,
            width: 2,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: color.withValues(alpha: 0.5),
              blurRadius: 8,
            ),
          ] : null,
        ),
        child: isSelected 
            ? const Icon(Icons.check, size: 16, color: Colors.white)
            : null,
      ),
    );
  }

  Widget _buildModelSelector(AppEngine engine, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择模型 (${_selectedModel})',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white60 : Colors.black54,
          ),
        ),
        const SizedBox(height: 8),
        ...AppConfig.availableModels.map((model) => _buildModelTile(model, engine, isDark)),
      ],
    );
  }

  Widget _buildModelTile(QwenModel model, AppEngine engine, bool isDark) {
    final isSelected = _selectedModel == model.id;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedModel = model.id);
        engine.updateModel(model.id);
        _showSnackBar('已切换到 ${model.name}');
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
              ? Colors.cyan.withValues(alpha: 0.15)
              : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? Colors.cyan : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? Colors.cyan : (isDark ? Colors.white38 : Colors.black38),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    model.name,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ),
                  Text(
                    model.desc,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),
            if (model.hasFreeQuota)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  '免费',
                  style: TextStyle(color: Colors.green, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
          ],
        ),
      ),
    );
  }

  /// 模型参数可视化
  Widget _buildModelParamsVisualizer(AppEngine engine, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.cyan.withValues(alpha: 0.1) : Colors.cyan.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.cyan.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.tune, size: 16, color: Colors.cyan.withValues(alpha: 0.8)),
              const SizedBox(width: 8),
              Text(
                '当前生成参数',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: Colors.cyan.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildParamIndicator('Temperature', '0.7', isDark),
              _buildParamIndicator('Top P', '0.8', isDark),
              _buildParamIndicator('Max Tokens', '1024', isDark),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildParamIndicator(String label, String value, bool isDark) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.cyanAccent : Colors.cyan,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white38 : Colors.black38,
          ),
        ),
      ],
    );
  }

  Widget _buildExportButtons(AppEngine engine) {
    return Row(
      children: [
        Expanded(child: _buildExportButton('JSON', Icons.code, () => _exportChat('json'))),
        const SizedBox(width: 8),
        Expanded(child: _buildExportButton('TXT', Icons.text_snippet, () => _exportChat('txt'))),
        const SizedBox(width: 8),
        Expanded(child: _buildExportButton('CSV', Icons.table_chart, () => _exportChat('csv'))),
      ],
    );
  }

  Widget _buildExportButton(String label, IconData icon, VoidCallback onTap) {
    return OutlinedButton.icon(
      onPressed: _isExporting ? null : onTap,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.cyan,
        side: const BorderSide(color: Colors.cyan),
      ),
    );
  }

  Widget _buildClearHistoryButton() {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: _showClearHistoryDialog,
        icon: const Icon(Icons.delete_outline, color: Colors.red),
        label: const Text('清空聊天记录'),
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
        ),
      ),
    );
  }

  Widget _buildApiKeyInput(AppEngine engine, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: _apiKeyController,
          decoration: InputDecoration(
            hintText: 'sk-...',
            helperText: '可选，留空使用内置 Key',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            prefixIcon: const Icon(Icons.vpn_key_outlined),
          ),
          obscureText: true,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              final key = _apiKeyController.text.trim();
              if (key.isNotEmpty) {
                engine.updateApiKey(key);
                _showSnackBar('API Key 已保存');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.cyan,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('保存 API Key'),
          ),
        ),
      ],
    );
  }

  Widget _buildUserProfileEditor(AppEngine engine, bool isDark) {
    final profile = engine.userProfile;
    return Column(
      children: [
        _buildProfileField(
          '昵称',
          _nicknameController,
          (val) => engine.updateUserProfile(profile.copyWith(nickname: val)),
          isDark,
        ),
        const SizedBox(height: 12),
        _buildProfileField(
          '职业',
          _occupationController,
          (val) => engine.updateUserProfile(profile.copyWith(occupation: val)),
          isDark,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildProfileField(
                '专业',
                _majorController,
                (val) => engine.updateUserProfile(profile.copyWith(major: val)),
                isDark,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildProfileField(
                '性别',
                _genderController,
                (val) => engine.updateUserProfile(profile.copyWith(gender: val)),
                isDark,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildProfileField(String label, TextEditingController controller, Function(String) onSave, bool isDark) {
    final ui = UIAdapter(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          onSubmitted: (val) {
            if (val.trim().isNotEmpty) {
              onSave(val.trim());
              _showSnackBar('$label 已更新');
            }
          },
          decoration: InputDecoration(
            isDense: true,
            hintText: '请输入$label',
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.withValues(alpha: 0.05),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none),
          ),
          style: TextStyle(fontSize: ui.bodyFontSize),
        ),
      ],
    );
  }

  Widget _buildVersionInfo(AppEngine engine, bool isDark) {
    return Center(
      child: Column(
        children: [
          Text(
            'AI Companion v2.1.0',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Research-Grade Edition',
            style: TextStyle(
              fontSize: 10,
              color: Colors.cyan.withValues(alpha: 0.5),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _exportChat(String format) async {
    final engine = context.read<AppEngine>();
    if (engine.messages.isEmpty) {
      _showSnackBar('没有聊天记录可导出');
      return;
    }

    setState(() => _isExporting = true);
    
    try {
      String path;
      final aiName = engine.personaConfig['name'] ?? 'AI';
      
      switch (format) {
        case 'json':
          path = await ChatExportService.exportAsJson(engine.messages);
          break;
        case 'txt':
          path = await ChatExportService.exportAsTxt(engine.messages, aiName);
          break;
        case 'csv':
          path = await ChatExportService.exportAsCsv(engine.messages);
          break;
        default:
          throw Exception('未知格式');
      }
      
      _showSnackBar('已导出到: $path');
    } catch (e) {
      _showSnackBar('导出失败: $e');
    } finally {
      setState(() => _isExporting = false);
    }
  }

  void _showClearHistoryDialog() {
    final engine = context.read<AppEngine>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('确认清空？'),
        content: const Text('所有聊天记录将被删除，此操作不可恢复'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              engine.clearChatHistory();
              Navigator.pop(ctx);
              _showSnackBar('聊天记录已清空');
            },
            child: const Text('确认删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}
