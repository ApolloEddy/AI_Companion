// UserProfile - 用户画像数据模型
//
// 设计原理：
// - 核心身份锚点，确保 AI 永不遗忘用户信息
// - 分层存储：静态身份 / 动态偏好 / 关系状态 / 情绪档案
// - 支持从对话中自动学习和更新

/// 用户画像 - 核心身份锚点
class UserProfile {
  // === 静态身份 (用户手动设置/确认) ===
  // === 静态身份 (用户手动设置/确认) ===
  final String nickname;
  final String? callSign;   // 【新增】称呼偏好 (AI 怎么叫用户)
  final String occupation;
  final String? major;
  final int? age;
  final DateTime? birthday; // 【新增】生日
  final String? gender;
  
  // === 重要背景 (从对话中提取并确认) ===
  final List<LifeContext> lifeContexts;
  
  // === 动态偏好 (从交互中自动学习) ===
  final DialoguePreferences preferences;
  
  // === 关系状态 ===
  final RelationshipState relationship;
  
  // === 情绪档案 ===
  final EmotionalArchive emotionalArchive;

  const UserProfile({
    required this.nickname,
    this.callSign,
    required this.occupation,
    this.major,
    this.age,
    this.birthday,
    this.gender,
    this.lifeContexts = const [],
    this.preferences = const DialoguePreferences(),
    this.relationship = const RelationshipState(),
    this.emotionalArchive = const EmotionalArchive(),
  });

  /// 空白配置 - 用户背景将从对话中学习
  factory UserProfile.empty() {
    return const UserProfile(
      nickname: '用户',  // 默认昵称（中文本地化），会从对话中学习
      occupation: '',     // 空白，从对话中提取
      major: null,
      age: null,
      gender: null,
      lifeContexts: [],   // 空白，从对话中学习
      preferences: DialoguePreferences(
        dislikedPatterns: [],  // 空白，从反馈中学习
        preferredStyles: [],
      ),
    );
  }

  /// 快速初始化（仅设置昵称）
  factory UserProfile.withNickname(String nickname) {
    return UserProfile(
      nickname: nickname,
      occupation: '',
      lifeContexts: const [],
      preferences: const DialoguePreferences(),
    );
  }

  /// 获取身份锚点描述 (用于 Prompt 注入)
  String getIdentityAnchor() {
    final lines = <String>[];
    lines.add('用户身份：$nickname');
    if (callSign != null && callSign!.isNotEmpty) {
      lines.add('称呼偏好：$callSign');
    }
    lines.add('职业：$occupation');
    if (major != null && major!.isNotEmpty) lines.add('专业：$major');
    if (age != null) lines.add('年龄：$age');
    if (gender != null) lines.add('性别：$gender');
    if (birthday != null) {
      lines.add('生日：${birthday!.year}年${birthday!.month}月${birthday!.day}日');
    }
    
    // 关系目标注入
    if (preferences.relationshipGoal.isNotEmpty) {
      lines.add('关系期望：${preferences.relationshipGoal}');
    }
    
    // 【去重 + 优化】仅取最重要且不重复的前 3 条背景，防止 Prompt 爆炸
    final uniqueContexts = <String>{};
    final sortedContexts = lifeContexts.toList()
      ..sort((a, b) => b.importance.compareTo(a.importance)); // 按重要性降序

    for (final context in sortedContexts) {
      final cleanContent = context.content.trim();
      if (cleanContent.isNotEmpty && !uniqueContexts.contains(cleanContent)) {
        uniqueContexts.add(cleanContent);
      }
      if (uniqueContexts.length >= 3) break; // 最多保留 3 条核心背景
    }

    if (uniqueContexts.isNotEmpty) {
      lines.add('核心背景：${uniqueContexts.join('；')}');
    }
    
    return lines.join('\n');
  }

