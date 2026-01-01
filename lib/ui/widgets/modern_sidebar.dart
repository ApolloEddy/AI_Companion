import 'dart:math';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_engine.dart';
import '../../core/provider/intimacy_color_provider.dart';
import 'persona_editor_dialog.dart';
import 'personality_radar_chart.dart'; // 【新增】
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
  // 情绪历史记录移至 EmotionEngine 管理，此处不再维护
  
  // 父级 ListView 滚动控制器
  
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
    // 更新情绪历史 (已移至 EmotionEngine 自动处理)
    // _updateEmotionHistory(valence, arousal);
    
    // 人格参数
    final config = engine.personaConfig;
    final personaName = config['name'] ?? 'April';
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
            final position = _listScrollController.position;
            // 【智能滚动】只有当用户接近底部时才自动滚动
            // 阈值设为 120 像素（约 4-5 行文本高度），允许一定的容差
            final isAtBottom = position.maxScrollExtent - position.pixels < 120.0;
            
            if (isAtBottom) {
              _listScrollController.animateTo(
                position.maxScrollExtent,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
              );
            }
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
                        valenceHistory: engine.emotionEngine.valenceHistory,
                        arousalHistory: engine.emotionEngine.arousalHistory,
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
                      
                      // 【新增】情绪象限可视化
                      _buildSectionTitle('情绪象限', isDark: isDark),
                      _buildEmotionQuadrant(valence: valence, arousal: arousal, isDark: isDark),
                      
                      const SizedBox(height: 24),
                      
                      // 【新增】关系稳定性监视器
                      _buildSectionTitle('关系成长效率', isDark: isDark),
                      _buildStabilityMonitor(engine, isDark),
                      
                      const SizedBox(height: 24),
                      
                      // 核心状态网格（置底）
                      _buildSectionTitle('核心状态', isDark: isDark),
                      _buildStatusGrid(engine, isDark),
                      
                      const SizedBox(height: 24),
                      
                      // 【新增】Big Five 人格雷达图
                      _buildSectionTitle('五因素人格模型', isDark: isDark),
                      _buildBigFiveRadar(engine, isDark),
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
    final personaName = engine.personaConfig['name'] ?? 'AI';
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
            child: Builder(
              builder: (context) {
                // 性别颜色逻辑
                final gender = engine.personaConfig['gender']?.toString().toLowerCase() ?? '';
                Color avatarColor;
                if (gender == 'male' || gender == 'man' || gender == '男' || gender == '男性') {
                  avatarColor = Colors.blueAccent;
                } else if (gender == 'female' || gender == 'woman' || gender == '女' || gender == '女性') {
                  avatarColor = Colors.pinkAccent;
                } else {
                  avatarColor = Colors.amber; // 中性/未知/其他
                }

                if (engine.aiAvatarPath != null && engine.aiAvatarPath!.isNotEmpty) {
                  return CircleAvatar(
                    radius: 28,
                    backgroundColor: isDark ? Colors.grey[900] : Colors.grey[200],
                    backgroundImage: FileImage(File(engine.aiAvatarPath!)),
                  );
                } else {
                  return Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: avatarColor.withValues(alpha: isDark ? 0.3 : 0.2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: avatarColor.withValues(alpha: 0.5),
                        width: 1.5,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        personaName.isNotEmpty ? personaName.substring(0, 1) : 'A',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: avatarColor,
                        ),
                      ),
                    ),
                  );
                }
              },
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


  /// 【Research-Grade】Big Five 人格雷达图 - 五边形可视化
  Widget _buildBigFiveRadar(AppEngine engine, bool isDark) {
    final traits = engine.personalityEngine.traits;
    // 获取经过亲密度修饰的有效人格
    final effective = engine.personalityEngine.getEffectiveTraits(
      intimacy: engine.intimacyEngine.intimacy,
    );

    final initial = engine.personalityEngine.initialTraits ?? traits;

    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252229) : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFFFFB74D).withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: PersonalityRadarChart(
          initialTraits: {
            'openness': initial.openness,
            'conscientiousness': initial.conscientiousness,
            'extraversion': initial.extraversion,
            'agreeableness': initial.agreeableness,
            'neuroticism': initial.neuroticism,
          },
          effectiveTraits: {
            'openness': effective.openness,
            'conscientiousness': effective.conscientiousness,
            'extraversion': effective.extraversion,
            'agreeableness': effective.agreeableness,
            'neuroticism': effective.neuroticism,
          },
          mode: RadarMode.monitoring,
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
                  // 获取渐变色 (左深右浅)
                  final gradientColors = IntimacyColorProvider.getGradientColors(intimacy);
                  
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 500),
                    height: 8,
                    width: constraints.maxWidth * intimacy.clamp(0.0, 1.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: gradientColors.last.withValues(alpha: 0.4),
                          blurRadius: 8,
                          spreadRadius: 1, // 增加发光扩散
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

  /// 【UI审计】使用统一的 IntimacyColorProvider 获取亲密度颜色
  Color _getIntimacyColor(double intimacy) {
    return IntimacyColorProvider.getIntimacyColor(intimacy);
  }

  /// 【新增】情绪象限可视化 - Valence-Arousal 二维坐标系
  Widget _buildEmotionQuadrant({
    required double valence,
    required double arousal,
    required bool isDark,
  }) {
    return Container(
      height: 180,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252229) : Colors.grey.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFFFFB74D).withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.2),
        ),
      ),
      child: CustomPaint(
        size: const Size(double.infinity, double.infinity),
        painter: _EmotionQuadrantPainter(
          valence: valence,
          arousal: arousal,
          isDark: isDark,
        ),
      ),
    );
  }

  /// 【新增】关系稳定性监视器 - 显示增长效率曲线和冷却状态
  Widget _buildStabilityMonitor(AppEngine engine, bool isDark) {
    final intimacyState = engine.intimacyEngine.currentState;
    final efficiency = intimacyState.growthEfficiency;
    final isCooling = intimacyState.isCooling;
    final coolingRemaining = intimacyState.coolingRemainingMinutes;
    
    // 获取增长效率曲线数据
    final curveData = engine.intimacyEngine.getGrowthEfficiencyCurve();
    
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 当前状态行
          Row(
            children: [
              // 当前效率
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前效率',
                      style: TextStyle(fontSize: 10, color: isDark ? Colors.white38 : Colors.black38),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${efficiency.toStringAsFixed(1)}%',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.greenAccent : const Color(0xFF2E7D32),
                      ),
                    ),
                  ],
                ),
              ),
              // 冷却状态
              if (isCooling) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hourglass_bottom, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Text(
                        '冷却中 ${coolingRemaining}分钟',
                        style: TextStyle(fontSize: 11, color: Colors.orange, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ] else ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '正常增长中',
                    style: TextStyle(fontSize: 11, color: isDark ? Colors.greenAccent : const Color(0xFF2E7D32)),
                  ),
                ),
              ],
            ],
          ),
          
          const SizedBox(height: 16),
          
          // 增长效率曲线
          Text(
            '边际收益曲线',
            style: TextStyle(fontSize: 9, color: isDark ? Colors.white30 : Colors.black54, letterSpacing: 0.5),
          ),
          const SizedBox(height: 8),
          Container(
            height: 60,
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.02) : Colors.black.withValues(alpha: 0.02),
              borderRadius: BorderRadius.circular(6),
            ),
            child: CustomPaint(
              size: const Size(double.infinity, 60),
              painter: _EfficiencyCurvePainter(
                curveData: curveData,
                currentIntimacy: engine.intimacyEngine.intimacy,
                isDark: isDark,
              ),
            ),
          ),
          
          const SizedBox(height: 8),
          
          // 说明
          Text(
            '亲密度越高，单次交互增长越慢（边际递减）',
            style: TextStyle(fontSize: 9, color: isDark ? Colors.white24 : Colors.black26),
          ),
        ],
      ),
    );
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
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.2),
          color.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();
    
    final paddingY = 4.0;
    final drawHeight = size.height - paddingY * 2;
    
    // 1. 将数据转换为坐标点
    List<Offset> points = [];
    for (int i = 0; i < data.length; i++) {
        final x = data.length == 1 ? size.width / 2 : (i / (data.length - 1)) * size.width;
        
        // 归一化 y 值到 0~1 范围
        double normalizedY;
        if (normalize) {
          normalizedY = (data[i] + 1) / 2; // -1~1 -> 0~1
        } else {
          normalizedY = data[i]; // 已经是 0~1
        }
        
        // 限制在有效范围内
        normalizedY = normalizedY.clamp(0.0, 1.0);
        
        final y = paddingY + drawHeight * (1 - normalizedY);
        points.add(Offset(x, y));
    }

    if (points.isEmpty) return;

    // 2. 绘制平滑曲线 (Catmull-Rom Spline to Cubic Bezier)
    path.moveTo(points[0].dx, points[0].dy);
    fillPath.moveTo(points[0].dx, size.height);
    fillPath.lineTo(points[0].dx, points[0].dy);

    if (points.length == 1) {
       path.lineTo(points[0].dx, points[0].dy); // 单点不动
    } else {
      for (int i = 0; i < points.length - 1; i++) {
        final p0 = i > 0 ? points[i - 1] : points[i];
        final p1 = points[i];
        final p2 = points[i + 1];
        final p3 = i < points.length - 2 ? points[i + 2] : p2;

        final cp1 = p1 + (p2 - p0) * 0.15; // 0.15 系数调整平滑度 (类似 tension)
        final cp2 = p2 - (p3 - p1) * 0.15;

        path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, p2.dx, p2.dy);
        // fillPath 只是简单的闭合，后续还要跟随 curve？
        // 实际上 fillPath 需要完全跟随 path 的边缘
      }
    }
    
    // 正确的做法：fillPath 应该基于 path 构建
    // 由于 path 是复杂的曲线，我们不能简单 lineTo
    // 我们复制 path 并闭合它
    fillPath.reset();
    fillPath.addPath(path, Offset.zero);
    fillPath.lineTo(points.last.dx, size.height);
    fillPath.lineTo(points.first.dx, size.height);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);
    
    // 绘制最后一个点的圆点
    if (points.isNotEmpty) {
      canvas.drawCircle(points.last, 3, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(covariant _EmotionCurvePainter oldDelegate) {
    return oldDelegate.data != data || oldDelegate.color != color;
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

/// 【新增】情绪象限绘制器 - Valence-Arousal 二维坐标系
class _EmotionQuadrantPainter extends CustomPainter {
  final double valence;  // -1 ~ 1 (横轴)
  final double arousal;  // 0 ~ 1 (纵轴)
  final bool isDark;

  _EmotionQuadrantPainter({
    required this.valence,
    required this.arousal,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final padding = 20.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;
    final centerX = size.width / 2;
    final centerY = size.height / 2;

    // 背景色
    final bgColor = isDark ? Colors.white.withValues(alpha: 0.03) : Colors.black.withValues(alpha: 0.02);
    final paint = Paint()..color = bgColor..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(padding, padding, chartWidth, chartHeight), paint);

    // 坐标轴
    final axisPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.15)
      ..strokeWidth = 1;
    // 横轴 (Valence)
    canvas.drawLine(Offset(padding, centerY), Offset(size.width - padding, centerY), axisPaint);
    // 纵轴 (Arousal)
    canvas.drawLine(Offset(centerX, padding), Offset(centerX, size.height - padding), axisPaint);

    // 象限标签
    final labelStyle = TextStyle(
      fontSize: 9,
      color: isDark ? Colors.white.withValues(alpha: 0.4) : Colors.black.withValues(alpha: 0.4),
    );
    
    // 四个象限标签
    _drawLabel(canvas, '兴奋', Offset(size.width - padding - 30, padding + 10), labelStyle);
    _drawLabel(canvas, '愉悦', Offset(size.width - padding - 30, size.height - padding - 20), labelStyle);
    _drawLabel(canvas, '焦躁', Offset(padding + 5, padding + 10), labelStyle);
    _drawLabel(canvas, '低落', Offset(padding + 5, size.height - padding - 20), labelStyle);

    // 轴标签
    _drawLabel(canvas, '消极', Offset(padding + 5, centerY - 15), labelStyle);
    _drawLabel(canvas, '积极', Offset(size.width - padding - 30, centerY - 15), labelStyle);
    _drawLabel(canvas, '低活力', Offset(centerX + 5, size.height - padding - 5), labelStyle);
    _drawLabel(canvas, '高活力', Offset(centerX + 5, padding + 5), labelStyle);

    // 当前情绪点
    final pointX = centerX + (valence * chartWidth / 2);
    final pointY = centerY - ((arousal - 0.5) * chartHeight); // arousal 0~1 映射

    // 发光效果
    final glowPaint = Paint()
      ..color = const Color(0xFFFFB74D).withValues(alpha: 0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 15);
    canvas.drawCircle(Offset(pointX, pointY), 20, glowPaint);

    // 当前点
    final pointPaint = Paint()
      ..color = const Color(0xFFFFB74D)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(pointX, pointY), 8, pointPaint);

    // 内部白点
    final innerPaint = Paint()
      ..color = isDark ? Colors.black : Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(pointX, pointY), 4, innerPaint);
  }

  void _drawLabel(Canvas canvas, String text, Offset offset, TextStyle style) {
    final textSpan = TextSpan(text: text, style: style);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _EmotionQuadrantPainter oldDelegate) {
    return oldDelegate.valence != valence || 
           oldDelegate.arousal != arousal || 
           oldDelegate.isDark != isDark;
  }
}

