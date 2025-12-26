import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../settings_loader.dart';

/// 人格状态服务 - 使用动态 YAML 配置
class PersonaService {
  final SharedPreferences prefs;
  late Map<String, dynamic> state;

  PersonaService(this.prefs) {
    _load();
    _applyEmotionDecay();
  }

  void _load() {
    final str = prefs.getString(AppConfig.personaKey);
    if (str != null && str.isNotEmpty) {
      try {
        state = jsonDecode(str);
      } catch (e) {
        state = _defaultState();
      }
    } else {
      state = _defaultState();
    }
  }

  Map<String, dynamic> _defaultState() {
    return {
      'emotion': {
        'valence': 0.1,
        'arousal': 0.5,
        'quadrant': '平静',
        'intensity': '平和'
      },
      'intimacy': 0.1,
      'interactions': 0,
      'lastInteraction': DateTime.now().toIso8601String(),
    };
  }

  Future<void> save() async {
    await prefs.setString(AppConfig.personaKey, jsonEncode(state));
  }

  Map<String, dynamic> get emotion => state['emotion'] ?? {};
  double get intimacy => (state['intimacy'] ?? 0.1).toDouble();
  int get interactions => state['interactions'] ?? 0;
  
  DateTime? get lastInteraction {
    final str = state['lastInteraction'];
    if (str == null) return null;
    return DateTime.tryParse(str);
  }

  /// 情绪衰减 - 使用 SettingsLoader 配置
  void _applyEmotionDecay() {
    final last = lastInteraction;
    if (last == null) return;
    
    final now = DateTime.now();
    final hoursPassed = now.difference(last).inHours;
    
    
    if (hoursPassed < 1) return;
    
    var em = state['emotion'];
    if (em == null) return;
    
    double v = (em['valence'] ?? 0.0).toDouble();
    double a = (em['arousal'] ?? 0.5).toDouble();
    
    const baseValence = 0.0;
    const baseArousal = 0.5;
    
    // 使用 SettingsLoader 动态读取配置
    final valenceDecay = SettingsLoader.valenceDecayRate * hoursPassed.clamp(0, 24);
    final arousalDecay = SettingsLoader.arousalDecayRate * hoursPassed.clamp(0, 24);
    
    v = v + (baseValence - v) * valenceDecay;
    a = a + (baseArousal - a) * arousalDecay;
    
    em['valence'] = v;
    em['arousal'] = a;
    
    _updateLabels();
    save();
  }

  Future<void> updateInteraction(String userMessage) async {
    state['interactions'] = (state['interactions'] ?? 0) + 1;
    state['lastInteraction'] = DateTime.now().toIso8601String();
    
    // 亲密度增长 - 使用 SettingsLoader 配置
    double currentIntimacy = (state['intimacy'] ?? 0.1).toDouble();
    double growth = SettingsLoader.intimacyGrowthRate;
    if (userMessage.length > 20) growth += 0.003;
    state['intimacy'] = (currentIntimacy + growth).clamp(0.0, 1.0);
    
    // 情绪波动 - 使用 SettingsLoader 配置
    var em = state['emotion'];
    if (em == null) {
      em = {'valence': 0.0, 'arousal': 0.5};
      state['emotion'] = em;
    }
    
    double v = (em['valence'] ?? 0.0).toDouble();
    double a = (em['arousal'] ?? 0.5).toDouble();
    
    final intimacyBuffer = 1.0 - (state['intimacy'] ?? 0.1) * SettingsLoader.intimacyBufferFactor;
    final valenceChange = SettingsLoader.baseValenceChange * intimacyBuffer;
    final arousalChange = SettingsLoader.baseArousalChange * intimacyBuffer;
    
    if (v < 0.8) v += valenceChange;
    a = (a + arousalChange).clamp(0.0, 1.0);
    
    if (v > 0.9) v -= SettingsLoader.boundarySoftness;
    
    em['valence'] = v;
    em['arousal'] = a;
    
    _updateLabels();
    await save();
  }

  void _updateLabels() {
    var em = state['emotion'];
    if (em == null) return;
    
    double v = (em['valence'] ?? 0.0).toDouble();
    double a = (em['arousal'] ?? 0.5).toDouble();
    
    String quadrant = '平静';
    if (v > 0.3 && a >= 0.5) {
      quadrant = '兴奋';
    } else if (v > 0.3) {
      quadrant = '开心';
    } else if (v < -0.3 && a < 0.5) {
      quadrant = '难过';
    } else if (v < -0.3) {
      quadrant = '烦躁';
    } else if (a > 0.6) {
      quadrant = '紧张';
    }
    
    final intensity = (v.abs() > SettingsLoader.highEmotionalIntensity || 
                       a.abs() > 0.7) ? '强烈' : '平和';
    
    em['quadrant'] = quadrant;
    em['intensity'] = intensity;
  }

  /// 更新亲密度（用于外部调节，如衰减逻辑）
  void updateIntimacy(double val) {
    state['intimacy'] = val.clamp(0.0, 1.0);
    save();
  }
}
