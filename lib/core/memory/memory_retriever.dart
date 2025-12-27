// LayeredMemoryRetriever - 分层记忆检索器
//
// 设计原理：
// - 实现四层记忆架构：工作记忆 / 情景记忆 / 语义记忆 / 程序记忆
// - 基于相关性和重要性智能检索
// - 与现有 MemoryManager 集成，扩展而非替代

import '../model/user_profile.dart';
import '../settings_loader.dart';
import 'memory_manager.dart';
import '../perception/perception_processor.dart';
import '../policy/generation_policy.dart';

/// 检索结果
class RetrievalResult {
  /// L1: 工作记忆 - 当前对话上下文
  List<String> workingMemory;

  /// L2: 情景记忆 - 近期对话摘要和重要事件
  List<EpisodicMemory> episodicMemory;

  /// L3: 语义记忆 - 用户画像和话题知识
  SemanticMemoryBundle semanticMemory;

  /// L4: 程序记忆 - 对话规则
  ProceduralRules proceduralMemory;

  RetrievalResult({
    this.workingMemory = const [],
    this.episodicMemory = const [],
    SemanticMemoryBundle? semanticMemory,
    ProceduralRules? proceduralMemory,
  }) : semanticMemory = semanticMemory ?? SemanticMemoryBundle.empty(),
       proceduralMemory = proceduralMemory ?? ProceduralRules.defaults();

  /// 格式化为 Prompt 内容
  String formatForPrompt() {
    final sections = <String>[];

    // 工作记忆
    if (workingMemory.isNotEmpty) {
      sections.add('【近期对话】\n${workingMemory.join('\n')}');
    }

    // 语义记忆 - 用户身份
    if (semanticMemory.identityAnchor.isNotEmpty) {
      sections.add('【用户身份】\n${semanticMemory.identityAnchor}');
    }

    // 情景记忆 - 重要事件
    if (episodicMemory.isNotEmpty) {
      final important = episodicMemory
          .where((e) => e.importance > 0.6)
          .map((e) => e.content);
      if (important.isNotEmpty) {
        sections.add('【重要记忆】\n${important.join('\n')}');
      }
    }

    // 相关话题
    if (semanticMemory.relevantFacts.isNotEmpty) {
      sections.add('【相关信息】\n${semanticMemory.relevantFacts.join('\n')}');
    }

    return sections.join('\n\n');
  }

  /// 估算 token 数量
  int get estimatedTokens {
    int total = 0;
    for (final m in workingMemory) {
      total += (m.length / 1.5).ceil();
    }
    for (final e in episodicMemory) {
      total += (e.content.length / 1.5).ceil();
    }
    total += (semanticMemory.identityAnchor.length / 1.5).ceil();
    for (final f in semanticMemory.relevantFacts) {
      total += (f.length / 1.5).ceil();
    }
    return total;
  }
}

/// 情景记忆条目
class EpisodicMemory {
  final String content;
  final DateTime timestamp;
  final double importance;
  final String? category;

  const EpisodicMemory({
    required this.content,
    required this.timestamp,
    this.importance = 0.5,
    this.category,
  });
}

/// 语义记忆包
class SemanticMemoryBundle {
  final String identityAnchor; // 用户身份描述
  final List<String> relevantFacts; // 相关事实
  final Map<String, String> topicContext; // 话题上下文

  const SemanticMemoryBundle({
    required this.identityAnchor,
    this.relevantFacts = const [],
    this.topicContext = const {},
  });

  factory SemanticMemoryBundle.empty() => const SemanticMemoryBundle(
    identityAnchor: '',
    relevantFacts: [],
    topicContext: {},
  );
}

/// 程序记忆 - 对话规则
class ProceduralRules {
  final List<String> avoidPatterns;
  final List<String> preferredBehaviors;
  final String responseGuideline;

  const ProceduralRules({
    required this.avoidPatterns,
    required this.preferredBehaviors,
    required this.responseGuideline,
  });

  factory ProceduralRules.defaults() => const ProceduralRules(
    avoidPatterns: ['重复提问', '说教', '过度关心'],
    preferredBehaviors: ['自然对话', '简洁回复'],
    responseGuideline: '像朋友一样自然聊天',
  );
}

/// 分层记忆检索器
class LayeredMemoryRetriever {
  final MemoryManager _memoryManager;
  final UserProfile _userProfile;

