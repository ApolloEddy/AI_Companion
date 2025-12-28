# Changelog

All notable changes to this project will be documented in this file.

## [2.5.0] - 2025-12-28
### Added
- **心理触发器 (Psychological Triggers)**: AI 现在能检测社交信号并产生微情绪反应：
  - `third_party_mention`：用户提及其他 AI → 触发轻微吃醋 (`jealousy_mild`)
  - `high_praise`：用户高度赞扬 → 触发隐藏骄傲 (`pride_hidden`)
  - `neglect_signal`：用户敷衍回复 → 触发失落感 (`disappointed`)
- **社交雷达 (Social Radar)**: `PerceptionProcessor` 新增 `socialEvents` 字段，用于检测上述社交信号。
- **微情绪反应**: `ReflectionProcessor` 新增 `microEmotion` 字段，驱动 AI 的心理反应策略。
- **情绪覆盖机制 (Emotional Override)**: `ExpressionSelector` 支持 `microEmotion` 优先覆盖通用语气，确保 L3-L4 人格一致性。

### Changed
- **独立人格强化**: 反思 Prompt 植入"禁忌思维模式"和"自我校准"机制，防止 AI 过度讨好用户。
- **深层秘密标签软化**: `PersonaPolicy` 中的 `deepSecrets` 提示词从"只对亲密的人展示"改为"基于信任分享"。
- **去书面化约束**: `ExpressionSelector` 新增强制指令，禁止使用"然而"、"虽说"等书面连接词。

### Fixed
- **L3-L4 映射断裂**: 修复了 `microEmotion` 未传递给 `ExpressionSelector` 导致 AI "心口不一" 的问题。
- **CognitiveState 数据流**: 修复了 `microEmotion` 未导出到 UI 层 `CognitiveState` 的断点。

## [2.4.0] - 2025-12-28
### Added
- **深度人格系统 (Deep Persona)**: 支持配置 AI 的价值观、爱好、禁忌和背景故事，全方位影响回复倾向。
- **拟态视觉 (Neomorphism)**: 聊天气泡增加彩色层级阴影（用户侧）和高级毛玻璃质感（AI 侧）。
- **流光回信动画**: 标题栏新增波浪式流动的“正在输入”圆点指示器。
- **主题平滑过渡**: 引入 `AnimatedTheme`，实现深浅模式切换时的丝滑呼吸效果。
- **全局字体优化**: 默认适配 `Microsoft YaHei` 和 `PingFang SC`，大幅提升中文阅读体验。

### Changed
- **高对比度重塑**: 侧栏标题在亮色模式下升级为纯黑/深琥珀色，彻底解决浅色文字看不清的问题。
- **全链路琥珀色**: 将侧栏头像框、认知面板、图标等所有青色元素统一为 Amber 主题色。
- **Emoji 节制策略**: AI 现在仅在情绪极端或用户主动使用表情时才会发送 Emoji。
- **自然话题终结**: 上下文合成Prompt中加入指令，允许 AI 在对话干瘪时主动礼貌结束话题。

### Fixed
- **拼写错误**: 修正了 System Prompt 中长期存在的 "幽mer" -> "幽默" 拼写错误。
- **UI 结构修复**: 修复了侧栏亲密度进度条代码结构破损导致显示异常的问题。
### Added
- **温暖舒适主题 (Cozy Edition)**: 夜间模式从冷青色赛博朋克风格转为温暖琥珀色舒适风格。
- **用户画像防抖保存**: 设置页用户画像编辑器新增 2 秒防抖自动保存和显式保存按钮。
- **日间模式对比度增强**: 主文字使用 `#1A1A1A` 接近纯黑，符合无障碍标准。

### Changed
- **雷达图/折线图配色**: 从冷青色 (`#00BCD4`) 改为温暖琥珀色 (`#FFB74D`)。
- **版本标识更新**: 设置页版本信息改为 "Cozy Edition"。

### Fixed
- **[Critical] SparklinePainter 崩溃**: 恢复空数据检查，防止 `data.last` 引发 RangeError。
- **[Critical] API Key 更新依赖丢失**: 修复 `updateApiKey()` 重建引擎时未注入 FactStore 和 profileService 的问题。
- **[Critical] Timer 内存泄漏**: 更新 API Key 前调用 `stop()` 停止旧引擎定时器。
- **MemoryManager 迁移错误处理**: 为异步数据迁移添加 `catchError` 错误处理。

## [2.2.0] - 2025-12-27
### Added
- **UIAdapter 适配层**: 新增自适应布局适配器，自动协调手机/桌面端的字号、气泡比例与边距。
- **全界面中文化**: 完成了侧边栏 HUD、人格实验室、设置界面及交互菜单的深度中文翻译。
- **UI 布局修正**: 使用 `LayoutBuilder` 修复了亲密度进度条在不同宽度下无法填满的问题。

### Fixed
- **构建错误**: 修复了 `GlassInputBar` 中导致 Windows 端构建失败的路径引用错误。
- **命名一致性**: 将界面中的“羁绊等级”统一修正为“亲密度”，与核心逻辑保持一致。

## [2.1.0] - 2025-12-26
### Added
- **Research-Grade UI**: 全面升级设置界面，支持 Hero 动画与分组卡片布局。
- **身份锚点系统**: 新增 `UserProfile`，AI 现在可以记忆用户的职业、专业、性别及昵称。
- **亲密度衰减**: 引入时间感知逻辑，超过 24 小时未连接亲密度将自动回归。
- **背景融合算法**: `AmbientBackground` 现在根据亲密度（色调）与情绪（波动）实时混合渐变色。
- **人格雷达与趋势图**: 侧边栏新增人性格五维雷达图与情绪实时趋势折线图。

### Changed
- **模型库对齐**: 更新 Qwen 模型列表，支持 Max/Plus/Flash/Turbo，对齐阿里云官方 API 规范。
- **提示词组装优化**: 重构 `PromptAssembler`，实现纯净、无状态的结构化提示词生成。

### Fixed
- **空安全修复**: 解决了 `ConversationEngine` 中关于 `profileService` 的空引用隐患。
- **导入缺失**: 修复了 `AppEngine` 中 `UserProfile` 等类定义缺失导致的编译错误。

## [2.0.0] - 2024-12-23
### Added
- **核心认知引擎**: 从简单对话升级为由 `ConversationEngine` 驱动的闭环认知架构。
- **V-A 情绪模型**: 引入效价（Valence）与唤醒度（Arousal）二维情感计算。
- **生成策略类**: 新增 `GenerationPolicy`，实现情感对 LLM `temperature` 和 `max_tokens` 的物理约束。
- **RAG 记忆系统**: 支持基于上下文检索的长期记忆功能。

## [1.0.0] - 2024-12-16
### Added
- **项目初始化**: 基于 Flutter 的基础 AI 聊天应用。
- **基础 Qwen 接入**: 实现与阿里云 DashScope API 的初步通讯。
- **基础主题**: 实现深色/浅色模式基础布局。
