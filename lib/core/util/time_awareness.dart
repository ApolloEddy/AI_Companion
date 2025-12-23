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
}
