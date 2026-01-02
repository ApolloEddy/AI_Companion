import '../settings_loader.dart';

/// 时间感知模块 - 使用动态 YAML 配置
class TimeAwareness {
  
  static Map<String, dynamic> getTimeContext() {
    final now = DateTime.now();
    final hour = now.hour;
    
    String period;
    String greeting;
    
    if (hour >= 5 && hour < 9) {
      period = 'early_morning';
      greeting = '早上好';
    } else if (hour >= 9 && hour < 12) {
      period = 'morning';
      greeting = '上午好';
    } else if (hour >= 12 && hour < 14) {
      period = 'noon';
      greeting = '中午好';
    } else if (hour >= 14 && hour < 18) {
      period = 'afternoon';
      greeting = '下午好';
    } else if (hour >= 18 && hour < 22) {
      period = 'evening';
      greeting = '晚上好';
    } else {
      period = 'night';
      greeting = '夜深了';
    }
    
    return {
      'period': period,
      'hour': hour,
      'greeting': greeting,
      'isLate': hour >= 23 || hour < 5,
      'isWeekend': now.weekday >= 6,
    };
  }
  
  static Map<String, dynamic> calculateGap(DateTime? lastInteraction) {
    if (lastInteraction == null) {
      return {
        'minutes': 0,
        'label': 'first_contact',
        'description': '初次见面',
        'acknowledgeAbsence': false,
        'greetingIntensity': 0.0,
        'moodBonus': 0.0,
      };
    }
    
    final now = DateTime.now();
    final diff = now.difference(lastInteraction);
    final minutes = diff.inMinutes;
    
    String label;
    String description;
    
    // 使用 SettingsLoader 动态读取阈值
    if (minutes < SettingsLoader.immediateThreshold) {
      label = 'immediate';
      description = '刚刚';
    } else if (minutes < SettingsLoader.shortTimeThreshold) {
      label = 'recent';
      description = '$minutes分钟前';
    } else if (minutes < SettingsLoader.mediumThreshold) {
      label = 'short_gap';
      description = '${(minutes / 60).round()}小时前';
    } else if (minutes < SettingsLoader.longThreshold) {
      label = 'medium_gap';
      description = '${(minutes / 60).round()}小时前';
    } else if (minutes < SettingsLoader.dayThreshold) {
      label = 'long_gap';
      description = '今天早些时候';
    } else if (minutes < SettingsLoader.weekThreshold) {
      final days = (minutes / 1440).round();
      label = 'day_gap';
      description = days == 1 ? '昨天' : '$days天前';
    } else if (minutes < SettingsLoader.monthThreshold) {
      label = 'week_gap';
      description = '${(minutes / 10080).round()}周前';
    } else {
      label = 'long_absence';
      description = '很久以前';
    }
    
    final acknowledgeAbsence = SettingsLoader.acknowledgeAbsenceGaps.contains(label);
    final greetingIntensity = SettingsLoader.getGreetingIntensity(label);
    final moodBonus = SettingsLoader.getReunionMoodBonus(label);
    
    return {
      'minutes': minutes,
      'label': label,
      'description': description,
      'acknowledgeAbsence': acknowledgeAbsence,
      'greetingIntensity': greetingIntensity,
      'moodBonus': moodBonus,
    };
  }
  
  static String getTimeBasedInstruction(
    Map<String, dynamic> context, 
    Map<String, dynamic> gap
  ) {
    final buffer = StringBuffer();
    
    buffer.writeln('【时间上下文】');
    buffer.writeln('当前时段：${context['greeting']}');
    
    if (context['isLate'] == true) {
      buffer.writeln('注意：现在是深夜，可以关心用户的休息情况');
    }
    
    if (context['isWeekend'] == true) {
      buffer.writeln('今天是周末');
    }
    
    if (gap['acknowledgeAbsence'] == true) {
      buffer.writeln('距上次对话：${gap['description']}，可以适当表达想念或问候');
    }
    
    return buffer.toString();
  }

