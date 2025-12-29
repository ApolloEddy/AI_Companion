// AppEngine - UI 适配层
//
// 设计原理：
// - 重构后：仅保留 Provider 适配和 UI 状态管理
// - 业务逻辑委托给 ConversationEngine
// - 保持 UI 层 (main_screen.dart) 无需修改

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'model/chat_message.dart';
import 'config.dart';
import 'settings_loader.dart';
import 'service/llm_service.dart';
import 'service/chat_history_service.dart';
import 'service/database_helper.dart';
import 'model/user_profile.dart';

// 新架构导入
import 'policy/generation_policy.dart';
import 'policy/persona_policy.dart';
import 'engine/emotion_engine.dart';
import 'memory/memory_manager.dart'; // Moved to memory
import 'engine/conversation_engine.dart';
import 'memory/fact_store.dart'; // Moved to memory

// 保留向后兼容
import 'service/persona_service.dart';
import 'service/profile_service.dart';
import 'service/startup_greeting_service.dart';

// 配置系统
import 'config/config_registry.dart';

class AppEngine extends ChangeNotifier {
  List<ChatMessage> messages = [];
  bool isLoading = false;
  bool isLoadingHistory = false;
  bool hasMoreHistory = false;
  int _oldestLoadedIndex = 0;

  // Token 统计
  int _totalTokensUsed = 0;
  int get totalTokensUsed => _totalTokensUsed;

  // 核心服务
  late LLMService llm;
  late ChatHistoryService chatHistory;
  late SharedPreferences prefs;

  // 新架构组件
  late ConversationEngine _conversationEngine;
  late EmotionEngine _emotionEngine;
  late MemoryManager _memoryManager;
  late PersonaPolicy _personaPolicy;
  late GenerationPolicy _generationPolicy;
  
  // Phase 2: FactStore 引用（用于 MemoryManagerScreen）
  late FactStore _factStore;
  FactStore get factStore => _factStore;

  // 向后兼容：保留旧服务引用
  late PersonaService persona;

  // 认知引擎：用户画像服务
  late ProfileService _profileService;

  // 启动问候服务
  StartupGreetingService? _startupGreetingService;

  bool isInitialized = false;


  Map<String, dynamic> personaConfig = {
    'name': '小悠',
    'gender': '女性',
    'age': '20岁左右的少女',
    'character': '温柔细腻，有时会害羞，真心对待朋友',
    'interests': '看小说、发呆、聊天',
    'values': ['真诚', '善良'],
    'formality': 0.5,
    'humor': 0.5,
  };

  // 最近的认知状态与流式独白（供 UI 层消费）
  Map<String, dynamic> _currentThoughtProcess = {};
  String _streamingMonologue = '';
  
  /// 获取实时步进的内心独白
  String get streamingMonologue => _streamingMonologue;

  /// 获取当前思考过程（UI 层可用）
  Map<String, dynamic> get currentThoughtProcess =>
      Map.unmodifiable(_currentThoughtProcess);

  /// 获取情绪状态（用于 UI 显示）
  Map<String, dynamic> get emotion => _emotionEngine.emotionMap;

  /// 获取亲密度
  double get intimacy => persona.intimacy;

  /// 获取记忆库条目数量（从持久化存储读取）
  int get memoryCount => _memoryManager.count;

  /// 获取已加载的对话消息数量
  int get chatCount => messages.length;

  /// 获取数据库中的总对话消息数量（异步获取后缓存）
  int _totalChatCount = 0;
  int get totalChatCount => _totalChatCount;
  
  /// 异步刷新总消息数
  Future<void> refreshTotalChatCount() async {
    _totalChatCount = await chatHistory.getTotalCount();
    notifyListeners();
  }

  /// 待发送消息队列（主动消息）
  final List<ChatMessage> _pendingMessages = [];
  List<ChatMessage> get pendingMessages => List.unmodifiable(_pendingMessages);
  
  // ======== 内心独白模型设置 ========
  String get monologueModel => 
      prefs.getString(AppConfig.monologueModelKey) ?? AppConfig.defaultMonologueModel;
  
  Future<void> updateMonologueModel(String model) async {
    await prefs.setString(AppConfig.monologueModelKey, model);
    notifyListeners();
    print('[AppEngine] Monologue model updated to: $model');
  }
  
  // ======== 头像设置 ========
  String? get userAvatarPath => prefs.getString(AppConfig.userAvatarKey);
  String? get aiAvatarPath => prefs.getString(AppConfig.aiAvatarKey);
  
