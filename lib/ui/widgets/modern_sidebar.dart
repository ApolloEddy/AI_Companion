import 'dart:math';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_engine.dart';
import 'persona_editor_dialog.dart';
import '../utils/ui_adapter.dart';

/// Research HUD 侧边栏 - 科幻风格实时状态监控面板
/// 
/// 【Research-Grade 升级】
/// - 情绪趋势折线图 (Emotion Trend Sparkline)
/// - 内心独白智能滚动
/// - 科幻数据展示风格
class ModernSideBar extends StatefulWidget {
  const ModernSideBar({super.key});

  @override
  State<ModernSideBar> createState() => _ModernSideBarState();
}

class _ModernSideBarState extends State<ModernSideBar> {
  // 情绪历史记录（最近20个数据点）
  final List<double> _valenceHistory = [];
  final List<double> _arousalHistory = [];
  static const int _maxHistoryLength = 20;
  
  // 父级 ListView 滚动控制器
  final ScrollController _listScrollController = ScrollController();
  
  // 内心独白生成状态跟踪
  String _previousMonologue = '';
  bool _isMonologueGenerating = false;
  
  @override
  void dispose() {
    _listScrollController.dispose();
    super.dispose();
  }
  
  void _updateEmotionHistory(double valence, double arousal) {
    // 仅当数值有明显变化时才记录
    if (_valenceHistory.isEmpty || 
        ((_valenceHistory.last - valence).abs() > 0.01 || 
         (_arousalHistory.last - arousal).abs() > 0.01)) {
      _valenceHistory.add(valence);
      _arousalHistory.add(arousal);
      if (_valenceHistory.length > _maxHistoryLength) {
        _valenceHistory.removeAt(0);
        _arousalHistory.removeAt(0);
      }
    }
  }

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
    
    // 更新情绪历史
    _updateEmotionHistory(valence, arousal);
    
    // 人格参数
    final config = engine.personaConfig;
    final personaName = config['name'] ?? '小悠';
    final userName = engine.userProfile.nickname.isNotEmpty 
        ? engine.userProfile.nickname 
        : '用户';
    