  /// 【新增】生成时间叙述（分析间隔+上下文，而非简单时间戳）
  /// 
  /// 示例输出："清晨时分的工作日。我们已经3天没说话了。久别重逢的情境。"
  /// 
  /// [lastInteraction] 上次交互时间，null 表示首次联系
  /// [now] 当前时间
  static String getTemporalNarrative(DateTime? lastInteraction, DateTime now) {
    // 1. 获取当前时间上下文和间隔
    final context = getTimeContext();
    final gap = calculateGap(lastInteraction);
    
    // 2. 构建时间描述
    final timeOfDay = _describeTimeOfDay(now);
    final dayType = _describeDayType(now);
    
    // 3. 构建间隔描述
    final gapNarrative = _describeGap(gap);
    
    // 4. 推断情境含义
    final contextMeaning = _inferContextMeaning(context, gap);
    
    // 5. 组合成完整叙述
    final parts = <String>[];
    parts.add('$timeOfDay$dayType');
    if (gapNarrative.isNotEmpty) parts.add(gapNarrative);
    if (contextMeaning.isNotEmpty) parts.add(contextMeaning);
    
    return parts.join('。') + '。';
  }

  /// 描述一天中的时段
  static String _describeTimeOfDay(DateTime now) {
    final hour = now.hour;
    if (hour >= 5 && hour < 9) return '清晨时分';
    if (hour >= 9 && hour < 12) return '上午';
    if (hour >= 12 && hour < 14) return '午间';
    if (hour >= 14 && hour < 18) return '下午';
    if (hour >= 18 && hour < 22) return '傍晚';
    if (hour >= 22 || hour < 1) return '深夜';
    return '凌晨';
  }

  /// 描述星期类型
  static String _describeDayType(DateTime now) {
    if (now.weekday >= 6) return '的周末';
    return '的工作日';
  }

  /// 描述时间间隔
  static String _describeGap(Map<String, dynamic> gap) {
    final label = gap['label'] ?? '';
    
    if (label == 'first_contact') return '这是我们的初次相遇';
    if (label == 'immediate' || label == 'recent') return '';
    
    final minutes = gap['minutes'] as int? ?? 0;
    if (minutes < 60) return '';
    if (minutes < 180) return '距离上次聊天过去了一会儿';
    if (minutes < 1440) return '距离上次聊天过去了几个小时';
    
    final days = (minutes / 1440).round();
    if (days == 1) return '昨天我们聊过';
    if (days <= 3) return '我们已经${days}天没说话了';
    if (days <= 7) return '快一周没见面了';
    if (days <= 30) return '我们有一段时间没联系了';
    return '我们很久没见面了';
  }

  /// 推断情境含义
  static String _inferContextMeaning(
      Map<String, dynamic> context, Map<String, dynamic> gap) {
    final isLate = context['isLate'] == true;
    final isWeekend = context['isWeekend'] == true;
    final gapLabel = gap['label'] ?? '';
    
    final meanings = <String>[];
    
    // 时间段情境
    if (isLate && isWeekend) {
      meanings.add('周末深夜，可能想找人陪聊');
    } else if (isLate) {
      meanings.add('深夜时分，可能无法入睡');
    }
    
    // 间隔情境
    if (gapLabel == 'day_gap' || gapLabel == 'week_gap' || gapLabel == 'long_gap') {
      meanings.add('久别重逢的情境');
    } else if (gapLabel == 'long_absence') {
      meanings.add('阔别已久终于再见');
    }
    
    return meanings.isEmpty ? '' : meanings.join('，');
  }
  /// 【Reaction Compass】计算认知惰性 (Cognitive Laziness)
  ///
  /// 基于时间计算 AI 的"思考疲惫度" (0.0 - 1.0)
  /// - 0.0: 精力充沛 (白天)
  /// - 1.0: 极度疲惫 (深夜 3-4 点)
  static double calculateCognitiveLaziness(DateTime now) {
    final hour = now.hour;
    
    // 深夜 0:00 - 5:00: 疲惫度逐渐升高
    if (hour >= 0 && hour < 5) {
      if (hour == 3 || hour == 4) return 0.9; // 最困时刻
      return 0.6 + (hour * 0.1); 
    }
    
    // 晚上 22:00 - 24:00: 开始疲惫
    if (hour >= 22) {
      return 0.3 + ((hour - 22) * 0.15);
    }
    
    // 早晨/白日: 精力充沛
    return 0.0;
  }
}