  Future<void> updateUserAvatar(String? path) async {
    if (path != null && path.isNotEmpty) {
      await prefs.setString(AppConfig.userAvatarKey, path);
    } else {
      await prefs.remove(AppConfig.userAvatarKey);
    }
    notifyListeners();
  }
  
  Future<void> updateAiAvatar(String? path) async {
    if (path != null && path.isNotEmpty) {
      await prefs.setString(AppConfig.aiAvatarKey, path);
    } else {
      await prefs.remove(AppConfig.aiAvatarKey);
    }
    notifyListeners();
  }

  Future<void> init() async {
    await SettingsLoader.loadAll();
    
    // 【新架构】加载配置注册表
    await ConfigRegistry.instance.loadAll();

    prefs = await SharedPreferences.getInstance();

    _loadPersonaConfig();
    _loadTokenCount();

    String key =
        prefs.getString(AppConfig.apiKeyKey) ?? AppConfig.defaultApiKey;
    String savedModel =
        prefs.getString(AppConfig.modelKey) ?? AppConfig.defaultModel;
    llm = LLMService(key, model: savedModel);

    // 初始化数据库
    final dbHelper = DatabaseHelper();

    // 初始化服务
    persona = PersonaService(prefs);
    await persona.init(); // 【重构】异步初始化人格策略 (Cold/Hot Boot)
    chatHistory = ChatHistoryService(dbHelper);

    // 初始化新架构组件
    _emotionEngine = EmotionEngine(prefs);
    _memoryManager = MemoryManager(dbHelper);
    await _memoryManager.init(); // 【Phase 3】异步初始化 SQLite 存储
    
    // 【重构】从 PersonaService 获取人格策略，而不是硬编码
    _personaPolicy = persona.personaPolicy;
    personaConfig = _personaPolicy.toJson(); // 同步到 UI 层配置
    
    _generationPolicy = GenerationPolicy.fromSettings();

    // 初始化用户画像服务（认知引擎核心）
    _profileService = ProfileService(prefs);

    // 初始化核心事实存储 (SQLite) 并注入 LLM 服务（启用混合提取）
    _factStore = FactStore(dbHelper);
    await _factStore.init();
    _factStore.setLLMService(llm);

    _conversationEngine = ConversationEngine(
      llmService: llm,
      memoryManager: _memoryManager,
      personaService: persona, // 【重构】注入 PersonaService
      emotionEngine: _emotionEngine,
      generationPolicy: _generationPolicy,
      profileService: _profileService, // 启用认知增强
    );

    // 注入 FactStore
    _conversationEngine.setFactStore(_factStore);
    
    // 注入内心独白模型获取回调
    _conversationEngine.monologueModelGetter = () => monologueModel;

    // 设置待发送消息回调 - 主动消息会先进入队列
    _conversationEngine.onPendingMessage = addPendingMessage;

    // 启动对话引擎（启动 Timer）
    await _conversationEngine.start();

    // 【Research-Grade】实现亲密度衰减逻辑
    if (persona.lastInteraction != null) {
      final hours = DateTime.now().difference(persona.lastInteraction!).inHours;
      if (hours >= 24) {
        final decayAmount = (hours / 24) * 0.05;
        final newIntimacy = (persona.intimacy - decayAmount).clamp(0.1, 1.0);
        persona.updateIntimacy(newIntimacy);
        print('[AppEngine] Intimacy decayed by $decayAmount due to $hours hours of absence. New intimacy: $newIntimacy');
      }
    }

    await _loadChatHistory();

    isInitialized = true;
    notifyListeners();

    // 启动问候服务（应用打开时判断是否需要问候）
    _initStartupGreeting();

    if (messages.isEmpty) {
      final name = personaConfig['name'] ?? '小悠';
      final welcomeMsg = ChatMessage(
        content: "你好呀！我是$name，有什么想聊的吗？",
        isUser: false,
        time: DateTime.now(),
      );
      messages.add(welcomeMsg);
      await chatHistory.addMessage(welcomeMsg);
    }
  }

