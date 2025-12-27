// AsyncReflectionEngine - 异步反思引擎
//
// 设计原理：
// - 对话静默后进行后台分析
// - 提取长期记忆，更新用户画像
// - 从对话中学习用户背景（而非预设）
// - 不阻塞主线程

import 'dart:async';
import 'dart:convert';
import '../model/user_profile.dart';
import '../service/profile_service.dart';
import '../memory/memory_manager.dart';
import '../service/llm_service.dart';

/// 对话轮次
class ConversationTurn {
  final String userMessage;
  final String aiResponse;
  final DateTime timestamp;
  final double userEmotionValence;

  ConversationTurn({
    required this.userMessage,
    required this.aiResponse,
    DateTime? timestamp,
    this.userEmotionValence = 0.0,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// 反思分析结果
class ReflectionAnalysisResult {
  final List<LifeContext> discoveredContexts;    // 发现的新背景信息
  final List<String> memoriesToStore;            // 需要存储的记忆
  final double intimacyDelta;                     // 亲密度变化
  final List<String> newDislikedPatterns;        // 新发现的不喜欢模式
  final List<String> newPreferredStyles;         // 新发现的偏好风格
  final String? milestone;                        // 里程碑事件

  ReflectionAnalysisResult({
    this.discoveredContexts = const [],
    this.memoriesToStore = const [],
    this.intimacyDelta = 0.0,
    this.newDislikedPatterns = const [],
    this.newPreferredStyles = const [],
    this.milestone,
  });

  factory ReflectionAnalysisResult.fromJson(Map<String, dynamic> json) {
    return ReflectionAnalysisResult(
      discoveredContexts: (json['discovered_contexts'] as List?)
          ?.map((e) => LifeContext(
                category: e['category'] ?? '其他',
                content: e['content'] ?? '',
                importance: (e['importance'] ?? 0.5).toDouble(),
                userConfirmed: false,  // 需要用户确认
              ))
          .toList() ?? [],
      memoriesToStore: (json['memories_to_store'] as List?)?.cast<String>() ?? [],
      intimacyDelta: (json['intimacy_delta'] ?? 0.0).toDouble(),
      newDislikedPatterns: (json['new_disliked_patterns'] as List?)?.cast<String>() ?? [],
      newPreferredStyles: (json['new_preferred_styles'] as List?)?.cast<String>() ?? [],
      milestone: json['milestone'],
    );
  }

  bool get hasUpdates =>
      discoveredContexts.isNotEmpty ||
      memoriesToStore.isNotEmpty ||
      intimacyDelta.abs() > 0.01 ||
      newDislikedPatterns.isNotEmpty ||
      newPreferredStyles.isNotEmpty ||
      milestone != null;
}

/// 异步反思引擎
class AsyncReflectionEngine {
  final LLMService _llmService;
  final ProfileService _profileService;
  final MemoryManager _memoryManager;
  
  Timer? _reflectionTimer;
  final Duration _quietPeriod;
  final List<ConversationTurn> _pendingTurns = [];
  
  bool _isReflecting = false;

  AsyncReflectionEngine({
    required LLMService llmService,
    required ProfileService profileService,
    required MemoryManager memoryManager,
    Duration? quietPeriod,
  }) : _llmService = llmService,
       _profileService = profileService,
       _memoryManager = memoryManager,
       _quietPeriod = quietPeriod ?? const Duration(minutes: 3);

  /// 记录对话轮次
  void recordTurn(ConversationTurn turn) {
    _pendingTurns.add(turn);
    _resetTimer();
  }

  /// 从消息创建轮次并记录
  void recordFromMessages(String userMessage, String aiResponse, {double emotionValence = 0.0}) {
    recordTurn(ConversationTurn(
      userMessage: userMessage,
      aiResponse: aiResponse,
      userEmotionValence: emotionValence,
    ));
  }

  void _resetTimer() {
    _reflectionTimer?.cancel();
    _reflectionTimer = Timer(_quietPeriod, _triggerReflection);
  }

  /// 触发异步反思
  Future<void> _triggerReflection() async {
    if (_pendingTurns.isEmpty || _isReflecting) return;
    
    _isReflecting = true;
    
    try {
      // 复制后清空
      final turnsToProcess = List<ConversationTurn>.from(_pendingTurns);
      _pendingTurns.clear();
      
      print('[AsyncReflection] Analyzing ${turnsToProcess.length} turns...');
      
      // 执行分析
      final result = await _analyzeConversation(turnsToProcess);
      
      // 应用结果
      if (result.hasUpdates) {
        await _applyResult(result);
        print('[AsyncReflection] Applied updates: ${_summarizeResult(result)}');
      }
    } catch (e) {
      print('[AsyncReflection] Error: $e');
    } finally {
      _isReflecting = false;
    }
  }

  /// 分析对话内容
  Future<ReflectionAnalysisResult> _analyzeConversation(
    List<ConversationTurn> turns,
  ) async {
    final prompt = _buildReflectionPrompt(turns);
    
    try {
      final response = await _llmService.completeWithSystem(
        systemPrompt: prompt,
        userMessage: '请分析上述对话，输出 JSON 格式的分析结果。',
        model: 'qwen-turbo',  // 使用便宜的模型
        temperature: 0.3,
        maxTokens: 600,
      );
      
      final json = _parseJsonResponse(response);
      return ReflectionAnalysisResult.fromJson(json);
    } catch (e) {
      print('[AsyncReflection] Analysis failed: $e');
      return ReflectionAnalysisResult();
    }
  }

  /// 构建反思 Prompt
  String _buildReflectionPrompt(List<ConversationTurn> turns) {
    final currentProfile = _profileService.profile;
    
    final conversationText = turns.map((t) => 
      '用户: ${t.userMessage}\nAI: ${t.aiResponse}'
    ).join('\n---\n');
    
    return '''
【后台反思任务 - 从对话中学习用户信息】

分析以下对话片段，提取有价值的长期信息。

这是一个学习过程：用户的背景、偏好、习惯都应该从对话中逐渐发现，而不是预设的。

=== 当前用户画像 ===
昵称：${currentProfile.nickname}
职业：${currentProfile.occupation.isEmpty ? '（未知）' : currentProfile.occupation}
已知背景：${currentProfile.lifeContexts.isEmpty ? '（暂无）' : currentProfile.lifeContexts.map((c) => c.content).join('；')}
已知偏好：${currentProfile.preferences.preferredStyles.isEmpty ? '（暂无）' : currentProfile.preferences.preferredStyles.join('、')}
已知不喜欢：${currentProfile.preferences.dislikedPatterns.isEmpty ? '（暂无）' : currentProfile.preferences.dislikedPatterns.join('、')}

=== 对话内容 ===
$conversationText

=== 你需要分析并提取 ===

1. 新发现的用户信息 (discovered_contexts)
   - 用户提到了什么职业/学校/身份？
   - 用户提到了什么重要事件/压力/目标？
   - 用户透露了什么兴趣爱好？
   - 每条信息需要标注类别(学业/工作/压力/兴趣/社交/其他)和重要性(0.0~1.0)

2. 值得记住的内容 (memories_to_store)
   - 有什么具体事件/话题值得长期记住？
   - 用简短一句话总结

3. 亲密度变化 (intimacy_delta)
   - 正数表示关系增进，负数表示疏远
   - 范围 -0.1 ~ 0.1

4. 用户偏好学习
   - new_disliked_patterns: 用户表现出不喜欢什么（如频繁打断、简短回复表示不耐烦）
   - new_preferred_styles: 用户喜欢什么风格

5. 里程碑事件 (milestone)
   - 是否有值得标记的重要时刻？（首次深度交流、重要情绪支持等）

=== 输出格式 ===
必须输出有效的 JSON：
{
  "discovered_contexts": [
    {"category": "...", "content": "...", "importance": 0.8}
  ],
  "memories_to_store": ["..."],
  "intimacy_delta": 0.02,
  "new_disliked_patterns": [],
  "new_preferred_styles": [],
  "milestone": null
}

注意：
- 只提取用户明确提到或可以高置信度推断的信息
- 不要编造或过度推断
- 如果没有发现新信息，返回空列表
''';
  }

  /// 应用反思结果
  Future<void> _applyResult(ReflectionAnalysisResult result) async {
    // 1. 添加发现的用户背景
    for (final context in result.discoveredContexts) {
      await _profileService.addLifeContext(context);
    }
    
    // 2. 存储记忆
    for (final memory in result.memoriesToStore) {
      await _memoryManager.addMemory(memory, importance: 0.7);
    }
    
    // 3. 更新亲密度
    if (result.intimacyDelta.abs() > 0.001) {
      await _profileService.incrementIntimacy(result.intimacyDelta);
    }
    
    // 4. 添加不喜欢的模式
    for (final pattern in result.newDislikedPatterns) {
      await _profileService.addDislikedPattern(pattern);
    }
    
    // 5. 添加里程碑
    if (result.milestone != null) {
      await _profileService.addMilestone(MilestoneEvent(
        description: result.milestone!,
        category: '对话里程碑',
      ));
    }
  }

  /// 解析 JSON 响应
  Map<String, dynamic> _parseJsonResponse(String response) {
    var jsonStr = response.trim();
    
    final codeBlockMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(jsonStr);
    if (codeBlockMatch != null) {
      jsonStr = codeBlockMatch.group(1)?.trim() ?? jsonStr;
    }
    
    final startIndex = jsonStr.indexOf('{');
    final endIndex = jsonStr.lastIndexOf('}');
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      jsonStr = jsonStr.substring(startIndex, endIndex + 1);
    }
    
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      return {};
    }
  }

  String _summarizeResult(ReflectionAnalysisResult result) {
    final parts = <String>[];
    if (result.discoveredContexts.isNotEmpty) {
      parts.add('${result.discoveredContexts.length} new contexts');
    }
    if (result.memoriesToStore.isNotEmpty) {
      parts.add('${result.memoriesToStore.length} memories');
    }
    if (result.intimacyDelta.abs() > 0.001) {
      parts.add('intimacy ${result.intimacyDelta > 0 ? '+' : ''}${result.intimacyDelta.toStringAsFixed(3)}');
    }
    if (result.milestone != null) {
      parts.add('milestone: ${result.milestone}');
    }
    return parts.isEmpty ? 'no updates' : parts.join(', ');
  }

  /// 手动触发反思（用于测试）
  Future<void> forceReflection() async {
    _reflectionTimer?.cancel();
    await _triggerReflection();
  }

  /// 停止引擎
  void stop() {
    _reflectionTimer?.cancel();
    _reflectionTimer = null;
  }

  /// 获取待处理轮次数量
  int get pendingTurnsCount => _pendingTurns.length;

  /// 是否正在反思
  bool get isReflecting => _isReflecting;
}
