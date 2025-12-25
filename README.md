# AI Companion 🤖💬

一款基于 Flutter 构建的智能 AI 陪伴聊天应用，使用阿里云通义千问（Qwen）系列模型提供对话能力。

## ✨ 特性

### 核心功能
- **智能对话** - 基于 Qwen 大语言模型的自然对话能力
- **情绪系统** - Valence/Arousal 二维情绪模型，实时衰减和交互影响
- **策略驱动生成** - 情绪状态动态调整 LLM 参数（极端负面→极短回复，高兴奋→随机表达）
- **记忆管理** - 智能记忆筛选和上下文管理
- **主动关怀** - 定时问候、久未联系关心等主动消息功能
- **启动问候** - 应用打开时自动判断并发送问候（早安/晚安/久未联系/随机想起）
- **AI 时间感知** - 自动注入当前精确时间到对话上下文

### 认知引擎（新增）
- **用户画像学习** - 从对话中自动提取用户身份、背景和偏好
- **禁止模式检查** - 硬编码规则杜绝重复提问、说教等恼人回复
- **异步反思引擎** - 对话静默后后台分析，持续学习用户信息
- **反馈信号分析** - 从用户行为推断隐含满意度

### 聊天体验
- **消息时间戳** - 每条消息显示发送时间
- **输入状态提示** - AI 回复时标题栏显示"正在输入..."
- **多气泡回复** - 自然分条发送，带随机间隔延迟
- **长按复制** - 长按消息气泡快速复制内容

### 个性化
- **模型选择** - 支持 5 种 Qwen 模型，按需切换
- **主题切换** - 支持日间/夜间/跟随系统主题
- **气泡自定义** - 可自定义聊天气泡颜色
- **人格配置** - 自定义 AI 名字、性格、爱好

### 数据管理
- **聊天记录导出** - 支持 JSON/TXT/CSV 三种格式
- **本地存储** - 聊天记录自动本地保存

## 📱 支持平台

| 平台 | 状态 | 字体 |
|------|------|------|
| Windows | ✅ | 微软雅黑 |
| Android | ✅ | 系统默认 |
| iOS | ⚠️ 需配置签名 | 系统默认 |

## 🚀 快速开始

### 1. 环境准备

```bash
# 确保已安装 Flutter SDK
flutter doctor

# 克隆项目
git clone <repo-url>
cd AI_Companion
```

### 2. 配置 API Key

创建 `lib/core/secrets.dart` 文件：

```dart
class Secrets {
  static const String dashScopeApiKey = 'sk-your-api-key-here';
}
```

或在应用设置页面中输入 API Key。

### 3. 运行应用

```bash
# Windows
flutter run -d windows

# Android
flutter run -d android
```

## 📁 项目结构

```
lib/
├── main.dart                 # 应用入口
├── core/                     # 核心业务逻辑
│   ├── app_engine.dart       # UI 适配层
│   ├── config.dart           # 应用配置（含模型列表）
│   ├── settings_loader.dart  # YAML 配置加载
│   │
│   ├── engine/               # 核心引擎
│   │   ├── conversation_engine.dart  # 对话调度器
│   │   ├── emotion_engine.dart       # 情绪计算
│   │   ├── memory_manager.dart       # 记忆管理
│   │   ├── perception_processor.dart # 【新】深度感知处理器
│   │   ├── reflection_processor.dart # 【新】内心反思处理器
│   │   ├── feedback_analyzer.dart    # 【新】反馈信号分析
│   │   ├── memory_retriever.dart     # 【新】分层记忆检索
│   │   └── async_reflection_engine.dart # 【新】异步反思引擎
│   │
│   ├── model/                # 数据模型
│   │   ├── chat_message.dart
│   │   └── user_profile.dart # 【新】用户画像模型
│   │
│   ├── policy/               # 策略层
│   │   ├── generation_policy.dart    # LLM 参数控制
│   │   ├── persona_policy.dart       # 人格约束
│   │   └── prohibited_patterns.dart  # 【新】禁止模式规则
│   │
│   ├── prompt/               # Prompt 管理
│   │   ├── prompt_assembler.dart     # Prompt 组装
│   │   ├── prompt_snapshot.dart      # 调试快照
│   │   └── stage_prompts.dart        # 【新】阶段 Prompt 模板
│   │
│   ├── service/              # 服务层
│   │   ├── llm_service.dart          # LLM API 调用
│   │   ├── profile_service.dart      # 【新】用户画像服务
│   │   ├── chat_history_service.dart
│   │   └── chat_export_service.dart
│   │
│   ├── provider/             # 状态管理
│   └── util/                 # 工具类
│
├── ui/                       # 界面组件
│   ├── main_screen.dart
│   ├── chat_bubble.dart
│   └── settings_screen.dart
│
└── assets/settings/          # YAML 配置文件
```

## ⚙️ 可用模型

| 模型 | API ID | 说明 |
|------|--------|------|
| Qwen Turbo | `qwen-turbo` | 速度快，免费额度充足 |
| Qwen Plus | `qwen-plus` | 平衡性能，有免费额度 |
| Qwen Max | `qwen-max` | 最强性能，少量免费额度 |
| Qwen3 8B | `qwen3-8b` | 开源模型，性能均衡 |
| Qwen3 Max | `qwen3-max` | Qwen3 最强性能 |
| Qwen3 Flash | `qwen3-flash` | Qwen3 极速响应 |
| QwQ 32B | `qwq-32b-preview` | 推理增强模型 |

在设置页面可随时切换模型。

## 🧠 策略驱动架构

本项目采用 **Policy-Driven** 架构，情绪状态直接影响 LLM 生成参数：

| 情绪状态 | 参数调整 | 效果 |
|---------|---------|------|
| 极端负面 (valence < -0.6) | maxTokens=20 | 强制极短回复 "哦。" |
| 负面 (valence < -0.3) | maxTokens×0.5 | 较短回复 |
| 极高兴奋 (arousal > 0.8) | temperature=1.1 | 随机/混乱表达 |
| 低亲密度 | maxTokens×0.7 | 更简短 |

## 🛠️ 开发说明

### 构建 Release

```bash
# Windows
flutter build windows --release

# Android APK
flutter build apk --release
```

### 配置文件

所有行为参数均可通过 `assets/settings/` 下的 YAML 文件调整：

- `emotion_settings.yaml` - 情绪衰减和变化参数
- `proactive_settings.yaml` - 主动消息触发条件
- `response_settings.yaml` - 回复格式和延迟

## 📄 License

MIT License

