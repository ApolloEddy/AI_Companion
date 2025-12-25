// ProfileService - 用户画像持久化服务
//
// 设计原理：
// - 管理 UserProfile 的加载、保存和更新
// - 提供身份锚点查询接口
// - 支持增量更新，避免覆盖重要数据

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/user_profile.dart';

/// 用户画像服务
class ProfileService {
  static const String _profileKey = 'ai_companion_user_profile';
  
  final SharedPreferences _prefs;
  UserProfile? _cachedProfile;
  
  ProfileService(this._prefs);
  
  /// 获取当前用户画像
  UserProfile get profile {
    if (_cachedProfile == null) {
      _load();
    }
    return _cachedProfile!;
  }
  
  /// 加载用户画像
  void _load() {
    final jsonStr = _prefs.getString(_profileKey);
    if (jsonStr != null) {
      try {
        final json = jsonDecode(jsonStr);
        _cachedProfile = UserProfile.fromJson(json);
      } catch (e) {
        print('[ProfileService] Failed to load profile: $e');
        _cachedProfile = UserProfile.empty();
      }
    } else {
      // 首次使用，创建默认配置
      _cachedProfile = UserProfile.empty();
      _save();
    }
  }
  
  /// 保存用户画像
  Future<void> _save() async {
    if (_cachedProfile == null) return;
    final jsonStr = jsonEncode(_cachedProfile!.toJson());
    await _prefs.setString(_profileKey, jsonStr);
  }
  
  /// 更新用户画像
  Future<void> updateProfile(UserProfile newProfile) async {
    _cachedProfile = newProfile;
    await _save();
  }
  
  /// 获取身份锚点 (用于 Prompt 注入)
  String getIdentityAnchor() {
    return profile.getIdentityAnchor();
  }
  
  /// 获取不喜欢的模式列表
  List<String> getDislikedPatterns() {
    return profile.preferences.dislikedPatterns;
  }
  
  /// 获取偏好风格
  List<String> getPreferredStyles() {
    return profile.preferences.preferredStyles;
  }
  
  /// 获取亲密度
  double getIntimacy() {
    return profile.relationship.intimacy;
  }
  
  /// 获取情绪趋势
  String getEmotionTrend() {
    return profile.emotionalArchive.getEmotionTrend();
  }
  
  // ========== 增量更新方法 ==========
  
  /// 添加生活背景
  Future<void> addLifeContext(LifeContext context) async {
    _cachedProfile = profile.addLifeContext(context);
    await _save();
  }
  
  /// 添加不喜欢的模式
  Future<void> addDislikedPattern(String pattern) async {
    final newPrefs = profile.preferences.addDislikedPattern(pattern);
    _cachedProfile = profile.copyWith(preferences: newPrefs);
    await _save();
  }
  
  /// 增加亲密度
  Future<void> incrementIntimacy(double delta) async {
    final newRelationship = profile.relationship.incrementIntimacy(delta);
    _cachedProfile = profile.copyWith(relationship: newRelationship);
    await _save();
  }
  
  /// 添加情绪快照
  Future<void> addEmotionSnapshot(EmotionSnapshot snapshot) async {
    final newArchive = profile.emotionalArchive.addSnapshot(snapshot);
    _cachedProfile = profile.copyWith(emotionalArchive: newArchive);
    await _save();
  }
  
  /// 添加里程碑事件
  Future<void> addMilestone(MilestoneEvent milestone) async {
    final newMilestones = [...profile.relationship.milestones, milestone];
    final newRelationship = RelationshipState(
      intimacy: profile.relationship.intimacy,
      totalInteractions: profile.relationship.totalInteractions,
      totalChatTime: profile.relationship.totalChatTime,
      firstMet: profile.relationship.effectiveFirstMet,
      milestones: newMilestones,
    );
    _cachedProfile = profile.copyWith(relationship: newRelationship);
    await _save();
  }
  
  /// 更新基本信息
  Future<void> updateBasicInfo({
    String? nickname,
    String? occupation,
    String? major,
    int? age,
    String? gender,
  }) async {
    _cachedProfile = profile.copyWith(
      nickname: nickname,
      occupation: occupation,
      major: major,
      age: age,
      gender: gender,
    );
    await _save();
  }
  
  /// 重新加载
  void reload() {
    _cachedProfile = null;
    _load();
  }
  
  /// 重置为默认
  Future<void> reset() async {
    _cachedProfile = UserProfile.empty();
    await _save();
  }
  
  /// 检查是否已初始化
  bool get isInitialized => _cachedProfile != null;
  
  /// 获取交互次数
  int get totalInteractions => profile.relationship.totalInteractions;
  
  /// 格式化用于调试的状态信息
  Map<String, dynamic> getDebugInfo() {
    return {
      'nickname': profile.nickname,
      'occupation': profile.occupation,
      'intimacy': profile.relationship.intimacy,
      'interactions': profile.relationship.totalInteractions,
      'lifeContextsCount': profile.lifeContexts.length,
      'dislikedPatternsCount': profile.preferences.dislikedPatterns.length,
      'emotionTrend': profile.emotionalArchive.getEmotionTrend(),
    };
  }
}
