// FactStore - 核心事实存储
//
// 设计原理：
// - 存储永不遗忘的关键用户信息
// - 每次 System Prompt 构建时自动注入
// - 支持从对话中自动学习和手动设置
// - 【新增】混合提取：正则守门 + LLM 精确提取

import 'dart:convert';
import '../settings_loader.dart';
import '../service/llm_service.dart';
import '../service/database_helper.dart';

/// 核心事实存储 - 确保 AI 永不遗忘的关键信息
class FactStore {
  static const String _storageKey = 'fact_store_data';

  // 预定义的核心事实 Key (Canonical Keys)
  static const String keyUserName = 'user_name';
  static const String keyUserRole = 'role';
  static const String keyUserGoal = 'goal';
  static const String keyImportantDate = 'important_date';
  static const String keyUserLocation = 'location';
  static const String keyUserAge = 'age';
  static const String keyUserPreference = 'preference'; 
  
  // 严格分类 Key
  static const String keyCurrentStatus = 'current_status'; // 状态 (加班/生病等)
  static const String keyOccupation = 'occupation';       // 职业 (警校/经侦等)
  static const String keyOrigin = 'origin';               // 籍贯 (山西/晋北等)

  final DatabaseHelper _dbHelper;
  LLMService? _llmService;
  
  void setLLMService(LLMService service) {
    _llmService = service;
  }

  // 核心事实存储 (内存缓存)
  final Map<String, FactEntry> _facts = {};

  FactStore(this._dbHelper);

  /// 初始化并加载数据
  Future<void> init() async {
    await _load();
  }

  /// 从持久化存储加载
  Future<void> _load() async {
    final rows = await _dbHelper.queryAll('facts');
    _facts.clear();
    
    for (final row in rows) {
      final key = row['key'] as String;
      _facts[key] = FactEntry(
        value: row['value'] ?? '',
        source: FactSource.values[row['source'] ?? 1],
        confidence: (row['importance'] ?? 0.8).toDouble(),
        updatedAt: DateTime.tryParse(row['timestamp'] ?? '') ?? DateTime.now(),
        status: FactStatus.values[row['status'] ?? 0],  // Phase 2: 加载状态
      );
    }
    
    // 加载后尝试迁移
    await _migrateLegacyData();
  }
  
  /// 脏数据清洗与迁移
  /// 
  /// 解决历史版本中"重复事实"的问题，强制合并到 Canonical Keys
  Future<void> _migrateLegacyData() async {
    bool refined = false;
    final keysToRemove = <String>[];
    final keywordMap = SettingsLoader.keywordToStorageKey;
    
    // 1. 扫描所有事实，寻找特定关键词
    final validFacts = _facts.entries.toList()
      ..sort((a, b) => a.value.updatedAt.compareTo(b.value.updatedAt)); // 按时间排序，保留最新的

    for (final entry in validFacts) {
      final val = entry.value.value;
      final key = entry.key;
      
      // 配置驱动的迁移逻辑
      for (final kw in keywordMap.keys) {
        if (val.contains(kw)) {
          final targetKey = keywordMap[kw]!;
          _facts[targetKey] = entry.value;
          if (key != targetKey) keysToRemove.add(key);
          refined = true;
          break;
        }
      }
    }
    
    // 2. 删除旧的冗余 Key
    for (final k in keysToRemove) {
      _facts.remove(k);
    }
    
    if (refined) {
      print('[FactStore] Data migration completed. Cleared duplicates.');
      // 迁移不需要全量保存，因为 setFact 和 removeFact 已经是增量保存了
      // 但为了确保状态一致，我们可以执行一次全量同步或依赖已有的逻辑
    }
  }

  /// 全量保存 (仅在迁移等特殊情况使用)
  Future<void> _saveAll() async {
    // 实际生产中应尽量避免全量覆盖，SQL 下可以用事务
    for (final entry in _facts.entries) {
      await _dbSaveFact(entry.key, entry.value);
    }
  }

  /// 单个事实保存到数据库
  Future<void> _dbSaveFact(String key, FactEntry entry) async {
    await _dbHelper.insert('facts', {
      'key': key,
      'value': entry.value,
      'source': entry.source.index,
      'timestamp': entry.updatedAt.toIso8601String(),
      'importance': entry.confidence,
      'status': entry.status.index,  // Phase 2: 保存状态
    });
  }

