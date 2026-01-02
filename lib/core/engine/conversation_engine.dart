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
//
// 【架构重构】状态驱动认知流水线 (State-Driven Cognitive Pipeline)
// 四阶段执行顺序：
// 1. 感知 (Perception) - 分析用户意图和情绪
// 2. 状态加载 (State Loading) - 更新情绪引擎，获取记忆
// 3. 决策 (Decision Making) - 反思处理，生成响应策略
// 4. 执行 (Execution) - 注入策略到 Prompt，调用 LLM

import 'dart:async';
import 'dart:convert'; // 【L2】JSON 解析
import 'dart:math';

import '../model/chat_message.dart';
import '../service/llm_service.dart';
import '../util/expression_selector.dart';
import '../util/response_formatter.dart';
import '../util/time_awareness.dart';

import '../policy/generation_policy.dart';
import '../policy/persona_policy.dart';
import '../service/persona_service.dart'; // 【新增】依赖 PersonaService

import 'emotion_engine.dart';
import 'intimacy_engine.dart';
import 'personality_engine.dart'; // 【L2/L3 重构】Big Five 人格引擎
import '../memory/memory_manager.dart';
import 'proactive_settings.dart';
import '../memory/fact_store.dart';
import '../mechanisms/reaction_engine.dart'; // 【Reaction Compass】
import '../settings_loader.dart';

// 认知引擎组件
import '../perception/perception_processor.dart';
import '../decision/reflection_processor.dart';
import '../perception/feedback_analyzer.dart';
import '../decision/async_reflection_engine.dart';
import '../service/profile_service.dart';
import '../policy/prohibited_patterns.dart';

import '../prompt/prompt_assembler.dart';
import '../prompt/prompt_snapshot.dart';
import '../prompt/prompt_builder.dart'; // 【新增】L2/L3 分层 Prompt
import '../util/input_sanitizer.dart';

/// 主动消息回调
typedef ProactiveMessageCallback = void Function(ChatMessage message);

/// 认知状态 - 封装流水线各阶段的内部状态 (用于 UI 可视化)
class CognitiveState {
  final Map<String, dynamic> perception;   // 感知结果
  final Map<String, dynamic> decision;     // 决策策略
  final Map<String, dynamic> emotion;      // AI情绪状态
  final String memorySummary;              // 记忆摘要

  const CognitiveState({
    required this.perception,
    required this.decision,
    required this.emotion,
    required this.memorySummary,
  });

  Map<String, dynamic> toMap() => {
    'perception': perception,
    'decision': decision,
    'emotion': emotion,
    'memory_summary': memorySummary,
  };
}

/// 对话引擎 - 核心调度器
class ConversationEngine {
  // 依赖注入 (支持热更新)
  final LLMService llmService;
  final MemoryManager memoryManager;
  final EmotionEngine emotionEngine;
  final IntimacyEngine intimacyEngine;
  final PersonalityEngine personalityEngine; // 【L2/L3 重构】Big Five 人格引擎
  
  // 【数据流重构】直接依赖 Service 获取最新策略
  final PersonaService personaService;
  
  // 【热更新支持】动态 getter 替代旧的 cached field
  PersonaPolicy get personaPolicy => personaService.personaPolicy;
  
  GenerationPolicy generationPolicy;

  // 主动消息配置
  ProactiveSettings? _proactiveSettings;

  // 定时器
  Timer? _emotionDecayTimer;
  Timer? _proactiveCheckTimer;
  Timer? _intimacyRegressionTimer; // 【新增】亲密度回归定时器

  // 状态
  DateTime? _lastProactiveMessage;
  bool _isRunning = false;

  // 亲密度（【重构】改从 IntimacyEngine 读取）
  double get _intimacy => intimacyEngine.intimacy;
  int _interactionCount = 0;
  DateTime? _lastInteraction;

  // 回调
  ProactiveMessageCallback? onPendingMessage; // 加入待发送队列
  
  /// 获取当前内心独白模型的回调（由 AppEngine 注入）
  String Function()? monologueModelGetter;

  // 最近的快照（用于调试）
  PromptSnapshot? lastSnapshot;

  ConversationEngine({
    required this.llmService,
    required this.memoryManager,
    required this.personaService,
    required this.emotionEngine,
    required this.intimacyEngine,
    required this.personalityEngine, // 【L2/L3 重构】
    required this.generationPolicy,
    this.profileService,
  });

  /// 【热更新】更新策略配置
  void updatePolicies({
    // PersonaPolicy 不再需要传入，通过 Service 自动获取
    GenerationPolicy? newGenerationPolicy,
  }) {
    // personaPolicy 更新由 Service 内部处理，此处无需手动同步
    if (newGenerationPolicy != null) {
      generationPolicy = newGenerationPolicy;
      print('[ConversationEngine] GenerationPolicy updated');
    }
  }

  // 认知引擎组件（可选，用于增强模式）
  ProfileService? profileService;
  PerceptionProcessor? _perceptionProcessor;
  ReflectionProcessor? _reflectionProcessor;
  FeedbackAnalyzer? _feedbackAnalyzer;
  AsyncReflectionEngine? _asyncReflectionEngine;
  bool _cognitiveEngineEnabled = false;