  /// 初始化启动问候服务
  void _initStartupGreeting() {
    final name = personaConfig['name'] ?? '小悠';
    _startupGreetingService = StartupGreetingService(prefs, personaName: name);

    // 设置问候消息回调
    _startupGreetingService!.onGreetingMessage = (message) {
      messages.add(message);
      chatHistory.addMessage(message);
      // 【Fix】实时更新总消息数
      _totalChatCount++;
      notifyListeners();
    };

    // 修复：设置虚拟时间戳消息回调（错过的问候）
    _startupGreetingService!.onMissedGreetingMessage = (message) {
      // 按时间戳插入到正确位置，而不是追加到末尾
      final insertIndex = messages.indexWhere(
        (m) => m.time.isAfter(message.time),
      );
      if (insertIndex == -1) {
        messages.add(message);
      } else {
        messages.insert(insertIndex, message);
      }
      chatHistory.addMessage(message);
      // 【Fix】实时更新总消息数
      _totalChatCount++;
      notifyListeners();
    };

    // 检查并调度问候
    _startupGreetingService!.checkAndScheduleGreeting();
  }

  /// 处理主动消息回调
  void _handleProactiveMessage(ChatMessage message) {
    messages.add(message);
    chatHistory.addMessage(message);
    // 【Fix】实时更新总消息数
    _totalChatCount++;
    notifyListeners();
  }

  void _loadTokenCount() {
    _totalTokensUsed = prefs.getInt(AppConfig.tokenCountKey) ?? 0;
  }

  Future<void> _saveTokenCount() async {
    await prefs.setInt(AppConfig.tokenCountKey, _totalTokensUsed);
  }

  Future<void> _loadChatHistory() async {
    final totalCount = await chatHistory.getTotalCount();
    final recentMessages = await chatHistory.loadRecentMessages(count: 50);

    messages = recentMessages;
    _oldestLoadedIndex = totalCount - recentMessages.length;
    hasMoreHistory = _oldestLoadedIndex > 0;
    
    // 缓存总消息数用于侧栏显示
    _totalChatCount = totalCount;
  }

  Future<void> loadMoreHistory() async {
    if (isLoadingHistory || !hasMoreHistory) return;

    isLoadingHistory = true;
    notifyListeners();

    try {
      final olderMessages = await chatHistory.loadOlderMessages(
        _oldestLoadedIndex,
        count: 30,
      );

      if (olderMessages.isNotEmpty) {
        messages.insertAll(0, olderMessages);
        _oldestLoadedIndex -= olderMessages.length;
        hasMoreHistory = _oldestLoadedIndex > 0;
      } else {
        hasMoreHistory = false;
      }
    } finally {
      isLoadingHistory = false;
      notifyListeners();
    }
  }

  void _loadPersonaConfig() {
    final saved = prefs.getString('personaConfig');
    if (saved != null && saved.isNotEmpty) {
      try {
        final decoded = jsonDecode(saved);
        if (decoded is Map<String, dynamic>) {
          personaConfig = {...personaConfig, ...decoded};
        }
      } catch (e) {
        // 使用默认值
      }
    }
  }

  Future<void> _savePersonaConfig() async {
    await prefs.setString('personaConfig', jsonEncode(personaConfig));
  }

  Future<void> updatePersonaConfig(Map<String, dynamic> newConfig) async {
    personaConfig = {...personaConfig, ...newConfig};
    _personaPolicy = PersonaPolicy(personaConfig);
    
    // 【重构】通过 PersonaService 持久化到运行时状态
    await persona.updatePersonaPolicy(_personaPolicy);
    
    // 【热更新】通知对话引擎更新策略 (仅需更新 GenerationPolicy，PersonaPolicy 自动同步)
    _conversationEngine.updatePolicies();
    
    // 保留旧的保存逻辑以确保兼容性
    await _savePersonaConfig();
    notifyListeners();
  }

  Future<void> updateApiKey(String newKey) async {
    await prefs.setString(AppConfig.apiKeyKey, newKey);
    final currentModelId =
        prefs.getString(AppConfig.modelKey) ?? AppConfig.defaultModel;
    llm = LLMService(newKey, model: currentModelId);

    // 关键修复：停止旧引擎，避免 Timer 泄漏
    _conversationEngine.stop();

    // 更新 ConversationEngine 中的 LLMService（保留所有依赖）
    _conversationEngine = ConversationEngine(
      llmService: llm,
      memoryManager: _memoryManager,
      personaService: persona, // 【重构】注入 PersonaService
      emotionEngine: _emotionEngine,
      generationPolicy: _generationPolicy,
      profileService: _profileService, // 保留认知引擎
    );
    
    // 重新初始化 FactStore（否则核心事实丢失）
    final dbHelper = DatabaseHelper();
    _factStore = FactStore(dbHelper);
    await _factStore.init();
    _factStore.setLLMService(llm);
    _conversationEngine.setFactStore(_factStore);
    
    // 注入内心独白模型获取回调
    _conversationEngine.monologueModelGetter = () => monologueModel;
    
    _conversationEngine.onPendingMessage = addPendingMessage;
    await _conversationEngine.start();

    notifyListeners();
  }


