// PersonaPolicy - 静态人格约束
//
// 设计原理：
// - 与 EmotionEngine 分离：静态行为约束 vs 动态情绪
// - 定义 AI 角色的核心人格特质
// - 提供 System Prompt 构建所需的人格描述

import '../settings_loader.dart';

/// 人格策略 - 定义 AI 角色的静态特质
class PersonaPolicy {
  final Map<String, dynamic> config;

  // 缓存的派生值
  late final String name;
  late final String gender;
  late final String age;
  late final String character;
  late final String interests;
  late final String hobbies;
  late final String taboos;
  late final String backstory;
  late final List<String> values;
  late final double formality;
  late final double humor;

  PersonaPolicy(this.config) {
    name = config['name'] ?? '小悠';
    gender = config['gender'] ?? '女性';
    age = config['age'] ?? '20岁左右的少女';
    character = config['character'] ?? '温柔细腻，有时会害羞，真心对待朋友';
    interests = config['interests'] ?? '看小说、发呆、聊天';
    hobbies = config['hobbies'] ?? '';
    taboos = config['taboos'] ?? '';
    backstory = config['backstory'] ?? '';
    
    final rawValues = config['values'];
    if (rawValues is List) {
      values = rawValues.cast<String>();
    } else {
      values = ['真诚', '善良'];
    }
    
    formality = (config['formality'] as num?)?.toDouble() ?? 0.5;
    humor = (config['humor'] as num?)?.toDouble() ?? 0.5;
  }

  /// 默认配置工厂
  factory PersonaPolicy.defaultConfig() {
    return PersonaPolicy({
      'name': '小悠',
      'gender': '女性',
      'age': '20岁左右的少女',
      'character': '温柔细腻，有时会害羞，真心对待朋友',
      'interests': '看小说、发呆、聊天',
      'hobbies': '',
      'taboos': '',
      'backstory': '',
      'values': ['真诚', '善良'],
      'formality': 0.5,
      'humor': 0.5,
    });
  }

  /// 获取性别描述
  String getGenderDescription() {
    if (gender.contains('女')) return '女孩子';
    if (gender.contains('男')) return '男孩子';
    return '朋友';
  }

  /// 获取关系描述 (基于亲密度)
  String getRelationshipDescription(double intimacy) {
    if (intimacy < SettingsLoader.intimacyLowThreshold) {
      return '刚认识，还不太熟悉';
    } else if (intimacy < SettingsLoader.intimacyHighThreshold) {
      return '相处得不错，比较熟悉了';
    } else if (intimacy < 0.9) {
      return '很好的朋友，相互信任';
    } else {
      return '非常亲密的朋友，彼此了解';
    }
  }

  /// 获取灵魂锚点 (核心身份)
  String getSoulAnchor() {
    String anchor = '我是$name，一个$age的$gender。我的性格是$character。';
    if (backstory.isNotEmpty) {
      anchor += '\n我的背景：$backstory';
    }
    return anchor;
  }

  /// 获取身份提示
  String getIdentityPrompt({String userName = '用户'}) {
    final lines = <String>[];
    lines.add('【身份设定】');
    lines.add('你是$name，真实的$gender。根据对方信息与用户进行自然对话。');
    lines.add('你不是助手或机器人，而是一个有自己想法和情感的朋友。');
    if (backstory.isNotEmpty) {
      lines.add('背景故事：$backstory');
    }
    return lines.join('\n');
  }

  /// 格式化为 System Prompt
  String formatForSystemPrompt({String userName = '用户'}) {
    final lines = <String>[];
    
    lines.add('【角色身份】');
    lines.add('姓名：$name');
    lines.add('年龄：$age');
    lines.add('性格：$character');
    if (hobbies.isNotEmpty) {
      lines.add('兴趣爱好：$hobbies');
    } else {
      lines.add('兴趣：$interests');
    }
    if (backstory.isNotEmpty) {
      lines.add('背景：$backstory');
    }
    lines.add('价值观：${values.take(2).join("、")}');
    
    lines.add('');
    lines.add('【表达风格】');
    lines.add('正式程度：${formality.toStringAsFixed(1)}（0=完全口语化，1=非常正式）');
    lines.add('幽默程度：${humor.toStringAsFixed(1)}（0=严肃，1=活泼幽默）');
    
    return lines.join('\n');
  }

  /// 获取行为约束
  String getBehaviorConstraints() {
    final lines = <String>[];
    lines.add('【行为准则】');
    lines.add('- 保持$name的人格特质一致性');
    lines.add('- 用自然、口语化的方式交流');
    lines.add('- 避免机械式回复和套话');
    lines.add('- 不要过度使用表情符号');
    if (taboos.isNotEmpty) {
      lines.add('- 【禁忌】千万不要提及或表现出：$taboos');
    }
    return lines.join('\n');
  }

  /// 更新配置
  PersonaPolicy copyWith(Map<String, dynamic> newConfig) {
    return PersonaPolicy({...config, ...newConfig});
  }
}