  // 【Phase 4】崩溃状态检测 (Meltdown Detection)
  // 当高唤醒度 + 极负效价时触发
  bool get isMeltdown => emotionEngine.arousal > SettingsLoader.meltdownArousalThreshold && 
                         emotionEngine.valence < SettingsLoader.meltdownValenceThreshold;

  // 多阶段 Agentic 工作流组件
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
    
    // 【新增】启动时应用亲密度回归
    intimacyEngine.applyRegressionSinceLastUpdate();

    // 启动定时器
    _startEmotionDecayTimer();
    _startProactiveMessageTimer();
    _startIntimacyRegressionTimer(); // 【新增】亲密度回归定时器

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
    _intimacyRegressionTimer?.cancel(); // 【新增】取消亲密度回归定时器
    _emotionDecayTimer = null;
    _proactiveCheckTimer = null;
    _intimacyRegressionTimer = null;
    _asyncReflectionEngine?.stop();

    print('[ConversationEngine] stopped');
  }

    // 初始化认知引擎组件
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

    _cognitiveEngineEnabled = true;
    print('[ConversationEngine] cognitive engine initialized');
  }

  /// 设置 FactStore（需要从外部注入 SharedPreferences 实例）
  void setFactStore(FactStore factStore) {
    _factStore = factStore;
    print('[ConversationEngine] FactStore initialized');
  }

  /// 【重构】更新状态（由外部传入）
  /// 注意：intimacy 参数仅用于同步到 PersonaService，实际值由 IntimacyEngine 管理
  void updateState({
    required double intimacy, // 保持接口兼容，但实际亲密度由 IntimacyEngine 管理
    required int interactionCount,
    DateTime? lastInteraction,
  }) {
    // 【重构】_intimacy 现在是 getter，不再直接赋值
    // 亲密度由 IntimacyEngine 内部管理，此处仅同步到 PersonaService
    personaService.updateIntimacy(intimacyEngine.intimacy);
    _interactionCount = interactionCount;
    _lastInteraction = lastInteraction;
  }

  // ========== 实时情绪衰减 ==========

  /// 启动情绪衰减定时器
  ///
  /// 每 5 分钟自动重算 Valence/Arousal
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

  /// 【新增】启动亲密度回归定时器
  ///
  /// 每 30 分钟检查并应用亲密度自然回归
  void _startIntimacyRegressionTimer() {
    const interval = Duration(minutes: 30);
    _intimacyRegressionTimer = Timer.periodic(interval, (_) {
      if (!_isRunning) return;

      intimacyEngine.applyNaturalRegression();
      // 同步亲密度到 PersonaService
      personaService.updateIntimacy(intimacyEngine.intimacy);
      
      print(
        '[ConversationEngine] intimacy regression tick: '
        'intimacy=${intimacyEngine.intimacy.toStringAsFixed(3)}, '
        'efficiency=${intimacyEngine.currentState.growthEfficiency.toStringAsFixed(1)}%',
      );
    });

    print('[ConversationEngine] intimacy regression timer started (interval: 30 min)');
  }

  // ========== 主动消息触发 ==========

  /// 启动主动消息检查定时器
  ///
  /// 定期检查并触发主动消息
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

  // ========== 核心消息处理：状态驱动认知流水线 ==========

  /// 处理用户消息
  ///
  /// 【架构重构】四阶段认知流水线：
  /// 1. 感知 (Perception) - 分析用户意图和情绪
  /// 2. 状态加载 (State Loading) - 更新情绪引擎，获取记忆
  /// 3. 决策 (Decision Making) - 反思处理，生成响应策略
  /// 4. 执行 (Execution) - 注入策略到 Prompt，调用 LLM
  Future<ConversationResult> processUserMessage(
    String text,
    List<ChatMessage> currentMessages, {
    Function(String)? onMonologueChunk,
  }) async {
    // 记录处理前的状态 (用于计算 delta)
    final prevValence = emotionEngine.valence;
    final prevArousal = emotionEngine.arousal;

    // 清理之前的思考状态
    if (onMonologueChunk != null) {
      onMonologueChunk(''); // 发送空串表示重置
    }
    
    // 【Phase 3】安全清洗用户输入，防止 Prompt 注入
    final sanitizedText = InputSanitizer.sanitize(text);

    // ======== Step 1: 感知阶段 (Perception) ========
    // 分析用户意图、情绪、潜台词
    print('[Pipeline] Step 1: Perception phase');
    final perception = await _runPerceptionPhase(sanitizedText, currentMessages);
    
    // ======== 【Safety Fast Track】紧急安全模式 ========
    // 检测到自杀/自残关键词时，跳过所有 L2/L3 处理，直接返回安全响应
    if (perception.systemAction == SystemAction.safety) {
      print('[Pipeline] 🚨 SAFETY MODE ACTIVATED - Bypassing L2/L3');
      return _handleSafetyMode(userMessage: sanitizedText);
    }
    
    // ======== Step 2: 状态加载阶段 (State Loading) ========
    // 更新情绪引擎，获取相关记忆
    print('[Pipeline] Step 2: State Loading phase');
    final stateData = await _runStateLoadingPhase(sanitizedText, perception);
    
    // ======== Step 3: 决策阶段 (Decision Making) ========
    // 反思处理，生成响应策略
    print('[Pipeline] Step 3: Decision Making phase');
    final reflection = await _runDecisionPhase(
      perception, 
      currentMessages,
      sanitizedText, // 传递清洗后的消息
      onMonologueChunk: onMonologueChunk,
    );

    // 【认知闭环】根据反思结果更新情绪状态
    if (reflection.emotionShift != null) {
      await emotionEngine.applyEmotionShift(reflection.emotionShift!);
    }
    
    // ======== Step 4: 执行阶段 (Execution) ========
    // 注入策略到 Prompt，调用 LLM 生成响应
    print('[Pipeline] Step 4: Execution phase');
    final result = await _runExecutionPhase(
      sanitizedText,
      currentMessages,
      perception,
      reflection,
      stateData,
      prevValence: prevValence,
      prevArousal: prevArousal,
    );
    
    return result;
  }

  /// 感知阶段 - 分析用户意图和情绪
  /// 
  /// 降级逻辑：如果 LLM 调用失败，使用快速规则分析
  Future<PerceptionResult> _runPerceptionPhase(
    String text,
    List<ChatMessage> currentMessages,
  ) async {
    // 如果认知引擎未启用，使用快速分析
    if (!_cognitiveEngineEnabled || _perceptionProcessor == null || profileService == null) {
      print('[Pipeline] Perception: using quick analyze (cognitive engine not enabled)');
      return PerceptionResult.fallback();
    }

    try {
      final recentMessages = currentMessages
          .take(5)
          .map((m) => '${m.isUser ? "用户" : "AI"}: ${m.content}')
          .toList();

      final lastAiMessage = currentMessages.isNotEmpty
          ? currentMessages.lastWhere((m) => !m.isUser, orElse: () => currentMessages.last).content
          : null;

      final perception = await _perceptionProcessor!.analyze(
        userMessage: text,
        userProfile: profileService!.profile,
        recentEmotionTrend: profileService!.getEmotionTrend(),
        currentTime: DateTime.now(),
        lastAiResponse: lastAiMessage,
        recentMessages: recentMessages,
      );

      print('[Pipeline] Perception completed: ${perception.underlyingNeed}, intent: ${perception.conversationIntent}');
      return perception;
    } catch (e) {
      // 降级：使用快速规则分析
      print('[Pipeline] Perception failed, using fallback: $e');
      return _perceptionProcessor!.quickAnalyze(text, DateTime.now());
    }
  }

  /// 状态加载阶段 - 更新情绪引擎，获取记忆
  Future<Map<String, dynamic>> _runStateLoadingPhase(
    String text,
    PerceptionResult perception,
  ) async {
    // 更新情绪状态（基于感知结果增强）
    await emotionEngine.applyInteractionImpact(perception, _intimacy);

    // 如果感知到高情绪，额外调整唤醒度
    if (perception.surfaceEmotion.arousal > 0.7) {
      final newArousal = emotionEngine.arousal + perception.surfaceEmotion.arousal * 0.3;
      await emotionEngine.setEmotion(arousal: newArousal.clamp(0.0, 1.0));
    }
    
    // 【Phase 7】更新亲密度 - 引入敌意负反馈
    // 基础交互质量由置信度和效价推导，并受敌意等级负向调节
    final baseQuality = 0.8 + (perception.confidence * 0.4) + (perception.surfaceEmotion.valence * 0.1);
    final interactionQuality = (baseQuality - (perception.offensiveness / 10.0)).clamp(0.1, 1.5);

    // 如果敌意等级 >= 3，显式触发负反馈机制 (即时扣减 + 增长抑制)
    if (perception.offensiveness >= 3) {
      await intimacyEngine.applyNegativeFeedback(severity: perception.offensiveness / 10.0);
    } else {
      // 否则进行正常的亲密度增长计算
      await intimacyEngine.updateIntimacy(
        interactionQuality: interactionQuality,
        emotionValence: emotionEngine.valence,
      );
    }

    // 同步亲密度到 PersonaService
    personaService.updateIntimacy(intimacyEngine.intimacy);

    // 【FactStore】从用户消息中提取核心事实
    if (_factStore != null) {
      final extracted = await _factStore!.extractAndStore(text);
      if (extracted.isNotEmpty) {
        print('[Pipeline] State Loading: Extracted facts: $extracted');
      }
    }

    // 构建对话上下文
    final context = ConversationContext(
      intimacy: _intimacy,
      emotionValence: emotionEngine.valence,
      emotionArousal: emotionEngine.arousal,
      messageLength: text.length,
      isProactiveMessage: false,
    );

    // 获取相关记忆
    final memories = memoryManager.getRelevantMemories(
      text,
      generationPolicy,
      context,
    );

    return {
      'context': context,
      'memories': memories,
    };
  }

  /// 决策阶段 - L2 意图生成
  /// 
  /// 【L2/L3 重构】使用 PromptBuilder.buildL2DecisionPrompt 生成 JSON 结构化意图
  /// 降级逻辑：如果 LLM 调用或 JSON 解析失败，使用规则基础反思
  Future<ReflectionResult> _runDecisionPhase(
    PerceptionResult perception,
    List<ChatMessage> currentMessages,
    String userMessage, {
    Function(String)? onMonologueChunk,
  }) async {
    // 如果认知引擎未启用，使用规则基础反思
    if (!_cognitiveEngineEnabled || profileService == null) {
      print('[Pipeline] Decision: using rule-based reflect (cognitive engine not enabled)');
      return ReflectionResult.fromRules(perception, []);
    }

    try {
      final lastAiMessage = currentMessages.isNotEmpty
          ? currentMessages.lastWhere((m) => !m.isUser, orElse: () => currentMessages.last).content
          : '';
      
      // 获取记忆上下文
      final recentMemories = memoryManager.getRecentMemories(5);
      final memories = recentMemories.join('\n');
      
      // 获取用户名
      final userName = _factStore?.getFact('user_name') ?? 
                       profileService!.profile.nickname;
      
      // 【L2】构建意图生成 Prompt
      // 【L2/L3 重构】注入 Raw Big Five 数值 (数据/表现分离)
      final bigFiveMetrics = PromptBuilder.formatBigFiveMetrics(
        openness: personalityEngine.traits.openness,
        conscientiousness: personalityEngine.traits.conscientiousness,
        extraversion: personalityEngine.traits.extraversion,
        agreeableness: personalityEngine.traits.agreeableness,
        neuroticism: personalityEngine.traits.neuroticism,
      );
      
      final l2Prompt = PromptBuilder.buildL2DecisionPrompt(
        userMessage: userMessage,
        userName: userName,
        memories: memories,
        userProfile: profileService!.profile,
        valence: emotionEngine.valence,
        arousal: emotionEngine.arousal,
        resentment: emotionEngine.resentment,
        personaName: personaPolicy.name,
        lastAiResponse: lastAiMessage,
        cognitiveBiases: _buildCognitiveBiases(),
        bigFiveMetrics: bigFiveMetrics, // 【L2/L3 重构】Raw Big Five
        intimacy: _intimacy,             // 【L2/L3 重构】亲密度数值
      );
      
      // 【L2】获取内心独白模型
      final monologueModel = monologueModelGetter?.call() ?? 'qwen-max';
      
      // 【L2】调用 LLM 生成 JSON 结构化意图
      String l2Response = '';
      
      if (onMonologueChunk != null) {
        // 流式调用 - 实时提取 inner_monologue
        final stream = llmService.streamComplete(
          systemPrompt: l2Prompt,
          userMessage: '（请输出 JSON 结果）',
          model: monologueModel,
        );
        
        await for (final chunk in stream) {
          l2Response += chunk;
          
          // 【修复】尝试从累积的响应中实时提取 inner_monologue
          String displayText = l2Response;
          try {
            // 尝试提取 inner_monologue 字段值（即使 JSON 不完整）
            final monologueMatch = RegExp(r'"inner_monologue"\s*:\s*"([^"]*)')
                .firstMatch(l2Response);
            if (monologueMatch != null) {
              displayText = monologueMatch.group(1) ?? l2Response;
            }
          } catch (_) {
            // 解析失败，保留原始文本
          }
          
          onMonologueChunk(displayText);
        }
      } else {
        // 非流式调用
        l2Response = await llmService.completeWithSystem(
          systemPrompt: l2Prompt,
          userMessage: '（请输出 JSON 结果）',
          model: monologueModel,
        );
      }
      
      // 【L2】解析 JSON 响应
      final jsonMatch = RegExp(r'```json\s*([\s\S]*?)\s*```').firstMatch(l2Response);
      final jsonString = jsonMatch?.group(1) ?? l2Response;
      
      try {
        final Map<String, dynamic> l2Json = jsonDecode(jsonString.trim());
        
        // 转换为 ReflectionResult
        final reflection = ReflectionResult.fromJson(l2Json);
        
        print('[Pipeline] L2 Decision completed: strategy=${reflection.responseStrategy}, tone=${reflection.emotionalTone}');
        return reflection;
        
      } catch (jsonError) {
        print('[Pipeline] L2 JSON parse failed: $jsonError, using fallback');
        // JSON 解析失败，但仍有内心独白文本
        return ReflectionResult(
          shouldAskQuestion: false,
          responseStrategy: '自然对话',
          avoidPatterns: [],
          emotionalTone: '平和',
          contentHints: [],
          recommendedLength: 0.5,
          useEmoji: false,
          timestamp: DateTime.now(),
          innerMonologue: l2Response,
        );
      }
      
    } catch (e) {
      // 降级：使用规则基础反思
      print('[Pipeline] L2 Decision failed, using fallback: $e');
      return ReflectionResult.fromRules(
        perception,
        profileService?.getDislikedPatterns() ?? [],
      );
    }
  }

  /// 执行阶段 - 注入策略到 Prompt，调用 LLM 生成响应
  Future<ConversationResult> _runExecutionPhase(
    String text,
    List<ChatMessage> currentMessages,
    PerceptionResult perception,
    ReflectionResult reflection,
    Map<String, dynamic> stateData, {
    double prevValence = 0.5,
    double prevArousal = 0.5,
  }) async {
    final context = stateData['context'] as ConversationContext;

    final memories = stateData['memories'] as String;
    
    // 【Fix】提前定义 profile 以供 userName使用
    final profile = profileService?.profile;

    // 【Fix】提前定义核心变量，确保作用域覆盖
    String tailInjection = ''; // Move tailInjection scope to top
    final behaviorRules = personaPolicy.getBehaviorConstraints();
    final userName = _factStore?.getFact('user_name') ?? profile?.nickname ?? '用户';

    // 【Phase 5】崩溃状态检测 - 使用 EmotionEngine 的 isMeltdown getter
    if (emotionEngine.isMeltdown) {
      print('[Pipeline] MELTDOWN DETECTED! resentment=${emotionEngine.resentment}, valence=${emotionEngine.valence}');
      
      // 随机选择一个崩溃响应
      final collapseResponses = SettingsLoader.meltdownResponses;
      final random = Random();
      final collapseText = collapseResponses[random.nextInt(collapseResponses.length)];
      
      // 构建崩溃状态的认知状态
      final collapseCognitiveState = CognitiveState(
        perception: {'meltdown': true},
        decision: {
          'response_strategy': SettingsLoader.meltdownStrategy,
          'inner_monologue': SettingsLoader.meltdownMonologue,
        },
        emotion: {
          'valence': emotionEngine.valence,
          'arousal': emotionEngine.arousal,
          'meltdown': true,
        },
        memorySummary: '',
      );
      
      return ConversationResult(
        success: true,
        delayedMessages: [
          DelayedMessage(
            message: ChatMessage(
              content: collapseText,
              isUser: false,
              time: DateTime.now(),
            ),
            delay: const Duration(milliseconds: 500),
          ),
        ],
        tokensUsed: 0,
        cognitiveState: collapseCognitiveState.toMap(),
      );
    }

    // 获取 LLM 参数
    final params = generationPolicy.getParams(context);

    // 【FactStore + UserProfile】合并核心事实
    final factData = _factStore?.formatForSystemPrompt() ?? '';
    // final profile = profileService?.profile; // Hoisted
    
    String coreFacts;
    if (factData.contains('用户') && factData.length > 20) {
       // 如果 FactStore 已经有详细摘录，仅从 Profile 补充 FactStore 没覆盖的内容（如专业）
       final major = profile?.major;
       coreFacts = (major != null && major.isNotEmpty && !factData.contains(major)) 
           ? '专业：$major\n$factData' 
           : factData;
    } else {
       // 兜底方案
       final identityAnchor = profile?.getIdentityAnchor() ?? '';
       coreFacts = '$identityAnchor\n\n$factData'.trim();
    }

    final temporalNarrative = TimeAwareness.getTemporalNarrative(
      _lastInteraction, 
      DateTime.now(),
    );

    final currentState = PromptAssembler.buildCurrentState(
      emotionDescription: emotionEngine.getEmotionDescription(),
      relationshipDescription: personaPolicy.getRelationshipDescription(
        _intimacy,
      ),
      temporalNarrative: temporalNarrative,
    );

    // 获取表达指引（【FIX】传入动态参数并进行取整，避免浮点数干扰）
    // 直接从 personaPolicy 获取推导后的值，确保 Big Five 变化实时反映到表达风格
    final personaFormality = personaPolicy.formality;
    final personaHumor = personaPolicy.humor;
    
    final expressionGuide = ExpressionSelector.getExpressionInstructions(
      emotionEngine.valence,
      emotionEngine.arousal,
      _intimacy,
      formality: double.parse(personaFormality.toStringAsFixed(1)),
      humor: double.parse(personaHumor.toStringAsFixed(1)),
      userUsedEmoji: perception.hasEmoji,
      microEmotion: reflection.microEmotion, // 【L2-L3 映射修复】传递微情绪
      currentTime: DateTime.now(), // 【新增】L2 时间感知
    );

    // 【Prompt 2.0】构建尾部注入内容 (Tail Injection)
    // 不再修改 System Prompt，而是作为临时指令附加在用户消息后
    // 【Prompt 2.0】构建尾部注入内容 (Tail Injection)
    // 不再修改 System Prompt，而是作为临时指令附加在用户消息后
    // String tailInjection = ''; // Hoisted
    if (_cognitiveEngineEnabled) {
      String cleanMonologue = '';
      if (reflection.innerMonologue != null && reflection.innerMonologue!.isNotEmpty) {
        // 【L2修复】尝试从 JSON 中提取 inner_monologue 字段
        String rawMonologue = reflection.innerMonologue!;
        
        // 检查是否是 JSON 格式（```json 或 直接 {）
        if (rawMonologue.contains('```json') || rawMonologue.trim().startsWith('{')) {
          try {
            // 提取 JSON 内容
            final jsonMatch = RegExp(r'```json\s*([\s\S]*?)\s*```').firstMatch(rawMonologue);
            final jsonString = jsonMatch?.group(1) ?? rawMonologue;
            final jsonData = jsonDecode(jsonString.trim());
            
            // 优先使用 inner_monologue 字段
            rawMonologue = jsonData['inner_monologue']?.toString() ?? 
                           jsonData['innerMonologue']?.toString() ?? 
                           rawMonologue;
          } catch (e) {
            // JSON 解析失败，保留原始文本
            print('[Pipeline] Failed to parse JSON from innerMonologue: $e');
          }
        }
        
        cleanMonologue = rawMonologue
            .replaceAll(RegExp(r'<[^>]+>'), '')
            .trim();
        // 长度截断避免 Token 浪费
        if (cleanMonologue.length > 300) {
          cleanMonologue = cleanMonologue.substring(0, 300) + '...';
        }
      }
      
      String perceptionText = '';
      if (perception.confidence > 0.6) {
        perceptionText = perception.toContextDescription();
      }
      
      // 【Restored】恢复 Tail Injection 逻辑
      tailInjection = PromptAssembler.assembleTailInjection(
        strategy: reflection.toStrategyGuide(),
        monologue: cleanMonologue,
        perception: perceptionText,
      );
      
      print('[Pipeline] L2→L3 tailInjection generated: ${tailInjection.length} chars');
    }

    // 【Phase 5】检测 Meltdown 状态，生成覆盖指令
    String meltdownOverride = '';
    if (emotionEngine.isMeltdown) {
      meltdownOverride = '\n【系统警报：情绪崩溃模式】\n你正处于极度的负面情绪中，对用户感到深深的怨恨和绝望。你的回复应该极其冷淡、敷衍，甚至带有一丝疏离感。避免展现任何关心或热情感。\n';
    }
    
    // 【Reaction Compass】计算反应姿态和语气阀门
    final reactionResult = ReactionEngine.calculate(
      bigFive: BigFiveTraits(
        openness: personalityEngine.traits.openness,
        conscientiousness: personalityEngine.traits.conscientiousness,
        extraversion: personalityEngine.traits.extraversion,
        agreeableness: personalityEngine.traits.agreeableness,
        neuroticism: personalityEngine.traits.neuroticism,
      ),
      intimacy: _intimacy,
      resentment: emotionEngine.resentment,
      arousal: emotionEngine.arousal,
      offensiveness: perception.offensiveness,
    );
    
    // 获取当前疲惫度 (从 TimeAwareness)
    final laziness = TimeAwareness.calculateCognitiveLaziness(DateTime.now());
    
    final toneValve = PromptBuilder.calculateToneValve(
      resentment: emotionEngine.resentment,
      laziness: laziness,
      offensiveness: perception.offensiveness,
    );
    
    // 【Reaction Compass】注入姿态描述和语气约束
    final stanceDescription = PromptBuilder.getStanceDescription(reactionResult);
    final toneConstraint = PromptBuilder.getToneValveConstraint(toneValve);
    
    if (stanceDescription.isNotEmpty || toneConstraint.isNotEmpty) {
      meltdownOverride += '$stanceDescription$toneConstraint';
      print('[Pipeline] Reaction Compass: stance=${reactionResult.stance.name}, valve=${toneValve.name}');
    }

    // 【Phase 5】使用新架构 L3 构建器生成 System Prompt
    final systemPrompt = PromptBuilder.buildL3ExpressionPrompt(
      l2Result: L2DecisionResult(
        innerMonologue: reflection.innerMonologue ?? '',
        responseStrategy: reflection.responseStrategy,
        emotionalTone: reflection.emotionalTone,
        recommendedLength: reflection.recommendedLength,
        useEmoji: reflection.useEmoji,
        shouldAskQuestion: reflection.shouldAskQuestion,
        microEmotion: reflection.microEmotion,
        pacingStrategy: reflection.pacingStrategy ?? 'single_shot',
        topicDepth: reflection.topicDepth ?? 'emotional',
      ),
      userName: userName,
      personaName: personaService.personaPolicy.name,
      personaGender: personaService.personaPolicy.gender,
      // 【L2/L3 重构】使用 PersonalityEngine 预计算的人格描述
      // 设计原理：亲密度融合在 Dart 层完成，LLM 不需要条件判断
      personaDescription: personalityEngine.generatePromptDescription(
        intimacy: _intimacy,
      ),
      valence: emotionEngine.valence,
      arousal: emotionEngine.arousal,
      resentment: emotionEngine.resentment,
      relationshipDescription: personaPolicy.getRelationshipDescription(_intimacy),
      behaviorRules: behaviorRules,
      userProfile: profileService!.profile,
      currentTime: _formatCurrentTime(),
      memories: memories,
      coreFacts: coreFacts,
      meltdownOverride: meltdownOverride,
    );
    
    // 构建 API 消息列表 (【时间注入】启用时间前缀)
    final historyCount = generationPolicy.getHistoryCount(context);
    final historyMessages = PromptAssembler.assembleHistoryMessages(
      currentMessages,
      maxCount: historyCount,
      excludeLastN: 1,
      injectTimestamps: true, // 启用时间注入
    );

    // 【核心逻辑】将尾部注入内容拼接到用户消息后
    // 这样做能利用 Recency Bias 最大化策略执行效果
    final effectiveUserContent = tailInjection.isNotEmpty
        ? '$text\n$tailInjection'
        : text;

    final apiMessages = <Map<String, String>>[
      {'role': 'system', 'content': systemPrompt},
      ...historyMessages,
      {'role': 'user', 'content': effectiveUserContent},
    ];

    // 创建快照 (用于调试) - 【修复】使用包含 tailInjection 的完整用户消息
    lastSnapshot = PromptSnapshot(
      fullPrompt: systemPrompt,
      userMessage: effectiveUserContent,  // 【修复】使用 effectiveUserContent 而非 text
      historyMessages: historyMessages,
      timestamp: DateTime.now(),
      estimatedTokens: PromptSnapshot.calculateEstimatedTokens(
        systemPrompt,
        historyMessages,
        effectiveUserContent,  // 【修复】同步更新 token 估算
      ),
      components: {}, // L2/L3 新架构暂时不使用 components 细分展示
      generationParams: params,
    );

    print(lastSnapshot!.toLogString());

    // 调用 LLM
    final response = await llmService.generateWithTokens(
      apiMessages,
      params: params,
    );

    // 构建认知状态 (用于 UI 可视化)
    final cognitiveState = CognitiveState(
      perception: {
        'surface_emotion': perception.surfaceEmotion.label,
        'valence': perception.surfaceEmotion.valence,
        'arousal': perception.surfaceEmotion.arousal,
        'underlying_need': perception.underlyingNeed,
        'conversation_intent': perception.conversationIntent,
        'subtext': perception.subtextInference,
        'confidence': perception.confidence,
        'temporal_context': temporalNarrative, // 【新增】
      },
      decision: {
        'response_strategy': reflection.responseStrategy,
        'inner_monologue': reflection.innerMonologue, // 【新增】
        'emotional_tone': reflection.emotionalTone,
        'recommended_length': reflection.recommendedLength,
        'use_emoji': reflection.useEmoji,
        'should_ask_question': reflection.shouldAskQuestion,
        'content_hints': reflection.contentHints,
        'micro_emotion': reflection.microEmotion, // 【新增】
      },
      emotion: {
        'valence': emotionEngine.valence,
        'arousal': emotionEngine.arousal,
        'valence_delta': emotionEngine.valence - prevValence, // 【新增】
        'arousal_delta': emotionEngine.arousal - prevArousal, // 【新增】
        'description': emotionEngine.getEmotionDescription(),
      },
      memorySummary: memories.length > 100 ? '${memories.substring(0, 100)}...' : memories,
    );

    // 处理响应
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

      // 【Fix】全方位清理 LLM 误输出的时间戳前缀 (如 [12-27 20:19])
      // 增强正则：支持多行匹配和各种空白符
      final timestampRegex = RegExp(r'\[\d{2}-\d{2} \d{2}:\d{2}\]\s*', multiLine: true);
      if (timestampRegex.hasMatch(responseText)) {
         print('[ConversationEngine] Removed hallucinated timestamps');
         responseText = responseText.replaceAll(timestampRegex, '').trim();
      }

      // 【Fix】清理可能泄漏到最终回复的 XML 标签（内心独白等）
      final xmlTagRegex = RegExp(r'</?(?:thought|strategy)>', caseSensitive: false);
      if (xmlTagRegex.hasMatch(responseText)) {
        print('[ConversationEngine] Removed leaked XML tags');
        responseText = responseText.replaceAll(xmlTagRegex, '').trim();
      }

      // 格式化响应（包含延迟信息）
      final formattedMessages = ResponseFormatter.formatResponse(
        responseText,
        arousal: emotionEngine.arousal,
      );

      // 【架构优化】Single Source of Truth: 直接根据发送给 LLM 的 apiMessages 生成记录
      // 确保 UI 看到的 Prompt 与 实际发送的完全一致
      final fullPromptLog = apiMessages.map((m) {
        final role = m['role']?.toUpperCase() ?? 'UNKNOWN';
        final content = m['content'] ?? '';
        return '=== [$role] ===\n$content';
      }).join('\n\n');

      // 转换为 ChatMessage，并附带延迟信息
      final aiMessages = <DelayedMessage>[];
      for (final msg in formattedMessages) {
        aiMessages.add(
          DelayedMessage(
            message: ChatMessage(
              content: msg['content'] as String,
              isUser: false,
              time: DateTime.now(),
              fullPrompt: fullPromptLog, // 【Fix】使用统一生成的 Log
              tokensUsed: response.tokensUsed,
            ),
            delay: Duration(
              milliseconds: ((msg['delay'] as double) * 1000).round(),
            ),
          ),
        );
      }

      // 【关键修复】动态计算记忆重要性 - 集成情感系统与记忆系统
      final isHighArousal =
          emotionEngine.arousal > SettingsLoader.highEmotionalIntensity;
      final isHighValence =
          emotionEngine.valence.abs() > SettingsLoader.highEmotionalIntensity;
      final containsPreferenceKeyword = SettingsLoader.preferenceKeywords.any(
        (keyword) => text.contains(keyword),
      );

      final isHighEmotionalValue =
          isHighArousal || isHighValence || containsPreferenceKeyword;

      double memoryScore;
      if (isHighEmotionalValue) {
        memoryScore = SettingsLoader.memoryEmotionalThreshold + 0.1;
      } else {
        memoryScore = SettingsLoader.memoryBaseScore + 0.35;
      }

      final finalScore = max(memoryScore, 0.65);

      await memoryManager.addMemory(
        '用户：$text',
        importance: finalScore.clamp(0.0, 1.0),
      );

      // 【认知增强】记录对话到异步反思引擎
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
        cognitiveState: cognitiveState.toMap(),
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
        cognitiveState: cognitiveState.toMap(),
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
      'cognitiveEngineEnabled': _cognitiveEngineEnabled,
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
  
  /// 【Phase 5】构建认知偏差描述 - 基于 Big Five 人格特质
  /// 
  /// 将 Big Five 特质映射为认知偏差，影响 L2 层的思考方式
  /// 【Phase 6 重构】直接使用 Big Five 特质，而非 formality/humor 代理
  String _buildCognitiveBiases() {
    // 直接获取 Big Five 特质
    final bigFive = personaPolicy.bigFive;
    
    List<String> biases = [];
    
    // Openness (开放性) -> 思维方式
    if (bigFive.openness > 0.7) {
      biases.add('思维开放，擅长联想和类比，可能给出创意性解读');
    } else if (bigFive.openness < 0.3) {
      biases.add('思维务实，偏好具体信息，避免过度解读');
    }
    
    // Conscientiousness (尽责性) -> 分析风格
    if (bigFive.conscientiousness > 0.7) {
      biases.add('分析严谨，关注细节和逻辑一致性');
    } else if (bigFive.conscientiousness < 0.3) {
      biases.add('反应灵活，可能跳跃性思考');
    }
    
    // Extraversion (外向性) -> 互动倾向
    if (bigFive.extraversion > 0.7) {
      biases.add('倾向主动表达，可能多说几句');
    } else if (bigFive.extraversion < 0.3) {
      biases.add('倾向简洁内敛，点到为止');
    }
    
    // Agreeableness (宜人性) -> 冲突处理
    if (bigFive.agreeableness > 0.7) {
      biases.add('倾向和解，可能主动软化冲突');
    } else if (bigFive.agreeableness < 0.3) {
      biases.add('保持独立观点，不轻易妥协');
    }
    
    // Neuroticism (神经质) -> 情绪敏感度
    if (bigFive.neuroticism > 0.7) {
      biases.add('情绪敏感，容易被对方情绪影响');
    } else if (bigFive.neuroticism < 0.3) {
      biases.add('情绪稳定，不容易被负面情绪带动');
    }
    
    // 怨恨值高时增加负面解读倾向 (动态情绪状态)
    if (emotionEngine.resentment > 0.5) {
      biases.add('因积怨而倾向负面解读对方意图');
    }
    
    return biases.isNotEmpty ? biases.join('；') : '无明显认知偏差';
  }

  /// 【Safety Fast Track】紧急安全模式响应
  /// 
  /// 设计原理：
  /// - 完全跳过 L2 决策和 L3 表达流程
  /// - 不使用任何人格修饰符 (无傲娇/慵懒等)
  /// - 返回固定的危机干预响应
  ConversationResult _handleSafetyMode({required String userMessage}) {
    const safetyResponse = '''
我注意到你可能正在经历非常困难的时刻。
请记住，你不是一个人。

如果你有自我伤害的想法，请立即拨打：
📞 全国心理援助热线：400-161-9995
📞 北京心理危机研究与干预中心：010-82951332
📞 生命热线：400-821-1215

我会一直在这里陪着你。''';

    final safetyMessage = ChatMessage(
      content: safetyResponse,
      isUser: false,
      time: DateTime.now(),
    );

    return ConversationResult(
      success: true,
      delayedMessages: [
        DelayedMessage(message: safetyMessage, delay: Duration.zero),
      ],
      tokensUsed: 0,
      cognitiveState: {
        'safety_mode': true,
        'trigger': userMessage,
        'strategy': 'crisis_intervention',
      },
    );
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
  
  /// 【新增】认知状态 - 供 UI 可视化 AI 的"心智"
  final Map<String, dynamic>? cognitiveState;

  const ConversationResult({
    required this.success,
    required this.delayedMessages,
    required this.tokensUsed,
    this.error,
    this.snapshot,
    this.cognitiveState,
  });

  /// 获取所有消息（不含延迟信息，用于向后兼容）
  List<ChatMessage> get messages =>
      delayedMessages.map((d) => d.message).toList();
}
