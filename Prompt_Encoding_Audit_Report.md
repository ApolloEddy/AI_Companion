# Prompt 硬编码 vs 软编码分析报告

## 编码策略分类

### 📌 硬编码 (Hardcoded) - 内嵌于 Dart 代码中

| 位置 | 内容 | 失效风险 |
|:---|:---|:---|
| `PromptAssembler._systemTemplate` | System Prompt 骨架模板 (L14-29) | 🟢 低 (结构稳定) |
| `PerceptionProcessor._buildPerceptionPrompt` | 整个感知 Prompt（200行中文指令） | 🔴 高 |
| `ReflectionProcessor._buildReflectionPrompt` | 整个反思 Prompt（"禁忌思维"等） | 🔴 高 |
| `ExpressionSelector.lengthGuide` | 长度描述 `short/medium/detailed` (L61-65) | 🟡 中 |
| `ExpressionSelector._microEmotionGuides` | 微情绪模板 (L28-40) | 🟡 中 |
| 情绪标签 (`开心/难过/焦虑/平静/烦躁/疲惫`) | `PerceptionProcessor` L224 | 🟠 高 |
| 深层需求类别 (`倾诉宣泄/寻求建议/...`) | `PerceptionProcessor` L229-234 | 🟠 高 |
| 对话意图类别 (`开启新话题/延续上文/结束对话`) | `PerceptionProcessor` L240-244 | 🟠 高 |

### 📌 软编码 (Softcoded) - 通过 YAML 配置

| 位置 | 内容 | 失效风险 |
|:---|:---|:---|
| `SettingsLoader` | `formality`, `humor`, `shortThreshold` 等阈值 | 🟢 低 |
| `expression_settings.yaml` | 表达模式配置 (`warm`, `playful`, `supportive`) | 🟢 低 |
| `persona_settings.yaml` | 人格参数（深层秘密、价值观） | 🟢 低 |
| `fact_schema.yaml` | 事实类型定义 | 🟢 低 |
| `BehaviorMatrix` | 情绪-行为映射 | 🟢 低 |

---

## 场景压力测试：失效预测

### 1. 数据规模 ×10
**最先失效**: `PerceptionProcessor` 中硬编码的**情绪标签列表** (L224)
- **原因**: 7种情绪无法覆盖大规模用户群体的多样性。如"无聊"、"期待"、"嫉妒"等未被定义。
- **后果**: LLM 被迫用"平静"这个兜底选项，情绪感知准确率下降。

### 2. 参数组合翻倍
**最先失效**: `ExpressionSelector._microEmotionGuides` (L28-40)
- **原因**: 当前仅定义 3 种微情绪 (`jealousy_mild`, `pride_hidden`, `disappointed`)。若心理触发器扩展（如"愧疚"、"羡慕"），需手动添加新 Map Entry。
- **后果**: 新微情绪无法被 L4 层正确响应，回退到通用表达，产生 L3-L4 映射断裂。

### 3. 用户行为反常分布
**最先失效**: `ReflectionProcessor` 中的**禁忌思维模式** (L365-369)
- **原因**: 硬编码的"替换规则"仅覆盖 4 种 Anti-Pattern。如果用户行为出现"恶意攻击"或"持续否定"，AI 缺乏应对策略。
- **后果**: AI 可能在高压场景下仍然表现出卑微/讨好，或完全失控。

### 4. 用户设定变化
**风险**: 🟢 低
- `persona_settings.yaml` 已是软编码，用户侧大部分设定可热更新。
- **唯一隐患**: `SettingsLoader` 使用单例 `_isLoaded` 锁，需要重启 App 才能生效。

### 5. AI 设定变化
**最先失效**: `ReflectionProcessor._buildReflectionPrompt` 中的**整段 System Persona** (L360-362)
```dart
你是一个有独立人格和清醒自我认知的女孩子...
```
- **原因**: 这段核心人设完全写死在 Dart 代码中，无法通过配置切换。
- **后果**: 若用户希望 AI 扮演"专业助手"或"温柔大哥哥"，必须修改源码并重新编译。

---

## 结论：优先重构清单

| 优先级 | 组件 | 重构方案 |
|:---|:---|:---|
| **P0** | `ReflectionProcessor` System Persona | 迁移到 `reflection_settings.yaml` |
| **P1** | Perception 情绪/需求/意图标签 | 定义为 `perception_settings.yaml` 枚举 |
| **P2** | `_microEmotionGuides` 模板 | 迁移到 `expression_settings.yaml` |
| **P3** | 禁忌思维模式 (Anti-Patterns) | 迁移到 `prohibited_patterns.yaml` |
