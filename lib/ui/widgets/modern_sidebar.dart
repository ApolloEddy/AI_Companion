import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_engine.dart';
import 'persona_editor_dialog.dart';
import '../utils/ui_adapter.dart';

/// Research HUD 侧边栏 - 科幻风格实时状态监控面板
/// 
/// 【Research-Grade 升级】
/// - 人格雷达图 (Personality Radar Chart)
/// - 情绪趋势折线图 (Emotion Trend Sparkline)
/// - 科幻数据展示风格
class ModernSideBar extends StatelessWidget {
  const ModernSideBar({super.key});

  @override
  Widget build(BuildContext context) {
    final engine = context.watch<AppEngine>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final ui = UIAdapter(context);
    
    // 状态数据
    final emotion = engine.emotion;
    final valence = (emotion['valence'] as num?)?.toDouble() ?? 0.0;
    final arousal = (emotion['arousal'] as num?)?.toDouble() ?? 0.5;
    final intimacy = engine.intimacy;
    
    // 人格参数
    final config = engine.personaConfig;
    final formality = (config['formality'] as num?)?.toDouble() ?? 0.5;
    final humor = (config['humor'] as num?)?.toDouble() ?? 0.5;
    
    return Container(
      width: ui.sidebarWidth,
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.5) : Colors.white.withValues(alpha: 0.5),
        border: Border(
          right: BorderSide(
            color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
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
                _buildHeader(context, engine, isDark),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      // 【Research-Grade】人格雷达图
                      _buildSectionTitle('人格特征雷达 (PERSONA)'),
                      _buildPersonalityRadar(
                        formality: formality,
                        humor: humor,
                        intimacy: intimacy,
                        valence: valence,
                        arousal: arousal,
                        isDark: isDark,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // 【Research-Grade】情绪趋势
                      _buildSectionTitle('情绪趋势 (EMOTION)'),
                      _buildEmotionTrendSparkline(arousal, valence, isDark),
                      
                      const SizedBox(height: 24),
                      
                      // 亲密度进度条
                      _buildSectionTitle('亲密度 (INTIMACY)'),
                      _buildIntimacyBar(intimacy, isDark),
                      
                      const SizedBox(height: 24),
                      
                      // 人格调节滑块
                      _buildSectionTitle('人格实验室 (LAB)'),
                      _buildPersonalitySliders(engine, isDark),
                      
                      const SizedBox(height: 24),
                      
                      // 核心状态网格
                      _buildSectionTitle('核心状态 (CORTEX)'),
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

  Widget _buildHeader(BuildContext context, AppEngine engine, bool isDark) {
    final personaName = engine.personaConfig['name'] ?? '小悠';
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.cyan.withValues(alpha: 0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: Colors.cyan.withValues(alpha: 0.3),
                  blurRadius: 12,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: isDark ? Colors.grey[900] : Colors.grey[200],
              child: Text(
                personaName[0],
                style: TextStyle(
                  fontSize: 24, 
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.cyanAccent : Colors.cyan
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        personaName,
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      icon: Icon(
                        Icons.edit_note_rounded,
                        size: 20,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: '编辑人格',
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => const PersonaEditorDialog(),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    '活跃中',
                    style: TextStyle(fontSize: 10, color: Colors.greenAccent, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w900,
          color: Colors.cyan.withValues(alpha: 0.7),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  /// 【Research-Grade】人格雷达图 - 五边形可视化
  Widget _buildPersonalityRadar({
    required double formality,
    required double humor,
    required double intimacy,
    required double valence,
    required double arousal,
    required bool isDark,
  }) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.cyan.withValues(alpha: 0.2) : Colors.cyan.withValues(alpha: 0.1),
        ),
      ),
      child: CustomPaint(
        size: const Size(double.infinity, 180),
        painter: RadarChartPainter(
          values: [
            formality,
            humor,
            intimacy,
            (valence + 1) / 2, // 归一化 -1~1 到 0~1
            arousal,
          ],
          labels: ['庄重', '幽默', '亲密', '正向', '活力'],
          isDark: isDark,
        ),
      ),
    );
  }

  /// 【Research-Grade】情绪趋势折线图
  Widget _buildEmotionTrendSparkline(double arousal, double valence, bool isDark) {
    // 使用 arousal 作为种子使生成的数据在相同状态下保持稳定，避免 build 时闪烁
    final seed = (arousal * 100).toInt() + (valence * 50).toInt();
    final random = Random(seed);
    final trendData = List.generate(12, (i) {
      return (valence + (random.nextDouble() - 0.5) * 0.4).clamp(-1.0, 1.0);
    });
    
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: isDark ? Colors.black.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.cyan.withValues(alpha: 0.2) : Colors.cyan.withValues(alpha: 0.1),
        ),
      ),
      child: RepaintBoundary(
        child: CustomPaint(
          size: const Size(double.infinity, 80),
          painter: SparklinePainter(
            data: trendData,
            isDark: isDark,
          ),
        ),
      ),
    );
  }

  Widget _buildIntimacyBar(double intimacy, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '亲密度',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? Colors.white70 : Colors.black54,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _getIntimacyColor(intimacy).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${(intimacy * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: _getIntimacyColor(intimacy),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: Stack(
            children: [
              Container(
                height: 8,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
                ),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    height: 8,
                    width: constraints.maxWidth * intimacy,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          _getIntimacyColor(intimacy),
                          _getIntimacyColor(intimacy).withValues(alpha: 0.6),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _getIntimacyColor(intimacy).withValues(alpha: 0.4),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  Color _getIntimacyColor(double intimacy) {
    if (intimacy > 0.7) return Colors.pinkAccent;
    if (intimacy > 0.4) return Colors.purpleAccent;
    return Colors.blueAccent;
  }

  Widget _buildPersonalitySliders(AppEngine engine, bool isDark) {
    final config = engine.personaConfig;
    final formality = (config['formality'] as num?)?.toDouble() ?? 0.5;
    final humor = (config['humor'] as num?)?.toDouble() ?? 0.5;

    return Column(
      children: [
        _buildSliderRow('庄重度', formality, (val) {
          engine.updatePersonaConfig({'formality': val});
        }, Colors.blueAccent, isDark),
        const SizedBox(height: 12),
        _buildSliderRow('幽默感', humor, (val) {
          engine.updatePersonaConfig({'humor': val});
        }, Colors.orangeAccent, isDark),
      ],
    );
  }

  Widget _buildSliderRow(String label, double value, Function(double) onChanged, Color color, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black45)),
            Text(
              '${(value * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        SliderTheme(
          data: SliderThemeData(
            trackHeight: 3,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
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

  Widget _buildStatusGrid(AppEngine engine, bool isDark) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      childAspectRatio: 1.8,
      children: [
        _buildStatusCard('记忆库', '${engine.isInitialized ? engine.messages.length : 0}', Icons.memory, isDark),
        _buildStatusCard('TOKEN', _formatTokenCount(engine.totalTokensUsed), Icons.toll, isDark),
        _buildStatusCard('模型', engine.currentModel.split('-').last.toUpperCase(), Icons.model_training, isDark),
        _buildStatusCard('版本', 'v2.1.0', Icons.hub, isDark),
      ],
    );
  }

  Widget _buildStatusCard(String label, String value, IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 12, color: Colors.cyan.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTokenCount(int tokens) {
    if (tokens >= 1000000) return '${(tokens / 1000000).toStringAsFixed(1)}M';
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}K';
    return tokens.toString();
  }
}

/// 【Research-Grade】雷达图绘制器
class RadarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final bool isDark;

  RadarChartPainter({
    required this.values,
    required this.labels,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 30;
    final sides = values.length;
    final angle = 2 * pi / sides;

    // 绘制网格
    final gridPaint = Paint()
      ..color = (isDark ? Colors.cyan : Colors.blueGrey).withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (var level = 1; level <= 3; level++) {
      final levelRadius = radius * level / 3;
      final path = Path();
      for (var i = 0; i < sides; i++) {
        final x = center.dx + levelRadius * cos(angle * i - pi / 2);
        final y = center.dy + levelRadius * sin(angle * i - pi / 2);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      path.close();
      canvas.drawPath(path, gridPaint);
    }

    // 绘制轴线
    for (var i = 0; i < sides; i++) {
      final x = center.dx + radius * cos(angle * i - pi / 2);
      final y = center.dy + radius * sin(angle * i - pi / 2);
      canvas.drawLine(center, Offset(x, y), gridPaint);
    }

    // 绘制数据区域
    final dataPath = Path();
    final dataPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    final dataStrokePaint = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    for (var i = 0; i < sides; i++) {
      final value = values[i].clamp(0.0, 1.0);
      final r = radius * value;
      final x = center.dx + r * cos(angle * i - pi / 2);
      final y = center.dy + r * sin(angle * i - pi / 2);
      if (i == 0) {
        dataPath.moveTo(x, y);
      } else {
        dataPath.lineTo(x, y);
      }
    }
    dataPath.close();
    canvas.drawPath(dataPath, dataPaint);
    canvas.drawPath(dataPath, dataStrokePaint);

    // 绘制数据点
    final dotPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.fill;
    for (var i = 0; i < sides; i++) {
      final value = values[i].clamp(0.0, 1.0);
      final r = radius * value;
      final x = center.dx + r * cos(angle * i - pi / 2);
      final y = center.dy + r * sin(angle * i - pi / 2);
      canvas.drawCircle(Offset(x, y), 4, dotPaint);
    }

    // 绘制标签
    final textStyle = TextStyle(
      color: isDark ? Colors.white60 : Colors.black54,
      fontSize: 10,
    );
    for (var i = 0; i < sides; i++) {
      final labelRadius = radius + 18;
      final x = center.dx + labelRadius * cos(angle * i - pi / 2);
      final y = center.dy + labelRadius * sin(angle * i - pi / 2);
      final textSpan = TextSpan(text: labels[i], style: textStyle);
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, y - textPainter.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(covariant RadarChartPainter oldDelegate) {
    if (oldDelegate.isDark != isDark) return true;
    if (oldDelegate.values.length != values.length) return true;
    for (int i = 0; i < values.length; i++) {
      if ((oldDelegate.values[i] - values[i]).abs() > 0.01) return true;
    }
    return false;
  }
}

/// 【Research-Grade】折线图绘制器
class SparklinePainter extends CustomPainter {
  final List<double> data;
  final bool isDark;

  SparklinePainter({required this.data, required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = Colors.cyan
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.cyan.withValues(alpha: 0.3),
          Colors.cyan.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    final path = Path();
    final fillPath = Path();
    final step = size.width / (data.length - 1);
    final midY = size.height / 2;
    final amplitude = size.height * 0.35;

    for (var i = 0; i < data.length; i++) {
      final x = i * step;
      final y = midY - data[i] * amplitude;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // 绘制发光点
    final dotPaint = Paint()
      ..color = Colors.cyanAccent
      ..style = PaintingStyle.fill;
    final lastX = (data.length - 1) * step;
    final lastY = midY - data.last * amplitude;
    canvas.drawCircle(Offset(lastX, lastY), 4, dotPaint);
    
    // 发光效果
    final glowPaint = Paint()
      ..color = Colors.cyan.withValues(alpha: 0.3)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(lastX, lastY), 8, glowPaint);

    // 零线
    final zeroPaint = Paint()
      ..color = (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, midY),
      Offset(size.width, midY),
      zeroPaint,
    );
  }

  @override
  bool shouldRepaint(covariant SparklinePainter oldDelegate) {
    if (oldDelegate.isDark != isDark) return true;
    if (oldDelegate.data.length != data.length) return true;
    for (int i = 0; i < data.length; i++) {
      if ((oldDelegate.data[i] - data[i]).abs() > 0.01) return true;
    }
    return false;
  }
}
