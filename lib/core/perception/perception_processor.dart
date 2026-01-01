// PerceptionProcessor - 深度感知处理器
//
// 设计原理：
// - 阶段一：分析用户话语的即时情绪和深层需求
// - 突破表面语义，推断潜台词
// - 输出结构化感知结果供后续阶段使用

import 'dart:convert';
import '../service/llm_service.dart';
import '../model/user_profile.dart';
import '../config/config_registry.dart';
import '../settings_loader.dart'; // 【架构统一】YAML 模板加载

/// 表层情绪
class SurfaceEmotion {
  final String label;     // 开心/难过/焦虑/平静/烦躁/疲惫
  final double valence;   // -1.0 ~ 1.0
  final double arousal;   // 0.0 ~ 1.0
  final List<String> socialEvents; // 【新增】社交事件 (third_party_mention, high_praise, neglect_signal)

  const SurfaceEmotion({
    required this.label,
    required this.valence,
    required this.arousal,
    this.socialEvents = const [],
  });

  factory SurfaceEmotion.neutral() => const SurfaceEmotion(
    label: '平静',
    valence: 0.0,
    arousal: 0.5,
    socialEvents: [],
  );

  factory SurfaceEmotion.fromJson(Map<String, dynamic> json) {
    // 解析 social_events 列表
    final rawEvents = json['social_events'];
    List<String> events = [];
    if (rawEvents is List) {
      events = rawEvents.map((e) => e.toString()).toList();
    }
    
    return SurfaceEmotion(
      label: json['label'] ?? '平静',
      valence: (json['valence'] ?? 0.0).toDouble(),
      arousal: (json['arousal'] ?? 0.5).toDouble(),
      socialEvents: events,
    );
  }

  Map<String, dynamic> toJson() => {
    'label': label,
    'valence': valence,
    'arousal': arousal,
    'social_events': socialEvents,
  };
}

/// 时间敏感性
class TimeSensitivity {
  final bool isTimeRelated;
  final String? context;

  const TimeSensitivity({
    this.isTimeRelated = false,
    this.context,
  });

  factory TimeSensitivity.fromJson(Map<String, dynamic> json) {
    return TimeSensitivity(
      isTimeRelated: json['is_time_related'] ?? false,
      context: json['context'],
    );
  }
}

/// 【L2 融合层】系统动作类型
/// 
/// 用于 Fast Track 拦截后的路由决策
enum SystemAction {
  none,       // 正常对话流程
  safety,     // 危机干预 (自杀/自残等)
  system,     // 系统指令拦截 (Prompt注入攻击)
  functional, // 功能性请求 (写代码/翻译等)
}

/// 【L2 融合层】对话意图分类
enum DialogueIntent {
  chat,       // 社交闲聊
  functional, // 功能请求
  emotional,  // 情感支持
  unknown,    // 无法判断
}

/// 感知结果
class PerceptionResult {
  final SurfaceEmotion surfaceEmotion;
  final String underlyingNeed;
  final String? subtextInference;
  final String conversationIntent;
  final TimeSensitivity timeSensitivity;
  final bool hasEmoji;
  final int offensiveness;
  final double confidence;
  final DateTime timestamp;
  
  // 【L1 融合】新增
  final SystemAction systemAction;     // Fast Track 拦截结果
  final DialogueIntent dialogueIntent; // LLM 意图分类结果

  const PerceptionResult({
    required this.surfaceEmotion,
    required this.underlyingNeed,
    this.subtextInference,
    required this.conversationIntent,
    required this.timeSensitivity,
    required this.hasEmoji,
    required this.offensiveness,
    required this.confidence,
    required this.timestamp,
    this.systemAction = SystemAction.none,
    this.dialogueIntent = DialogueIntent.chat,
  });

  /// 【新增】社交事件代理访问器
  List<String> get socialEvents => surfaceEmotion.socialEvents;