    // 检测内心独白生成状态
    final currentMonologue = engine.streamingMonologue;
    final isNewContent = currentMonologue != _previousMonologue && currentMonologue.isNotEmpty;
    if (isNewContent) {
      _isMonologueGenerating = currentMonologue.length > _previousMonologue.length;
      _previousMonologue = currentMonologue;
      
      // 内心独白生成中时，确保面板可见
      if (_isMonologueGenerating) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _listScrollController.hasClients) {
            _listScrollController.animateTo(
              _listScrollController.position.maxScrollExtent,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        });
      }
    } else if (currentMonologue.isEmpty) {
      _isMonologueGenerating = false;
    }
    
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
                    controller: _listScrollController,
                    padding: const EdgeInsets.all(20),
                    children: [
                      // $personaName 的情绪状态（带曲线）
                      _buildSectionTitle('$personaName 的情绪状态', isDark: isDark),
                      _buildEmotionStatusPanel(
                        valence: valence,
                        arousal: arousal,
                        intimacy: intimacy,
                        isDark: isDark,
                        valenceHistory: _valenceHistory,
                        arousalHistory: _arousalHistory,
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // $personaName 的认知状态
                      _buildSectionTitle('$personaName 的认知状态', isDark: isDark),
                      _buildCognitiveStatePanel(engine, isDark),
                      
                      const SizedBox(height: 24),
                      
                      // 内心独白（自适应高度，无内部滚动条）
                      _buildSectionTitle('$personaName 的内心独白', isDark: isDark),
                      _buildMonologuePanel(engine, isDark),
                      
                      const SizedBox(height: 24),
                      
                      // 亲密度进度条
                      _buildSectionTitle('亲密度', isDark: isDark),
                      _buildIntimacyBar(intimacy, isDark),
                      
                      const SizedBox(height: 24),
                      
                      // 核心状态网格（置底）
                      _buildSectionTitle('核心状态', isDark: isDark),
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
              border: Border.all(color: (isDark ? const Color(0xFFFFB74D) : const Color(0xFFD87C00)).withValues(alpha: 0.5), width: 2),
              boxShadow: [
                BoxShadow(
                  color: (isDark ? const Color(0xFFFFB74D) : const Color(0xFFD87C00)).withValues(alpha: 0.3),
                  blurRadius: 12,
                ),
              ],
            ),
            child: CircleAvatar(
              radius: 28,
              backgroundColor: isDark ? Colors.grey[900] : Colors.grey[200],
              backgroundImage: engine.aiAvatarPath != null && engine.aiAvatarPath!.isNotEmpty
                  ?  FileImage(File(engine.aiAvatarPath!))
                  : null,
              child: (engine.aiAvatarPath == null || engine.aiAvatarPath!.isEmpty)
                  ? Text(
                      personaName[0],
                      style: TextStyle(
                        fontSize: 24, 
                        fontWeight: FontWeight.bold,
                        color: isDark ? const Color(0xFFFFB74D) : const Color(0xFFD87C00)
                      ),
                    )
                  : null,
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
                  child: Text(
                    '活跃中',
                    style: TextStyle(
                      fontSize: 10, 
                      color: isDark ? Colors.greenAccent : const Color(0xFF2E7D32), 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, {bool isDark = true}) {
    // 浅色模式用深绿，深色模式用琥珀
    final color = isDark 
        ? const Color(0xFFFFB74D).withValues(alpha: 0.9) 
        : const Color(0xFFD87C00); // 改为深琥珀色提升对比度
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12, // 增大字号
          fontWeight: FontWeight.w800,
          color: color,
          letterSpacing: 1.2,
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
        color: isDark ? const Color(0xFF252229) : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFFFFB74D).withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.2),
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
        color: isDark ? const Color(0xFF252229) : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFFFFB74D).withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.2),
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

  /// 【重构】情绪状态面板 - 展示核心情绪指标和动态曲线
  Widget _buildEmotionStatusPanel({
    required double valence,
    required double arousal,
    required double intimacy,
    required bool isDark,
    required List<double> valenceHistory,
    required List<double> arousalHistory,
  }) {
    // 计算情绪象限
    String quadrant;
    Color quadrantColor;
    if (valence > 0.3 && arousal >= 0.5) {
      quadrant = '兴奋';
      quadrantColor = isDark ? Colors.orangeAccent : const Color(0xFFE65100);
    } else if (valence > 0.3) {
      quadrant = '愉悦';
      quadrantColor = isDark ? Colors.greenAccent : const Color(0xFF2E7D32);
    } else if (valence < -0.3 && arousal < 0.5) {
      quadrant = '低落';
      quadrantColor = isDark ? Colors.blueGrey : const Color(0xFF455A64);
    } else if (valence < -0.3) {
      quadrant = '焦躁';
      quadrantColor = isDark ? Colors.redAccent : const Color(0xFFC62828);
    } else if (arousal > 0.6) {
      quadrant = '警觉';
      quadrantColor = isDark ? Colors.amber : const Color(0xFFD84315);
    } else {
      quadrant = '平静';
      quadrantColor = isDark ? Colors.cyanAccent : const Color(0xFF00838F);
    }

    // 情绪强度
    final intensity = (valence.abs() > 0.5 || arousal > 0.7) ? '强烈' : '平和';
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252229) : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFFFFB74D).withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          // 情绪象限 - 大标题
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: quadrantColor,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: quadrantColor.withValues(alpha: 0.5), blurRadius: 8)],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                quadrant,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: quadrantColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  intensity,
                  style: TextStyle(fontSize: 11, color: quadrantColor, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 数值指标网格 - 使用更易懂的术语
          Row(
            children: [
              Expanded(
                child: _buildEmotionMetric(
                  label: '愉悦度',
                  value: valence,
                  displayValue: valence >= 0 ? '+${valence.toStringAsFixed(2)}' : valence.toStringAsFixed(2),
                  color: valence >= 0 ? Colors.greenAccent : Colors.redAccent,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildEmotionMetric(
                  label: '活跃度',
                  value: arousal,
                  displayValue: '${(arousal * 100).toStringAsFixed(0)}%',
                  color: arousal > 0.6 
                      ? (isDark ? Colors.orangeAccent : const Color(0xFFD87C00)) 
                      : (isDark ? Colors.cyanAccent : const Color(0xFF00796B)),
                  isDark: isDark,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 愉悦度变化曲线
          _buildEmotionCurve(
            label: '愉悦度变化',
            history: valenceHistory,
            color: isDark ? Colors.greenAccent : const Color(0xFF2E7D32),
            isDark: isDark,
            normalize: true, // valence 范围 -1~1
          ),
          
          const SizedBox(height: 8),
          
          // 活跃度变化曲线
          _buildEmotionCurve(
            label: '活跃度变化',
            history: arousalHistory,
            color: isDark ? Colors.orangeAccent : const Color(0xFFD87C00),
            isDark: isDark,
            normalize: false, // arousal 范围 0~1
          ),
        ],
      ),
    );
  }
  
  /// 情绪变化曲线
  Widget _buildEmotionCurve({
    required String label,
    required List<double> history,
    required Color color,
    required bool isDark,
    bool normalize = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 9, color: isDark ? Colors.white30 : Colors.black54, letterSpacing: 0.5),
        ),
        const SizedBox(height: 4),
        Container(
          height: 40,
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
            borderRadius: BorderRadius.circular(6),
          ),
          child: history.isEmpty
              ? Center(
                  child: Text(
                    '等待数据...',
                    style: TextStyle(fontSize: 9, color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.2)),
                  ),
                )
              : CustomPaint(
                  size: const Size(double.infinity, 40),
                  painter: _EmotionCurvePainter(
                    data: history,
                    color: color,
                    isDark: isDark,
                    normalize: normalize,
                  ),
                ),
        ),
      ],
    );
  }
  
  /// 情绪指标卡片
  Widget _buildEmotionMetric({
    required String label,
    required double value,
    required String displayValue,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38),
          ),
          const SizedBox(height: 4),
          Text(
            displayValue,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
  
  /// 进度条组件
  Widget _buildProgressBar({
    required String label,
    required double value,
    required Color color,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 9, color: isDark ? Colors.white30 : Colors.black26, letterSpacing: 1),
            ),
            Text(
              '${(value * 100).toStringAsFixed(0)}%',
              style: TextStyle(fontSize: 9, color: color.withValues(alpha: 0.8)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: Stack(
            children: [
              Container(
                height: 4,
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.05),
              ),
              LayoutBuilder(
                builder: (context, constraints) {
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 400),
                    height: 4,
                    width: constraints.maxWidth * value.clamp(0.0, 1.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [color, color.withValues(alpha: 0.6)],
                      ),
                      boxShadow: [
                        BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 4),
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
                  color: isDark ? const Color(0xFFFFB74D) : const Color(0xFFD87C00)
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
                    width: constraints.maxWidth * intimacy.clamp(0.0, 1.0),
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
        _buildStatusCard('记忆库', '${engine.memoryCount}', Icons.memory, isDark),
        _buildStatusCard('对话', '${engine.totalChatCount}', Icons.chat_bubble_outline, isDark),
        _buildStatusCard('TOKEN', _formatTokenCount(engine.totalTokensUsed), Icons.toll, isDark),
        _buildStatusCard('模型', engine.currentModel.split('-').last.toUpperCase(), Icons.model_training, isDark),
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
              Icon(icon, size: 12, color: isDark ? const Color(0xFFFFB74D).withValues(alpha: 0.7) : const Color(0xFFD87C00)),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black87)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  /// 【新增】认知状态面板 - 显示 AI 的感知与决策状态
  Widget _buildCognitiveStatePanel(AppEngine engine, bool isDark) {
    // 获取最新的调试状态
    final debugState = engine.getDebugState();
    final cognitiveEnabled = debugState['cognitiveEngineEnabled'] ?? false;
    
    if (!cognitiveEnabled) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.psychology_outlined, size: 16, color: isDark ? Colors.white38 : Colors.black38),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '认知引擎待激活',
                style: TextStyle(fontSize: 12, color: isDark ? Colors.white38 : Colors.black38),
              ),
            ),
          ],
        ),
      );
    }
    
    // 模拟认知状态数据（实际应从 engine 获取最新的 cognitiveState）
    final emotion = engine.emotion;
    final valence = (emotion['valence'] as num?)?.toDouble() ?? 0.0;
    final arousal = (emotion['arousal'] as num?)?.toDouble() ?? 0.5;
    
    // 基于情绪推断感知状态
    String perceptionLabel;
    Color perceptionColor;
    if (valence > 0.3) {
      perceptionLabel = '积极';
      perceptionColor = isDark ? Colors.greenAccent : const Color(0xFF1B5E20); // 亮色用深绿
    } else if (valence < -0.3) {
      perceptionLabel = '消极';
      perceptionColor = isDark ? Colors.redAccent : const Color(0xFFB71C1C); // 亮色用深红
    } else {
      perceptionLabel = '中性';
      perceptionColor = isDark ? Colors.blueAccent : const Color(0xFF0D47A1); // 亮色用深蓝
    }
    
    // 基于唤醒度推断活跃程度
    String arousalLabel;
    if (arousal > 0.7) {
      arousalLabel = '高活跃';
    } else if (arousal < 0.3) {
      arousalLabel = '低活跃';
    } else {
      arousalLabel = '平稳';
    }
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252229) : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? const Color(0xFFFFB74D).withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 感知状态
          _buildCognitiveRow(
            icon: Icons.visibility_outlined,
            label: '感知',
            value: perceptionLabel,
            color: perceptionColor,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          // 活跃度
          _buildCognitiveRow(
            icon: Icons.bolt_outlined,
            label: '活跃',
            value: arousalLabel,
            color: arousal > 0.7 ? Colors.orangeAccent : Colors.cyanAccent,
            isDark: isDark,
          ),
          const SizedBox(height: 8),
          // 响应策略
          _buildCognitiveRow(
            icon: Icons.route_outlined,
            label: '策略',
            value: '自然对话',
            color: Colors.tealAccent,
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildCognitiveRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required bool isDark,
  }) {
    return Row(
      children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.8)),
        const SizedBox(width: 8),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withValues(alpha: isDark ? 0.2 : 0.3), width: 0.5),
          ),
          child: Text(
            value,
            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  /// 内心独白面板 - 自适应高度，无内部滚动条
  Widget _buildMonologuePanel(AppEngine engine, bool isDark) {
    final rawText = engine.streamingMonologue;
    final personaName = engine.personaConfig['name'] ?? '小悠';
    
    // 清理 XML 标签
    final cleanedText = _cleanXmlTags(rawText);
    
    if (cleanedText.isEmpty) {
      return Container(
        height: 80,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.05),
          ),
        ),
        child: Text(
          '等候指令中...',
          style: TextStyle(fontSize: 12, color: isDark ? Colors.white24 : Colors.black45),
        ),
      );
    }
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1C22) : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFFFFB74D).withValues(alpha: 0.2) : const Color(0xFFFFB74D).withValues(alpha: 0.3),
        ),
        boxShadow: isDark ? [
          BoxShadow(
            color: const Color(0xFFFFB74D).withValues(alpha: 0.05),
            blurRadius: 10,
            spreadRadius: -2,
          )
        ] : [],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // 标题区域
          Row(
            children: [
              Icon(Icons.auto_awesome, size: 14, color: const Color(0xFFFFB74D)),
              const SizedBox(width: 8),
              Text(
                '$personaName 的思维流',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? const Color(0xFFFFB74D).withValues(alpha: 0.8) : const Color(0xFFD87C00),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // 自适应高度的文本内容
          SelectableText(
            cleanedText,
            style: TextStyle(
              fontSize: 13,
              height: 1.6,
              color: isDark ? Colors.white.withValues(alpha: 0.6) : Colors.black87,
              fontFamily: 'Georgia',
            ),
          ),
        ],
      ),
    );
  }
  
  /// 清理 XML 标签 (多策略版: 适配流式传输场景)
  static String _cleanXmlTags(String text) {
    var cleaned = text;
    
    // 1. 移除完整的 XML 标签 (含属性)
    cleaned = cleaned.replaceAll(RegExp(r'</?[a-zA-Z][a-zA-Z0-9]*(?:\s+[^>]*)?>'), '');
    
    // 2. 移除末尾残留的起始不完整标签 (流式场景): <thou, <stra
    cleaned = cleaned.replaceAll(RegExp(r'</?[a-zA-Z]{1,15}$'), '');
    
    // 3. 移除开头残留的闭合不完整标签: ght>, tegy>
    cleaned = cleaned.replaceAll(RegExp(r'^[a-zA-Z]{1,15}>'), '');
    
    // 4. 移除开头的单独 > 或 />
    cleaned = cleaned.replaceAll(RegExp(r'^/?>'), '');
    
    // 5. 移除末尾的单独 < 或 </
    cleaned = cleaned.replaceAll(RegExp(r'</?$'), '');
    
    return cleaned.trim();
  }

  String _formatTokenCount(int tokens) {
    if (tokens >= 1000000) return '${(tokens / 1000000).toStringAsFixed(1)}M';
    if (tokens >= 1000) return '${(tokens / 1000).toStringAsFixed(1)}K';
    return tokens.toString();
  }
}