  /// 获取当前使用的模型
  String get currentModel => llm.currentModel;

  /// 切换语言模型
  Future<void> updateModel(String modelId) async {
    await prefs.setString(AppConfig.modelKey, modelId);
    llm.setModel(modelId);
    notifyListeners();
  }

  /// 获取用户画像
  UserProfile get userProfile => _profileService.profile;

  /// 更新用户画像
  Future<void> updateUserProfile(UserProfile newProfile) async {
    await _profileService.updateProfile(newProfile);
    notifyListeners();
  }

  Future<void> clearChatHistory() async {
    messages.clear();
    await chatHistory.clearAll();
    _oldestLoadedIndex = 0;
    hasMoreHistory = false;
    notifyListeners();
  }

  Future<void> resetTokenCount() async {
    _totalTokensUsed = 0;
    await _saveTokenCount();
    notifyListeners();
  }

  /// 发送消息 - 异步处理，不阻塞UI，支持连续发送多条
  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMsg = ChatMessage(
      content: text,
      isUser: true,
      time: DateTime.now(),
    );
    messages.add(userMsg);
    // 【Fix】实时更新总消息数
    _totalChatCount++;
    notifyListeners(); // 立即显示用户消息

    // 异步保存历史
    chatHistory.addMessage(userMsg);

    // 异步处理响应（不阻塞UI）
    _processMessageAsync(text);
  }

  /// 异步处理消息响应
  Future<void> _processMessageAsync(String text) async {
    // 显示"正在输入..."状态
    isLoading = true;
    notifyListeners();

    try {
      // 更新 PersonaService 状态（保持向后兼容）
      await persona.updateInteraction(text);

      // 同步状态给 ConversationEngine
      _conversationEngine.updateState(
        intimacy: persona.intimacy,
        interactionCount: persona.interactions,
        lastInteraction: persona.lastInteraction,
      );

      // 委托给 ConversationEngine 处理 (增加流式独白回调)
      final result = await _conversationEngine.processUserMessage(
        text,
        messages,
        onMonologueChunk: (chunk) {
          _streamingMonologue = chunk;
          notifyListeners(); 
        },
      );

      // 捕获并缓存认知状态
      _currentThoughtProcess = result.cognitiveState ?? {};

      // 更新 token 统计
      if (result.tokensUsed > 0) {
        _totalTokensUsed += result.tokensUsed;
        await _saveTokenCount();
      }

      // 按延迟逐条发送响应消息
      for (final delayed in result.delayedMessages) {
        if (delayed.delay.inMilliseconds > 0) {
          await Future.delayed(delayed.delay);
        }
        messages.add(delayed.message);
        await chatHistory.addMessage(delayed.message);
        // 【Fix】实时更新总消息数
        _totalChatCount++;
        notifyListeners(); // 每条消息单独通知 UI 更新
      }
    } catch (e) {
      final errorMsg = ChatMessage(
        content: "[系统错误] $e",
        isUser: false,
        time: DateTime.now(),
      );
      messages.add(errorMsg);
      await chatHistory.addMessage(errorMsg);
      notifyListeners();
    } finally {
      // 恢复正常状态
      isLoading = false;
      notifyListeners();
    }
  }

  /// 获取调试状态
  Map<String, dynamic> getDebugState() {
    return _conversationEngine.getDebugState();
  }

  // ========== 待发送消息队列操作 ==========

  /// 添加待发送消息到队列
  void addPendingMessage(ChatMessage message) {
    _pendingMessages.add(message);
    notifyListeners();
  }

  /// 立即发送队列中的某条消息
  void sendPendingMessageNow(int index) {
    if (index < 0 || index >= _pendingMessages.length) return;

    final message = _pendingMessages.removeAt(index);
    messages.add(message);
    chatHistory.addMessage(message);
    notifyListeners();
  }

  /// 清空所有待发送消息
  void clearPendingMessages() {
    _pendingMessages.clear();
    notifyListeners();
  }

  /// 从队列中移除已发送的消息（由 ConversationEngine 调用）
  void removePendingMessage(ChatMessage message) {
    _pendingMessages.removeWhere((m) => m.id == message.id);
    notifyListeners();
  }

  @override
  void dispose() {
    _conversationEngine.stop();
    super.dispose();
  }
}