  /// 设置事实 (自动路由到 Canonical Keys)
  /// 
  /// Phase 4: 增强冲突解决策略
  /// - 用户确认(verified)的事实绝对不覆盖
  /// - 使用时间衰减算法计算有效置信度
  /// - 支持 per-type 置信度阈值
  Future<void> setFact(
    String key,
    String value, {
    FactSource source = FactSource.inferred,
    double confidence = 0.8,
  }) async {
    // 配置驱动的关键词路由
    String targetKey = key;
    final keywordMap = SettingsLoader.keywordToStorageKey;
    
    // 遍历关键词映射（已按长度降序排序）
    for (final kw in keywordMap.keys) {
      if (value.contains(kw)) {
        targetKey = keywordMap[kw]!;
        break;
      }
    }
    
    // Phase 4: 增强冲突解决（时间衰减 + per-type 阈值）
    final existing = _facts[targetKey];
    if (existing != null) {
      // 规则 1: 用户确认的事实绝对不覆盖
      if (existing.status == FactStatus.verified) {
        print('[FactStore] Protected: $targetKey is verified, not overwriting');
        return;
      }
      
      // 规则 2: 活跃状态下的智能覆盖（时间衰减算法）
      if (existing.status == FactStatus.active) {
        // 获取类型配置
        final typeKey = SettingsLoader.getTypeKeyByStorageKey(targetKey) ?? targetKey;
        final expiryDays = SettingsLoader.getFactExpiryDays(typeKey);
        final decayRate = SettingsLoader.getFactDecayRate(typeKey);
        
        // 计算旧事实的有效置信度（时间衰减）
        final age = DateTime.now().difference(existing.updatedAt).inDays;
        final decayFactor = (1 - decayRate * (age / expiryDays)).clamp(0.0, 1.0);
        final effectiveConfidence = existing.confidence * decayFactor;
        
        // 比较新置信度与衰减后的旧置信度
        if (confidence <= effectiveConfidence) {
          print('[FactStore] Retained: $targetKey (effective: ${effectiveConfidence.toStringAsFixed(2)}, new: $confidence, decay: ${decayFactor.toStringAsFixed(2)})');
          return;
        }
        print('[FactStore] Overwriting: $targetKey (effective: ${effectiveConfidence.toStringAsFixed(2)} < new: $confidence)');
      }
    }

    final entry = FactEntry(
      value: value,
      source: source,
      confidence: confidence,
      updatedAt: DateTime.now(),
    );
    _facts[targetKey] = entry;
    
    // 异步保存到数据库
    await _dbSaveFact(targetKey, entry);
    print('[FactStore] Set fact: $targetKey = $value (confidence: $confidence, routed from $key)');
  }

  /// 获取事实值
  String? getFact(String key) => _facts[key]?.value;

  /// 获取事实条目
  FactEntry? getFactEntry(String key) => _facts[key];

  /// 获取所有事实
  Map<String, FactEntry> getAllFacts() => Map.unmodifiable(_facts);
  
  /// Phase 2: 获取活跃事实（排除已拒绝）
  Map<String, FactEntry> getActiveFacts() {
    return Map.fromEntries(
      _facts.entries.where((e) => e.value.status != FactStatus.rejected)
    );
  }

  /// 删除事实
  Future<void> removeFact(String key) async {
    _facts.remove(key);
    await _dbHelper.delete('facts', 'key', key);
  }

  /// 清空所有事实
  Future<void> clearAll() async {
    _facts.clear();
    await _dbHelper.clearTable('facts');
  }
  
  /// Phase 2: 确认事实（用户验证）
  Future<void> verifyFact(String key) async {
    final entry = _facts[key];
    if (entry == null) return;
    _facts[key] = entry.copyWith(status: FactStatus.verified);
    await _dbSaveFact(key, _facts[key]!);
    print('[FactStore] Fact verified: $key');
  }
  
