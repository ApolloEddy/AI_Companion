import 'package:flutter/services.dart';
import 'package:yaml/yaml.dart';

/// Prompt 模板配置
/// 对应 assets/settings/prompt_templates.yaml
class PromptConfig {
  final Map<String, ExpressionModeConfig> expressionModes;
  final Map<String, String> timeModifiers;
  final Map<String, String> lengthGuides;
  final String globalCaveats;
  final ResponseFormatConfig responseFormat;
  final Map<String, String> systemPrompts;
  final Map<String, PersonaModeConfig> personaModes; // 【人格真实性修正新增】

  PromptConfig({
    required this.expressionModes,
    required this.timeModifiers,
    required this.lengthGuides,
    required this.globalCaveats,
    required this.responseFormat,
    required this.systemPrompts,
    required this.personaModes, // 【人格真实性修正新增】
  });

  /// 加载配置
  static Future<PromptConfig> load() async {
    try {
      final yamlString = await rootBundle.loadString('assets/settings/prompt_templates.yaml');
      final doc = loadYaml(yamlString);
      
      final expGuides = doc['expression_guides'];
      final respFormats = doc['response_formats'];
      final sysPrompts = doc['system_prompts'];
      final personaModesDef = doc['persona_modes']; // 【人格真实性修正新增】

      // 解析 Expression Modes
      final modes = <String, ExpressionModeConfig>{};
      final modesMap = expGuides['modes'] as Map;
      modesMap.forEach((k, v) {
        modes[k.toString()] = ExpressionModeConfig.fromMap(v);
      });

      // 解析 Time Modifiers
      final timeMods = <String, String>{};
      (expGuides['time_modifiers'] as Map).forEach((k, v) {
        timeMods[k.toString()] = v['tone_suffix']?.toString() ?? '';
      });
      
      // 解析 Length Guides
      final lens = <String, String>{};
      (expGuides['length_guides'] as Map).forEach((k, v) {
        lens[k.toString()] = v.toString();
      });

      // 解析 System Prompts
      final prompts = <String, String>{};
      if (sysPrompts != null && sysPrompts is Map) {
        sysPrompts.forEach((k, v) {
          prompts[k.toString()] = v.toString();
        });
      }

      // 解析 Persona Modes 【人格真实性修正新增】
      final pModes = <String, PersonaModeConfig>{};
      if (personaModesDef != null && personaModesDef is Map) {
        personaModesDef.forEach((k, v) {
          pModes[k.toString()] = PersonaModeConfig.fromMap(v);
        });
      }

      return PromptConfig(
        expressionModes: modes,
        timeModifiers: timeMods,
        lengthGuides: lens,
        globalCaveats: expGuides['global_caveats']?.toString() ?? '',
        responseFormat: ResponseFormatConfig.fromMap(respFormats['chat']),
        systemPrompts: prompts,
        personaModes: pModes, // 【人格真实性修正新增】
      );
    } catch (e) {
      print('Failed to load prompt templates: $e');
      // 返回空壳兜底，避免崩溃
      return PromptConfig(
        expressionModes: {},
        timeModifiers: {},
        lengthGuides: {},
        globalCaveats: '',
        responseFormat: ResponseFormatConfig(instruction: '', example: ''),
        systemPrompts: {},
        personaModes: {}, // 【人格真实性修正新增】
      );
    }
  }
}

class ExpressionModeConfig {
  final String description;
  final String tone;

  ExpressionModeConfig({required this.description, required this.tone});

  factory ExpressionModeConfig.fromMap(dynamic map) {
    if (map is! Map) return ExpressionModeConfig(description: '', tone: '');
    return ExpressionModeConfig(
      description: map['description']?.toString() ?? '',
      tone: map['tone']?.toString() ?? '',
    );
  }
}

class ResponseFormatConfig {
  final String instruction;
  final String example;

  ResponseFormatConfig({required this.instruction, required this.example});

  factory ResponseFormatConfig.fromMap(dynamic map) {
    if (map is! Map) return ResponseFormatConfig(instruction: '', example: '');
    return ResponseFormatConfig(
      instruction: map['instruction']?.toString() ?? '',
      example: map['example']?.toString() ?? '',
    );
  }
}

/// 【人格真实性修正新增】Persona 模式配置
/// 
/// 根据 laziness 和 tolerance 动态选择不同的人格表达模式
class PersonaModeConfig {
  final String instruction;
  final String description;

  PersonaModeConfig({required this.instruction, required this.description});

  factory PersonaModeConfig.fromMap(dynamic map) {
    if (map is! Map) return PersonaModeConfig(instruction: '', description: '');
    return PersonaModeConfig(
      instruction: map['instruction']?.toString() ?? '',
      description: map['description']?.toString() ?? '',
    );
  }
}

