import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'models.dart';
import 'config.dart';
import 'settings_loader.dart';
import 'llm_service.dart';
import 'memory_service.dart';
import 'persona_service.dart';
import 'prompt_builder.dart';
import 'response_formatter.dart';
import 'chat_history_service.dart';

class AppEngine extends ChangeNotifier {
  List<ChatMessage> messages = [];
  bool isLoading = false;
  bool isLoadingHistory = false;
  bool hasMoreHistory = false;
  int _oldestLoadedIndex = 0;
  
  // Token 统计
  int _totalTokensUsed = 0;
  int get totalTokensUsed => _totalTokensUsed;
  
  late LLMService llm;
  late MemoryService memory;
  late PersonaService persona;
  late ChatHistoryService chatHistory;
  late SharedPreferences prefs;
  bool isInitialized = false;

  Map<String, dynamic> personaConfig = {
    'name': '小悠',
    'gender': '女性',
    'age': '20岁左右的少女',
    'character': '温柔细腻，有时会害羞，真心对待朋友',
    'interests': '看小说、发呆、聊天',
    'values': ['真诚', '善良'],
  };

  Future<void> init() async {
    await SettingsLoader.loadAll();
    
    prefs = await SharedPreferences.getInstance();
    
    _loadPersonaConfig();
    _loadTokenCount();
    
    String key = prefs.getString(AppConfig.apiKeyKey) ?? AppConfig.defaultApiKey;
    llm = LLMService(key);
    
    memory = MemoryService(prefs);
    persona = PersonaService(prefs);
    chatHistory = ChatHistoryService(prefs);
    
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
    await _savePersonaConfig();
    notifyListeners();
  }

  Future<void> updateApiKey(String newKey) async {
    await prefs.setString(AppConfig.apiKeyKey, newKey);
    llm = LLMService(newKey);
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

  Future<void> sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    final userMsg = ChatMessage(content: text, isUser: true, time: DateTime.now());
    messages.add(userMsg);
    await chatHistory.addMessage(userMsg);
    
    isLoading = true;
    notifyListeners();

    try {
        await persona.updateInteraction(text);
        
        final memText = memory.getRelevantContext(text);
        
        final systemPrompt = PromptBuilder.buildSystemPrompt(
          persona: personaConfig,
          emotion: persona.emotion,
          intimacy: persona.intimacy,
          interactions: persona.interactions,
          memoriesText: memText,
          lastInteraction: persona.lastInteraction,
        );
        
        List<Map<String, String>> apiMessages = [
            {'role': 'system', 'content': systemPrompt}
        ];
        
        final historyForApi = messages.length > 11 
            ? messages.sublist(messages.length - 11, messages.length - 1) 
            : messages.sublist(0, messages.length - 1);
        
        for (var m in historyForApi) {
           apiMessages.add({
             'role': m.isUser ? 'user' : 'assistant',
             'content': m.content
           });
        }
        
        apiMessages.add({'role': 'user', 'content': text});
        
        // 使用新的带 token 统计的方法
        final response = await llm.generateWithTokens(apiMessages);
        
        // 更新 token 统计
        if (response.tokensUsed > 0) {
          _totalTokensUsed += response.tokensUsed;
          await _saveTokenCount();
        }
        
        if (response.success && response.content != null) {
             final arousal = (persona.emotion['arousal'] ?? 0.5).toDouble();
             final formattedMessages = ResponseFormatter.formatResponse(
               response.content!, 
               arousal: arousal
             );
             
             final List<ChatMessage> aiMessages = [];
             for (final msg in formattedMessages) {
               final aiMsg = ChatMessage(
                 content: msg['content'] as String, 
                 isUser: false, 
                 time: DateTime.now()
               );
               messages.add(aiMsg);
               aiMessages.add(aiMsg);
             }
             
             await chatHistory.addMessages(aiMessages);
             memory.addMemory("用户：$text");
        } else {
             final errorMsg = ChatMessage(
               content: "（${response.error ?? '网络连接失败'}）", 
               isUser: false, 
               time: DateTime.now()
             );
             messages.add(errorMsg);
             await chatHistory.addMessage(errorMsg);
        }
    } catch (e) {
        final errorMsg = ChatMessage(
          content: "[系统错误] $e", 
          isUser: false, 
          time: DateTime.now()
        );
        messages.add(errorMsg);
        await chatHistory.addMessage(errorMsg);
    }
    
    isLoading = false;
    notifyListeners();
  }
}