  /// Phase 2: 拒绝事实（从 Prompt 中移除）
  Future<void> rejectFact(String key) async {
    final entry = _facts[key];
    if (entry == null) return;
    _facts[key] = entry.copyWith(status: FactStatus.rejected);
    await _dbSaveFact(key, _facts[key]!);
    print('[FactStore] Fact rejected: $key');
  }
  
  /// Phase 2: 恢复事实为活跃状态
  Future<void> activateFact(String key) async {
    final entry = _facts[key];
    if (entry == null) return;
    _facts[key] = entry.copyWith(status: FactStatus.active);
    await _dbSaveFact(key, _facts[key]!);
    print('[FactStore] Fact activated: $key');
  }

  /// 格式化为 System Prompt
  /// 
  /// [maxLength] 输出最大字符数，防止 Token 超限
  /// Phase 2: 自动过滤已拒绝的事实
  String formatForSystemPrompt({double minConfidence = 0.6, int maxLength = 500}) {
    return deduplicateAndSummarize(minConfidence: minConfidence, maxLength: maxLength);
  }

  /// 【重构】去重并摘要 (严格 Schema 模式)
  /// 
  /// 输出格式："用户是{occupation}，来自{origin}。当前状态：{current_status}。偏好：{preferences}"
  /// 
  /// Phase 2: 自动过滤已拒绝的事实
  String deduplicateAndSummarize({double minConfidence = 0.6, int maxLength = 500}) {
    final parts = <String>[];
    
    // Phase 2: 使用活跃事实（排除已拒绝）
    final activeFacts = getActiveFacts();

    // 1. 基础身份 (高优先)
    final nameEntry = activeFacts[keyUserName];
    final name = nameEntry?.value;
    final occupation = activeFacts[keyOccupation]?.value ?? activeFacts[keyUserRole]?.value;
    final origin = activeFacts[keyOrigin]?.value ?? activeFacts[keyUserLocation]?.value;
    
    String identity = '用户';
    if (name != null) identity += '身份：$name';
    if (occupation != null) identity += '是$occupation'; 
    if (origin != null) identity += '，来自$origin';
    
    if (identity != '用户') {
      parts.add(identity);
    }
    
    // 2. 当前状态 (中优先) - 过滤过期状态
    final statusEntry = activeFacts[keyCurrentStatus];
    if (statusEntry != null && !statusEntry.isExpired(keyCurrentStatus)) {
      parts.add('当前状态：${statusEntry.value}');
    }
    
    // 3. 目标 (中优先)
    final goal = activeFacts[keyUserGoal]?.value;
    if (goal != null) {
      parts.add('目标是$goal');
    }
    
    // 4. 偏好 (低优先，可能被截断)
    final preferences = activeFacts.entries
        .where((e) => e.key.startsWith('preference') || e.key == keyUserPreference)
        .map((e) => e.value.value)
        .toSet()
        .take(5)  // 限制偏好数量
        .join('；');
        
    if (preferences.isNotEmpty) {
      parts.add('偏好：$preferences');
    }

    if (parts.isEmpty) return '（暂无已知信息）';
    
    // 长度控制
    String result = parts.join('。') + '。';
    if (result.length > maxLength) {
      // 智能截断：保留高优先信息
      result = result.substring(0, maxLength - 3) + '...';
    }
    
    return result;
  }

  /// 获取事实标签 (GUI 显示用)
  String _getFactLabel(String key) {
    switch (key) {
      case keyUserName: return '用户姓名';
      case keyOccupation:
      case keyUserRole: return '身份/职业';
      case keyOrigin:
      case keyUserLocation: return '籍贯/所在地';
      case keyCurrentStatus: return '当前状态';
      case keyUserGoal: return '当前目标';
      default: return key;
    }
  }

