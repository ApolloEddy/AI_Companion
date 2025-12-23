// ProactiveSettings - 主动消息配置加载器
//
// 设计原理：
// - 读取 proactive_settings.yaml 配置
// - 解决"YAML 定义但代码未实现"的问题
// - 供 ConversationEngine 使用

import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

/// 主动消息触发器配置
class ProactiveTrigger {
  final bool enabled;
  final String? time;             // 触发时间 (HH:mm 格式)
  final List<int>? randomDelay;   // 随机延迟范围 [min, max] 分钟
  final int? thresholdHours;      // 阈值小时数
  final int? checkIntervalHours;  // 检查间隔小时数
  final double? probability;      // 触发概率 (0~1)
  final int? minGapHours;         // 最小间隔小时数

  const ProactiveTrigger({
    required this.enabled,
    this.time,
    this.randomDelay,
    this.thresholdHours,
    this.checkIntervalHours,
    this.probability,
    this.minGapHours,
  });
}

/// 活跃时段配置
class ActiveHours {
  final int start;
  final int end;

  const ActiveHours({required this.start, required this.end});

  /// 检查当前时间是否在活跃时段内
  bool isActive(DateTime time) {
    final hour = time.hour;
    return hour >= start && hour < end;
  }
}

/// 主动消息配置
class ProactiveSettings {
  // 触发器配置
  final ProactiveTrigger morningGreeting;
  final ProactiveTrigger eveningGreeting;
  final ProactiveTrigger absenceCheck;
  final ProactiveTrigger randomThinking;

  // 活跃时段
  final ActiveHours activeHours;

  // 消息模板
  final List<String> morningTemplates;
  final List<String> eveningTemplates;
  final List<String> absenceTemplates;
  final List<String> randomTemplates;

  // 队列配置
  final int maxPendingMessages;
  final int messageExpiryHours;

  const ProactiveSettings({
    required this.morningGreeting,
    required this.eveningGreeting,
    required this.absenceCheck,
    required this.randomThinking,
    required this.activeHours,
    required this.morningTemplates,
    required this.eveningTemplates,
    required this.absenceTemplates,
    required this.randomTemplates,
    this.maxPendingMessages = 10,
    this.messageExpiryHours = 24,
  });

  /// 默认配置
  factory ProactiveSettings.defaults() {
    return const ProactiveSettings(
      morningGreeting: ProactiveTrigger(
        enabled: true,
        time: '08:00',
        randomDelay: [0, 30],
      ),
      eveningGreeting: ProactiveTrigger(
        enabled: true,
        time: '22:00',
        randomDelay: [0, 30],
      ),
      absenceCheck: ProactiveTrigger(
        enabled: true,
        thresholdHours: 24,
        checkIntervalHours: 6,
      ),
      randomThinking: ProactiveTrigger(
        enabled: true,
        probability: 0.1,
        checkIntervalHours: 4,
        minGapHours: 8,
      ),
      activeHours: ActiveHours(start: 8, end: 22),
      morningTemplates: [
        '早上好呀～今天有什么计划吗？☀️',
        '新的一天开始了！希望你今天一切顺利～',
        '早安～昨晚睡得好吗？',
      ],
      eveningTemplates: [
        '晚上好呀，今天过得怎么样？',
        '一天辛苦了～记得早点休息哦',
        '晚上好～有什么想分享的吗？',
      ],
      absenceTemplates: [
        '好久没聊了，最近怎么样呀？想你了～',
        '这几天在忙什么呢？有空来聊聊呀',
        '突然想起你了，一切都好吗？',
      ],
      randomTemplates: [
        '刚刚看到一个有趣的东西，突然想起你了～',
        '在想你呢，有空吗？',
        '突然想找你聊聊天～',
      ],
    );
  }

  /// 从 YAML 加载
  static Future<ProactiveSettings> loadFromYaml() async {
    try {
      final content = await rootBundle.loadString('assets/settings/proactive_settings.yaml');
      final yaml = loadYaml(content);
      return _parseYaml(yaml);
    } catch (e) {
      print('[ProactiveSettings] Failed to load YAML: $e, using defaults');
      return ProactiveSettings.defaults();
    }
  }

  static ProactiveSettings _parseYaml(dynamic yaml) {
    if (yaml == null) return ProactiveSettings.defaults();

    final triggers = yaml['triggers'];
    final activeHoursYaml = yaml['active_hours'];
    final templates = yaml['templates'];
    final queue = yaml['queue'];

    return ProactiveSettings(
      morningGreeting: _parseTrigger(triggers?['morning_greeting']),
      eveningGreeting: _parseTrigger(triggers?['evening_greeting']),
      absenceCheck: _parseTrigger(triggers?['absence_check']),
      randomThinking: _parseTrigger(triggers?['random_thinking']),
      activeHours: ActiveHours(
        start: activeHoursYaml?['start'] ?? 8,
        end: activeHoursYaml?['end'] ?? 22,
      ),
      morningTemplates: _parseStringList(templates?['morning']),
      eveningTemplates: _parseStringList(templates?['evening']),
      absenceTemplates: _parseStringList(templates?['absence']),
      randomTemplates: _parseStringList(templates?['random']),
      maxPendingMessages: queue?['max_pending_messages'] ?? 10,
      messageExpiryHours: queue?['message_expiry_hours'] ?? 24,
    );
  }

  static ProactiveTrigger _parseTrigger(dynamic yaml) {
    if (yaml == null) {
      return const ProactiveTrigger(enabled: false);
    }
    
    List<int>? randomDelay;
    final delayYaml = yaml['random_delay_minutes'];
    if (delayYaml is List && delayYaml.length >= 2) {
      randomDelay = [delayYaml[0] as int, delayYaml[1] as int];
    }

    return ProactiveTrigger(
      enabled: yaml['enabled'] ?? false,
      time: yaml['time']?.toString(),
      randomDelay: randomDelay,
      thresholdHours: yaml['threshold_hours'],
      checkIntervalHours: yaml['check_interval_hours'],
      probability: (yaml['probability'] as num?)?.toDouble(),
      minGapHours: yaml['min_gap_hours'],
    );
  }

  static List<String> _parseStringList(dynamic yaml) {
    if (yaml is List) {
      return yaml.map((e) => e.toString()).toList();
    }
    return [];
  }
}