  /// 复制并更新
  UserProfile copyWith({
    String? nickname,
    String? callSign,
    String? occupation,
    String? major,
    int? age,
    DateTime? birthday,
    String? gender,
    List<LifeContext>? lifeContexts,
    DialoguePreferences? preferences,
    RelationshipState? relationship,
    EmotionalArchive? emotionalArchive,
  }) {
    return UserProfile(
      nickname: nickname ?? this.nickname,
      callSign: callSign ?? this.callSign,
      occupation: occupation ?? this.occupation,
      major: major ?? this.major,
      age: age ?? this.age,
      birthday: birthday ?? this.birthday,
      gender: gender ?? this.gender,
      lifeContexts: lifeContexts ?? this.lifeContexts,
      preferences: preferences ?? this.preferences,
      relationship: relationship ?? this.relationship,
      emotionalArchive: emotionalArchive ?? this.emotionalArchive,
    );
  }

  /// 添加生活背景 (内含去重逻辑)
  UserProfile addLifeContext(LifeContext context) {
    final newContent = context.content.trim().toLowerCase();
    
    // 如果已经存在相似内容，不再重复添加
    final exists = lifeContexts.any((c) => 
      c.content.trim().toLowerCase() == newContent
    );
    
    if (exists) return this;

    return copyWith(
      lifeContexts: [...lifeContexts, context],
    );
  }

  Map<String, dynamic> toJson() => {
    'nickname': nickname,
    'callSign': callSign,
    'occupation': occupation,
    'major': major,
    'age': age,
    'birthday': birthday?.toIso8601String(),
    'gender': gender,
    'lifeContexts': lifeContexts.map((c) => c.toJson()).toList(),
    'preferences': preferences.toJson(),
    'relationship': relationship.toJson(),
    'emotionalArchive': emotionalArchive.toJson(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      nickname: json['nickname'] ?? '用户',
      callSign: json['callSign'],
      occupation: json['occupation'] ?? '',
      major: json['major'],
      age: json['age'],
      birthday: DateTime.tryParse(json['birthday'] ?? ''),
      gender: json['gender'],
      lifeContexts: (json['lifeContexts'] as List?)
          ?.map((e) => LifeContext.fromJson(e))
          .toList() ?? [],
      preferences: json['preferences'] != null
          ? DialoguePreferences.fromJson(json['preferences'])
          : const DialoguePreferences(),
      relationship: json['relationship'] != null
          ? RelationshipState.fromJson(json['relationship'])
          : const RelationshipState(),
      emotionalArchive: json['emotionalArchive'] != null
          ? EmotionalArchive.fromJson(json['emotionalArchive'])
          : const EmotionalArchive(),
    );
  }
}

/// 生活背景条目
class LifeContext {
  final String category;      // "学业"/"压力"/"兴趣"/"社交"
  final String content;
  final DateTime addedAt;
  final double importance;    // 0.0 ~ 1.0
  final bool userConfirmed;   // 是否经用户确认

  LifeContext({
    required this.category,
    required this.content,
    DateTime? addedAt,
    this.importance = 0.5,
    this.userConfirmed = false,
  }) : addedAt = addedAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'category': category,
    'content': content,
    'addedAt': addedAt.toIso8601String(),
    'importance': importance,
    'userConfirmed': userConfirmed,
  };

  factory LifeContext.fromJson(Map<String, dynamic> json) {
    return LifeContext(
      category: json['category'] ?? '',
      content: json['content'] ?? '',
      addedAt: DateTime.tryParse(json['addedAt'] ?? ''),
      importance: (json['importance'] ?? 0.5).toDouble(),
      userConfirmed: json['userConfirmed'] ?? false,
    );
  }
}

/// 对话偏好
class DialoguePreferences {
  final List<String> dislikedPatterns;
  final List<String> preferredStyles;
  final double preferredResponseLength;  // 0.0(简短) ~ 1.0(详细)
  final bool allowProactiveMessages;
  final Set<String> sensitiveTopics;
  final String relationshipGoal; // 【新增】关系目标 (如 "挚友", "导师", "恋人")

  const DialoguePreferences({
    this.dislikedPatterns = const [],
    this.preferredStyles = const [],
    this.preferredResponseLength = 0.5,
    this.allowProactiveMessages = true,
    this.sensitiveTopics = const {},
    this.relationshipGoal = '',
  });