  LayeredMemoryRetriever({
    required MemoryManager memoryManager,
    required UserProfile userProfile,
  }) : _memoryManager = memoryManager,
       _userProfile = userProfile;

  /// 检索相关记忆
  Future<RetrievalResult> retrieve({
    required String query,
    required PerceptionResult perception,
    required List<String> recentMessages,
    int maxTokens = 1000,
  }) async {
    final result = RetrievalResult();

    // L1: 工作记忆 - 最近的对话
    result.workingMemory = _getWorkingMemory(recentMessages);

    // L2: 情景记忆 - 从 MemoryManager 检索
    result.episodicMemory = await _retrieveEpisodicMemory(query, perception);

    // L3: 语义记忆 - 用户画像 + 相关事实
    result.semanticMemory = _buildSemanticMemory(query, perception);

    // L4: 程序记忆 - 基于感知结果加载规则
    result.proceduralMemory = _loadProceduralRules(perception);

    // 如果超过 token 限制，进行压缩
    if (result.estimatedTokens > maxTokens) {
      return _compressResult(result, maxTokens);
    }

    return result;
  }

  /// L1: 获取工作记忆
  List<String> _getWorkingMemory(List<String> recentMessages) {
    // 最多保留最近 10 条消息
    final maxMessages = 10;
    if (recentMessages.length <= maxMessages) {
      return recentMessages;
    }
    return recentMessages.sublist(recentMessages.length - maxMessages);
  }

  /// L2: 检索情景记忆（使用加权评分算法）
  ///
  /// 现在直接使用 MemoryEntry 的真实时间戳和重要性
  Future<List<EpisodicMemory>> _retrieveEpisodicMemory(
    String query,
    PerceptionResult perception,
  ) async {
    final memories = <EpisodicMemory>[];

    // 从 MemoryManager 获取完整的记忆条目
    final allEntries = _memoryManager.getAllMemoryEntries();

    // 使用加权评分算法计算相关性
    for (final entry in allEntries) {
      final score = _calculateWeightedScore(
        memory: entry.content,
        query: query,
        timestamp: entry.timestamp, // 使用真实时间戳
        importance: entry.importance, // 使用真实重要性
      );

      if (score > 0.25) {
        memories.add(
          EpisodicMemory(
            content: entry.content,
            timestamp: entry.timestamp,
            importance: score,
          ),
        );
      }
    }

    // 按加权分数排序，取前 5 条
    memories.sort((a, b) => b.importance.compareTo(a.importance));
    return memories.take(5).toList();
  }

  /// 加权评分算法
  ///
  /// Score = (Keyword Match * 0.6) + (Recency * 0.2) + (Importance * 0.2)
  double _calculateWeightedScore({
    required String memory,
    required String query,
    required DateTime timestamp,
    required double importance,
  }) {
    final keywordScore = _calculateKeywordMatch(memory, query);
    final recencyScore = _calculateRecency(timestamp);

    return (keywordScore * 0.6) + (recencyScore * 0.2) + (importance * 0.2);
  }

  /// 计算关键词匹配分数 (0.0 ~ 1.0)
  double _calculateKeywordMatch(String memory, String query) {
    final memLower = memory.toLowerCase();
    // 分词：按空格和常见标点分割
    final queryWords = query
        .toLowerCase()
        .split(
          RegExp(
            r'[\s,，。！？、；：""'
            ']+',
          ),
        )
        .where((w) => w.length > 1)
        .toList();

    if (queryWords.isEmpty) return 0.3;

    int matches = 0;
    int partialMatches = 0;

    for (final word in queryWords) {
      if (memLower.contains(word)) {
        matches++;
      } else {
        // 部分匹配（至少 2 个连续字符）
        for (int i = 0; i < word.length - 1; i++) {
          if (memLower.contains(word.substring(i, i + 2))) {
            partialMatches++;
            break;
          }
        }
      }
    }

    // 完全匹配权重 1.0，部分匹配权重 0.3
    final score = (matches + partialMatches * 0.3) / queryWords.length;
    return score.clamp(0.0, 1.0);
  }

