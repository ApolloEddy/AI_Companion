// ConversationEngine - 核心调度器
//
// 设计原理：
// - 接管 AppEngine 的所有智能决策逻辑
// - 协调 LLMService、MemoryManager、PersonaPolicy、EmotionEngine
// - 【关键】实现 Timer 驱动的情绪衰减和主动消息
//
// 业务逻辑修复：
// - 情绪衰减：Timer 每 5 分钟自动重算 Valence/Arousal
// - 主动消息：读取 proactive_settings.yaml，检查触发条件

import 'dart:async';
import 'dart:math';

import '../model/chat_message.dart';
import '../service/llm_service.dart';
import '../util/expression_selector.dart';
import '../util/response_formatter.dart';
import '../util/time_awareness.dart';

import '../policy/generation_policy.dart';
import '../policy/persona_policy.dart';

import 'emotion_engine.dart';
import 'memory_manager.dart';
import 'proactive_settings.dart';
import 'fact_store.dart';
import '../settings_loader.dart';

// 认知引擎组件
import 'perception_processor.dart';
import 'reflection_processor.dart';
import 'feedback_analyzer.dart';
import 'async_reflection_engine.dart';
import '../service/profile_service.dart';
import '../service/analysis_service.dart';
import '../policy/prohibited_patterns.dart';

import '../prompt/prompt_assembler.dart';
import '../prompt/prompt_snapshot.dart';

/// 主动消息回调
typedef ProactiveMessageCallback = void Function(ChatMessage message);

/// 对话引擎 - 核心调度器
class ConversationEngine {
  // 依赖注入
  final LLMService llmService;
  final MemoryManager memoryManager;
  final PersonaPolicy personaPolicy;
  final EmotionEngine emotionEngine;
  final GenerationPolicy generationPolicy;

  // 主动消息配置
  ProactiveSettings? _proactiveSettings;

  // 定时器
  Timer? _emotionDecayTimer;
  Timer? _proactiveCheckTimer;

  // 状态
  DateTime? _lastProactiveMessage;
  bool _isRunning = false;

  // 亲密度（由外部管理，这里只读取）
  double _intimacy = 0.1;
  int _interactionCount = 0;
  DateTime? _lastInteraction;

  // 回调
  ProactiveMessageCallback? onProactiveMessage; // 立即发送
  ProactiveMessageCallback? onPendingMessage; // 加入待发送队列

  // 最近的快照（用于调试）
  PromptSnapshot? lastSnapshot;

  ConversationEngine({
    required this.llmService,
    required this.memoryManager,
    required this.personaPolicy,
    required this.emotionEngine,
    required this.generationPolicy,
    this.profileService,
  });

  // 认知引擎组件（可选，用于增强模式）
  ProfileService? profileService;
  // ignore: unused_field - 保留用于未来认知引擎扩展
  PerceptionProcessor? _perceptionProcessor;
  // ignore: unused_field - 保留用于未来认知引擎扩展
  ReflectionProcessor? _reflectionProcessor;
  // ignore: unused_field - 保留用于未来认知引擎扩展
  FeedbackAnalyzer? _feedbackAnalyzer;
  AsyncReflectionEngine? _asyncReflectionEngine;
  bool _cognitiveEngineEnabled = false;

  // 多阶段 Agentic 工作流组件
  AnalysisService? _analysisService;
  FactStore? _factStore;

  // ========== 生命周期管理 ==========

  /// 启动引擎
  Future<void> start() async {
    if (_isRunning) return;
    _isRunning = true;

    // 加载主动消息配置
    _proactiveSettings = await ProactiveSettings.loadFromYaml();

    // 启动时先应用一次衰减
    emotionEngine.applyDecaySinceLastUpdate();

    // 启动定时器
    _startEmotionDecayTimer();
    _startProactiveMessageTimer();

    // 初始化认知引擎组件（如果有 ProfileService）
    if (profileService != null) {
      _initCognitiveEngine();
    }

    print('[ConversationEngine] started');
  }

  /// 停止引擎
  void stop() {
    _isRunning = false;
    _emotionDecayTimer?.cancel();
    _proactiveCheckTimer?.cancel();
    _emotionDecayTimer = null;
    _proactiveCheckTimer = null;
    _asyncReflectionEngine?.stop();

    print('[ConversationEngine] stopped');
  }