  /// 从文本中自动提取事实（配置驱动的动态模式匹配）
  ///
  /// Phase 4: 完全配置化的提取器
  /// - 从 YAML 读取所有类型的正则模式
  /// - 动态构建提取逻辑，无需硬编码
  Future<List<String>> extractAndStore(String text) async {
    final extracted = <String>[];
    
    // Phase 4: 使用配置驱动的动态模式
    final allPatterns = SettingsLoader.allFactPatterns;
    
    for (final entry in allPatterns.entries) {
      final storageKey = entry.key;
      final patterns = entry.value;
      
      for (final pattern in patterns) {
        final match = pattern.firstMatch(text);
        if (match != null && match.groupCount >= 1) {
          final value = match.group(1)?.trim();
          if (value != null && value.isNotEmpty && value.length <= 50) {
            // 检查是否已存在相同值
            if (_facts[storageKey]?.value != value) {
              await setFact(storageKey, value, source: FactSource.inferred, confidence: 0.75);
              extracted.add('$storageKey: $value');
            }
            break; // 每个类型只取第一个匹配
          }
        }
      }
    }

    // 偏好提取（关键词驱动，保留原逻辑）
    final preferenceKeywords = SettingsLoader.preferenceKeywords;
    if (preferenceKeywords.isNotEmpty) {
      final sortedKeywords = List<String>.from(preferenceKeywords)
        ..sort((a, b) => b.length.compareTo(a.length));

      final escapedKeywords = sortedKeywords
          .map((k) => RegExp.escape(k))
          .join('|');

      final mergedPattern = RegExp('([^。！？]*($escapedKeywords)[^。！？]*)');

      for (final match in mergedPattern.allMatches(text)) {
        final preference = match.group(1)?.trim();
        if (preference == null ||
            preference.isEmpty ||
            preference.length > 50) {
          continue;
        }

        final matchedKeyword = preferenceKeywords.firstWhere(
          (k) => preference.contains(k),
          orElse: () => 'preference',
        );

        final factKey = 'preference_$matchedKeyword';

        if (_facts[factKey]?.value != preference) {
          await setFact(
            factKey,
            preference,
            source: FactSource.inferred,
            confidence: 0.7,
          );
          extracted.add('偏好($matchedKeyword): $preference');
        }
      }
    }
    
    // 如果有任何提取且有 LLM 服务，使用 LLM 精确提取
    if (extracted.isNotEmpty && _llmService != null) {
      final llmFacts = await _extractFactsWithLLM(text);
      for (final fact in llmFacts) {
        if (!extracted.contains(fact)) {
          extracted.add(fact);
        }
      }
    }

    return extracted;
  }
  
  /// 使用 LLM 精确提取用户事实
  /// 
  /// 解决正则无法区分"用户喜欢"和"AI喜欢"的问题
  /// 【Phase 1】动态注入类型描述
  Future<List<String>> _extractFactsWithLLM(String text) async {
    if (_llmService == null) return [];
    
    // 动态生成类型描述
    final typeDescriptions = SettingsLoader.factTypeDescriptionsForPrompt;
    
    final prompt = '''你是一个事实提取助手。从对话中提取关于【用户】的事实信息。

可识别的事实类型：
$typeDescriptions
规则：
1. 只提取关于用户（说话者）的事实，忽略关于 AI 助手的描述。
2. 区分"我喜欢"（用户喜好）和"你喜欢"（AI喜好，忽略）。
3. 返回 JSON 数组，每个元素包含 key（类型key）、value（提取值）和 confidence（置信度1-10）。

示例输入："我叫小明，今年25岁，我喜欢吃火锅"
示例输出：[{"key":"user_name","value":"小明","confidence":9},{"key":"preference","value":"喜欢吃火锅","confidence":8}]

只返回 JSON 数组，不要其他内容。如果没有提取到任何事实，返回空数组 []。''';

    try {
      final response = await _llmService!.completeWithSystem(
        systemPrompt: prompt,
        userMessage: '提取以下文本中关于用户的事实：\n$text',
        model: 'qwen-flash',
        maxTokens: 200,
        temperature: 0.1,
      );
      
      return await _parseLLMFacts(response);
    } catch (e) {
      print('[FactStore] LLM extraction error: $e');
      return [];
    }
  }
  
