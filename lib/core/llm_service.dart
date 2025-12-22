import 'dart:convert';
import 'dart:async';
import 'package:http/http.dart' as http;
import 'config.dart';

/// LLM 响应结果
class LLMResponse {
  final String? content;
  final int tokensUsed;
  final bool success;
  final String? error;
  
  LLMResponse({
    this.content,
    this.tokensUsed = 0,
    this.success = false,
    this.error,
  });
}

/// LLM 服务 - 与大模型 API 通信
class LLMService {
  final String apiKey;
  
  static const Duration timeout = Duration(seconds: 30);
  
  LLMService(this.apiKey);

  /// 生成响应 (返回详细结果包含 token 数)
  Future<LLMResponse> generateWithTokens(List<Map<String, String>> messages) async {
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
          'model': AppConfig.model,
          'messages': messages,
          'temperature': 0.85, 
          'top_p': 0.9,
          'max_tokens': 1024,
        }),
      ).timeout(timeout, onTimeout: () {
        throw TimeoutException('Request timed out');
      });

      if (response.statusCode == 200) {
        try {
          final data = jsonDecode(utf8.decode(response.bodyBytes));
          
          // 提取 token 使用量
          int tokensUsed = 0;
          if (data['usage'] != null) {
            tokensUsed = (data['usage']['total_tokens'] ?? 0) as int;
          }
          
          if (data['choices'] != null && 
              data['choices'] is List && 
              (data['choices'] as List).isNotEmpty) {
            final content = data['choices'][0]['message']?['content'];
            if (content is String && content.isNotEmpty) {
              return LLMResponse(
                content: content,
                tokensUsed: tokensUsed,
                success: true,
              );
            }
          }
          
          return LLMResponse(error: 'Unexpected response format', tokensUsed: tokensUsed);
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
  Future<String?> generate(List<Map<String, String>> messages) async {
    final result = await generateWithTokens(messages);
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
}