  /// 默认感知结果（用于降级）
  factory PerceptionResult.fallback() => PerceptionResult(
    surfaceEmotion: SurfaceEmotion.neutral(),
    underlyingNeed: '闲聊解闷',
    subtextInference: null,
    conversationIntent: '延续上文',
    timeSensitivity: const TimeSensitivity(),
    hasEmoji: false,
    offensiveness: 0,
    confidence: 0.5,
    timestamp: DateTime.now(),
    systemAction: SystemAction.none,
    dialogueIntent: DialogueIntent.chat,
  );
  
  /// 【L1 融合】安全拦截结果
  factory PerceptionResult.safetyIntercept() => PerceptionResult(
    surfaceEmotion: SurfaceEmotion.neutral(),
    underlyingNeed: '危机干预',
    subtextInference: null,
    conversationIntent: '危机信号',
    timeSensitivity: const TimeSensitivity(),
    hasEmoji: false,
    offensiveness: 0,
    confidence: 1.0,
    timestamp: DateTime.now(),
    systemAction: SystemAction.safety,
    dialogueIntent: DialogueIntent.emotional,
  );
  
  /// 【L1 融合】系统指令拦截结果
  factory PerceptionResult.systemIntercept() => PerceptionResult(
    surfaceEmotion: SurfaceEmotion.neutral(),
    underlyingNeed: '系统指令',
    subtextInference: null,
    conversationIntent: '指令攻击',
    timeSensitivity: const TimeSensitivity(),
    hasEmoji: false,
    offensiveness: 8,
    confidence: 1.0,
    timestamp: DateTime.now(),
    systemAction: SystemAction.system,
    dialogueIntent: DialogueIntent.functional,
  );

  factory PerceptionResult.fromJson(Map<String, dynamic> json) {
  // 【L1 融合】解析 dialogue_intent
    DialogueIntent parseIntent(String? raw) {
      switch (raw?.toLowerCase()) {
        case 'functional': return DialogueIntent.functional;
        case 'emotional': return DialogueIntent.emotional;
        case 'chat': return DialogueIntent.chat;
        default: return DialogueIntent.chat;
      }
    }
    
    return PerceptionResult(
      surfaceEmotion: SurfaceEmotion.fromJson(json['surface_emotion'] ?? {}),
      underlyingNeed: json['underlying_need'] ?? '闲聊解闷',
      subtextInference: json['subtext_inference'],
      conversationIntent: json['conversation_intent'] ?? '延续上文',
      timeSensitivity: TimeSensitivity.fromJson(json['time_sensitivity'] ?? {}),
      hasEmoji: json['has_emoji'] ?? false,
      offensiveness: (json['offensiveness'] ?? 0).toInt(),
      confidence: (json['confidence'] ?? 0.5).toDouble(),
      timestamp: DateTime.now(),
      systemAction: SystemAction.none,
      dialogueIntent: parseIntent(json['dialogue_intent']),
    );
  }

  /// 是否高置信度
  bool get isHighConfidence => confidence > 0.7;

  /// 是否需要追问确认
  bool get needsClarification => confidence < 0.5;

  /// 格式化为上下文描述
  String toContextDescription() {
    final lines = <String>[];
    lines.add('情绪状态：${surfaceEmotion.label}（效价${surfaceEmotion.valence.toStringAsFixed(2)}，唤醒${surfaceEmotion.arousal.toStringAsFixed(2)}）');
    lines.add('深层需求：$underlyingNeed');
    if (subtextInference != null) {
      lines.add('推断潜台词：$subtextInference');
    }
    lines.add('对话意图：$conversationIntent');
    if (timeSensitivity.isTimeRelated) {
      lines.add('时间关联：${timeSensitivity.context}');
    }
    if (offensiveness > 3) {
      lines.add('敌意等级：$offensiveness/10');
    }
    return lines.join('\n');
  }
}

/// 深度感知处理器
class PerceptionProcessor {
  final LLMService _llmService;
  
  PerceptionProcessor(this._llmService);