  /// 计算时间衰减分数 (0.0 ~ 1.0)
  ///
  /// 使用安全的线性衰减公式：score = 1.0 - (hoursSince / decayHours)
  /// 显式处理 decayHours <= 0 的边界情况
  double _calculateRecency(DateTime timestamp) {
    final now = DateTime.now();
    final hoursSince = now.difference(timestamp).inHours;
    final decayDays = SettingsLoader.memoryDecayDays;

    // 防止配置错误导致崩溃
    if (decayDays <= 0) {
      return 0.5; // 返回中性分数
    }

    final decayHours = decayDays * 24;

    // 安全的线性衰减公式
    // hoursSince = 0 时，score = 1.0
    // hoursSince = decayHours 时，score = 0.0
    final score = 1.0 - (hoursSince / decayHours);
    return score.clamp(0.0, 1.0);
  }

  /// L3: 构建语义记忆
  SemanticMemoryBundle _buildSemanticMemory(
    String query,
    PerceptionResult perception,
  ) {
    // 获取用户身份锚点
    final identityAnchor = _userProfile.getIdentityAnchor();

    // 从用户画像的生活背景中提取相关信息
    final relevantContexts = _userProfile.lifeContexts
        .where((c) => c.importance > 0.5)
        .map((c) => c.content)
        .toList();

    return SemanticMemoryBundle(
      identityAnchor: identityAnchor,
      relevantFacts: relevantContexts,
      topicContext: {},
    );
  }

  /// L4: 加载程序记忆
  ProceduralRules _loadProceduralRules(PerceptionResult perception) {
    final avoidPatterns = <String>[
      ..._userProfile.preferences.dislikedPatterns,
    ];

    final preferredBehaviors = <String>[
      ..._userProfile.preferences.preferredStyles,
    ];

    // 根据感知结果调整规则
    String guideline = '自然对话';
    switch (perception.underlyingNeed) {
      case '倾诉宣泄':
        guideline = '专注倾听，不要急于给建议';
        avoidPatterns.add('过度建议');
        break;
      case '陪伴安慰':
        guideline = '温暖陪伴，少讲道理';
        avoidPatterns.add('说教');
        break;
      case '寻求建议':
        guideline = '提供具体想法，但不要强加观点';
        break;
      default:
        guideline = '轻松自然地聊天';
    }

    if (perception.conversationIntent == '结束对话') {
      guideline = '简短回应或不回复';
      avoidPatterns.add('追问');
    }

    return ProceduralRules(
      avoidPatterns: avoidPatterns,
      preferredBehaviors: preferredBehaviors,
      responseGuideline: guideline,
    );
  }

  /// 压缩结果以符合 token 限制
  RetrievalResult _compressResult(RetrievalResult result, int maxTokens) {
    // 优先保留：身份锚点 > 工作记忆 > 重要情景记忆

    // 计算各部分预算（身份锚点约20%，工作记忆40%，情景记忆30%）
    final workingBudget = (maxTokens * 0.4).round();
    final episodicBudget = (maxTokens * 0.3).round();

    // 压缩工作记忆
    var workingMemory = result.workingMemory;
    int workingTokens = workingMemory.fold(
      0,
      (sum, m) => sum + (m.length / 1.5).ceil(),
    );
    while (workingTokens > workingBudget && workingMemory.length > 2) {
      workingMemory = workingMemory.sublist(1);
      workingTokens = workingMemory.fold(
        0,
        (sum, m) => sum + (m.length / 1.5).ceil(),
      );
    }

    // 压缩情景记忆 - 只保留最重要的
    var episodicMemory = result.episodicMemory;
    episodicMemory.sort((a, b) => b.importance.compareTo(a.importance));
    int episodicTokens = episodicMemory.fold(
      0,
      (sum, e) => sum + (e.content.length / 1.5).ceil(),
    );
    while (episodicTokens > episodicBudget && episodicMemory.length > 1) {
      episodicMemory = episodicMemory.sublist(0, episodicMemory.length - 1);
      episodicTokens = episodicMemory.fold(
        0,
        (sum, e) => sum + (e.content.length / 1.5).ceil(),
      );
    }

    return RetrievalResult(
      workingMemory: workingMemory,
      episodicMemory: episodicMemory,
      semanticMemory: result.semanticMemory,
      proceduralMemory: result.proceduralMemory,
    );
  }

  /// 获取身份锚点（快速方法）
  String getIdentityAnchor() {
    return _userProfile.getIdentityAnchor();
  }
}
