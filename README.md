# AI Companion 🤖💬

一款基于 Flutter 构建的智能 AI 陪伴聊天应用，使用阿里云通义千问（Qwen）系列模型提供对话能力。

## ✨ 特性

- **智能对话** - 基于 Qwen 大语言模型的自然对话能力
- **情绪系统** - Valence/Arousal 二维情绪模型，实时衰减和交互影响
- **记忆管理** - 智能记忆筛选和上下文管理
- **主动关怀** - 定时问候、久未联系关心等主动消息功能
- **模型选择** - 支持 5 种 Qwen 模型，按需切换
- **主题切换** - 支持日间/夜间/跟随系统主题
- **气泡自定义** - 可自定义聊天气泡颜色

## 📱 支持平台

- Windows ✅
- Android ✅  
- iOS (需自行配置签名)

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
│   ├── engine/               # 核心引擎
│   │   ├── conversation_engine.dart  # 对话调度器
│   │   ├── emotion_engine.dart       # 情绪计算
│   │   └── memory_manager.dart       # 记忆管理
│   ├── model/                # 数据模型
│   │   └── chat_message.dart
│   ├── policy/               # 策略层
│   │   ├── generation_policy.dart    # LLM 参数控制
│   │   └── persona_policy.dart       # 人格约束
│   ├── prompt/               # Prompt 管理
│   ├── provider/             # 状态管理
│   │   ├── theme_provider.dart
│   │   └── bubble_color_provider.dart
│   ├── service/              # 服务层
│   │   ├── llm_service.dart          # LLM API 调用
│   │   ├── chat_history_service.dart
│   │   ├── persona_service.dart
│   │   └── memory_service.dart
│   └── util/                 # 工具类
│       ├── time_awareness.dart
│       ├── expression_selector.dart
│       └── response_formatter.dart
├── ui/                       # 界面组件
│   ├── main_screen.dart
│   ├── chat_bubble.dart
│   ├── app_drawer.dart
│   └── settings_screen.dart
└── assets/settings/          # YAML 配置文件
    ├── emotion_settings.yaml
    ├── proactive_settings.yaml
    └── ...
```

## ⚙️ 可用模型

| 模型 | API ID | 说明 |
|------|--------|------|
| Qwen Turbo | `qwen-turbo` | 速度快，免费额度充足 |
| Qwen Plus | `qwen-plus` | 平衡性能，有免费额度 |
| Qwen Max | `qwen-max` | 最强性能，少量免费额度 |
| Qwen3 8B | `qwen3-8b` | 开源模型，性能均衡 |
| QwQ 32B | `qwq-32b-preview` | 推理增强模型 |

在设置页面可随时切换模型。

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
