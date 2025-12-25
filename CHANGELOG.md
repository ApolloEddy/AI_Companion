# AI Companion 更新日志

## [v2.0.0] - 2025-12-25 🎄

### 🚀 新增：认知引擎系统

#### 用户画像学习
- 新增 `UserProfile` 数据模型，支持空白初始化
- 新增 `ProfileService` 持久化服务，支持增量更新
- 用户身份、职业、背景从对话中自动提取，而非预设

#### 多阶段处理器
- 新增 `PerceptionProcessor` - 深度感知处理器（阶段一）
  - 分析用户表面情绪、潜台词、意图
  - 支持规则基础的快速分析
- 新增 `ReflectionProcessor` - 内心反思处理器（阶段三）
  - 回复前内部思考，动态调整对话风格
  - 生成回复策略指导

#### 禁止模式检测
- 新增 `ProhibitedPatterns` 硬编码规则系统
  - 检测重复提问、说教、过度关心等恼人模式
  - 自动清理违规内容

#### 异步反思引擎
- 新增 `AsyncReflectionEngine` 后台学习系统
  - 对话静默 3 分钟后自动触发
  - 从对话中提取用户信息并更新画像
  - 记录里程碑事件

#### 反馈分析器
- 新增 `FeedbackAnalyzer` 用户行为分析
  - 从消息长度、响应延迟推断满意度
  - 识别不满信号，学习对话偏好

#### 分层记忆检索
- 新增 `LayeredMemoryRetriever` 四层记忆架构
  - L1: 工作记忆（当前对话）
  - L2: 情景记忆（近期事件）
  - L3: 语义记忆（用户画像）
  - L4: 程序记忆（对话规则）

### 🐛 修复

#### Android 后台通知失效
- **问题**: Flutter Timer 在 Android 后台被系统暂停，导致主动消息失效
- **解决**: 使用 Android WorkManager 实现真正的后台任务调度
- 新增 `BackgroundService` 和 `LocalNotificationService`
- 添加 `workmanager`、`flutter_local_notifications`、`timezone` 依赖
- 更新 AndroidManifest.xml 添加通知权限

#### ConversationEngine 集成
- 集成禁止模式检查，自动清理违规输出
- 集成异步反思引擎，每次对话后自动记录
- 集成反馈分析器，追踪用户行为信号

#### LLM 服务扩展
- 新增 `completeWithSystem()` 方法，支持指定模型和参数
- 新增 `streamComplete()` 预留接口

#### 模型支持
- 新增 Qwen3 Max (`qwen3-max`) - Qwen3 最强性能
- 新增 Qwen3 Flash (`qwen3-flash`) - Qwen3 极速响应

### 📁 新增文件

| 文件 | 路径 |
|------|------|
| 用户画像模型 | `lib/core/model/user_profile.dart` |
| 画像服务 | `lib/core/service/profile_service.dart` |
| 深度感知处理器 | `lib/core/engine/perception_processor.dart` |
| 内心反思处理器 | `lib/core/engine/reflection_processor.dart` |
| 禁止模式规则 | `lib/core/policy/prohibited_patterns.dart` |
| 反馈分析器 | `lib/core/engine/feedback_analyzer.dart` |
| 分层记忆检索 | `lib/core/engine/memory_retriever.dart` |
| 异步反思引擎 | `lib/core/engine/async_reflection_engine.dart` |
| 阶段 Prompt 模板 | `lib/core/prompt/stage_prompts.dart` |

### 🔧 修改文件

| 文件 | 变更 |
|------|------|
| `conversation_engine.dart` | 集成认知组件 |
| `app_engine.dart` | 初始化 ProfileService |
| `llm_service.dart` | 添加新 API 方法 |
| `config.dart` | 添加新模型 |

---

## [v1.x] - 之前版本

- 基础对话功能
- Valence/Arousal 情绪系统
- 策略驱动生成参数
- 主动消息系统
- 记忆管理