/// 情绪变化曲线绘制器
class _EmotionCurvePainter extends CustomPainter {
  final List<double> data;
  final Color color;
  final bool isDark;
  final bool normalize; // true: -1~1, false: 0~1

  _EmotionCurvePainter({
    required this.data,
    required this.color,
    required this.isDark,
    this.normalize = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = color.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    
    final paddingY = 4.0;
    final drawHeight = size.height - paddingY * 2;
    
    for (int i = 0; i < data.length; i++) {
      final x = data.length == 1 ? size.width / 2 : (i / (data.length - 1)) * size.width;
      
      // 归一化 y 值到 0~1 范围
      double normalizedY;
      if (normalize) {
        normalizedY = (data[i] + 1) / 2; // -1~1 -> 0~1
      } else {
        normalizedY = data[i]; // 已经是 0~1
      }
      
      final y = paddingY + drawHeight * (1 - normalizedY);
      
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }
    
    // 完成填充路径
    fillPath.lineTo(size.width, size.height);
    fillPath.close();
    
    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
    
    // 绘制最后一个点的圆点
    if (data.isNotEmpty) {
      final lastX = size.width;
      double lastNormalized = normalize ? (data.last + 1) / 2 : data.last;
      final lastY = paddingY + drawHeight * (1 - lastNormalized);
      
      canvas.drawCircle(Offset(lastX, lastY), 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _EmotionCurvePainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
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

    // 绘制网格 - 温暖色系
    final warmAccent = isDark ? const Color(0xFFFFB74D) : const Color(0xFF8D6E63);
    final gridPaint = Paint()
      ..color = warmAccent.withValues(alpha: 0.25)
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

    // 绘制数据区域 - 温暖琥珀色
    final dataPath = Path();
    final dataPaint = Paint()
      ..color = const Color(0xFFFFB74D).withValues(alpha: 0.35)
      ..style = PaintingStyle.fill;
    final dataStrokePaint = Paint()
      ..color = const Color(0xFFFFB74D)
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

    // 绘制数据点 - 温暖色
    final dotPaint = Paint()
      ..color = const Color(0xFFFFCC80)
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
    // 【CRITICAL FIX】空数据安全检查 - 防止 data.last 崩溃
    if (data.isEmpty) return;
    
    // 温暖琥珀色系
    final warmAmber = const Color(0xFFFFB74D);
    final paint = Paint()
      ..color = warmAmber
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          warmAmber.withValues(alpha: 0.35),
          warmAmber.withValues(alpha: 0.0),
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

    // 绘制发光点 - 温暖色
    final dotPaint = Paint()
      ..color = const Color(0xFFFFCC80)
      ..style = PaintingStyle.fill;
    final lastX = (data.length - 1) * step;
    final lastY = midY - data.last * amplitude;
    canvas.drawCircle(Offset(lastX, lastY), 4, dotPaint);
    
    // 发光效果 - 温暖光晕
    final glowPaint = Paint()
      ..color = const Color(0xFFFFB74D).withValues(alpha: 0.35)
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
