// StartupGreetingService - 应用启动时问候判断
//
// 设计原理：
// - 简化方案：不使用后台服务，仅在应用打开时判断
// - 如果需要问候，随机延迟后发送一条消息
// - 使用 SharedPreferences 记录上次问候时间

import 'dart:async';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart';
import '../model/chat_message.dart';

/// 问候类型
enum GreetingType {
  morning,   // 早安 (6:00-10:00)
  evening,   // 晚安 (20:00-23:00)
  absence,   // 久未联系 (>24小时)
  random,    // 随机想起
  none,      // 不需要问候
}

/// 启动问候服务
class StartupGreetingService {
  static const String _lastGreetingKey = 'last_greeting_time';
  static const String _lastMorningKey = 'last_morning_greeting_date';
  static const String _lastEveningKey = 'last_evening_greeting_date';
  static const String _lastInteractionKey = 'last_interaction_time';
  
  final SharedPreferences _prefs;
  // ignore: unused_field - 保留用于未来个性化问候
  final String _personaName;
  
  /// 问候消息回调
  void Function(ChatMessage message)? onGreetingMessage;
  
  StartupGreetingService(this._prefs, {String personaName = 'April'}) 
      : _personaName = personaName;
  
  /// 问候回调：生成虚拟时间戳消息时调用
  void Function(ChatMessage message)? onMissedGreetingMessage;
  
  /// 检查并调度问候（应用启动时调用）
  /// 
  /// 新逻辑：
  /// 1. 先检查错过的触发器（虚拟时间戳策略）
  /// 2. 再检查当前时段的正常问候
  Future<void> checkAndScheduleGreeting() async {
    // 【虚拟时间戳策略】先检查错过的触发器
    final missedMessages = await _checkMissedTriggers();
    for (final msg in missedMessages) {
      print('[StartupGreeting] Inserting missed greeting with virtual timestamp: ${msg.time}');
      onMissedGreetingMessage?.call(msg);
    }
    
    // 如果有错过的消息，则跳过当前时段的正常问候（避免重复）
    if (missedMessages.isNotEmpty) {
      return;
    }
    
    final greetingType = _determineGreetingType();
    
    if (greetingType == GreetingType.none) {
      print('[StartupGreeting] No greeting needed');
      return;
    }
    
    // 随机延迟 2-30 秒后发送
    final delaySeconds = Random().nextInt(28) + 2;
    print('[StartupGreeting] Will send $greetingType greeting in $delaySeconds seconds');
    
    Timer(Duration(seconds: delaySeconds), () {
      _sendGreeting(greetingType);
    });
  }
  
  /// 【虚拟时间戳策略】检查错过的触发器
  /// 
  /// 比较 current_time 与 last_active_time，如果错过了预定的触发器，
  /// 生成带有虚拟时间戳的消息
  Future<List<ChatMessage>> _checkMissedTriggers() async {
    final missedMessages = <ChatMessage>[];
    final now = DateTime.now();
    final todayDate = '${now.year}-${now.month}-${now.day}';
    
    // 获取上次活跃时间
    final lastActive = _prefs.getInt(_lastInteractionKey) ?? 0;
    if (lastActive == 0) {
      return missedMessages; // 首次使用，无需补发
    }
    
    final lastActiveTime = DateTime.fromMillisecondsSinceEpoch(lastActive);
    
    // 检查是否错过早安问候 (今天8:00)
    final morningTrigger = DateTime(now.year, now.month, now.day, 8, 0);
    final lastMorning = _prefs.getString(_lastMorningKey);
    
    if (lastMorning != todayDate && // 今天未发送过早安
        now.hour >= 8 && now.hour < 12 && // 现在是上午
        lastActiveTime.isBefore(morningTrigger)) { // 上次活跃在今天8点之前
      
      // 生成虚拟时间戳（8:15）
      final virtualTime = DateTime(now.year, now.month, now.day, 8, 15);
      final message = _getGreetingMessage(GreetingType.morning);
      if (message != null) {
        missedMessages.add(ChatMessage(
          content: message,
          isUser: false,
          time: virtualTime,
        ));
        // 更新记录
        await _prefs.setString(_lastMorningKey, todayDate);
        await _prefs.setInt(_lastGreetingKey, now.millisecondsSinceEpoch);
      }
    }
    
    // 检查是否错过晚安问候 (今天22:00)
    final eveningTrigger = DateTime(now.year, now.month, now.day, 22, 0);
    final lastEvening = _prefs.getString(_lastEveningKey);
    
    if (lastEvening != todayDate && // 今天未发送过晚安
        now.hour >= 22 && // 现在是晚上
        lastActiveTime.isBefore(eveningTrigger)) { // 上次活跃在今天22点之前
      
      // 生成虚拟时间戳（22:15）
      final virtualTime = DateTime(now.year, now.month, now.day, 22, 15);
      final message = _getGreetingMessage(GreetingType.evening);
      if (message != null) {
        missedMessages.add(ChatMessage(
          content: message,
          isUser: false,
          time: virtualTime,
        ));
        // 更新记录
        await _prefs.setString(_lastEveningKey, todayDate);
        await _prefs.setInt(_lastGreetingKey, now.millisecondsSinceEpoch);
      }
    }
    
    return missedMessages;
  }
  