  /// 初始化认知引擎组件
  void _initCognitiveEngine() {
    _perceptionProcessor = PerceptionProcessor(llmService);
    _reflectionProcessor = ReflectionProcessor(llmService);
    _feedbackAnalyzer = FeedbackAnalyzer();
    _asyncReflectionEngine = AsyncReflectionEngine(
      llmService: llmService,
      profileService: profileService!,
      memoryManager: memoryManager,
      quietPeriod: const Duration(minutes: 3),
    );

    // 初始化多阶段 Agentic 工作流组件
    _analysisService = AnalysisService(llmService);

    _cognitiveEngineEnabled = true;
    print('[ConversationEngine] cognitive engine initialized');
  }

  /// 设置 FactStore（需要从外部注入 SharedPreferences 实例）
  void setFactStore(FactStore factStore) {
    _factStore = factStore;
    print('[ConversationEngine] FactStore initialized');
  }

  /// 更新状态（由外部传入）
  void updateState({
    required double intimacy,
    required int interactionCount,
    DateTime? lastInteraction,
  }) {
    _intimacy = intimacy;
    _interactionCount = interactionCount;
    _lastInteraction = lastInteraction;
  }

  // ========== 【业务修复1】实时情绪衰减 ==========

  /// 启动情绪衰减定时器
  ///
  /// 原问题：衰减仅在启动时计算一次
  /// 修复：每 5 分钟自动重算 Valence/Arousal
  void _startEmotionDecayTimer() {
    const interval = Duration(minutes: 5);
    _emotionDecayTimer = Timer.periodic(interval, (_) {
      if (!_isRunning) return;

      emotionEngine.applyDecay(interval);
      print(
        '[ConversationEngine] emotion decay tick: '
        'v=${emotionEngine.valence.toStringAsFixed(2)}, '
        'a=${emotionEngine.arousal.toStringAsFixed(2)}',
      );
    });

    print('[ConversationEngine] emotion decay timer started (interval: 5 min)');
  }

  // ========== 【业务修复2】主动消息触发 ==========

  /// 启动主动消息检查定时器
  ///
  /// 原问题：proactive_settings.yaml 被忽略
  /// 修复：定期检查并触发主动消息
  void _startProactiveMessageTimer() {
    const interval = Duration(minutes: 30);
    _proactiveCheckTimer = Timer.periodic(interval, (_) {
      if (!_isRunning) return;
      _checkProactiveMessage();
    });

    // 启动后延迟 1 分钟做一次检查
    Future.delayed(const Duration(minutes: 1), () {
      if (_isRunning) _checkProactiveMessage();
    });

    print(
      '[ConversationEngine] proactive message timer started (interval: 30 min)',
    );
  }

  /// 检查是否应发送主动消息
  void _checkProactiveMessage() {
    final settings = _proactiveSettings;
    if (settings == null) return;

    final now = DateTime.now();

    // 检查是否在活跃时段
    if (!settings.activeHours.isActive(now)) {
      print('[ConversationEngine] outside active hours, skip proactive check');
      return;
    }

    // 检查早安问候
    if (_shouldTriggerGreeting(
      settings.morningGreeting,
      now,
      isMorning: true,
    )) {
      _sendProactiveMessage(settings.morningTemplates, 'morning');
      return;
    }

    // 检查晚安问候
    if (_shouldTriggerGreeting(
      settings.eveningGreeting,
      now,
      isMorning: false,
    )) {
      _sendProactiveMessage(settings.eveningTemplates, 'evening');
      return;
    }

    // 检查久未联系
    if (_shouldTriggerAbsenceCheck(settings.absenceCheck, now)) {
      _sendProactiveMessage(settings.absenceTemplates, 'absence');
      return;
    }

    // 检查随机想起
    if (_shouldTriggerRandomThinking(settings.randomThinking, now)) {
      _sendProactiveMessage(settings.randomTemplates, 'random');
      return;
    }
  }

  bool _shouldTriggerGreeting(
    ProactiveTrigger trigger,
    DateTime now, {
    required bool isMorning,
  }) {
    if (!trigger.enabled || trigger.time == null) return false;

    // 解析时间
    final parts = trigger.time!.split(':');
    if (parts.length != 2) return false;

    final targetHour = int.tryParse(parts[0]) ?? 0;
    final targetMinute = int.tryParse(parts[1]) ?? 0;

    // 检查是否在目标时间附近（允许 30 分钟窗口）
    final targetTime = DateTime(
      now.year,
      now.month,
      now.day,
      targetHour,
      targetMinute,
    );
    final diff = now.difference(targetTime).inMinutes;

    if (diff >= 0 && diff <= 30) {
      // 检查今天是否已发送过
      if (_lastProactiveMessage != null) {
        final lastDate = _lastProactiveMessage!;
        if (lastDate.year == now.year &&
            lastDate.month == now.month &&
            lastDate.day == now.day) {
          // 检查是否是同类型消息
          return false;
        }
      }
      return true;
    }

    return false;
  }

