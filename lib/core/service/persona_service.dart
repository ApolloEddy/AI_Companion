// PersonaService - 人格状态仓储服务
//
// 【重构说明】
// 实现 Repository 模式，分离工厂配置 (YAML) 与运行时状态 (Persistence)
//
// 加载逻辑：
// 1. Cold Boot: SharedPreferences 为空 -> 从 YAML 模板加载 -> 立即持久化
// 2. Hot Boot: SharedPreferences 有数据 -> 从持久化加载
//
// 职责：
// - 管理 PersonaPolicy 的生命周期
// - 管理情绪/亲密度的运行时状态
// - 提供持久化和更新接口

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../config.dart';
import '../settings_loader.dart';
import '../policy/persona_policy.dart';

/// 人格状态服务 - Repository 模式
class PersonaService {
  static const String _personaPolicyKey = 'runtime_persona_policy';
  
  final SharedPreferences prefs;
  late Map<String, dynamic> state;
  
  // 【新增】人格策略实例
  PersonaPolicy? _personaPolicy;
  bool _isInitialized = false;

  PersonaService(this.prefs) {
    _loadState();
    _applyEmotionDecay();
  }
  
  /// 获取当前人格策略
  PersonaPolicy get personaPolicy {
    if (_personaPolicy == null) {
      throw StateError('PersonaService not initialized. Call init() first.');
    }
    return _personaPolicy!;
  }
  
  /// 是否已初始化
  bool get isInitialized => _isInitialized;

  // ========== 初始化逻辑 ==========

  /// 异步初始化 - 加载人格策略
  /// 
  /// Cold Boot: 从 YAML 模板加载
  /// Hot Boot: 从 SharedPreferences 加载
  Future<void> init() async {
    if (_isInitialized) return;
    
    final jsonStr = prefs.getString(_personaPolicyKey);
    
    if (jsonStr == null || jsonStr.isEmpty) {
      // Cold Boot: 从 YAML 模板加载
      print('[PersonaService] Cold boot - loading from YAML template');
      final template = await SettingsLoader.loadPersonaTemplate();
      _personaPolicy = PersonaPolicy.fromJson(template);
      await _savePersonaPolicy();
    } else {
      // Hot Boot: 从持久化加载
      print('[PersonaService] Hot boot - loading from SharedPreferences');
      try {
        final json = jsonDecode(jsonStr) as Map<String, dynamic>;
        _personaPolicy = PersonaPolicy.fromJson(json);
      } catch (e) {
        print('[PersonaService] Failed to parse persona, falling back to template: $e');
        final template = await SettingsLoader.loadPersonaTemplate();
        _personaPolicy = PersonaPolicy.fromJson(template);
        await _savePersonaPolicy();
      }
    }
    
    _isInitialized = true;
    print('[PersonaService] Initialized with persona: ${_personaPolicy?.name}');
  }

  /// 更新人格策略并持久化
  Future<void> updatePersonaPolicy(PersonaPolicy newPolicy) async {
    _personaPolicy = newPolicy;
    await _savePersonaPolicy();
    print('[PersonaService] PersonaPolicy updated and saved');
  }

  /// 从配置 Map 更新人格
  Future<void> updatePersonaConfig(Map<String, dynamic> config) async {
    _personaPolicy = PersonaPolicy.fromJson(config);
    await _savePersonaPolicy();
    print('[PersonaService] PersonaPolicy updated from config');
  }

  /// 持久化人格策略
  Future<void> _savePersonaPolicy() async {
    if (_personaPolicy == null) return;
    final jsonStr = jsonEncode(_personaPolicy!.toJson());
    await prefs.setString(_personaPolicyKey, jsonStr);
  }

  /// 重置为工厂默认值
  Future<void> resetToFactory() async {
    print('[PersonaService] Resetting to factory defaults');
    final template = await SettingsLoader.loadPersonaTemplate();
    _personaPolicy = PersonaPolicy.fromJson(template);
    await _savePersonaPolicy();
  }

  // ========== 情绪/亲密度状态管理 (保留原有逻辑) ==========

  void _loadState() {
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