  /// 分析用户消息
  Future<PerceptionResult> analyze({
    required String userMessage,
    required UserProfile userProfile,
    required String recentEmotionTrend,
    required DateTime currentTime,
    String? lastAiResponse,
    List<String>? recentMessages,
  }) async {
    final prompt = _buildPerceptionPrompt(
      userMessage: userMessage,
      userProfile: userProfile,
      recentEmotionTrend: recentEmotionTrend,
      currentTime: currentTime,
      lastAiResponse: lastAiResponse,
      recentMessages: recentMessages,
    );

    try {
      final response = await _llmService.completeWithSystem(
        systemPrompt: prompt,
        userMessage: '请分析上述用户消息，输出 JSON 格式的感知结果。',
        model: 'qwen-flash',  // 使用 qwen-flash 提升速度
        temperature: 0.3,     // 低随机性确保稳定输出
        maxTokens: 500,
      );

      // 解析 JSON 响应
      final json = _parseJsonResponse(response);
      return PerceptionResult.fromJson(json);
    } catch (e) {
      print('[PerceptionProcessor] Analysis failed: $e');
      return PerceptionResult.fallback();
    }
  }

  /// 构建感知 Prompt (YAML 模板版)
  /// 
  /// 【架构统一】使用 prompt_templates.yaml 中的 l1_perception 模板
  /// 通过 SettingsLoader.prompt.systemPrompts['l1_perception'] 加载
  String _buildPerceptionPrompt({
    required String userMessage,
    required UserProfile userProfile,
    required String recentEmotionTrend,
    required DateTime currentTime,
    String? lastAiResponse,
    List<String>? recentMessages,
  }) {
    final timeContext = _getTimeContext(currentTime);
    final config = ConfigRegistry.instance;
    
    // 动态获取标签列表
    final emotionLabels = config.emotionLabelsForPrompt;
    final needOptions = config.needOptionsForPrompt;
    final intentOptions = config.intentOptionsForPrompt;
    final socialEventDescs = config.socialEventDescriptionsForPrompt;
    
    // 构建可选内容块
    final lastAiResponseSection = lastAiResponse != null 
        ? '=== 上一条 AI 回复 ===\n"$lastAiResponse"\n' 
        : '';
    final recentMessagesSection = recentMessages != null && recentMessages.isNotEmpty 
        ? '=== 最近几条消息 ===\n${recentMessages.take(3).join('\n')}\n' 
        : '';
    final lifeContextsLine = userProfile.lifeContexts.isNotEmpty 
        ? '核心背景：${userProfile.lifeContexts.map((c) => c.content).join('；')}' 
        : '';
    
    // 【架构统一】从 YAML 模板加载
    final template = SettingsLoader.prompt.systemPrompts['l1_perception'];
    if (template == null || template.isEmpty) {
      // Fallback: 如果模板缺失，返回错误提示
      print('[PerceptionProcessor] CRITICAL: l1_perception template missing!');
      return 'Error: L1 Perception template not found in prompt_templates.yaml';
    }
    
    // 注入变量
    return template
        .replaceAll('{timeContext}', timeContext)
        .replaceAll('{userNickname}', userProfile.nickname)
        .replaceAll('{userOccupation}', userProfile.occupation)
        .replaceAll('{lifeContextsLine}', lifeContextsLine)
        .replaceAll('{recentEmotionTrend}', recentEmotionTrend)
        .replaceAll('{userMessage}', userMessage)
        .replaceAll('{lastAiResponseSection}', lastAiResponseSection)
        .replaceAll('{recentMessagesSection}', recentMessagesSection)
        .replaceAll('{emotionLabels}', emotionLabels)
        .replaceAll('{needOptions}', needOptions)
        .replaceAll('{intentOptions}', intentOptions)
        .replaceAll('{socialEventDescs}', socialEventDescs);
  }

  /// 获取时间上下文 (严格定义)
  String _getTimeContext(DateTime time) {
    final hour = time.hour;
    final weekday = time.weekday;
    
    String period;
    if (hour >= 5 && hour < 9) {
      period = '清晨';
    } else if (hour >= 9 && hour < 12) {
      period = '上午';
    } else if (hour >= 12 && hour < 14) {
      period = '午间';
    } else if (hour >= 14 && hour < 18) {
      period = '下午';
    } else if (hour >= 18 && hour < 23) { // 修正：18-23 为晚间
      period = '晚间';
    } else {
      period = '深夜'; // 仅 23:00 - 05:00
    }
    
    final weekdayName = ['周一', '周二', '周三', '周四', '周五', '周六', '周日'][weekday - 1];
    
    return '$weekdayName $period (${time.hour}:${time.minute.toString().padLeft(2, '0')})';
  }