  /// 判断需要哪种问候
  GreetingType _determineGreetingType() {
    final now = DateTime.now();
    final hour = now.hour;
    final todayDate = '${now.year}-${now.month}-${now.day}';
    
    // 检查早安 (6:00-10:00)
    if (hour >= 6 && hour < 10) {
      final lastMorning = _prefs.getString(_lastMorningKey);
      if (lastMorning != todayDate) {
        return GreetingType.morning;
      }
    }
    
    // 检查晚安 (20:00-23:00)
    if (hour >= 20 && hour < 23) {
      final lastEvening = _prefs.getString(_lastEveningKey);
      if (lastEvening != todayDate) {
        return GreetingType.evening;
      }
    }
    
    // 检查久未联系 (>24小时)
    final lastInteraction = _prefs.getInt(_lastInteractionKey) ?? 0;
    if (lastInteraction > 0) {
      final lastTime = DateTime.fromMillisecondsSinceEpoch(lastInteraction);
      final hoursSinceLastInteraction = now.difference(lastTime).inHours;
      if (hoursSinceLastInteraction >= 24) {
        // 检查今天是否已经发过久未联系问候
        final lastGreeting = _prefs.getInt(_lastGreetingKey) ?? 0;
        final lastGreetingTime = DateTime.fromMillisecondsSinceEpoch(lastGreeting);
        if (now.difference(lastGreetingTime).inHours >= 12) {
          return GreetingType.absence;
        }
      }
    }
    
    // 10% 概率随机想起（只在活跃时段 8:00-22:00）
    if (hour >= 8 && hour < 22) {
      final lastGreeting = _prefs.getInt(_lastGreetingKey) ?? 0;
      final lastGreetingTime = DateTime.fromMillisecondsSinceEpoch(lastGreeting);
      if (now.difference(lastGreetingTime).inHours >= 4) {
        if (Random().nextDouble() < 0.1) {
          return GreetingType.random;
        }
      }
    }
    
    return GreetingType.none;
  }
  
  /// 发送问候消息
  void _sendGreeting(GreetingType type) {
    final message = _getGreetingMessage(type);
    if (message == null) return;
    
    final chatMessage = ChatMessage(
      content: message,
      isUser: false,
      time: DateTime.now(),
    );
    
    // 更新记录
    final now = DateTime.now();
    final todayDate = '${now.year}-${now.month}-${now.day}';
    
    _prefs.setInt(_lastGreetingKey, now.millisecondsSinceEpoch);
    
    if (type == GreetingType.morning) {
      _prefs.setString(_lastMorningKey, todayDate);
    } else if (type == GreetingType.evening) {
      _prefs.setString(_lastEveningKey, todayDate);
    }
    
    print('[StartupGreeting] Sending $type greeting: ${message.substring(0, message.length.clamp(0, 20))}...');
    
    onGreetingMessage?.call(chatMessage);
  }
  
  /// 获取问候消息内容
  String? _getGreetingMessage(GreetingType type) {
    final random = Random();
    
    switch (type) {
      case GreetingType.morning:
        final messages = [
          '早上好呀～今天有什么计划吗？☀️',
          '新的一天开始了！希望你今天一切顺利～',
          '早安～昨晚睡得好吗？',
          '早上好！今天也要开开心心的哦～',
        ];
        return messages[random.nextInt(messages.length)];
        
      case GreetingType.evening:
        final messages = [
          '晚上好呀，今天过得怎么样？',
          '一天辛苦了～记得早点休息哦',
          '晚上好～有什么想分享的吗？',
          '这个点了，今天还顺利吗？',
        ];
        return messages[random.nextInt(messages.length)];
        
      case GreetingType.absence:
        final messages = [
          '好久没聊了，最近怎么样呀？想你了～',
          '这几天在忙什么呢？有空来聊聊呀',
          '突然想起你了，一切都好吗？',
          '好几天没见你了，有点想你呢～',
        ];
        return messages[random.nextInt(messages.length)];
        
      case GreetingType.random:
        final messages = [
          '在想你呢，有空吗？',
          '突然想找你聊聊天～',
          '刚刚想起你了，最近怎么样？',
        ];
        return messages[random.nextInt(messages.length)];
        
      case GreetingType.none:
        return null;
    }
  }
  
  /// 记录用户交互时间（发送消息时调用）
  Future<void> recordInteraction() async {
    await _prefs.setInt(_lastInteractionKey, DateTime.now().millisecondsSinceEpoch);
  }
}