  bool _shouldTriggerAbsenceCheck(ProactiveTrigger trigger, DateTime now) {
    if (!trigger.enabled) return false;

    final thresholdHours = trigger.thresholdHours ?? 24;

    // 检查距离上次互动的时间
    if (_lastInteraction != null) {
      final hoursSinceLastInteraction = now
          .difference(_lastInteraction!)
          .inHours;
      if (hoursSinceLastInteraction >= thresholdHours) {
        // 检查距离上次主动消息的间隔
        if (_lastProactiveMessage != null) {
          final hoursSinceLastProactive = now
              .difference(_lastProactiveMessage!)
              .inHours;
          if (hoursSinceLastProactive < (trigger.checkIntervalHours ?? 6)) {
            return false;
          }
        }
        return true;
      }
    }

    return false;
  }

  bool _shouldTriggerRandomThinking(ProactiveTrigger trigger, DateTime now) {
    if (!trigger.enabled) return false;

    final probability = trigger.probability ?? 0.1;
    final minGapHours = trigger.minGapHours ?? 8;

    // 检查最小间隔
    if (_lastProactiveMessage != null) {
      final hoursSinceLastProactive = now
          .difference(_lastProactiveMessage!)
          .inHours;
      if (hoursSinceLastProactive < minGapHours) {
        return false;
      }
    }

    // 概率判断
    final random = Random();
    return random.nextDouble() < probability;
  }

  void _sendProactiveMessage(List<String> templates, String type) {
    if (templates.isEmpty) return;

    final random = Random();
    final template = templates[random.nextInt(templates.length)];

    final message = ChatMessage(
      content: template,
      isUser: false,
      time: DateTime.now(),
    );

    _lastProactiveMessage = DateTime.now();

    print(
      '[ConversationEngine] queueing proactive message ($type): ${template.substring(0, template.length.clamp(0, 20))}...',
    );

    // 加入待发送队列，而不是直接发送
    onPendingMessage?.call(message);
  }

  // ========== 核心消息处理 ==========