  /// 添加不喜欢的模式
  DialoguePreferences addDislikedPattern(String pattern) {
    if (dislikedPatterns.contains(pattern)) return this;
    return DialoguePreferences(
      dislikedPatterns: [...dislikedPatterns, pattern],
      preferredStyles: preferredStyles,
      preferredResponseLength: preferredResponseLength,
      allowProactiveMessages: allowProactiveMessages,
      sensitiveTopics: sensitiveTopics,
      relationshipGoal: relationshipGoal,
    );
  }

  Map<String, dynamic> toJson() => {
    'dislikedPatterns': dislikedPatterns,
    'preferredStyles': preferredStyles,
    'preferredResponseLength': preferredResponseLength,
    'allowProactiveMessages': allowProactiveMessages,
    'sensitiveTopics': sensitiveTopics.toList(),
    'relationshipGoal': relationshipGoal,
  };

  factory DialoguePreferences.fromJson(Map<String, dynamic> json) {
    return DialoguePreferences(
      dislikedPatterns: (json['dislikedPatterns'] as List?)?.cast<String>() ?? [],
      preferredStyles: (json['preferredStyles'] as List?)?.cast<String>() ?? [],
      preferredResponseLength: (json['preferredResponseLength'] ?? 0.5).toDouble(),
      allowProactiveMessages: json['allowProactiveMessages'] ?? true,
      sensitiveTopics: ((json['sensitiveTopics'] as List?) ?? []).cast<String>().toSet(),
      relationshipGoal: json['relationshipGoal'] ?? '',
    );
  }
}

/// 关系状态
class RelationshipState {
  final double intimacy;
  final int totalInteractions;
  final Duration totalChatTime;
  final DateTime firstMet;
  final List<MilestoneEvent> milestones;

  const RelationshipState({
    this.intimacy = 0.3,
    this.totalInteractions = 0,
    this.totalChatTime = Duration.zero,
    DateTime? firstMet,
    this.milestones = const [],
  }) : firstMet = firstMet ?? const _DefaultDateTime();

  // 使用 getter 处理默认日期
  DateTime get effectiveFirstMet => 
      firstMet is _DefaultDateTime ? DateTime.now() : firstMet;

  /// 增加亲密度
  RelationshipState incrementIntimacy(double delta) {
    return RelationshipState(
      intimacy: (intimacy + delta).clamp(0.0, 1.0),
      totalInteractions: totalInteractions + 1,
      totalChatTime: totalChatTime,
      firstMet: firstMet,
      milestones: milestones,
    );
  }

  Map<String, dynamic> toJson() => {
    'intimacy': intimacy,
    'totalInteractions': totalInteractions,
    'totalChatTimeMinutes': totalChatTime.inMinutes,
    'firstMet': effectiveFirstMet.toIso8601String(),
    'milestones': milestones.map((m) => m.toJson()).toList(),
  };

  factory RelationshipState.fromJson(Map<String, dynamic> json) {
    return RelationshipState(
      intimacy: (json['intimacy'] ?? 0.3).toDouble(),
      totalInteractions: json['totalInteractions'] ?? 0,
      totalChatTime: Duration(minutes: json['totalChatTimeMinutes'] ?? 0),
      firstMet: DateTime.tryParse(json['firstMet'] ?? ''),
      milestones: (json['milestones'] as List?)
          ?.map((e) => MilestoneEvent.fromJson(e))
          .toList() ?? [],
    );
  }
}

/// 占位用的默认日期类
class _DefaultDateTime implements DateTime {
  const _DefaultDateTime();
  
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// 里程碑事件
class MilestoneEvent {
  final String description;
  final DateTime occurredAt;
  final String category;  // "首次对话"/"深度交流"/"情绪支持"

  MilestoneEvent({
    required this.description,
    DateTime? occurredAt,
    required this.category,
  }) : occurredAt = occurredAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'description': description,
    'occurredAt': occurredAt.toIso8601String(),
    'category': category,
  };

  factory MilestoneEvent.fromJson(Map<String, dynamic> json) {
    return MilestoneEvent(
      description: json['description'] ?? '',
      occurredAt: DateTime.tryParse(json['occurredAt'] ?? ''),
      category: json['category'] ?? '',
    );
  }
}

