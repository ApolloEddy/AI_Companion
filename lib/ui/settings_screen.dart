import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_engine.dart';
import '../core/config.dart';
import '../core/service/chat_export_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _apiKeyController = TextEditingController();
  String _selectedModel = AppConfig.defaultModel;
  bool _isExporting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final engine = context.read<AppEngine>();
      if (engine.isInitialized) {
        setState(() {
          _selectedModel = engine.currentModel;
        });
      }
    });
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
      ),
    );
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
                _showSnackBar('已切换到 ${model.name}');
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
          
          // ========== 聊天记录管理 ==========
          const Text(
            '聊天记录',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            '导出或清空聊天记录',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          
          // 导出按钮
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isExporting ? null : () => _exportChat('json'),
                  icon: const Icon(Icons.code, size: 18),
                  label: const Text('JSON'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isExporting ? null : () => _exportChat('txt'),
                  icon: const Icon(Icons.text_snippet, size: 18),
                  label: const Text('TXT'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _isExporting ? null : () => _exportChat('csv'),
                  icon: const Icon(Icons.table_chart, size: 18),
                  label: const Text('CSV'),
                ),
              ),
            ],
          ),
          
          if (_isExporting)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: LinearProgressIndicator(),
            ),
          
          const SizedBox(height: 16),
          
          // 清空记录按钮
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _showClearHistoryDialog,
              icon: const Icon(Icons.delete_outline, color: Colors.red),
              label: const Text('清空聊天记录', style: TextStyle(color: Colors.red)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
              ),
            ),
          ),
          
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
                  _showSnackBar('API Key 已保存');
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

