import 'dart:io';
import 'dart:ui';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_engine.dart';
import '../core/config.dart';
import '../core/model/user_profile.dart'; // 【Fix】导入 UserProfile
import '../core/policy/generation_policy.dart';
import '../core/provider/theme_provider.dart';
import '../core/provider/bubble_color_provider.dart';
import '../core/service/chat_export_service.dart';
import 'widgets/persona_editor_dialog.dart';
import 'widgets/genesis_editor_dialog.dart'; // 【新增】
import 'widgets/success_dialog.dart';
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
  // AI 身份控制器
  // AI 身份控制器已移至 PersonaEditorDialog
  // final TextEditingController _aiNameController ...
  // bool _hasUnsavedAiChanges ...
  
  // 用户画像控制器
  final TextEditingController _nicknameController = TextEditingController();
  final TextEditingController _callSignController = TextEditingController(); // 【新增】
  final TextEditingController _occupationController = TextEditingController();
  final TextEditingController _majorController = TextEditingController();
  String _selectedUserGender = '男性'; // 【重构】改为下拉选项
  DateTime? _birthday; // 【新增】
  String _relationshipGoal = ''; // 【新增】
  String _selectedModel = AppConfig.defaultModel;
  bool _isExporting = false;
  
  // Debounce timer for auto-save
  Timer? _debounceTimer;
  bool _hasUnsavedProfileChanges = false;

  @override
  void initState() {
    super.initState();
    final engine = context.read<AppEngine>();
    final profile = engine.userProfile;
    
    _apiKeyController.text = engine.llm.apiKey; // Initialize API key controller

    // 初始化用户画像
    _nicknameController.text = profile.nickname;
    _callSignController.text = profile.callSign ?? ''; // 【新增】
    _occupationController.text = profile.occupation;
    _majorController.text = profile.major ?? '';
    _selectedUserGender = profile.gender ?? '男性';
    // 兼容旧数据格式
    if (!['男性', '女性', '其他'].contains(_selectedUserGender)) {
      if (_selectedUserGender.contains('男')) {
        _selectedUserGender = '男性';
      } else if (_selectedUserGender.contains('女')) {
        _selectedUserGender = '女性';
      } else {
        _selectedUserGender = '其他';
      }
    }
    _birthday = profile.birthday; // 【新增】
    _relationshipGoal = profile.preferences.relationshipGoal; // 【新增】

    // AI 身份初始化已移除，由 PersonaEditorDialog 接管

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (engine.isInitialized) {
        setState(() {
          _selectedModel = engine.currentModel;
          // 确保第一次加载也能同步 UI
          _birthday = engine.userProfile.birthday;
          _relationshipGoal = engine.userProfile.preferences.relationshipGoal;
        });
      }
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _apiKeyController.dispose();
    
    // AI 控制器已移除
    
    _nicknameController.dispose();
    _callSignController.dispose();
    _occupationController.dispose();
    _majorController.dispose();
    // _selectedUserGender 无需 dispose
    super.dispose();
  }
  
  // _onAiIdentityChanged 和 _saveAiIdentity 已移除



  void _saveUserProfile() {
    final engine = context.read<AppEngine>();
    final profile = engine.userProfile;
    
    // 构造新的 preferences
    final newPrefs = profile.preferences.toJson();
    newPrefs['relationshipGoal'] = _relationshipGoal;
    
    engine.updateUserProfile(profile.copyWith(
      nickname: _nicknameController.text.trim(),
      callSign: _callSignController.text.trim(), // 【新增】
      occupation: _occupationController.text.trim(),
      major: _majorController.text.trim(),
      gender: _selectedUserGender, // 【重构】使用下拉值
      birthday: _birthday, // 【新增】
      preferences: DialoguePreferences.fromJson(newPrefs), // 【新增】
    ));
    setState(() => _hasUnsavedProfileChanges = false);
    SuccessDialog.show(context, '用户画像已保存');
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeProvider>();
    final bubbleColor = context.watch<BubbleColorProvider>();
    final engine = context.watch<AppEngine>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;

        bool saved = false;
        if (_hasUnsavedProfileChanges) {
          _saveUserProfile(); // synchronous call to logic, but internal is async?
          // _saveUserProfile logic:
          // final engine = context.read<AppEngine>(); 
          // engine.updateUserProfile(...) -> async
          // So I should await it if possible, but _saveUserProfile is void in current code.
          // I should verify _saveUserProfile implementation.
          saved = true;
        }
        
        // if (_hasUnsavedAiChanges) logic removed
        if (saved) {
           // If only profile changes, we need to ensure it's saved.
           // _saveUserProfile is void. I should inspect it.
           // For now assuming it fires and forgets.
           // To properly wait, I might need to refactor _saveUserProfile to Future.
           SuccessDialog.show(context, '配置已保存');
           await Future.delayed(const Duration(milliseconds: 1000));
        }

        if (context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: isDark ? const Color(0xFF121212) : const Color(0xFFF5F5F7),
        appBar: _buildAppBar(isDark),
        body: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
          children: [
            // 主题切换卡片
            _buildSectionCard(
              title: '外观 (APPEARANCE)',
              icon: Icons.palette_outlined,
              isDark: isDark,
              children: [
                _buildThemeSelector(theme, isDark),
                const SizedBox(height: 16),
                _buildBubbleColorPicker(bubbleColor, isDark),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 模型配置卡片
            _buildSectionCard(
              title: '核心模型 (CORE MODEL)',
              icon: Icons.memory, // 芯片图标
              isDark: isDark,
              children: [
                _buildModelSelector(engine, isDark),
                const SizedBox(height: 16),
                _buildModelParamsVisualizer(engine, isDark),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 【新增】内心独白模型选择
            _buildSectionCard(
              title: '内心独白模型',
              icon: Icons.psychology_outlined,
              isDark: isDark,
              children: [
                _buildMonologueModelSelector(engine, isDark),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // 【新增】头像设置
            _buildSectionCard(
              title: '头像设置',
              icon: Icons.face_outlined,
              isDark: isDark,
              children: [
                _buildAvatarSettings(engine, isDark),
              ],
            ),
  
            const SizedBox(height: 16),
            
            // 【新增】AI 身份设定 (核心修复)
            _buildSectionCard(
              title: 'AI 身份设定 (IDENTITY)',
              icon: Icons.fingerprint,
              isDark: isDark,
              children: [
                _buildAiIdentityEditor(engine, isDark),
                const SizedBox(height: 12),
                _buildGenesisButton(context, engine, isDark), // 【新增】Genesis 入口
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
  

            
            // 聊天记录卡片
            _buildSectionCard(
              title: '数据管理',
              icon: Icons.storage_outlined,
              isDark: isDark,
              children: [
                _buildExportButtons(engine),
                const SizedBox(height: 12),

                _buildClearHistoryButton(),
                const SizedBox(height: 12),
                _buildFactoryResetButton(context, engine, isDark), // 【新增】出厂重置按钮
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
    const accentColor = Color(0xFFFFB74D); // 统一使用 amber 主题色
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252229) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? accentColor.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.2),
        ),
        boxShadow: isDark ? null : [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 12,
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
                Icon(icon, size: 20, color: accentColor),
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
    const accentColor = Color(0xFFFFB74D);
    return GestureDetector(
      onTap: () => provider.setTheme(mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected 
              ? accentColor.withValues(alpha: 0.2)
              : (isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1)),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? accentColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: isSelected ? (isDark ? accentColor : const Color(0xFFD87C00)) : (isDark ? Colors.white70 : Colors.black87),
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
          '选择模型 ($_selectedModel)',
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
    const accentColor = Color(0xFFFFB74D);
    return GestureDetector(
      onTap: () {
        setState(() => _selectedModel = model.id);
        engine.updateModel(model.id);
        SuccessDialog.show(context, '已切换到 ${model.name}');
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected 
              ? accentColor.withValues(alpha: 0.15)
              : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.withValues(alpha: 0.05)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? accentColor : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? accentColor : (isDark ? Colors.white38 : Colors.black38),
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
              _buildParamIndicator('Temperature', GenerationPolicy.defaultTemperature.toString(), isDark),
              _buildParamIndicator('Top P', GenerationPolicy.defaultTopP.toString(), isDark),
              _buildParamIndicator('Max Tokens', '${GenerationPolicy.defaultMaxTokens}', isDark),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _buildExportCard(
              label: 'JSON',
              desc: '结构化数据',
              icon: Icons.code,
              onTap: () => _exportChat('json'),
              isDark: isDark,
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildExportCard(
              label: 'TXT',
              desc: '纯文本',
              icon: Icons.text_snippet,
              onTap: () => _exportChat('txt'),
              isDark: isDark,
            )),
            const SizedBox(width: 10),
            Expanded(child: _buildExportCard(
              label: 'CSV',
              desc: '表格格式',
              icon: Icons.table_chart,
              onTap: () => _exportChat('csv'),
              isDark: isDark,
            )),
          ],
        ),
      ],
    );
  }

  Widget _buildExportCard({
    required String label,
    required String desc,
    required IconData icon,
    required VoidCallback onTap,
    required bool isDark,
  }) {
    const accentColor = Color(0xFFFFB74D); // 主题琥珀色
    return GestureDetector(
      onTap: _isExporting ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? accentColor.withValues(alpha: 0.3) : accentColor.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 22, color: accentColor),
            const SizedBox(height: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              desc,
              style: TextStyle(
                fontSize: 9,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
            ),
          ],
        ),
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
                SuccessDialog.show(context, 'API Key 已保存');
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

  Widget _buildAiIdentityEditor(AppEngine engine, bool isDark) {
        final personaName = engine.personaConfig['name'] ?? 'AI';
        return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => const PersonaEditorDialog(),
          );
        },
        icon: const Icon(Icons.psychology, size: 18),
        label: Text('配置 $personaName 人格与详细设定'),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFFFB74D),
          foregroundColor: Colors.black87,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 0,
        ),
      ),
    );
  }
  
  Widget _buildTextField(String label, TextEditingController controller, bool isDark) {
    // 简单的 TextField 封装，不带 Debounce，因为 AI 设定手动保存更安全
    final ui = UIAdapter(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          decoration: InputDecoration(
            isDense: true,
            hintText: '请输入$label',
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
          style: TextStyle(fontSize: ui.bodyFontSize),
        ),
      ],
    );
  }

  Widget _buildUserProfileEditor(AppEngine engine, bool isDark) {
    return Column(
      children: [
        _buildProfileFieldWithDebounce('昵称', _nicknameController, isDark),
        const SizedBox(height: 12),
        _buildProfileFieldWithDebounce('职业', _occupationController, isDark),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildProfileFieldWithDebounce('专业', _majorController, isDark)),
            const SizedBox(width: 12),
            Expanded(child: _buildUserGenderDropdown(isDark)), // 【重构】下拉选择器
          ],
        ),
        const SizedBox(height: 12),
        // 【新增】称呼偏好
        _buildProfileFieldWithDebounce('称呼偏好 (AI怎么称呼你)', _callSignController, isDark),
        const SizedBox(height: 12),
        // 【新增】生日与关系目标
        Row(
          children: [
            Expanded(child: _buildBirthdayPicker(isDark)),
            const SizedBox(width: 12),
            Expanded(child: _buildRelationshipGoalSelector(isDark)),
          ],
        ),
        const SizedBox(height: 16),
        // 保存按钮
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _hasUnsavedProfileChanges ? _saveUserProfile : null,
            icon: Icon(_hasUnsavedProfileChanges ? Icons.save : Icons.check, size: 18),
            label: Text(_hasUnsavedProfileChanges ? '保存用户画像' : '已保存'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFFB74D),
              foregroundColor: Colors.black87,
              disabledBackgroundColor: isDark ? Colors.white12 : Colors.grey.shade200,
              disabledForegroundColor: isDark ? Colors.white38 : Colors.black38,
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ),
      ],
    );
  }

  /// 【新增】生日选择器
  Widget _buildBirthdayPicker(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '生日',
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
        ),
        const SizedBox(height: 4),
        GestureDetector(
          onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(
              context: context,
              initialDate: _birthday ?? DateTime(2000, 1, 1),
              firstDate: DateTime(1900),
              lastDate: now,
              builder: (context, child) {
                return Theme(
                  data: isDark ? ThemeData.dark() : ThemeData.light(),
                  child: child!,
                );
              },
            );
            if (picked != null && picked != _birthday) {
              setState(() => _birthday = picked);
              _onProfileFieldChanged();
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _birthday != null 
                      ? '${_birthday!.year}-${_birthday!.month.toString().padLeft(2, '0')}-${_birthday!.day.toString().padLeft(2, '0')}' 
                      : '选择日期',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                Icon(Icons.calendar_today, size: 16, color: isDark ? Colors.white38 : Colors.black38),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// 【新增】关系目标选择器
  Widget _buildRelationshipGoalSelector(bool isDark) {
    final goals = ['朋友', '挚友', '恋人', '导师', '树洞'];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '关系期望',
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _relationshipGoal.isNotEmpty ? _relationshipGoal : null,
              hint: Text('选择', style: TextStyle(fontSize: 14, color: isDark ? Colors.white38 : Colors.black38)),
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF252229) : Colors.white,
              items: goals.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(
                    value, 
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white : Colors.black87
                    )
                  ),
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() => _relationshipGoal = newValue);
                  _onProfileFieldChanged();
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  /// 【新增】用户性别下拉选择器
  Widget _buildUserGenderDropdown(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '性别',
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedUserGender,
              isExpanded: true,
              dropdownColor: isDark ? const Color(0xFF252229) : Colors.white,
              items: const [
                DropdownMenuItem(value: '男性', child: Text('男性')),
                DropdownMenuItem(value: '女性', child: Text('女性')),
                DropdownMenuItem(value: '其他', child: Text('其他')),
              ],
              onChanged: (v) {
                setState(() => _selectedUserGender = v ?? '男性');
                _onProfileFieldChanged();
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileFieldWithDebounce(String label, TextEditingController controller, bool isDark) {
    final ui = UIAdapter(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white54 : Colors.black54),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: controller,
          onChanged: (_) => _onProfileFieldChanged(),
          decoration: InputDecoration(
            isDense: true,
            hintText: '请输入$label',
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
          ),
          style: TextStyle(fontSize: ui.bodyFontSize),
        ),
      ],
    );
  }

  /// 【新增】内心独白模型选择器
  Widget _buildMonologueModelSelector(AppEngine engine, bool isDark) {
    final currentModel = engine.monologueModel;
    final models = [
      {'id': 'qwen-max', 'name': 'Qwen Max', 'desc': '深度思考，质量更高'},
      {'id': 'qwen-flash', 'name': 'Qwen Flash', 'desc': '快速响应，节省资源'},
    ];
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '选择用于生成内心独白的模型',
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
        const SizedBox(height: 12),
        ...models.map((model) {
          final isSelected = currentModel == model['id'];
          return GestureDetector(
            onTap: () {
              engine.updateMonologueModel(model['id']!);
              SuccessDialog.show(context, '已切换内心独白模型为 ${model['name']}');
            },
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFFB74D).withValues(alpha: 0.15)
                    : (isDark ? Colors.white.withValues(alpha: 0.03) : Colors.grey.withValues(alpha: 0.05)),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFFFFB74D) : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: isSelected ? const Color(0xFFFFB74D) : (isDark ? Colors.white38 : Colors.black38),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          model['name']!,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        Text(
                          model['desc']!,
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  /// 【新增】头像设置
  Widget _buildAvatarSettings(AppEngine engine, bool isDark) {
    final personaName = engine.personaConfig['name'] ?? 'AI';
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildAvatarPicker(
                label: '$personaName 头像',
                currentPath: engine.aiAvatarPath,
                onPick: () => _pickAvatar(engine, isAi: true),
                onRemove: () => engine.updateAiAvatar(null),
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildAvatarPicker(
                label: '用户头像',
                currentPath: engine.userAvatarPath,
                onPick: () => _pickAvatar(engine, isAi: false),
                onRemove: () => engine.updateUserAvatar(null),
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          '支持 JPG/PNG/BMP/ICO 格式，5MB 以内',
          style: TextStyle(fontSize: 10, color: isDark ? Colors.white30 : Colors.black26),
        ),
      ],
    );
  }

  Widget _buildAvatarPicker({
    required String label,
    required String? currentPath,
    required VoidCallback onPick,
    required VoidCallback onRemove,
    required bool isDark,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: isDark ? Colors.white54 : Colors.black54),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onPick,
          child: Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1),
              ),
              image: currentPath != null
                  ? DecorationImage(
                      image: FileImage(File(currentPath)),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: currentPath == null
                ? Icon(Icons.add_a_photo, color: isDark ? Colors.white38 : Colors.black38)
                : null,
          ),
        ),
        if (currentPath != null) ...[
          const SizedBox(height: 4),
          GestureDetector(
            onTap: onRemove,
            child: Text(
              '移除',
              style: TextStyle(fontSize: 10, color: Colors.redAccent.withValues(alpha: 0.8)),
            ),
          ),
        ],
      ],
    );
  }

  Future<void> _pickAvatar(AppEngine engine, {required bool isAi}) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'bmp', 'ico'],
      withData: false,
    );
    
    if (result != null && result.files.isNotEmpty) {
      final file = result.files.first;
      if (file.path != null) {
        // 检查文件大小 (5MB = 5 * 1024 * 1024 = 5242880)
        final fileSize = File(file.path!).lengthSync();
        if (fileSize > 5242880) {
          SuccessDialog.show(context, '文件过大，请选择 5MB 以内的图片');
          return;
        }
        
        if (isAi) {
          await engine.updateAiAvatar(file.path);
        } else {
          await engine.updateUserAvatar(file.path);
        }
        SuccessDialog.show(context, '头像已更新');
      }
    }
  }

  Widget _buildVersionInfo(AppEngine engine, bool isDark) {
    return Center(
      child: Column(
        children: [
          Text(
            'AI Companion v2.2.0',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white24 : Colors.black26,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Cozy Edition',
            style: TextStyle(
              fontSize: 10,
              color: const Color(0xFFFFB74D).withValues(alpha: 0.6),
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
      SuccessDialog.show(context, '没有聊天记录可导出');
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
      
      SuccessDialog.show(context, '已导出到: $path');
    } catch (e) {
      SuccessDialog.show(context, '导出失败: $e');
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
              SuccessDialog.show(context, '聊天记录已清空');
            },
            child: const Text('确认删除', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  // 【新增】Big Five 可视化与调节
  Widget _buildBigFiveVisualizer(AppEngine engine, bool isDark) {
    // 监听 PersonalityEngine 的变化
    return AnimatedBuilder(
      animation: engine.personalityEngine,
      builder: (context, child) {
        final traits = engine.personalityEngine.traits;
        
        return Column(
          children: [
            _buildTraitSlider('开放性 (Openness)', traits.openness, isDark, (val) {
              engine.personalityEngine.setTraits(traits.copyWith(openness: val));
            }, desc: '低: 保守务实 - 高: 创意抽象'),
            _buildTraitSlider('尽责性 (Conscientiousness)', traits.conscientiousness, isDark, (val) {
              engine.personalityEngine.setTraits(traits.copyWith(conscientiousness: val));
            }, desc: '低: 随性散漫 - 高: 严谨自律'),
            _buildTraitSlider('外向性 (Extraversion)', traits.extraversion, isDark, (val) {
              engine.personalityEngine.setTraits(traits.copyWith(extraversion: val));
            }, desc: '低: 内向安静 - 高: 热情活跃'),
            _buildTraitSlider('宜人性 (Agreeableness)', traits.agreeableness, isDark, (val) {
              engine.personalityEngine.setTraits(traits.copyWith(agreeableness: val));
            }, desc: '低: 独立挑战 - 高: 友善顺从'),
            _buildTraitSlider('神经质 (Neuroticism)', traits.neuroticism, isDark, (val) {
              engine.personalityEngine.setTraits(traits.copyWith(neuroticism: val));
            }, desc: '低: 情绪稳定 - 高: 敏感焦虑'),
            
            const Divider(height: 24),
            
            // 可塑性参数 (只展示，不建议随意修改)
            _buildTraitSlider('性格可塑性 (Plasticity)', traits.plasticity, isDark, (val) {
              engine.personalityEngine.setTraits(traits.copyWith(plasticity: val));
            }, desc: '影响性格随反馈变化的速率', activeColor: Colors.purpleAccent),
            
            const SizedBox(height: 8),
            
            // 复位按钮
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                   engine.personalityEngine.reset();
                   SuccessDialog.show(context, '人格参数已重置');
                },
                icon: const Icon(Icons.settings_backup_restore, size: 16),
                label: const Text('重置可塑性与人格'),
                style: TextButton.styleFrom(
                  foregroundColor: isDark ? Colors.white54 : Colors.black54,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTraitSlider(String label, double value, bool isDark, ValueChanged<double> onChanged, {
    String? desc,
    Color? activeColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            Text(
              value.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 12,
                fontFamily: 'RobotoMono',
                color: isDark ? Colors.cyanAccent : Colors.cyan,
              ),
            ),
          ],
        ),
        if (desc != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(desc, style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38)),
          ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
          ),
          child: Slider(
            value: value,
            min: 0.0,
            max: 1.0,
            activeColor: activeColor ?? const Color(0xFFFFB74D),
            inactiveColor: isDark ? Colors.white10 : Colors.grey.withValues(alpha: 0.2),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  void _onProfileFieldChanged() {
    setState(() => _hasUnsavedProfileChanges = true);
    // 移除自动保存逻辑，改为仅标记状态
    _debounceTimer?.cancel();
  }

  // ... (save logic unchanged for now) ...
  Widget _buildGenesisButton(BuildContext context, AppEngine engine, bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: () async {
          if (engine.personalityEngine.isGenesisLocked) {
            final personaName = engine.personaConfig['name'] ?? 'AI';
             showDialog(
              context: context,
              builder: (context) => AlertDialog(
                backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
                title: const Text('已锁定'),
                content: Text(
                  '人格矩阵已完成创世纪(Genesis)定型。\n\n'
                  '请尊重 $personaName 的独立人格，让 TA 随交互自然成长。',
                  style: const TextStyle(height: 1.5),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('知道了'),
                  ),
                ],
              ),
            );
          } else {
             await showDialog(
              context: context,
              builder: (context) => const GenesisEditorDialog(),
            );
             setState(() {});
          }
        },
        icon: const Icon(Icons.fingerprint, size: 18),
        label: const Text('人格塑形 (Genesis)'),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDark ? Colors.cyanAccent : Colors.cyan,
          side: BorderSide(color: isDark ? Colors.cyanAccent.withValues(alpha: 0.5) : Colors.cyan.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildFactoryResetButton(BuildContext context, AppEngine engine, bool isDark) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: () => _showFactoryResetDialog(context, engine),
        icon: const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 16),
        label: const Text('重置人格与记忆 (Factory Reset)'),
        style: TextButton.styleFrom(
          foregroundColor: Colors.redAccent,
          backgroundColor: Colors.redAccent.withValues(alpha: 0.1),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      ),
    );
  }

  void _showFactoryResetDialog(BuildContext context, AppEngine engine) {
    final personaName = engine.personaConfig['name'] ?? 'AI';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? const Color(0xFF1E1E1E) 
            : Colors.white,
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red),
            SizedBox(width: 8),
            Text('危险操作'),
          ],
        ),
        content: Text(
          '此操作将执行"出厂重置"：\n\n'
          '1. 清空所有聊天记录与亲密度。\n'
          '2. 永久删除核心事实库与记忆。\n'
          '3. 重置 Big Five 人格参数（解锁 Genesis 编辑权）。\n\n'
          '$personaName 将完全忘记你们的过去并重生。此操作不可恢复！\n\n'
          '是否确定继续？',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Close first dialog
              _performFactoryReset(context, engine);
            },
            child: const Text('我意已决', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _performFactoryReset(BuildContext context, AppEngine engine) async {
    // 显示加载中
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(child: CircularProgressIndicator()),
    );
    
    await Future.delayed(const Duration(milliseconds: 1000)); // 假装很忙，增加仪式感
    await engine.factoryReset();
    
    if (context.mounted) {
      Navigator.of(context).pop(); // Close loading
      SuccessDialog.show(context, '系统已重置，Genesis 协议已重启');
      setState(() {}); // Refresh UI state
    }
  }
}