  /// 处理用户消息
  ///
  /// 协调各模块完成一次完整的对话流程：
  /// 1. 更新情绪状态
  /// 2. 构建上下文
  /// 3. 组装 Prompt
  /// 4. 调用 LLM
  /// 5. 格式化响应
  Future<ConversationResult> processUserMessage(
    String text,
    List<ChatMessage> currentMessages,
  ) async {
    // 【多阶段 Agentic 工作流】Step 1: 快速分析用户意图和情绪
    AnalysisResult? analysis;
    String dynamicRules = '';
    if (_analysisService != null) {
      final recentContext = currentMessages
          .take(3)
          .map((m) => '${m.isUser ? "用户" : "AI"}: ${m.content}')
          .toList();
      analysis = await _analysisService!.analyze(
        text,
        recentContext: recentContext,
      );
      dynamicRules = _analysisService!.generateDynamicRules(analysis);
      print('[ConversationEngine] Analysis: $analysis');
    }

    // 【FactStore】从用户消息中提取核心事实
    if (_factStore != null) {
      final extracted = await _factStore!.extractAndStore(text);
      if (extracted.isNotEmpty) {
        print('[ConversationEngine] Extracted facts: $extracted');
      }
    }

    // 1. 更新情绪状态
    await emotionEngine.applyInteractionImpact(text, _intimacy);

    // 2. 构建对话上下文
    final context = ConversationContext(
      intimacy: _intimacy,
      emotionValence: emotionEngine.valence,
      emotionArousal: emotionEngine.arousal,
      messageLength: text.length,
      isProactiveMessage: false,
    );

    // 3. 获取 LLM 参数
    final params = generationPolicy.getParams(context);

    // 4. 获取各组件内容
    final memories = memoryManager.getRelevantMemories(
      text,
      generationPolicy,
      context,
    );

    // 【FactStore】获取核心事实用于注入 Prompt
    final coreFacts = _factStore?.formatForSystemPrompt() ?? '';

    final timeContext = TimeAwareness.getTimeContext();
    final timeGap = _lastInteraction != null
        ? TimeAwareness.calculateGap(_lastInteraction!)
        : <String, dynamic>{};

    // 5. 构建当前状态
    String? absenceAck;
    if (timeGap['acknowledgeAbsence'] == true) {
      absenceAck = '距离上次聊天有一段时间了，可以表达想念或问候';
    }

    String? lateNightReminder;
    if (timeContext['isLate'] == true) {
      lateNightReminder = '现在很晚了，可以关心对方是否该休息了';
    }

    final currentState = PromptAssembler.buildCurrentState(
      emotionDescription: emotionEngine.getEmotionDescription(),
      relationshipDescription: personaPolicy.getRelationshipDescription(
        _intimacy,
      ),
      timeContext: timeContext['greeting'] ?? '白天',
      absenceAcknowledge: absenceAck,
      lateNightReminder: lateNightReminder,
    );

    // 6. 获取表达指引
    final expressionGuide = ExpressionSelector.getExpressionInstructions(
      emotionEngine.valence,
      emotionEngine.arousal,
      _intimacy,
    );

    // 7. 组装 Prompt（包含核心事实和动态规则）
    final behaviorRules = personaPolicy.getBehaviorConstraints() + dynamicRules;
    final assembleResult = PromptAssembler.assemble(
      personaHeader: personaPolicy.formatForSystemPrompt(),
      currentTime: _formatCurrentTime(),
      currentState: currentState,
      memories: memories,
      expressionGuide: expressionGuide,
      responseFormat: ResponseFormatter.getSplitInstruction(),
      behaviorRules: behaviorRules,
      coreFacts: coreFacts,
    );

    // 8. 构建 API 消息列表
    final historyCount = generationPolicy.getHistoryCount(context);
    // 【修复】用户消息已在 app_engine.dart:287 添加到 currentMessages
    // 必须排除最后一条（当前用户消息），避免在 history 和 user message 中重复出现
    final historyMessages = PromptAssembler.assembleHistoryMessages(
      currentMessages,
      maxCount: historyCount,
      excludeLastN: 1, // 排除最后一条（当前用户消息），因为它会单独添加在 apiMessages 末尾
    );

    final apiMessages = <Map<String, String>>[
      {'role': 'system', 'content': assembleResult.systemPrompt},
      ...historyMessages,
      {'role': 'user', 'content': text},
    ];

    // 9. 创建快照 (用于调试)
    lastSnapshot = PromptSnapshot(
      fullPrompt: assembleResult.systemPrompt,
      userMessage: text,
      historyMessages: historyMessages,
      timestamp: DateTime.now(),
      estimatedTokens: PromptSnapshot.calculateEstimatedTokens(
        assembleResult.systemPrompt,
        historyMessages,
        text,
      ),
      components: assembleResult.components,
      generationParams: params, // 记录生成参数用于调试
    );

    print(lastSnapshot!.toLogString());

    // 10. 调用 LLM
    final response = await llmService.generateWithTokens(
      apiMessages,
      params: params,
    );

    // 11. 处理响应
    if (response.success && response.content != null) {
      var responseText = response.content!;

      // 【认知增强】检查并清理禁止模式
      final patternCheck = ProhibitedPatterns.check(responseText);
      if (!patternCheck.isClean) {
        print(
          '[ConversationEngine] Prohibited patterns detected: $patternCheck',
        );
        responseText = ProhibitedPatterns.sanitize(responseText);
      }

      // 格式化响应（包含延迟信息）
      final formattedMessages = ResponseFormatter.formatResponse(
        responseText,
        arousal: emotionEngine.arousal,
      );

      // 转换为 ChatMessage，并附带延迟信息
      final aiMessages = <DelayedMessage>[];
      for (final msg in formattedMessages) {
        aiMessages.add(
          DelayedMessage(
            message: ChatMessage(
              content: msg['content'] as String,
              isUser: false,
              time: DateTime.now(),
              fullPrompt: assembleResult.systemPrompt, // 记录完整 Prompt
              tokensUsed: response.tokensUsed,         // 记录消耗 Token
            ),
            delay: Duration(
              milliseconds: ((msg['delay'] as double) * 1000).round(),
            ),
          ),
        );
      }

      // 【关键修复】动态计算记忆重要性 - 集成情感系统与记忆系统
      //
      // Step 1: 检测高情感价值时刻
      // - 条件A: AI情绪唤醒度或效价绝对值超过阈值
      // - 条件B: 用户输入包含偏好关键词（如"喜欢"、"讨厌"）
      final isHighArousal =
          emotionEngine.arousal > SettingsLoader.highEmotionalIntensity;
      final isHighValence =
          emotionEngine.valence.abs() > SettingsLoader.highEmotionalIntensity;
      final containsPreferenceKeyword = SettingsLoader.preferenceKeywords.any(
        (keyword) => text.contains(keyword),
      );

      final isHighEmotionalValue =
          isHighArousal || isHighValence || containsPreferenceKeyword;

      // Step 2: 计算重要性分数
      // - 使用 memoryEmotionalThreshold 参数（此处应用未使用的配置参数）
      // - 高情感时刻: emotionalThreshold + 0.1 ≈ 0.7 (确保超过存储阈值0.6)
      // - 普通消息: baseScore + 0.35 ≈ 0.65 (仍能被存储)
      double memoryScore;
      if (isHighEmotionalValue) {
        // Using memoryEmotionalThreshold parameter here
        memoryScore = SettingsLoader.memoryEmotionalThreshold + 0.1;
      } else {
        memoryScore = SettingsLoader.memoryBaseScore + 0.35;
      }

      // 使用 max 确保分数至少达到存储阈值以上
      final finalScore = max(memoryScore, 0.65);

      await memoryManager.addMemory(
        '用户：$text',
        importance: finalScore.clamp(0.0, 1.0),
      );

      // 【认知增强】记录对话到异步反思引擎（用于后台学习用户信息）
      if (_cognitiveEngineEnabled && _asyncReflectionEngine != null) {
        final fullResponse = formattedMessages
            .map((m) => m['content'])
            .join(' ');
        _asyncReflectionEngine!.recordFromMessages(
          text,
          fullResponse,
          emotionValence: emotionEngine.valence,
        );
      }

      // 【认知增强】记录反馈信号
      if (_cognitiveEngineEnabled &&
          _feedbackAnalyzer != null &&
          currentMessages.isNotEmpty) {
        final lastAiMessage = currentMessages.lastWhere(
          (m) => !m.isUser,
          orElse: () => currentMessages.last,
        );
        _feedbackAnalyzer!.inferFromBehavior(
          userMessage: text,
          previousAiResponse: lastAiMessage.content,
          responseDelay: DateTime.now().difference(lastAiMessage.time),
          userMessageLength: text.length,
          aiMessageLength: lastAiMessage.content.length,
        );
      }

      return ConversationResult(
        success: true,
        delayedMessages: aiMessages,
        tokensUsed: response.tokensUsed,
        snapshot: lastSnapshot,
      );
    } else {
      // 错误响应
      return ConversationResult(
        success: false,
        delayedMessages: [
          DelayedMessage(
            message: ChatMessage(
              content: '（${response.error ?? '网络连接失败'}）',
              isUser: false,
              time: DateTime.now(),
            ),
            delay: Duration.zero,
          ),
        ],
        tokensUsed: response.tokensUsed,
        error: response.error,
        snapshot: lastSnapshot,
      );
    }
  }

