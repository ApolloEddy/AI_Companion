// RelationState - L3 关系状态枚举
//
// 设计原理：
// - 纯状态标识，无语义解释
// - L3 只看到枚举名称，不做任何推断
// - 所有"软理解"在 L2/Dart 层完成

import '../config/intimacy_config.dart';
import '../settings_loader.dart';

/// L3 关系状态枚举 - 纯状态标识
enum RelationState {
  close,       // intimacy > highThreshold
  normal,      // lowThreshold <= intimacy <= highThreshold
  distant,     // intimacy < lowThreshold
  terminating, // 紧急退出模式 (meltdown/hostile)
}

/// L3 交互模式枚举
enum InteractionMode {
  engaged,  // 正常交互
  neutral,  // 低能量/敷衍
  exiting,  // 结束对话
}

/// 从亲密度数值计算关系状态
RelationState computeRelationState(
  double intimacy, {
  bool isTerminating = false,
}) {
  if (isTerminating) return RelationState.terminating;
  
  final lowThreshold = SettingsLoader.intimacyLowThreshold;
  final highThreshold = SettingsLoader.intimacyHighThreshold;
  
  if (intimacy > highThreshold) return RelationState.close;
  if (intimacy < lowThreshold) return RelationState.distant;
  return RelationState.normal;
}

/// 从情绪和敌意计算交互模式
InteractionMode computeInteractionMode({
  required double arousal,
  required double resentment,
  required double valence,
  bool isMeltdown = false,
}) {
  // 崩溃状态或高敌意 -> 退出模式
  if (isMeltdown || resentment > 0.8) {
    return InteractionMode.exiting;
  }
  
  // 低能量或负面情绪 -> 中立模式
  if (arousal < 0.3 || valence < -0.3) {
    return InteractionMode.neutral;
  }
  
  return InteractionMode.engaged;
}
