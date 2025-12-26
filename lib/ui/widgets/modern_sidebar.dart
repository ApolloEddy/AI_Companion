import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_engine.dart';
import '../../core/provider/theme_provider.dart';

/// Neural HUD 侧边栏 - 高级感、实时状态、人格实验室
class ModernSideBar extends StatelessWidget {
  const ModernSideBar({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<AppEngine>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    // 状态数据
    final emotion = engine.emotion;
    final valence = (emotion['valence'] as num?)?.toDouble() ?? 0.0;
    final arousal = (emotion['arousal'] as num?)?.toDouble() ?? 0.5;
    final intimacy = engine.intimacy;
    
    return Container(
      width: 300,
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.5) : Colors.white.withOpacity(0.5),
        border: Border(
          right: BorderSide(
            color: isDark ? Colors.white.withOpacity(0.1) : Colors.black.withOpacity(0.05),
          ),
        ),
      ),
      child: ClipRRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: SafeArea(
            bottom: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(engine, isDark),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _buildSectionTitle('生命体征 (Vital Signs)'),
                      _buildEmotionWaveform(arousal, isDark),
                      const SizedBox(height: 16),
                      _buildIntimacyBar(intimacy),
                      
                      const SizedBox(height: 32),
                      _buildSectionTitle('人格实验室 (Personality Lab)'),
                      _buildPersonalitySliders(engine, isDark),
                      
                      const SizedBox(height: 32),
                      _buildSectionTitle('核心状态 (Cortex Status)'),
                      _buildStatusGrid(engine, isDark),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppEngine engine, bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.cyan.withOpacity(0.5), width: 2),
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: isDark ? Colors.grey[900] : Colors.grey[200],
              child: Text(
                engine.personaConfig['name']?[0] ?? 'A',
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.cyanAccent : Colors.cyan
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                engine.personaConfig['name'] ?? '小悠',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text(
                  'LINKED',
                  style: TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w900,
          color: Colors.grey.withOpacity(0.7),
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildEmotionWaveform(double arousal, bool isDark) {
    return Container(
      height: 60,
      width: double.infinity,
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withOpacity(0.2) : Colors.black.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: WaveformPainter(
          arousal: arousal,
          color: Colors.cyanAccent.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildIntimacyBar(double intimacy) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('亲密度 (Intimacy)', style: TextStyle(fontSize: 12)),
            Text('${(intimacy * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: intimacy,
            minHeight: 6,
            backgroundColor: Colors.grey.withOpacity(0.2),
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.pinkAccent),
          ),
        ),
      ],
    );
  }

  Widget _buildPersonalitySliders(AppEngine engine, bool isDark) {
    final config = engine.personaConfig;
    // 假设庄重度和幽默感存储在配置中，范围 0-1
    final formality = (config['formality'] as num?)?.toDouble() ?? 0.5;
    final humor = (config['humor'] as num?)?.toDouble() ?? 0.5;

    return Column(
      children: [
        _buildSliderRow('庄重度 (Formality)', formality, (val) {
          engine.updatePersonaConfig({'formality': val});
        }, Colors.blueAccent),
        const SizedBox(height: 12),
        _buildSliderRow('幽默感 (Humor)', humor, (val) {
          engine.updatePersonaConfig({'humor': val});
        }, Colors.orangeAccent),
      ],
    );
  }

  Widget _buildSliderRow(String label, double value, Function(double) onChanged, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
            activeTrackColor: color,
            inactiveTrackColor: color.withOpacity(0.2),
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

  Widget _buildStatusGrid(AppEngine engine, bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.8,
      children: [
        _buildStatusCard('记忆库', '${engine.isInitialized ? engine.messages.length : 0}', Icons.memory),
        _buildStatusCard('TOKEN', _formatTokenCount(engine.totalTokensUsed), Icons.toll),
        _buildStatusCard('工作负载', '${(engine.totalTokensUsed / 1000).toStringAsFixed(1)}%', Icons.speed),
        _buildStatusCard('节点', 'v2.2.0', Icons.hub),
      ],
    );
  }

  Widget _buildStatusCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: Colors.grey),
              const SizedBox(width: 4),
              Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  String _formatTokenCount(int tokens) {
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}K';
    return tokens.toString();
  }
}

class WaveformPainter extends CustomPainter {
  final double arousal;
  final Color color;

  WaveformPainter({required this.arousal, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final path = Path();
    path.moveTo(0, size.height / 2);

    final points = 20;
    for (var i = 1; i <= points; i++) {
      final x = (size.width / points) * i;
      final y = size.height / 2 + 
               (i % 2 == 0 ? 1 : -1) * (10 + arousal * 30) * (i / points);
      path.lineTo(x, y);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
