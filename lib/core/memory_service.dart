import 'package:shared_preferences/shared_preferences.dart';
import 'config.dart';

class MemoryService {
  final SharedPreferences prefs;
  
  MemoryService(this.prefs);

  List<String> getMemories() {
    return prefs.getStringList(AppConfig.memoryKey) ?? [];
  }

  Future<void> addMemory(String content) async {
    final list = getMemories();
    // 简单的关键词提取或直接存储重要对话
    // 这里为了演示直接存储
    if (list.contains(content)) return;
    
    list.add(content);
    
    // 限制 100 条
    if (list.length > 100) {
      list.removeRange(0, list.length - 100);
    }
    
    await prefs.setStringList(AppConfig.memoryKey, list);
  }
  
  String getRelevantContext(String query) {
    // 简单的上下文拼接 (最近 10 条)
    final all = getMemories();
    if (all.isEmpty) return "（暂无记忆）";
    
    final recent = all.length > 10 ? all.sublist(all.length - 10) : all;
    return recent.join('\n');
  }
}