  // ========== 调试支持 ==========

  /// 获取当前引擎状态（用于调试）
  Map<String, dynamic> getDebugState() {
    return {
      'isRunning': _isRunning,
      'emotion': emotionEngine.emotionMap,
      'intimacy': _intimacy,
      'interactionCount': _interactionCount,
      'lastInteraction': _lastInteraction?.toIso8601String(),
      'lastProactiveMessage': _lastProactiveMessage?.toIso8601String(),
      'lastSnapshot': lastSnapshot?.toMap(),
    };
  }

  /// 格式化当前时间（供 AI 感知）
  String _formatCurrentTime() {
    final now = DateTime.now();
    final weekdays = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'];
    final weekday = weekdays[now.weekday - 1];

    final year = now.year;
    final month = now.month;
    final day = now.day;
    final hour = now.hour.toString().padLeft(2, '0');
    final minute = now.minute.toString().padLeft(2, '0');

    return '${year}年${month}月${day}日 $weekday $hour:$minute';
  }
}

/// 延迟消息 - 包含发送延迟信息
class DelayedMessage {
  final ChatMessage message;
  final Duration delay;

  const DelayedMessage({required this.message, required this.delay});
}

/// 对话处理结果
class ConversationResult {
  final bool success;
  final List<DelayedMessage> delayedMessages; // 带延迟的消息列表
  final int tokensUsed;
  final String? error;
  final PromptSnapshot? snapshot;

  const ConversationResult({
    required this.success,
    required this.delayedMessages,
    required this.tokensUsed,
    this.error,
    this.snapshot,
  });

  /// 获取所有消息（不含延迟信息，用于向后兼容）
  List<ChatMessage> get messages =>
      delayedMessages.map((d) => d.message).toList();
}
