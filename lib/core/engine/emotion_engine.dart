// EmotionEngine - 情绪计算引擎
//
// 设计原理：
// - 【必须保留】Valence/Arousal 向量计算逻辑
// - 从 PersonaService 中分离出来，专注于情绪状态管理
// - 支持实时衰减（由 ConversationEngine 的 Timer 调用）

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../settings_loader.dart';

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
  DateTime _lastUpdated = DateTime.now();

  // 基准值 (衰减目标)
  static const double _baseValence = 0.0;
  static const double _baseArousal = 0.5;

  final SharedPreferences prefs;

  EmotionEngine(this.prefs) {
    _load();
  }

  // ========== 属性访问 ==========

  double get valence => _valence;
  double get arousal => _arousal;
  DateTime get lastUpdated => _lastUpdated;

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
        final lastStr = data['lastUpdated'];
        if (lastStr != null) {
          _lastUpdated = DateTime.tryParse(lastStr) ?? DateTime.now();
        }
      } catch (e) {
        // 使用默认值
      }
    }
  }

  Future<void> save() async {
    final data = {
      'valence': _valence,
      'arousal': _arousal,
      'lastUpdated': _lastUpdated.toIso8601String(),
    };
    await prefs.setString('${AppConfig.personaKey}_emotion', jsonEncode(data));
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

    _lastUpdated = DateTime.now();
    
    // 日志输出用于调试
    print('[EmotionEngine] decay applied: valence=$_valence, arousal=$_arousal');
    
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
  Future<void> applyInteractionImpact(String message, double intimacy) async {
    // 使用 SettingsLoader 读取配置
    final intimacyBuffer = 1.0 - intimacy * SettingsLoader.intimacyBufferFactor;
    final valenceChange = SettingsLoader.baseValenceChange * intimacyBuffer;
    final arousalChange = SettingsLoader.baseArousalChange * intimacyBuffer;

    // 应用变化
    if (_valence < 0.8) {
      _valence += valenceChange;
    }
    _arousal = (_arousal + arousalChange).clamp(0.0, 1.0);

    // 边界软化：接近上限时减缓增长
    if (_valence > 0.9) {
      _valence -= SettingsLoader.boundarySoftness;
    }

    // 消息长度影响（较长消息表示更投入的交流）
    if (message.length > 50) {
      _valence = (_valence + 0.02).clamp(-1.0, 1.0);
      _arousal = (_arousal + 0.03).clamp(0.0, 1.0);
    }

    _lastUpdated = DateTime.now();
    await save();
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
  String getEmotionDescription() {
    final labels = getLabels();
    return '当前心情：${labels.quadrant}，${labels.intensity}';
  }

  /// 手动设置情绪 (用于测试或特殊场景)
  Future<void> setEmotion({double? valence, double? arousal}) async {
    if (valence != null) _valence = valence.clamp(-1.0, 1.0);
    if (arousal != null) _arousal = arousal.clamp(0.0, 1.0);
    _lastUpdated = DateTime.now();
    await save();
  }

  /// 重置为默认状态
  Future<void> reset() async {
    _valence = 0.1;
    _arousal = 0.5;
    _lastUpdated = DateTime.now();
    await save();
  }
}
