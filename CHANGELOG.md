# Changelog

All notable changes to this project will be documented in this file.

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
