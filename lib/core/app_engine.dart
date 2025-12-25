// AppEngine - UI 适配层
//
// 设计原理：
// - 【重构后】仅保留 Provider 适配和 UI 状态管理
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

// 新架构导入
import 'policy/generation_policy.dart';
import 'policy/persona_policy.dart';
import 'engine/emotion_engine.dart';
import 'engine/memory_manager.dart';
import 'engine/conversation_engine.dart';

// 保留向后兼容
import 'service/memory_service.dart';
import 'service/persona_service.dart';
import 'service/profile_service.dart';

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
  
  // 向后兼容：保留旧服务引用
  late MemoryService memory;
  late PersonaService persona;
  
  // 认知引擎：用户画像服务
  late ProfileService _profileService;
  
  bool isInitialized = false;

  Map<String, dynamic> personaConfig = {
    'name': '小悠',
    'gender': '女性',
    'age': '20岁左右的少女',
    'character': '温柔细腻，有时会害羞，真心对待朋友',
    'interests': '看小说、发呆、聊天',
    'values': ['真诚', '善良'],
  };

  /// 获取情绪状态（用于 UI 显示）
  Map<String, dynamic> get emotion => _emotionEngine.emotionMap;
  
  /// 获取亲密度
  double get intimacy => persona.intimacy;

  /// 待发送消息队列（主动消息）
  final List<ChatMessage> _pendingMessages = [];
  List<ChatMessage> get pendingMessages => List.unmodifiable(_pendingMessages);

  Future<void> init() async {
    await SettingsLoader.loadAll();
    
    prefs = await SharedPreferences.getInstance();
    
    _loadPersonaConfig();
    _loadTokenCount();
    
    String key = prefs.getString(AppConfig.apiKeyKey) ?? AppConfig.defaultApiKey;
    String savedModel = prefs.getString(AppConfig.modelKey) ?? AppConfig.defaultModel;
    llm = LLMService(key, model: savedModel);
    
    // 初始化向后兼容服务
    memory = MemoryService(prefs);
    persona = PersonaService(prefs);
    chatHistory = ChatHistoryService(prefs);
    
    // 初始化新架构组件
    _emotionEngine = EmotionEngine(prefs);
    _memoryManager = MemoryManager(prefs);
    _personaPolicy = PersonaPolicy(personaConfig);
    _generationPolicy = GenerationPolicy.fromSettings();
    
    // 初始化用户画像服务（认知引擎核心）
    _profileService = ProfileService(prefs);
    
    _conversationEngine = ConversationEngine(
      llmService: llm,
      memoryManager: _memoryManager,
      personaPolicy: _personaPolicy,
      emotionEngine: _emotionEngine,
      generationPolicy: _generationPolicy,
      profileService: _profileService,  // 启用认知增强
    );
    
    // 设置主动消息回调
    _conversationEngine.onProactiveMessage = _handleProactiveMessage;
    // 设置待发送消息回调 - 主动消息会先进入队列
    _conversationEngine.onPendingMessage = addPendingMessage;
    
    // 启动对话引擎（启动 Timer）
    await _conversationEngine.start();
    
    await _loadChatHistory();
    
    isInitialized = true;
    notifyListeners();
    
    if (messages.isEmpty) {
      final name = personaConfig['name'] ?? '小悠';
      final welcomeMsg = ChatMessage(
        content: "你好呀！我是$name，有什么想聊的吗？", 
        isUser: false, 
        time: DateTime.now()
      );
      messages.add(welcomeMsg);
      await chatHistory.addMessage(welcomeMsg);
    }
  }

  /// 处理主动消息回调
  void _handleProactiveMessage(ChatMessage message) {
    messages.add(message);
    chatHistory.addMessage(message);
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
  }

  Future<void> loadMoreHistory() async {
    if (isLoadingHistory || !hasMoreHistory) return;
    
    isLoadingHistory = true;
    notifyListeners();
    
    try {
      final olderMessages = await chatHistory.loadOlderMessages(
        _oldestLoadedIndex, 
        count: 30
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
    if (saved != null) {
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
    await _savePersonaConfig();
    notifyListeners();
  }

  Future<void> updateApiKey(String newKey) async {
    await prefs.setString(AppConfig.apiKeyKey, newKey);
    final currentModelId = prefs.getString(AppConfig.modelKey) ?? AppConfig.defaultModel;
    llm = LLMService(newKey, model: currentModelId);
    
    // 更新 ConversationEngine 中的 LLMService
    _conversationEngine = ConversationEngine(
      llmService: llm,
      memoryManager: _memoryManager,
      personaPolicy: _personaPolicy,
      emotionEngine: _emotionEngine,
      generationPolicy: _generationPolicy,
    );
    _conversationEngine.onProactiveMessage = _handleProactiveMessage;
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

    final userMsg = ChatMessage(content: text, isUser: true, time: DateTime.now());
    messages.add(userMsg);
    notifyListeners();  // 立即显示用户消息
    
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
      
      // 委托给 ConversationEngine 处理
      final result = await _conversationEngine.processUserMessage(text, messages);
      
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
        notifyListeners();  // 每条消息单独通知 UI 更新
      }
      
    } catch (e) {
      final errorMsg = ChatMessage(
        content: "[系统错误] $e", 
        isUser: false, 
        time: DateTime.now()
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