/// 情绪档案
class EmotionalArchive {
  final List<EmotionSnapshot> recentSnapshots;
  final Map<String, double> topicEmotionMap;
  final List<StressPattern> stressPatterns;

  const EmotionalArchive({
    this.recentSnapshots = const [],
    this.topicEmotionMap = const {},
    this.stressPatterns = const [],
  });

  /// 添加情绪快照
  EmotionalArchive addSnapshot(EmotionSnapshot snapshot) {
    final newSnapshots = [...recentSnapshots, snapshot];
    // 只保留最近30天的快照
    final thirtyDaysAgo = DateTime.now().subtract(const Duration(days: 30));
    final filtered = newSnapshots.where((s) => s.timestamp.isAfter(thirtyDaysAgo)).toList();
    
    return EmotionalArchive(
      recentSnapshots: filtered,
      topicEmotionMap: topicEmotionMap,
      stressPatterns: stressPatterns,
    );
  }

  /// 获取最近的情绪趋势
  String getEmotionTrend() {
    if (recentSnapshots.isEmpty) return '平稳';
    
    final recent = recentSnapshots.length > 5 
        ? recentSnapshots.sublist(recentSnapshots.length - 5) 
        : recentSnapshots;
    
    final avgValence = recent.map((s) => s.valence).reduce((a, b) => a + b) / recent.length;
    
    if (avgValence > 0.3) return '积极';
    if (avgValence < -0.3) return '低落';
    return '平稳';
  }

  Map<String, dynamic> toJson() => {
    'recentSnapshots': recentSnapshots.map((s) => s.toJson()).toList(),
    'topicEmotionMap': topicEmotionMap,
    'stressPatterns': stressPatterns.map((p) => p.toJson()).toList(),
  };

  factory EmotionalArchive.fromJson(Map<String, dynamic> json) {
    return EmotionalArchive(
      recentSnapshots: (json['recentSnapshots'] as List?)
          ?.map((e) => EmotionSnapshot.fromJson(e))
          .toList() ?? [],
      topicEmotionMap: (json['topicEmotionMap'] as Map?)?.cast<String, double>() ?? {},
      stressPatterns: (json['stressPatterns'] as List?)
          ?.map((e) => StressPattern.fromJson(e))
          .toList() ?? [],
    );
  }
}

/// 情绪快照
class EmotionSnapshot {
  final double valence;
  final double arousal;
  final DateTime timestamp;
  final String? trigger;  // 触发事件描述

  EmotionSnapshot({
    required this.valence,
    required this.arousal,
    DateTime? timestamp,
    this.trigger,
  }) : timestamp = timestamp ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'valence': valence,
    'arousal': arousal,
    'timestamp': timestamp.toIso8601String(),
    'trigger': trigger,
  };

  factory EmotionSnapshot.fromJson(Map<String, dynamic> json) {
    return EmotionSnapshot(
      valence: (json['valence'] ?? 0.0).toDouble(),
      arousal: (json['arousal'] ?? 0.5).toDouble(),
      timestamp: DateTime.tryParse(json['timestamp'] ?? ''),
      trigger: json['trigger'],
    );
  }
}

/// 压力模式
class StressPattern {
  final String description;
  final List<String> triggers;
  final double frequency;  // 出现频率 0.0 ~ 1.0
  final DateTime lastOccurred;

  StressPattern({
    required this.description,
    this.triggers = const [],
    this.frequency = 0.0,
    DateTime? lastOccurred,
  }) : lastOccurred = lastOccurred ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'description': description,
    'triggers': triggers,
    'frequency': frequency,
    'lastOccurred': lastOccurred.toIso8601String(),
  };

  factory StressPattern.fromJson(Map<String, dynamic> json) {
    return StressPattern(
      description: json['description'] ?? '',
      triggers: (json['triggers'] as List?)?.cast<String>() ?? [],
      frequency: (json['frequency'] ?? 0.0).toDouble(),
      lastOccurred: DateTime.tryParse(json['lastOccurred'] ?? ''),
    );
  }
}
