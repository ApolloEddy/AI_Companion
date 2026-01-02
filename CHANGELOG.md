# Changelog

All notable changes to this project will be documented in this file.

## [2.8.0] - 2026-01-02 (Cognitive Architecture Refactoring)

### Added

- **Personality Genesis Radar**: 新增“人格塑形雷达”组件，在创建 AI 时可通过拖拽 5 个顶点直观塑造 Big Five 人格特质 (Openness, Conscientiousness, Extraversion, Agreeableness, Neuroticism)。
- **Dual-Mode Visualization**: 雷达图支持“塑形模式”(Sculpting) 和“监测模式”(Monitoring)，分别用于初始设定和日常对话中的人格漂移观测。
- **Factory Reset**: 新增"重置人格与记忆"功能（危险区），支持一键清空所有记忆、聊天记录并重置 Big Five 参数（解锁 Genesis 二次编辑）。
- **Persona Unification**: 统一了人格配置源，移除了代码中的硬编码默认值，现在 `default_persona.yaml` 是唯一的出厂设定源。默认 AI 名称变更为 **April**。

### Changed

- **由四变三**: 认知架构重构为 **L1 感知 (Perception) -> L2 决策 (Decision) -> L3 表达 (Expression)** 三层模型。
  - 移除了独立的 L2 情绪层 (Emoji/Valence)，将其融合进 L1 与 L2 决策流。
  - 将原 L3 意图层升级为 L2 决策核心 (Decision Core)。
  - 将原 L4 表达层重命名为 L3 表达核心 (Expression Core)。
- **Prompt 标准化**: `prompt_templates.yaml` 中的所有 Prompt (包括 L1) 统一对齐为 L2/L3 的 Markdown 格式 (Headers, Lists, Alerts)。
- **去硬编码**: 移除了 `PromptBuilder` 中残留的硬编码 `buildSynthesisPrompt` 及字符串拼接逻辑，完全实现 YAML 配置驱动。

### Documentation

- **Psychological Models Overhaul**: `README` 全面重写，新增了详细的 H-E-I 动力学反馈环、V-A-R 情绪空间、亲密度增长函数、认知懒惰 (Cognitive Laziness) 模型公式以及社会雷达 (Social Radar) 机制说明，并辅以 Mermaid 流程图。

### Fixed

- **Meltdown 失效修复**: 将 `{meltdownOverride}` 从 Prompt 头部移动到 `{pacingInstruction}` 之后 (Prompt 尾部)，利用 LLM Recency Bias 确保 Meltdown 状态不会被后续 L2 指令覆盖。
- **Critical Safety Mode**: 新增紧急安全模式，当检测到自杀/自残关键词时，完全跳过 L2/L3 流程，返回固定危机干预响应（包含心理援助热线），避免人格修饰符污染严肃场景。
- **Anti-Simp Guardrail**: 新增反舔狗行为约束，防止 AI 在用户连续冷回复时无限追问。
- **UI 美化与规范化**:
  - **性别选择器**: 将 AI 人格编辑器与用户资料中的性别输入框改为下拉选择 (`男性`/`女性`/`其他`)，并统一标签为"性别"。
  - **交互反馈升级**: 全局替换旧版 SnackBar 为带有呼吸动画的 `SuccessDialog` 成功确认弹窗 (Persona 保存/复制气泡/资料更新)。
  - **文档更新**: 补充 `README` 与 `CHANGELOG`，确保文档与代码实现一致。

## [2.7.0] - 2025-12-30 (Psychological Dynamics Update)

### Added

- **4-Layer Cognitive Architecture**: 虽然底层架构早已成型，但本次更新正式完成了 L1(感知)-L2(情绪)-L3(意图)-L4(表达) 的全链路闭环，实现了真正的“心理动力学”驱动。
- **敌意检测系统 (Hostility Detection)**:
  - L1 感知层新增 `offensiveness` (0-10) 评分。
  - 实现了基于等级的响应：3-5级 (试探) -> 宽容/不悦；6-8级 (攻击) -> 怨恨；9-10级 (毁灭) -> 心理创伤。
