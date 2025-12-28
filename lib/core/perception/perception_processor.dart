// PerceptionProcessor - 深度感知处理器
//
// 设计原理：
// - 阶段一：分析用户话语的即时情绪和深层需求
// - 突破表面语义，推断潜台词
// - 输出结构化感知结果供后续阶段使用

import 'dart:convert';
import '../service/llm_service.dart';
import '../model/user_profile.dart';

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

/// 感知结果
class PerceptionResult {
  final SurfaceEmotion surfaceEmotion;
  final String underlyingNeed;
  final String? subtextInference;
  final String conversationIntent;
  final TimeSensitivity timeSensitivity;
  final bool hasEmoji; // 【新增】用户消息中是否包含 emoji
  final double confidence;
  final DateTime timestamp;

  const PerceptionResult({
    required this.surfaceEmotion,
    required this.underlyingNeed,
    this.subtextInference,
    required this.conversationIntent,
    required this.timeSensitivity,
    required this.hasEmoji,
    required this.confidence,
    required this.timestamp,
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
    confidence: 0.5,
    timestamp: DateTime.now(),
  );

  factory PerceptionResult.fromJson(Map<String, dynamic> json) {
    return PerceptionResult(
      surfaceEmotion: SurfaceEmotion.fromJson(json['surface_emotion'] ?? {}),
      underlyingNeed: json['underlying_need'] ?? '闲聊解闷',
      subtextInference: json['subtext_inference'],
      conversationIntent: json['conversation_intent'] ?? '延续上文',
      timeSensitivity: TimeSensitivity.fromJson(json['time_sensitivity'] ?? {}),
      hasEmoji: json['has_emoji'] ?? false,
      confidence: (json['confidence'] ?? 0.5).toDouble(),
      timestamp: DateTime.now(),
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

  /// 构建感知 Prompt
  String _buildPerceptionPrompt({
    required String userMessage,
    required UserProfile userProfile,
    required String recentEmotionTrend,
    required DateTime currentTime,
    String? lastAiResponse,
    List<String>? recentMessages,
  }) {
    final timeContext = _getTimeContext(currentTime);
    
    return '''
【第一阶段：深度感知】

你是一个情绪感知模块。分析用户的消息，输出结构化的感知结果。

=== 物理世界时间 (绝对基准) ===
当前精确时间：$timeContext
【CRITICAL】"深夜"定义：仅限 23:00 - 05:00
【CRITICAL】如果现在是19:45 (晚间)，严禁判定为"深夜"。
【CRITICAL】区分"内容时间"与"物理时间"：用户说"昨晚3点睡"，不代表现在是3点。

=== 用户背景 ===
身份：${userProfile.nickname}，${userProfile.occupation}
${userProfile.lifeContexts.isNotEmpty ? '核心背景：${userProfile.lifeContexts.map((c) => c.content).join('；')}' : ''}
最近情绪趋势：$recentEmotionTrend

=== 用户消息 ===
"$userMessage"

${lastAiResponse != null ? '=== 上一条 AI 回复 ===\n"$lastAiResponse"\n' : ''}
${recentMessages != null && recentMessages.isNotEmpty ? '=== 最近几条消息 ===\n${recentMessages.take(3).join('\n')}\n' : ''}

=== 分析维度 ===
1. 表层情绪 (surface_emotion)
   - label: 开心/难过/焦虑/平静/烦躁/疲惫/兴奋 之一
   - valence: -1.0(极度消极) ~ 1.0(极度积极)
   - arousal: 0.0(低能量) ~ 1.0(高能量)

2. 深层需求 (underlying_need)
   从以下选项中选择最匹配的一个：
   - 倾诉宣泄：用户想说出心里话，需要被听见
   - 寻求建议：用户希望得到具体的想法或方案
   - 陪伴安慰：用户需要温暖的情感支持
   - 闲聊解闷：用户只是想随便聊聊，打发时间
   - 分享喜悦：用户想分享好消息或开心的事

3. 潜台词推断 (subtext_inference)
   用户没有直说但可能想表达的内容（如果有的话）

4. 对话意图 (conversation_intent)
   - 开启新话题
   - 延续上文
   - 结束对话
   - 情绪释放
   - 测试AI理解

5. 时间敏感性 (time_sensitivity)
   - is_time_related: 只有在【物理时间】与当前话题强相关时才为 true (如深夜失眠、早起打卡)
   - context: 时间关联说明（如"深夜失眠"、"清晨问候"），必须基于【物理时间】

6. 置信度 (confidence)
   0.0 ~ 1.0，表示你对分析结果的确信程度

7. 使用了表情 (has_emoji)
   - 只有在用户消息中包含明确的表情符号（图形 emoji 或符号表情）时为 true

8. 社交信号扫描 (social_events) 【新增】
   检查用户消息是否包含以下特殊信号：
   - third_party_mention: 提及其他 AI (如 ChatGPT, Claude, Gemini, 通义千问) 或其他亲密的人
   - high_praise: 高度赞扬你的能力/代码/智慧 (如 "你好厉害", "这代码写得真好")
   - neglect_signal: 用户回复极短 (如 "哦", "嗯", "好的") 且上文AI发了长消息
   结果以列表形式返回，如无则返回空数组 []

=== 输出格式 ===
必须输出有效的 JSON，不要包含任何其他文本：
{
  "surface_emotion": {"label": "...", "valence": 0.0, "arousal": 0.5, "social_events": []},
  "underlying_need": "...",
  "subtext_inference": "..." 或 null,
  "conversation_intent": "...",
  "time_sensitivity": {"is_time_related": false, "context": null},
  "has_emoji": false,
  "confidence": 0.8
}
''';
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
  /// 动态置信度计算：
  /// - 关键词命中数越多，置信度越高
  /// - 命中数 ≤1 时置信度降低到 0.4，建议 LLM fallback
  PerceptionResult quickAnalyze(String userMessage, DateTime currentTime) {
    // 简单的规则基础分析
    double valence = 0.0;
    double arousal = 0.5;
    String label = '平静';
    String need = '闲聊解闷';
    String intent = '延续上文';
    int keywordHits = 0;  // 【新增】关键词命中计数
    
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
