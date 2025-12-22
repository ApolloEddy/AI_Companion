import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/app_engine.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _controller = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('设置'),
        backgroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '大模型配置',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text('DashScope API Key'),
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              hintText: 'sk-... (留空则使用内置默认 Key)',
              border: OutlineInputBorder(),
              helperText: '用于直接调用通义千问 API',
            ),
            obscureText: true,
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF07C160),
                foregroundColor: Colors.white,
              ),
              onPressed: () {
                final key = _controller.text.trim();
                if (key.isNotEmpty) {
                  context.read<AppEngine>().updateApiKey(key);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('设置已保存')),
                  );
                }
              },
              child: const Text('保存配置'),
            ),
          ),
          const SizedBox(height: 40),
          const Divider(),
          ListTile(
            title: const Text('关于'),
            subtitle: const Text('AI Companion Flutter Version 1.0.0'),
            dense: true,
          ),
        ],
      ),
    );
  }
}
