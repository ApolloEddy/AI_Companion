// BackgroundService - Android 后台任务调度
//
// 设计原理：
// - 使用 WorkManager 实现真正的后台任务
// - Flutter Timer 在后台会被系统暂停，WorkManager 不会
// - 结合 flutter_local_notifications 发送本地通知

import 'dart:io';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:workmanager/workmanager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'dart:math';

/// 后台任务名称常量
class BackgroundTaskNames {
  static const String proactiveCheck = 'proactive_check';
  static const String morningGreeting = 'morning_greeting';
  static const String eveningGreeting = 'evening_greeting';
}

/// 本地通知服务
class LocalNotificationService {
  static final FlutterLocalNotificationsPlugin _notifications = 
      FlutterLocalNotificationsPlugin();
  
  static bool _initialized = false;

  /// 初始化通知服务
  static Future<void> initialize() async {
    if (_initialized) return;
    
    // 初始化时区
    tz.initializeTimeZones();
    
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    
    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );
    
    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );
    
    _initialized = true;
    print('[LocalNotification] Initialized');
  }

  /// 通知被点击时的回调
  static void _onNotificationTapped(NotificationResponse response) {
    print('[LocalNotification] Tapped: ${response.payload}');
    // TODO: 打开对应的聊天界面
  }

  /// 发送即时通知
  static Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'ai_companion_channel',
      'AI Companion 消息',
      channelDescription: '来自 AI 伙伴的消息',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );
    
    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    const details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );
    
    await _notifications.show(id, title, body, details, payload: payload);
    print('[LocalNotification] Shown: $title');
  }

  /// 取消所有通知
  static Future<void> cancelAll() async {
    await _notifications.cancelAll();
  }
}

/// 后台任务服务
class BackgroundService {
  static const String _lastProactiveKey = 'last_proactive_notification';
  static const String _personaNameKey = 'persona_name';

  /// 初始化后台服务（仅 Android）
  static Future<void> initialize() async {
    if (!Platform.isAndroid) {
      print('[BackgroundService] Not Android, skipping WorkManager init');
      return;
    }

    await Workmanager().initialize(
      _callbackDispatcher,
      isInDebugMode: false,
    );

    // 注册定期任务：每小时检查一次
    await Workmanager().registerPeriodicTask(
      'proactive_check_periodic',
      BackgroundTaskNames.proactiveCheck,
      frequency: const Duration(hours: 1),
      constraints: Constraints(
        networkType: NetworkType.not_required,
      ),
      existingWorkPolicy: ExistingWorkPolicy.replace,
    );

    print('[BackgroundService] WorkManager initialized with periodic task');
  }

  /// 注册早安问候任务（每天早上 8 点）
  static Future<void> scheduleMorningGreeting() async {
    if (!Platform.isAndroid) return;

    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, 8, 0);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    final delay = scheduled.difference(now);

    await Workmanager().registerOneOffTask(
      'morning_greeting_${scheduled.day}',
      BackgroundTaskNames.morningGreeting,
      initialDelay: delay,
      constraints: Constraints(networkType: NetworkType.not_required),
    );

    print('[BackgroundService] Morning greeting scheduled for: $scheduled');
  }

  /// 注册晚安问候任务（每天晚上 10 点）
  static Future<void> scheduleEveningGreeting() async {
    if (!Platform.isAndroid) return;

    final now = DateTime.now();
    var scheduled = DateTime(now.year, now.month, now.day, 22, 0);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    final delay = scheduled.difference(now);

    await Workmanager().registerOneOffTask(
      'evening_greeting_${scheduled.day}',
      BackgroundTaskNames.eveningGreeting,
      initialDelay: delay,
      constraints: Constraints(networkType: NetworkType.not_required),
    );

    print('[BackgroundService] Evening greeting scheduled for: $scheduled');
  }

  /// 取消所有后台任务
  static Future<void> cancelAll() async {
    if (!Platform.isAndroid) return;
    await Workmanager().cancelAll();
    print('[BackgroundService] All tasks cancelled');
  }
}

/// WorkManager 回调（必须是顶级函数）
@pragma('vm:entry-point')
void _callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    print('[BackgroundService] Executing task: $task');
    
    try {
      // 初始化通知服务
      await LocalNotificationService.initialize();
      
      final prefs = await SharedPreferences.getInstance();
      final personaName = prefs.getString('persona_name') ?? '小悠';
      
      switch (task) {
        case BackgroundTaskNames.proactiveCheck:
          await _handleProactiveCheck(prefs, personaName);
          break;
        case BackgroundTaskNames.morningGreeting:
          await _handleMorningGreeting(personaName);
          // 重新调度明天的任务
          await BackgroundService.scheduleMorningGreeting();
          break;
        case BackgroundTaskNames.eveningGreeting:
          await _handleEveningGreeting(personaName);
          // 重新调度明天的任务
          await BackgroundService.scheduleEveningGreeting();
          break;
      }
      
      return true;
    } catch (e) {
      print('[BackgroundService] Task error: $e');
      return false;
    }
  });
}

/// 处理定期主动检查
Future<void> _handleProactiveCheck(SharedPreferences prefs, String personaName) async {
  final now = DateTime.now();
  final hour = now.hour;
  
  // 只在活跃时段内发送 (8:00 - 22:00)
  if (hour < 8 || hour >= 22) {
    print('[BackgroundService] Outside active hours, skipping');
    return;
  }
  
  // 检查上次发送时间，避免过于频繁
  final lastSent = prefs.getInt(BackgroundService._lastProactiveKey) ?? 0;
  final lastSentTime = DateTime.fromMillisecondsSinceEpoch(lastSent);
  final hoursSinceLastSent = now.difference(lastSentTime).inHours;
  
  if (hoursSinceLastSent < 4) {
    print('[BackgroundService] Too soon since last notification ($hoursSinceLastSent hours)');
    return;
  }
  
  // 10% 概率发送随机想起消息
  final random = Random();
  if (random.nextDouble() < 0.1) {
    final messages = [
      '在想你呢，有空吗？',
      '突然想找你聊聊天～',
      '刚刚想起你了，最近怎么样？',
    ];
    final message = messages[random.nextInt(messages.length)];
    
    await LocalNotificationService.showNotification(
      id: DateTime.now().millisecondsSinceEpoch % 100000,
      title: personaName,
      body: message,
      payload: 'proactive',
    );
    
    await prefs.setInt(BackgroundService._lastProactiveKey, now.millisecondsSinceEpoch);
  }
}

/// 处理早安问候
Future<void> _handleMorningGreeting(String personaName) async {
  final messages = [
    '早上好呀～今天有什么计划吗？☀️',
    '新的一天开始了！希望你今天一切顺利～',
    '早安～昨晚睡得好吗？',
  ];
  final random = Random();
  final message = messages[random.nextInt(messages.length)];
  
  await LocalNotificationService.showNotification(
    id: 1001,
    title: personaName,
    body: message,
    payload: 'morning',
  );
}

/// 处理晚安问候
Future<void> _handleEveningGreeting(String personaName) async {
  final messages = [
    '晚上好呀，今天过得怎么样？',
    '一天辛苦了～记得早点休息哦',
    '晚上好～有什么想分享的吗？',
  ];
  final random = Random();
  final message = messages[random.nextInt(messages.length)];
  
  await LocalNotificationService.showNotification(
    id: 1002,
    title: personaName,
    body: message,
    payload: 'evening',
  );
}