/// 【新增】效率曲线绘制器 - 显示边际递减曲线
class _EfficiencyCurvePainter extends CustomPainter {
  final List<Map<String, double>> curveData;
  final double currentIntimacy;
  final bool isDark;

  _EfficiencyCurvePainter({
    required this.curveData,
    required this.currentIntimacy,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (curveData.isEmpty) return;

    final padding = 4.0;
    final chartWidth = size.width - padding * 2;
    final chartHeight = size.height - padding * 2;

    // 绘制曲线
    final curvePaint = Paint()
      ..color = isDark ? Colors.greenAccent : const Color(0xFF2E7D32)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = (isDark ? Colors.greenAccent : const Color(0xFF2E7D32)).withValues(alpha: 0.15)
      ..style = PaintingStyle.fill;

    final path = Path();
    final fillPath = Path();

    // 找到最大效率值用于归一化
    double maxEfficiency = 0;
    for (final item in curveData) {
      if (item['efficiency']! > maxEfficiency) {
        maxEfficiency = item['efficiency']!;
      }
    }
    if (maxEfficiency == 0) maxEfficiency = 1;

    for (int i = 0; i < curveData.length; i++) {
      final item = curveData[i];
      final x = padding + (item['intimacy']! * chartWidth);
      final y = padding + chartHeight * (1 - item['efficiency']! / maxEfficiency);

      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height - padding);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    // 完成填充路径
    fillPath.lineTo(padding + chartWidth, size.height - padding);
    fillPath.close();

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, curvePaint);

    // 标记当前亲密度位置
    final currentX = padding + (currentIntimacy.clamp(0, 1) * chartWidth);
    
    // 垂直虚线
    final dashPaint = Paint()
      ..color = const Color(0xFFFFB74D).withValues(alpha: 0.5)
      ..strokeWidth = 1;
    
    for (double y = padding; y < size.height - padding; y += 4) {
      canvas.drawLine(
        Offset(currentX, y), 
        Offset(currentX, (y + 2).clamp(0, size.height - padding)), 
        dashPaint
      );
    }

    // 当前点标记
    // 找到对应的效率值
    double currentEfficiency = 0;
    for (final item in curveData) {
      if ((item['intimacy']! - currentIntimacy).abs() < 0.15) {
        currentEfficiency = item['efficiency']!;
        break;
      }
    }
    final currentY = padding + chartHeight * (1 - currentEfficiency / maxEfficiency);
    
    final pointPaint = Paint()
      ..color = const Color(0xFFFFB74D)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(currentX, currentY), 5, pointPaint);
  }

  @override
  bool shouldRepaint(covariant _EfficiencyCurvePainter oldDelegate) {
    return oldDelegate.currentIntimacy != currentIntimacy ||
           oldDelegate.isDark != isDark;
  }
}