  /// 解析 LLM 返回的事实 JSON
  /// Phase 3: 支持置信度评分和过滤
  /// 解析 LLM 返回的事实 JSON
  /// Phase 3: 支持置信度评分和过滤
  /// Phase 4 Fix: 支持 Per-Type 阈值和键名映射
  Future<List<String>> _parseLLMFacts(String response) async {
    final extracted = <String>[];
    // REMOVED: final confidenceThreshold = SettingsLoader.llmConfidenceThreshold; // <--- 移除全局阈值
    
    try {
      // 提取 JSON 数组
      final jsonMatch = RegExp(r'\[[\s\S]*\]').firstMatch(response);
      if (jsonMatch == null) return [];
      
      final facts = jsonDecode(jsonMatch.group(0)!) as List<dynamic>;
      
      for (final fact in facts) {
        if (fact is Map<String, dynamic>) {
          final typeKey = fact['key']?.toString(); // LLM返回的是 Type Key (如 'name')
          final value = fact['value']?.toString();
          // Phase 3: 解析置信度（1-10 -> 0.1-1.0）
          final rawConfidence = (fact['confidence'] as num?)?.toDouble() ?? 5.0;
          final confidence = rawConfidence / 10.0;
          
          if (typeKey == null || value == null || value.isEmpty) continue;

          // 【FIX 1】获取 Per-Type 阈值
          final threshold = SettingsLoader.getFactConfidenceThreshold(typeKey);
          
          // Phase 3: 置信度过滤
          if (rawConfidence < threshold) {
            print('[FactStore] Low confidence fact ignored: $typeKey = $value (confidence: $rawConfidence < threshold: $threshold)');
            continue;
          }
          
          // 【FIX 2】映射 TypeKey -> StorageKey
          // 确保 'name' 映射回 'user_name'
          final typeData = SettingsLoader.factTypes[typeKey];
          var storageKey = typeKey;
          if (typeData is Map && typeData['storage_key'] != null) {
            storageKey = typeData['storage_key'];
          }
          
          // 存储到 FactStore
          // 注意：此处传递 storageKey
          await setFact(storageKey, value, source: FactSource.inferred, confidence: confidence);
          extracted.add('$storageKey: $value (LLM, confidence: ${rawConfidence.toInt()})');
        }
      }
    } catch (e) {
      print('[FactStore] LLM parse error: $e');
    }
    
    return extracted;
  }
}

/// 事实来源
enum FactSource {
  manual, // 用户手动设置
  inferred, // 从对话中推断
  confirmed, // 用户确认的推断
}

/// Phase 2: 事实状态枚举
enum FactStatus {
  active,    // 0: 活跃（默认，可被覆盖）
  verified,  // 1: 用户已确认（绝对保护）
  rejected,  // 2: 用户已拒绝（不进入 Prompt）
}

/// 事实条目
class FactEntry {
  final String value;
  final FactSource source;
  final double confidence; // 置信度 0.0 ~ 1.0
  final DateTime updatedAt;
  final FactStatus status;  // Phase 2: 添加状态

  const FactEntry({
    required this.value,
    this.source = FactSource.inferred,
    this.confidence = 0.8,
    required this.updatedAt,
    this.status = FactStatus.active,
  });
  
  /// Phase 2: copyWith 用于状态更新
  FactEntry copyWith({
    String? value,
    FactSource? source,
    double? confidence,
    DateTime? updatedAt,
    FactStatus? status,
  }) {
    return FactEntry(
      value: value ?? this.value,
      source: source ?? this.source,
      confidence: confidence ?? this.confidence,
      updatedAt: updatedAt ?? this.updatedAt,
      status: status ?? this.status,
    );
  }

  /// 检查事实是否过期
  /// 
  /// 过期规则：使用配置中的 expiry_days
  bool isExpired(String key) {
    final now = DateTime.now();
    final age = now.difference(updatedAt);
    final expiryDays = SettingsLoader.getFactExpiryDays(key);
    return age.inDays > expiryDays;
  }

  Map<String, dynamic> toJson() => {
    'value': value,
    'source': source.index,
    'confidence': confidence,
    'updatedAt': updatedAt.toIso8601String(),
    'status': status.index,
  };

  factory FactEntry.fromJson(Map<String, dynamic> json) {
    return FactEntry(
      value: json['value'] ?? '',
      source: FactSource.values[json['source'] ?? 0],
      confidence: (json['confidence'] ?? 0.8).toDouble(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
      status: FactStatus.values[json['status'] ?? 0],
    );
  }
}

