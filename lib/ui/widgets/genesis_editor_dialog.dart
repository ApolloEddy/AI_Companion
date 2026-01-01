import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_engine.dart';
import '../../core/model/big_five_personality.dart';
import 'personality_radar_chart.dart';
import 'success_dialog.dart';

/// Genesis Editor Dialog - 初次人格重塑工具
class GenesisEditorDialog extends StatefulWidget {
  const GenesisEditorDialog({super.key});

  @override
  State<GenesisEditorDialog> createState() => _GenesisEditorDialogState();
}

class _GenesisEditorDialogState extends State<GenesisEditorDialog> {
  late Map<String, double> _currentTraits;

  @override
  void initState() {
    super.initState();
    final engine = context.read<AppEngine>();
    final traits = engine.personalityEngine.traits;
    
    // 初始化为当前人格
    _currentTraits = {
      'openness': traits.openness,
      'conscientiousness': traits.conscientiousness,
      'extraversion': traits.extraversion,
      'agreeableness': traits.agreeableness,
      'neuroticism': traits.neuroticism,
    };
  }

  void _save(BuildContext context) {
    // 确认对话框
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Theme.of(context).brightness == Brightness.dark 
            ? const Color(0xFF1E1E1E) 
            : Colors.white,
        title: const Text('确认人格定型?'),
        content: const Text(
          '这是 AI 全生命周期中唯一一次"基因编辑"机会。\n\n'
          '一旦保存:\n'
          '1. 当前设定将成为永久的"出厂设置" (灰色基准线)。\n'
          '2. 之后的人格变化将基于此基准线自然演化。\n'
          '3. 此界面将永久锁定，无法再次修改。\n\n'
          '是否确定?',
          style: TextStyle(height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('再想想'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop(); // Close confirm dialog
              _performLock();
            },
            child: const Text('确定定型', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );
  }

  void _performLock() {
    final engine = context.read<AppEngine>();
    
    final newTraits = BigFiveTraits(
      openness: _currentTraits['openness'] ?? 0.5,
      conscientiousness: _currentTraits['conscientiousness'] ?? 0.5,
      extraversion: _currentTraits['extraversion'] ?? 0.5,
      agreeableness: _currentTraits['agreeableness'] ?? 0.5,
      neuroticism: _currentTraits['neuroticism'] ?? 0.5,
      plasticity: engine.personalityEngine.traits.plasticity,
      totalInteractions: 0, // 重置交互计数，新生命开始
    );
    
    engine.personalityEngine.lockGenesis(newTraits);
    // engine.saveState(); // 自动通过 listener 保存
    
    Navigator.of(context).pop(); // Close editor
    SuccessDialog.show(context, '人格矩阵已永久定型');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final engine = context.watch<AppEngine>();
    final personaName = engine.personaConfig['name'] ?? 'April';

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        width: 400,
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
            // Header
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  const Icon(Icons.fingerprint, color: Colors.blueAccent),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '人格塑形 (Genesis)',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                   Text(
                     '请拖动雷达图顶点，设定 $personaName 的初始人格基因。\n这将决定TA的核心底色。',
                     textAlign: TextAlign.center,
                     style: const TextStyle(fontSize: 13, height: 1.4, color: Colors.grey),
                   ),
                   const SizedBox(height: 24),
                   SizedBox(
                      height: 260,
                      child: PersonalityRadarChart(
                        initialTraits: _currentTraits,
                        mode: RadarMode.sculpting,
                        isDark: isDark,
                        onTraitChanged: (newTraits) {
                           setState(() => _currentTraits = newTraits);
                        },
                      ),
                   ),
                   const SizedBox(height: 12),
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                     decoration: BoxDecoration(
                       color: Colors.blue.withValues(alpha: 0.1),
                       borderRadius: BorderRadius.circular(8),
                     ),
                     child: const Row(
                       mainAxisSize: MainAxisSize.min,
                       children: [
                         Icon(Icons.info_outline, size: 16, color: Colors.blue),
                         SizedBox(width: 8),
                         Text(
                           '拖动顶点即可调整',
                           style: TextStyle(fontSize: 12, color: Colors.blue),
                         ),
                       ],
                     ),
                   ),
                   const SizedBox(height: 24),
                ],
              ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.all(20),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () => _save(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.lock_outline, size: 20),
                  label: const Text('保存并锁定 (Lock Genesis)'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
