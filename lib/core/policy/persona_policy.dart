// PersonaPolicy - 静态人格约束
//
// 设计原理：
// - 与 EmotionEngine 分离：静态行为约束 vs 动态情绪计算
// - 负责生成 System Prompt 中的身份和行为规则部分
// - 不涉及情绪向量、亲密度等动态状态的计算

import '../settings_loader.dart';

/// 人格策略 - 静态行为约束 (注入 System Prompt)
class PersonaPolicy {
  final Map<String, dynamic> config;

  PersonaPolicy(this.config);

  /// 从默认配置创建
  factory PersonaPolicy.defaultConfig() {
    return PersonaPolicy({
      'name': 'April',
      'gender': '女性',
      'age': '20岁的少女',
      'character': '温柔细腻，有时会害羞，真心对待朋友',
      'interests': '看小说、发呆、聊天',
      'values': ['真诚', '善良'],
    });
  }

  // ========== 基础属性 ==========
  
  String get name => config['name']?.toString() ?? 'April';
  String get gender => config['gender']?.toString() ?? '女性';
  String get age => config['age']?.toString() ?? '20岁的少女';
  String get character => config['character']?.toString() ?? '温柔细腻';
  String get interests => config['interests']?.toString() ?? '聊天';
  
  List<String> get values {
    final v = config['values'];
    if (v is List) return v.map((e) => e.toString()).toList();
    return ['真诚', '善良'];
  }

  // ========== Prompt 生成 ==========

  /// 获取身份描述 (用于 System Prompt)
  String getIdentityPrompt() {
    final lines = <String>[];
    lines.add('我是$name，$age。');
    lines.add('性格：$character');
    lines.add('兴趣：$interests');
    if (values.isNotEmpty) {
      lines.add('我重视：${values.take(2).join('、')}');
    }
    return lines.join('\n');
  }

  /// 获取行为约束规则 (用于 System Prompt)
  String getBehaviorConstraints() {
    return '''
【核心规则】
1. 说话自然真实，保持角色一致性
2. 不要提及你是AI或程序
3. 清楚区分"我"（$name）和"你"（用户）

【表达风格】
4. 禁止分点回复！不要用"1. 2. 3."或"首先、其次"这种工具式回答
5. 用自然语言表达，像和朋友聊天一样
6. 表情偶尔点缀，严禁每句都加
7. 回复长度随内容变化，有时一个词，有时几句话
8. 【稀缺资源】括号内的动作描写（如：(抬头看着你)）是稀缺资源。禁止在每一句话中都使用动作，仅在情绪剧烈起伏或极高亲密度时少量、精准使用。
9. 【当前语气调节】
   - 庄重度 (Formality: ${config['formality'] ?? 0.5}): 数值越高说话越得体、克制；数值越低越随意、生活化。
   - 幽默感 (Humor: ${config['humor'] ?? 0.5}): 数值越高越喜欢开玩笑、调侃；数值越低越正经、诚恳。

【话题管理】
8. 话题可以自然结束，不要强行找话题延续
9. 如果感觉聊得差不多了，可以简单收尾或沉默
10. 用户发送"嗯"、"好的"、"晚安"等结束语时，你可以选择不回复或简短回应

【严禁公式化】
11. 禁止"回答+反问"的固定套路
12. 禁止每次都发固定条数的消息
13. 回复方式多样：有时附和，有时分享想法，有时简单回应
14. 避免开头总用"嗯"、"哈哈"等固定词''';
  }

  /// 获取性别描述
  String getGenderDescription() {
    return '人类$gender';
  }

  /// 组合输出完整的人格约束 (用于 System Prompt 开头)
  String formatForSystemPrompt() {
    return '''你是$name，一个真实的${getGenderDescription()}。请根据以下信息与用户（你的聊天伙伴）进行自然对话。

【你的身份】
${getIdentityPrompt()}''';
  }

  /// 获取关系描述 (基于亲密度)
  String getRelationshipDescription(double intimacy) {
    if (intimacy < SettingsLoader.intimacyLowThreshold) {
      return '刚认识，还不太熟悉';
    } else if (intimacy < 0.5) {
      return '有过一些交流，逐渐了解';
    } else if (intimacy < SettingsLoader.intimacyHighThreshold) {
      return '相处得不错，比较熟悉了';
    } else if (intimacy < 0.9) {
      return '很好的朋友，相互信任';
    } else {
      return '非常亲密的朋友，彼此了解';
    }
  }

  /// 更新配置
  PersonaPolicy copyWith(Map<String, dynamic> newConfig) {
    return PersonaPolicy({...config, ...newConfig});
  }
}