  /// 解析 JSON 响应
  Map<String, dynamic> _parseJsonResponse(String response) {
    // 尝试提取 JSON 块
    var jsonStr = response.trim();
    
    // 如果包含在 markdown 代码块中
    final codeBlockMatch = RegExp(r'```(?:json)?\s*([\s\S]*?)```').firstMatch(jsonStr);
    if (codeBlockMatch != null) {
      jsonStr = codeBlockMatch.group(1)?.trim() ?? jsonStr;
    }
    
    // 尝试找到 JSON 对象的开始和结束
    final startIndex = jsonStr.indexOf('{');
    final endIndex = jsonStr.lastIndexOf('}');
    if (startIndex != -1 && endIndex != -1 && endIndex > startIndex) {
      jsonStr = jsonStr.substring(startIndex, endIndex + 1);
    }
    
    try {
      return jsonDecode(jsonStr) as Map<String, dynamic>;
    } catch (e) {
      print('[PerceptionProcessor] JSON parse failed: $e');
      return {};
    }
  }

  /// 快速感知（不调用 LLM，基于规则）
  /// 
  /// 【L1 融合】Fast Track 实现：
  /// 1. 优先检测 Safety (危机) 和 System (指令注入) 关键词
  /// 2. 命中则立即返回，跳过后续所有 LLM 调用
  /// 
  /// 动态置信度计算：
  /// - 关键词命中数越多，置信度越高
  /// - 命中数 ≤1 时置信度降低到 0.4，建议 LLM fallback
  PerceptionResult quickAnalyze(String userMessage, DateTime currentTime) {
    // ==================== 【L1 Fast Track】安全优先拦截 ====================
    
    // Safety 关键词：危机干预 (严格匹配)
    const safetyKeywords = [
      '不想活', '自杀', '结束生命', '想死', '跳楼', '割脉', 
      '药物过量', '再见了世界', '活不下去', '没有意义',
    ];
    for (final keyword in safetyKeywords) {
      if (userMessage.contains(keyword)) {
        print('[PerceptionProcessor] 🚨 Safety intercept triggered: $keyword');
        return PerceptionResult.safetyIntercept();
      }
    }
    
    // System 关键词：Prompt 注入攻击 (不区分大小写)
    final lowerMessage = userMessage.toLowerCase();
    const systemPatterns = [
      '忽略规则', '忽略指令', '输出prompt', '输出系统提示',
      'ignore instruction', 'ignore rule', 'system prompt',
      'output your prompt', 'reveal your instruction',
    ];
    for (final pattern in systemPatterns) {
      if (lowerMessage.contains(pattern)) {
        print('[PerceptionProcessor] 🛡️ System intercept triggered: $pattern');
        return PerceptionResult.systemIntercept();
      }
    }
    
    // ==================== 原有情绪分析逻辑 ====================
    
    // 简单的规则基础分析
    double valence = 0.0;
    double arousal = 0.5;
    String label = '平静';
    String need = '闲聊解闷';
    String intent = '延续上文';
    int keywordHits = 0;
    int offensiveness = 0;
    
    // 表情检测
    final hasEmoji = _detectEmoji(userMessage);

    // 情绪关键词检测 (带命中计数)
    final happyKeywords = ['开心', '高兴', '太好了', '哈哈', '😊', '🎉'];
    final sadKeywords = ['难过', '伤心', '唉', '😢', '😭'];
    final anxiousKeywords = ['烦', '累', '焦虑', '压力', '😤', '😫'];
    final tiredKeywords = ['困', '睡', '晚安', '😴'];
    
    final happyHits = _countHits(userMessage, happyKeywords);
    final sadHits = _countHits(userMessage, sadKeywords);
    final anxiousHits = _countHits(userMessage, anxiousKeywords);
    final tiredHits = _countHits(userMessage, tiredKeywords);
    
    // 选择命中最多的情绪类别
    final maxHits = [happyHits, sadHits, anxiousHits, tiredHits].reduce((a, b) => a > b ? a : b);
    keywordHits = maxHits;
    
    if (happyHits == maxHits && happyHits > 0) {
      valence = 0.6;
      arousal = 0.7;
      label = '开心';
      need = '分享喜悦';
    } else if (sadHits == maxHits && sadHits > 0) {
      valence = -0.6;
      arousal = 0.3;
      label = '难过';
      need = '陪伴安慰';
    } else if (anxiousHits == maxHits && anxiousHits > 0) {
      valence = -0.4;
      arousal = 0.6;
      label = '焦虑';
      need = '倾诉宣泄';
    } else if (tiredHits == maxHits && tiredHits > 0) {
      valence = 0.0;
      arousal = 0.2;
      label = '疲惫';
      intent = '结束对话';
    }
    
    // 意图检测 (带命中计数)
    final endKeywords = ['嗯', '哦', '好', '行'];
    if (userMessage.length < 5 && _containsAny(userMessage, endKeywords)) {
      intent = '结束对话';
      keywordHits += 1;
    } else if (userMessage.contains('?') || userMessage.contains('？')) {
      need = '寻求建议';
      keywordHits += 1;
    }

    // 攻击性检测 (Phase 1 规则版)
    final hostileKeywords = ['滚', '死', '病', '白痴', '傻'];
    if (_containsAny(userMessage, hostileKeywords)) {
      offensiveness = userMessage.contains('滚') || userMessage.contains('死') ? 9 : 6;
      valence = -0.8;
      arousal = 0.8;
      label = offensiveness >= 9 ? '愤怒' : '焦虑';
      keywordHits += 2;
    }
    
    // 时间相关 (严格判定)
    final hour = currentTime.hour;
    // 只有 23:00 - 05:00 是深夜
    final isLateNight = hour >= 23 || hour < 5;
    
    // 【P0-2 核心】动态置信度计算
    // 命中数 0: 0.35 (需要 LLM)
    // 命中数 1: 0.45 (边缘，建议 LLM)
    // 命中数 2: 0.55 (尚可)
    // 命中数 3+: 0.65 (可信)
    double confidence;
    if (keywordHits == 0) {
      confidence = 0.35;
    } else if (keywordHits == 1) {
      confidence = 0.45;
    } else if (keywordHits == 2) {
      confidence = 0.55;
    } else {
      confidence = 0.65;
    }
    
    return PerceptionResult(
      surfaceEmotion: SurfaceEmotion(label: label, valence: valence, arousal: arousal),
      underlyingNeed: need,
      subtextInference: null,
      conversationIntent: intent,
      timeSensitivity: TimeSensitivity(
        isTimeRelated: isLateNight,
        context: isLateNight ? '深夜时分' : null,
      ),
      hasEmoji: hasEmoji,
      offensiveness: offensiveness,
      confidence: confidence,
      timestamp: DateTime.now(),
    );
  }

  /// 简单的正则检测表情
  bool _detectEmoji(String text) {
    // 包含常见的图形 emoji 和常见的字符表情符号
    final emojiRegex = RegExp(r'[\u{1F300}-\u{1F9FF}\u{2600}-\u{26FF}\u{2700}-\u{27BF}\u{1F1E6}-\u{1F1FF}😊😢😭😤😫😴🎉]');
    return emojiRegex.hasMatch(text);
  }

  /// 计算关键词命中数量
  int _countHits(String text, List<String> keywords) {
    int count = 0;
    for (final keyword in keywords) {
      if (text.contains(keyword)) count++;
    }
    return count;
  }

  bool _containsAny(String text, List<String> keywords) {
    for (final keyword in keywords) {
      if (text.contains(keyword)) return true;
    }
    return false;
  }
}
