import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_engine.dart';

/// Persona Editor Dialog - Deep customization for AI persona
class PersonaEditorDialog extends StatefulWidget {
  const PersonaEditorDialog({super.key});

  @override
  State<PersonaEditorDialog> createState() => _PersonaEditorDialogState();
}

class _PersonaEditorDialogState extends State<PersonaEditorDialog> {
  late TextEditingController _nameController;
  late TextEditingController _appearanceController;
  late TextEditingController _personalityController;
  late TextEditingController _speakingStyleController;
  late TextEditingController _hobbiesController;
  late final TextEditingController _taboosController;
  late final TextEditingController _backstoryController;
  late final TextEditingController _valuesController;
  late final TextEditingController _deepSecretsController; // 【新增】
  
  double _formality = 0.5;
  double _humor = 0.5;

  @override
  void initState() {
    super.initState();
    final engine = context.read<AppEngine>();
    final config = engine.personaConfig;
    
    _nameController = TextEditingController(text: config['name'] ?? 'April');
    _appearanceController = TextEditingController(
      text: config['appearance'] ?? config['age'] ?? '',
    );
    _personalityController = TextEditingController(text: config['personality'] ?? '');
    _speakingStyleController = TextEditingController(text: config['speakingStyle'] ?? '');
    _hobbiesController = TextEditingController(text: config['hobbies'] ?? '');
    _taboosController = TextEditingController(text: config['taboos'] ?? '');
    _backstoryController = TextEditingController(text: config['backstory'] ?? '');
    _valuesController = TextEditingController(
      text: (config['values'] is List) 
          ? (config['values'] as List).join('、') 
          : (config['values']?.toString() ?? ''),
    );
    _deepSecretsController = TextEditingController( // 【新增】
      text: (config['deepSecrets'] is List) 
          ? (config['deepSecrets'] as List).join('\n') // 使用换行分隔
          : (config['deepSecrets']?.toString() ?? ''),
    );

    _formality = (config['formality'] as num?)?.toDouble() ?? 0.5;
    _humor = (config['humor'] as num?)?.toDouble() ?? 0.5;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _appearanceController.dispose();
    _personalityController.dispose();
    _speakingStyleController.dispose();
    _hobbiesController.dispose();
    _taboosController.dispose();
    _backstoryController.dispose();
    _valuesController.dispose();
    _deepSecretsController.dispose();
    super.dispose();
  }

  void _save() {
    final engine = context.read<AppEngine>();
    final personaName = _nameController.text.trim();
    
    engine.updatePersonaConfig({
      'name': personaName.isEmpty ? '小悠' : personaName,
      'appearance': _appearanceController.text.trim(),
      'age': _appearanceController.text.trim(),
      'personality': _personalityController.text.trim(),
      'speakingStyle': _speakingStyleController.text.trim(),
      'hobbies': _hobbiesController.text.trim(),
      'taboos': _taboosController.text.trim(),
      'backstory': _backstoryController.text.trim(),
      'values': _valuesController.text.trim().split(RegExp(r'[、,，\s]+')).where((s) => s.isNotEmpty).toList(),
      'deepSecrets': _deepSecretsController.text.trim().split('\n').where((s) => s.isNotEmpty).toList(), // 【新增】
      'formality': _formality,
      'humor': _humor,
    });
    
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('已保存 $personaName 的人格配置'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final personaName = _nameController.text.isEmpty ? 'April' : _nameController.text;
    
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
        constraints: const BoxConstraints(maxHeight: 700), // 增加高度
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(isDark, personaName),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildTextField(
                      label: '名字',
                      hint: 'AI 伴侣的名字',
                      controller: _nameController,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: '外貌/基本背景',
                      hint: '描述外貌、年龄、性别、身份等...',
                      controller: _appearanceController,
                      isDark: isDark,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: '性格特征',
                      hint: '她/他的性格特点是怎样的？',
                      controller: _personalityController,
                      isDark: isDark,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: '说话风格',
                      hint: '平时是怎么说话的？（如：温柔、俏皮、高冷）',
                      controller: _speakingStyleController,
                      isDark: isDark,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: '兴趣爱好',
                      hint: '喜欢什么？（如：看小说、听音乐、画画）',
                      controller: _hobbiesController,
                      isDark: isDark,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: '禁忌/雷区',
                      hint: '应该避免谈论什么话题？',
                      controller: _taboosController,
                      isDark: isDark,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: '背景故事',
                      hint: '她/他有什么过去的经历或背景？',
                      controller: _backstoryController,
                      isDark: isDark,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField(
                      label: '价值观',
                      hint: '她/他看重什么？（如：真诚、自由、努力）用逗号或顿号分隔',
                      controller: _valuesController,
                      isDark: isDark,
                      maxLines: 2,
                    ),
                    const SizedBox(height: 16),
                    _buildTextField( // 【新增】深层秘密
                      label: '深层秘密 (高亲密度解锁)',
                      hint: '只有在极度亲密（>80%）时才会分享的内心秘密，每行一条',
                      controller: _deepSecretsController,
                      isDark: isDark,
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    _buildSlider(
                      label: '庄重度',
                      value: _formality,
                      onChanged: (v) => setState(() => _formality = v),
                      isDark: isDark,
                      color: Colors.blueAccent, // 【修改】蓝色
                    ),
                    const SizedBox(height: 16),
                    _buildSlider(
                      label: '幽默感',
                      value: _humor,
                      onChanged: (v) => setState(() => _humor = v),
                      isDark: isDark,
                      color: Colors.orangeAccent, // 【修改】橙色
                    ),
                  ],
                ),
              ),
            ),
            _buildFooter(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, String personaName) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.05),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: const Color(0xFFFFB74D).withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.psychology, color: Color(0xFFFFB74D)),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '人格实验室',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              Text(
                '深度定制 $personaName 的核心灵魂',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String hint,
    required TextEditingController controller,
    required bool isDark,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white70 : Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(
              color: isDark ? Colors.white24 : Colors.black26,
              fontSize: 13,
            ),
            filled: true,
            fillColor: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ],
    );
  }

  Widget _buildSlider({
    required String label,
    required double value,
    required ValueChanged<double> onChanged,
    required bool isDark,
    required Color color,
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
                color: isDark ? Colors.white70 : Colors.black87,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                value.toStringAsFixed(2), // 【修改】保留两位小数
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 4,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            activeTrackColor: color,
            inactiveTrackColor: color.withValues(alpha: 0.2),
            thumbColor: color,
          ),
          child: Slider(
            value: value,
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildFooter(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('取消'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB74D),
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('保存'),
            ),
          ),
        ],
      ),
    );
  }
}
