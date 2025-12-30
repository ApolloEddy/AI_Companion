// EmotionEngine - 情绪计算引擎
//
// 设计原理：
// - 【必须保留】Valence/Arousal 向量计算逻辑
// - 从 PersonaService 中分离出来，专注于情绪状态管理
// - 支持实时衰减（由 ConversationEngine 的 Timer 调用）

import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../settings_loader.dart';
import '../perception/perception_processor.dart';

/// 情绪标签
class EmotionLabels {
  final String quadrant;   // 象限标签：平静/兴奋/开心/难过/烦躁/紧张
  final String intensity;  // 强度标签：平和/强烈

  const EmotionLabels({
    required this.quadrant,
    required this.intensity,
  });

  @override
  String toString() => '$quadrant，$intensity';
}

/// 情绪状态快照
class EmotionState {
  final double valence;    // 效价 (-1 ~ 1): 负面 ↔ 正面
  final double arousal;    // 唤醒度 (0 ~ 1): 低活力 ↔ 高活力
  final EmotionLabels labels;
  final DateTime lastUpdated;

  const EmotionState({
    required this.valence,
    required this.arousal,
    required this.labels,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'valence': valence,
      'arousal': arousal,
      'quadrant': labels.quadrant,
      'intensity': labels.intensity,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

/// 情绪引擎 - 保留 Valence/Arousal 向量计算
class EmotionEngine {
  // 情绪向量
  double _valence = 0.1;   // 效价 (-1 ~ 1)
  double _arousal = 0.5;   // 唤醒度 (0 ~ 1)
  double _resentment = 0.0; // 【Phase 3】怨恨值 (0 ~ 1)
  DateTime _lastUpdated = DateTime.now();

  // 基准值 (衰减目标)
  static const double _baseValence = 0.0;
  static const double _baseArousal = 0.5;

  // 情绪历史记录
  List<double> _valenceHistory = [];
  List<double> _arousalHistory = [];
  static const int _maxHistoryLength = 30;

  final SharedPreferences prefs;

  EmotionEngine(this.prefs) {
    _load();
  }

  // ========== 属性访问 ==========

  double get valence => _valence;
  double get arousal => _arousal;
  double get resentment => _resentment; // 【Phase 3】怨恨值访问器
  DateTime get lastUpdated => _lastUpdated;
  
  List<double> get valenceHistory => List.unmodifiable(_valenceHistory);
  List<double> get arousalHistory => List.unmodifiable(_arousalHistory);
  
  /// 【Phase 5】Meltdown 检测 - 情绪崩溃阈值
  /// 当怨恨值 > 0.8 且 效价 < -0.7 时触发
  bool get isMeltdown => _resentment > 0.8 && _valence < -0.7;

  /// 获取当前情绪状态
  EmotionState get currentState => EmotionState(
    valence: _valence,
    arousal: _arousal,
    labels: getLabels(),
    lastUpdated: _lastUpdated,
  );

  /// 获取情绪 Map (向后兼容)
  Map<String, dynamic> get emotionMap => {
    'valence': _valence,
    'arousal': _arousal,
    'quadrant': getLabels().quadrant,
    'intensity': getLabels().intensity,
  };

  // ========== 持久化 ==========

  void _load() {
    final str = prefs.getString('${AppConfig.personaKey}_emotion');
    if (str != null) {
      try {
        final data = jsonDecode(str);
        _valence = (data['valence'] ?? 0.1).toDouble();
        _arousal = (data['arousal'] ?? 0.5).toDouble();
        _resentment = (data['resentment'] ?? 0.0).toDouble(); // 【Phase 3】加载怨恨值
        
        // 加载历史记录
        if (data['valenceHistory'] != null) {
          _valenceHistory = (data['valenceHistory'] as List).map((e) => (e as num).toDouble()).toList();
        }
        if (data['arousalHistory'] != null) {
          _arousalHistory = (data['arousalHistory'] as List).map((e) => (e as num).toDouble()).toList();
        }
        
        final lastStr = data['lastUpdated'];
        if (lastStr != null) {
          _lastUpdated = DateTime.tryParse(lastStr) ?? DateTime.now();
        }
      } catch (e) {
        // 使用默认值
        print('[EmotionEngine] Load failed: $e');
      }
    }
  }

  Future<void> save() async {
    final data = {
      'valence': _valence,
      'arousal': _arousal,
      'resentment': _resentment, // 【Phase 3】保存怨恨值
      'valenceHistory': _valenceHistory,
      'arousalHistory': _arousalHistory,
      'lastUpdated': _lastUpdated.toIso8601String(),
    };
    await prefs.setString('${AppConfig.personaKey}_emotion', jsonEncode(data));
  }
  
  void _recordHistory() {
    bool changed = false;
    
    // 仅当数值有明显变化时才记录 (阈值 0.01)，或者历史为空
    if (_valenceHistory.isEmpty || (_valenceHistory.last - _valence).abs() > 0.01) {
      _valenceHistory.add(_valence);
      if (_valenceHistory.length > _maxHistoryLength) {
        _valenceHistory.removeAt(0);
      }
      changed = true;
    }
    
    if (_arousalHistory.isEmpty || (_arousalHistory.last - _arousal).abs() > 0.01) {
      _arousalHistory.add(_arousal);
      if (_arousalHistory.length > _maxHistoryLength) {
        _arousalHistory.removeAt(0);
      }
      changed = true;
    }
  }

  // ========== 【必须保留】时间衰减计算 ==========

  /// 应用情绪衰减
  /// 
  /// 原理：情绪随时间向基准值回归
  /// - valence 向 0 回归
  /// - arousal 向 0.5 回归
  /// 
  /// 由 ConversationEngine 的 Timer 定期调用
  void applyDecay(Duration elapsed) {
    final hours = elapsed.inMinutes / 60.0;
    if (hours < 0.1) return; // 太短时间不处理

    // 使用 SettingsLoader 动态读取衰减率
    final valenceDecayRate = SettingsLoader.valenceDecayRate;
    final arousalDecayRate = SettingsLoader.arousalDecayRate;

    // 计算衰减量 (最多按 24 小时计算)
    final effectiveHours = hours.clamp(0.0, 24.0);
    final valenceDecay = valenceDecayRate * effectiveHours;
    final arousalDecay = arousalDecayRate * effectiveHours;

    // 应用衰减：向基准值靠拢
    _valence = _valence + (_baseValence - _valence) * valenceDecay;
    _arousal = _arousal + (_baseArousal - _arousal) * arousalDecay;
    
    // 【Phase 3】怨恨值自然衰减
    _resentment = (_resentment * SettingsLoader.resentmentDecayFactor).clamp(0.0, 1.0);

    _lastUpdated = DateTime.now();
    
    // 日志输出用于调试
    print('[EmotionEngine] decay applied: valence=$_valence, arousal=$_arousal, resentment=$_resentment');
    
    _recordHistory();
    save();
  }

  /// 基于时间差自动衰减 (用于启动时)
  void applyDecaySinceLastUpdate() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastUpdated);
    if (elapsed.inMinutes >= 1) {
      applyDecay(elapsed);
    }
  }

  // ========== 【必须保留】交互影响计算 ==========

  /// 应用交互产生的情绪影响
  /// 
  /// 原理：
  /// - 对话交互通常产生正向情绪
  /// - 高亲密度时情绪变化更平缓（缓冲作用）
  /// - 接近边界时变化减缓（软边界）
  /// - 【Phase 3】怨恨值抑制正面情绪增长
  /// - 【Phase 3】高唤醒度时情绪衰减（疑劳逻辑）
  Future<void> applyInteractionImpact(PerceptionResult perception, double intimacy) async {
    final offense = perception.offensiveness;
    final isNewUser = intimacy < 0.3;

    // 【Phase 6】道歉阀门 (Apology Valve)
    if (perception.underlyingNeed == 'apology') {
      _resentment = (_resentment - 0.4).clamp(0.0, 1.0);
      _valence = (_valence + 0.3).clamp(-1.0, 1.0);
      print('[EmotionEngine] APOLOGY DETECTED: Resentment lowered to $_resentment');
      _lastUpdated = DateTime.now();
      _recordHistory();
      await save();
      return; 
    }

    // 【Phase 2/6】心理创伤逻辑 (Trauma Logic)
    if (offense >= 9) {
      // 9-10级：毁灭性打击，无视宽容协议
      _resentment = (_resentment + (offense - 5) * 0.1).clamp(0.0, 1.0);
      _valence = (_valence - (offense / 10.0) * 1.5).clamp(-1.0, 1.0);
      _arousal = (_arousal + 0.4).clamp(0.0, 1.0);
      print('[EmotionEngine] TRAUMA DETECTED (L9-10): V=$_valence, R=$_resentment');
    } else if (offense >= 6) {
      // 6-8级：中度伤害，新用户怨恨减半
      double resentmentInc = (offense - 5) * 0.1;
      if (isNewUser) resentmentInc *= 0.5;
      
      _resentment = (_resentment + resentmentInc).clamp(0.0, 1.0);
      _valence = (_valence - 0.6).clamp(-1.0, 1.0);
      _arousal = (_arousal + 0.2).clamp(0.0, 1.0);
      print('[EmotionEngine] Moderate Hostility: offense=$offense, resentmentInc=$resentmentInc');
    } else if (offense >= 3) {
      // 3-5级：试探/调侃。新用户不增加怨恨值，仅降低效价
      if (!isNewUser) {
        _resentment = (_resentment + 0.05).clamp(0.0, 1.0);
      }
      _valence = (_valence - 0.2).clamp(-1.0, 1.0);
      _arousal = (_arousal + 0.1).clamp(0.0, 1.0);
      print('[EmotionEngine] Minor/Testing Hostility: offense=$offense, isNewUser=$isNewUser');
    }

    if (offense >= 6) {
      _lastUpdated = DateTime.now();
      _recordHistory();
      await save();
      return; // 遭受中重度伤害后，跳过正向逻辑
    }

    // --- 以下为原有的正向/中性交互逻辑 ---

    // 使用 SettingsLoader 读取配置
    final intimacyBuffer = 1.0 - intimacy * SettingsLoader.intimacyBufferFactor;
    double valenceChange = SettingsLoader.baseValenceChange * intimacyBuffer;
    double arousalChange = SettingsLoader.baseArousalChange * intimacyBuffer;

    // 【Phase 3】原本的负面词汇检测（作为补充）
    // 由于有了 L1 感知，这里可以简化，但保留 social_events 中的负面信号判定
    final detectedNegative = perception.socialEvents.contains('neglect_signal');
    
    if (detectedNegative) {
      _resentment = (_resentment + SettingsLoader.resentmentIncrease).clamp(0.0, 1.0);
    }
    
    // 【Phase 5】非线性怨恨抑制
    if (valenceChange > 0) {
      final sigmoidSuppression = 1.0 / (1.0 + exp(-10 * (_resentment - 0.5)));
      valenceChange *= (1.0 - sigmoidSuppression);
    }
    
    // 【Phase 5】渐进式唤醒度疲劳
    if (_arousal > 0.6) {
      final fatigueMultiplier = (1.0 - (_arousal - 0.6) * 2.5).clamp(0.2, 1.0);
      valenceChange *= fatigueMultiplier;
      arousalChange *= fatigueMultiplier;
    }

    // 应用变化
    if (_valence < 0.8) {
      _valence += valenceChange;
    }
    _arousal = (_arousal + arousalChange).clamp(0.0, 1.0);

    // 边界软化
    if (_valence > 0.9) {
      _valence -= SettingsLoader.boundarySoftness;
    }

    _lastUpdated = DateTime.now();
    _recordHistory();
    await save();
  }

  /// 应用基于反思的情绪偏移 (Reflective Steering)
  Future<void> applyEmotionShift(Map<String, double> shift) async {
    final dv = shift['valence'] ?? 0.0;
    final da = shift['arousal'] ?? 0.0;

    if (dv == 0.0 && da == 0.0) return;

    _valence = (_valence + dv).clamp(-1.0, 1.0);
    _arousal = (_arousal + da).clamp(0.0, 1.0);

    _lastUpdated = DateTime.now();
    _recordHistory();
    await save();
    
    print('[EmotionEngine] Reflective shift applied: DV=$dv, DA=$da -> New V=$_valence, A=$_arousal');
  }

  // ========== 【必须保留】象限标签更新 ==========

  /// 获取情绪标签
  /// 
  /// 基于 Valence-Arousal 二维模型：
  /// - 高 V + 高 A = 兴奋
  /// - 高 V + 低 A = 开心
  /// - 低 V + 低 A = 难过
  /// - 低 V + 高 A = 烦躁
  EmotionLabels getLabels() {
    String quadrant = '平静';
    
    if (_valence > 0.3 && _arousal >= 0.5) {
      quadrant = '兴奋';
    } else if (_valence > 0.3) {
      quadrant = '开心';
    } else if (_valence < -0.3 && _arousal < 0.5) {
      quadrant = '难过';
    } else if (_valence < -0.3) {
      quadrant = '烦躁';
    } else if (_arousal > 0.6) {
      quadrant = '紧张';
    }

    final intensity = (_valence.abs() > SettingsLoader.highEmotionalIntensity || 
                       _arousal.abs() > 0.7) ? '强烈' : '平和';

    return EmotionLabels(quadrant: quadrant, intensity: intensity);
  }

  /// 获取情绪描述文本 (用于 Prompt)
  /// 重构：输出自然语言而非简单的标签
  String getEmotionDescription() {
    // 翻译 Valence (愉悦度)
    String vDesc;
    if (_valence > 0.7) {
      vDesc = '感到非常愉悦和兴奋';
    } else if (_valence > 0.3) {
      vDesc = '心请不错，比较开心';
    } else if (_valence > -0.3) {
      vDesc = '心情平和稳定';
    } else if (_valence > -0.7) {
      vDesc = '有些低落，提不起精神';
    } else {
      vDesc = '感到很难过，甚至有些抑郁';
    }

    // 翻译 Arousal (唤醒度)
    String aDesc;
    if (_arousal > 0.7) {
      aDesc = '充满活力';
    } else if (_arousal > 0.4) {
      aDesc = ''; // 正常活力范围不特意强调，更自然
    } else {
      aDesc = '略显疲惫慵懒';
    }

    final combined = [vDesc, aDesc].where((s) => s.isNotEmpty).join('，');
    return '你现在$combined。';
  }

  /// 手动设置情绪 (用于测试或特殊场景)
  Future<void> setEmotion({double? valence, double? arousal}) async {
    if (valence != null) _valence = valence.clamp(-1.0, 1.0);
    if (arousal != null) _arousal = arousal.clamp(0.0, 1.0);
    _lastUpdated = DateTime.now();
    _recordHistory();
    await save();
  }

  /// 重置为默认状态
  Future<void> reset() async {
    _valence = 0.1;
    _arousal = 0.5;
    _resentment = 0.0; // 【Phase 3】重置怨恨值
    _lastUpdated = DateTime.now();
    _recordHistory();
    await save();
  }
}