- **心理创伤机制 (Psychological Trauma)**:
  - 高唤醒度 + 极低效价 + 高怨恨的组合状态。
  - 触发后 AI 进入“冷淡防御模式”，切断正向情绪供给，必须通过时间或真诚道歉才能恢复。
- **能够道歉 (Apology Valve)**: AI 现在能识别用户的 `apology` 意图，并触发“道歉阀门”，瞬间释放部分怨恨值，模拟人际关系中的“心软”。
- **亲密度负反馈 (Intimacy Feedback)**:
  - 实现了“关系定损”：攻击行为将根据严重程度即时扣除亲密度数值 (Immediate Deduction)。
  - 引入“信任冷却期”：负面事件后，亲密度增长系数 (Growth Coefficient) 会在数小时内被抑制。
- **性别独立配置 (Gender Config)**: 人格编辑器新增独立“性别”字段，并支持在 Prompt 中通过 `{personaGender}` 变量动态注入，强化角色认知。

### Changed

- **Pacing Protocol (节奏控制)**: 彻底重构了回复长度控制逻辑，引入 `single_shot` (默认)、`burst` (激动) 和 `hesitant` (迟疑) 三种模式，杜绝了机械式的分段回复。
- **Depth Filter (深度过滤)**: 为防止 cringe (尴尬) 行为，AI 现在会对“吃饭/睡觉”等琐事应用钝感滤镜，拒绝过度升华；只对情感话题开启深度共情。
- **Prompt 模板变量化**: `prompt_templates.yaml` 全面接入动态变量系统，解耦了代码与提示词逻辑。

### Fixed

- **编译错误修复**: 修复了 `EmotionEngine` 中因代码块错位导致的严重编译失败。
- **新用户体验优化**: 为 intimacy < 0.3 的新用户添加了“容忍保护期”，避免 AI 在初期因误判玩笑而反应过激。

## [2.6.0] - 2025-12-29 (Prompt Architecture 2.0)

### Added

- **Prompt Architecture 2.0**: 全面重构 Prompt 构建逻辑，实现配置驱动与拟人化增强：
  - **配置化模板**: `prompt_templates.yaml` 集中管理语气模式、回复格式和禁忌语。
  - **Few-Shot 接口**: `PromptAssembler` 预留 `{few_shots}` 插槽，为未来高质量示例注入做准备。
  - **尾部注入 (Tail Injection)**: 策略和内心独白从 System Prompt 移至 User Message 末尾，利用 Recency Bias 强化执行。
  - **自然语言情绪**: `EmotionEngine.getEmotionDescription()` 将 Valence/Arousal 转译为"你现在感到愉悦"等描述。
  - **时间感知语气**: `ExpressionSelector` 根据当前时段（深夜/清晨）自动调节语气。
- **AI 身份编辑器**: 设置页新增"AI 身份设定 (IDENTITY)"卡片，允许用户自定义 AI 名字、性别和年龄。
- **Big Five 雷达图**: 侧栏新增五因素人格可视化雷达图（只读），替代原设置页滑块调节。
- **成功弹窗反馈**: 所有 SnackBar 反馈升级为带对钩动画的 Success Popup，提升交互质感。

### Changed

- **设置页 Big Five 移除**: 不再允许用户直接调节人格参数；Big Five 仅作为可视化展示在侧栏。
- **手动保存模式**: 用户画像不再自动保存，改为退出设置页时或点击保存按钮时触发。
- **L1 Prompt 瘦身**: `PersonaPolicy.toSystemPrompt` 移除冗余"表达风格"段落，精简 Big Five 和亲密度描述，节省约 30% Token。
- **L5 格式泛化**: `ResponseFormatter.getSplitInstruction` 从 YAML 配置读取，移除硬编码示例。

### Fixed

- **AI 性别无法定义**: 修复了设置页缺少 AI CoreIdentity 编辑入口的问题 (`updateAiCoreIdentity` in AppEngine)。
- **重复方法定义**: 修复 `SettingsScreen` 中 `_onProfileFieldChanged` 重复定义导致的编译错误。
- **Deprecated API**: 将 `withOpacity` 替换为 `withValues(alpha: ...)` 以消除 Flutter SDK 弃用警告。

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
