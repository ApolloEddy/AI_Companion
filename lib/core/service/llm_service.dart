import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import '../config.dart';
import '../policy/generation_policy.dart';

/// LLM 响应结果（含详细 Token 统计）
class LLMResponse {
  final String? content;
  final int promptTokens;     // 【新增】输入消耗的 Token
  final int completionTokens; // 【新增】输出消耗的 Token  
  final int totalTokens;      // 【重命名】总 Token 数
  final bool success;
  final String? error;
  
  LLMResponse({
    this.content,
    this.promptTokens = 0,
    this.completionTokens = 0,
    this.totalTokens = 0,
    this.success = false,
    this.error,
  });
  
  /// 向后兼容: tokensUsed getter
  int get tokensUsed => totalTokens;
}

/// LLM 服务 - 纯 API 适配层
/// 
/// 设计原理：
/// - 【瘦身后】只处理 API 通信，不含业务逻辑
/// - 所有生成参数由调用方传入 (GenerationParams)
/// - 支持动态切换模型
class LLMService {
  final String apiKey;
  String _model;  // 当前使用的模型
  
  static const Duration timeout = Duration(seconds: 30);
  
  LLMService(this.apiKey, {String? model}) 
      : _model = model ?? AppConfig.defaultModel;

  /// 获取当前模型
  String get currentModel => _model;

  /// 切换模型
  void setModel(String modelId) {
    _model = modelId;
  }

  /// 生成响应 (返回详细结果包含 token 数)
  /// 
  /// [params] 由 GenerationPolicy 提供，禁止硬编码
  Future<LLMResponse> generateWithTokens(
    List<Map<String, String>> messages, {
    required GenerationParams params,
  }) async {
    if (apiKey.isEmpty) {
      return LLMResponse(error: 'API Key is empty');
    }

    try {
      final response = await http.post(
        Uri.parse(AppConfig.apiUrl),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': _model,  // 使用动态模型
          'messages': messages,
          // 使用传入的参数，不再硬编码
          ...params.toApiParams(),
        }),
      ).timeout(timeout, onTimeout: () {
        throw TimeoutException('Request timed out');
      });

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          
          // 提取 token 使用量（分别统计输入/输出）
          int promptTokens = 0;
          int completionTokens = 0;
          int totalTokens = 0;
          if (data['usage'] != null) {
            promptTokens = (data['usage']['prompt_tokens'] ?? 0) as int;
            completionTokens = (data['usage']['completion_tokens'] ?? 0) as int;
            totalTokens = (data['usage']['total_tokens'] ?? 0) as int;
          }
          
          if (data['choices'] != null && 
              data['choices'] is List && 
              (data['choices'] as List).isNotEmpty) {
            final content = data['choices'][0]['message']?['content'];
            if (content is String && content.isNotEmpty) {
              return LLMResponse(
                content: content,
                promptTokens: promptTokens,
                completionTokens: completionTokens,
                totalTokens: totalTokens,
                success: true,
              );
            }
          }
          
          return LLMResponse(error: 'Unexpected response format', totalTokens: totalTokens);
        } catch (e) {
          return LLMResponse(error: 'JSON parse error: $e');
        }
      } else if (response.statusCode == 401) {
        return LLMResponse(error: 'Invalid API Key');
      } else if (response.statusCode == 429) {
        return LLMResponse(error: 'Rate limited, please wait');
      } else {
        return LLMResponse(error: 'API Error ${response.statusCode}');
      }
    } on TimeoutException {
      return LLMResponse(error: 'Request timeout');
    } catch (e) {
      return LLMResponse(error: 'Network error: $e');
    }
  }

  /// 简化版生成 (向后兼容)
  /// 
  /// 注意：此方法使用默认参数，推荐使用 generateWithTokens 并传入 GenerationParams
  Future<String?> generate(List<Map<String, String>> messages) async {
    // 使用阿里云官方默认参数保持向后兼容
    const defaultParams = GenerationParams(
      temperature: 0.7,
      topP: 0.8,
      maxTokens: 1024,
    );
    final result = await generateWithTokens(messages, params: defaultParams);
    return result.content;
  }

  /// 估算消息的 token 数量 (简化计算)
  /// 中文约 1.5 字符/token，英文约 4 字符/token
  static int estimateTokens(String text) {
    int chineseCount = 0;
    int otherCount = 0;
    
    for (int i = 0; i < text.length; i++) {
      final code = text.codeUnitAt(i);
      if (code >= 0x4E00 && code <= 0x9FFF) {
        chineseCount++;
      } else {
        otherCount++;
      }
    }
    
    // 中文约 1.5 字符/token，其他约 4 字符/token
    return (chineseCount / 1.5).ceil() + (otherCount / 4).ceil();
  }

  /// 带系统提示的完成调用（用于认知引擎各阶段）
  /// 
  /// [model] 可选，覆盖默认模型
  /// [temperature] 控制随机性
  /// [maxTokens] 最大输出 token
  Future<String> completeWithSystem({
    required String systemPrompt,
    required String userMessage,
    String? model,
    double temperature = 0.85,
    int maxTokens = 1024,
  }) async {
    final messages = [
      {'role': 'system', 'content': systemPrompt},
      {'role': 'user', 'content': userMessage},
    ];

    final params = GenerationParams(
      temperature: temperature,
      topP: 0.8,  // 阿里云官方默认值
      maxTokens: maxTokens,
    );

    // 临时切换模型（如果指定）
    final originalModel = _model;
    if (model != null) {
      _model = model;
    }

    try {
      final result = await generateWithTokens(messages, params: params);
      return result.content ?? '';
    } finally {
      // 恢复原模型
      if (model != null) {
        _model = originalModel;
      }
    }
  }

  /// 流式生成 (SSE 实现)
  Stream<String> streamComplete({
    required String systemPrompt,
    required String userMessage,
    String? model,
    double temperature = 0.85,
    int maxTokens = 512,
  }) async* {
    if (apiKey.isEmpty) {
      yield 'Error: API Key is empty';
      return;
    }

    final client = http.Client();
    try {
      final request = http.Request('POST', Uri.parse(AppConfig.apiUrl));
      request.headers.addAll({
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $apiKey',
      });
      
      request.body = jsonEncode({
        'model': model ?? _model,
        'messages': [
          {'role': 'system', 'content': systemPrompt},
          {'role': 'user', 'content': userMessage},
        ],
        'temperature': temperature,
        'max_tokens': maxTokens,
        'stream': true, // 【关键】启用流式输出
      });

      final response = await client.send(request).timeout(timeout);
      
      if (response.statusCode != 200) {
        yield 'API Error: ${response.statusCode}';
        return;
      }

      // 处理 SSE 数据流
      await for (final line in response.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        
        if (line.isEmpty) continue;
        if (line == 'data: [DONE]') break;
        
        if (line.startsWith('data: ')) {
          final dataJson = line.substring(6);
          try {
            final data = jsonDecode(dataJson);
            final content = data['choices']?[0]?['delta']?['content'] ?? '';
            if (content.isNotEmpty) {
              yield content;
            }
          } catch (e) {
            // 忽略非 JSON 数据块或解析错误
            continue;
          }
        }
      }
    } catch (e) {
      yield 'Stream Error: $e';
    } finally {
      client.close();
    }
  }
}
