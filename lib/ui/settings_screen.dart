import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_engine.dart';
import '../core/config.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  String _selectedModel = AppConfig.defaultModel;

  @override
  void initState() {
    super.initState();
    // 延迟加载当前模型
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final engine = context.read<AppEngine>();
      if (engine.isInitialized) {
        setState(() {
          _selectedModel = engine.currentModel;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<AppEngine>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: isDark ? const Color(0xFF2D2D2D) : Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ========== 模型选择 ==========
          const Text(
            '语言模型',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '选择回复使用的 AI 模型',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          
          ...AppConfig.availableModels.map((model) => RadioListTile<String>(
            value: model.id,
            groupValue: _selectedModel,
            onChanged: (value) {
              if (value != null) {
                setState(() => _selectedModel = value);
                engine.updateModel(value);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('已切换到 ${model.name}'),
                    duration: const Duration(milliseconds: 800),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            title: Row(
              children: [
                Text(model.name),
                const SizedBox(width: 8),
                if (model.hasFreeQuota)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      '免费',
                      style: TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
              ],
            ),
            subtitle: Text(model.desc, style: const TextStyle(fontSize: 12)),
            dense: true,
          )),
          
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          
          // ========== API Key 配置 ==========
          const Text(
            'API Key 配置',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '可选项，留空使用内置 Key',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _apiKeyController,
            decoration: const InputDecoration(
              hintText: 'sk-... ',
              border: OutlineInputBorder(),
              helperText: 'DashScope API Key',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF07C160),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final key = _apiKeyController.text.trim();
                if (key.isNotEmpty) {
                  engine.updateApiKey(key);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('API Key 已保存'),
                      duration: Duration(milliseconds: 800),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('保存 API Key'),
            ),
          ),
          
          const SizedBox(height: 40),
          const Divider(),
          ListTile(
            title: const Text('关于'),
            subtitle: const Text('AI Companion Flutter v2.0.0'),
            dense: true,
          ),
          ListTile(
            title: const Text('当前模型'),
            subtitle: Text(engine.isInitialized ? engine.currentModel : '加载中...'),
            dense: true,
          ),
        ],
      ),
    );
  }
}
