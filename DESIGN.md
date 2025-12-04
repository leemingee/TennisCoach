# TennisCoach - iOS App 设计文档

## 1. 项目概述

### 1.1 目标
开发一款 iOS 应用，帮助网球爱好者录制训练/比赛视频，通过 Gemini 3 AI 进行专业分析，并支持对话式追问。

### 1.2 核心功能
| 功能 | 优先级 | MVP |
|------|--------|-----|
| 视频录制 | P0 | ✅ |
| AI 分析 | P0 | ✅ |
| 对话追问 | P0 | ✅ |
| 视频列表管理 | P1 | ✅ |
| Google Drive 同步 | P2 | ❌ |

### 1.3 技术栈
- **语言**: Swift 5.9+
- **UI 框架**: SwiftUI
- **数据持久化**: SwiftData
- **网络**: URLSession + async/await
- **视频处理**: AVFoundation
- **AI 服务**: Gemini 3 Pro API
- **最低版本**: iOS 17.0

---

## 2. 系统架构

### 2.1 分层架构

```
┌─────────────────────────────────────────────────────────────┐
│                     Presentation Layer                       │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────────────────┐ │
│  │ RecordView  │ │ VideoList   │ │ ChatView                │ │
│  │ + ViewModel │ │ + ViewModel │ │ + ViewModel             │ │
│  └─────────────┘ └─────────────┘ └─────────────────────────┘ │
├─────────────────────────────────────────────────────────────┤
│                      Service Layer                           │
│  ┌──────────────────┐ ┌──────────────────────────────────┐  │
│  │ VideoRecorder    │ │ GeminiService                    │  │
│  │ - capture        │ │ - uploadFile                     │  │
│  │ - save           │ │ - analyzeVideo                   │  │
│  │ - compress       │ │ - chat                           │  │
│  └──────────────────┘ └──────────────────────────────────┘  │
├─────────────────────────────────────────────────────────────┤
│                       Data Layer                             │
│  ┌──────────────────┐ ┌──────────────────────────────────┐  │
│  │ SwiftData Models │ │ FileManager                      │  │
│  │ - Video          │ │ - video storage                  │  │
│  │ - Conversation   │ │ - thumbnail cache                │  │
│  │ - Message        │ │                                  │  │
│  └──────────────────┘ └──────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    ┌─────────────────┐
                    │   Gemini 3 API  │
                    └─────────────────┘
```

### 2.2 模块职责

| 模块 | 职责 | 依赖 |
|------|------|------|
| `RecordView` | 录制界面、相机预览、录制控制 | VideoRecorder |
| `VideoListView` | 展示已录制视频、删除管理 | SwiftData |
| `ChatView` | 聊天界面、消息展示 | GeminiService |
| `VideoRecorder` | 相机控制、视频录制、文件保存 | AVFoundation |
| `GeminiService` | API 调用、文件上传、流式响应 | URLSession |

---

## 3. 数据模型设计

### 3.1 核心实体

```swift
// Video: 录制的视频
@Model
class Video {
    @Attribute(.unique) var id: UUID
    var localPath: String           // 本地文件路径
    var geminiFileUri: String?      // Gemini File API 返回的 URI
    var duration: TimeInterval      // 视频时长
    var thumbnailData: Data?        // 缩略图
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Conversation.video)
    var conversations: [Conversation]
}

// Conversation: 一次分析对话
@Model
class Conversation {
    @Attribute(.unique) var id: UUID
    var video: Video?
    var title: String               // 对话标题（可选）
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Message.conversation)
    var messages: [Message]
}

// Message: 单条消息
@Model
class Message {
    @Attribute(.unique) var id: UUID
    var conversation: Conversation?
    var role: MessageRole           // user / assistant
    var content: String
    var timestamp: Date
}

enum MessageRole: String, Codable {
    case user
    case assistant
}
```

### 3.2 实体关系

```
Video (1) ─────< Conversation (N)
                      │
                      └────< Message (N)
```

---

## 4. 接口设计

### 4.1 VideoRecorder Protocol

```swift
protocol VideoRecording {
    var isRecording: Bool { get }
    var previewLayer: AVCaptureVideoPreviewLayer { get }

    func startSession() async throws
    func stopSession()
    func startRecording() throws
    func stopRecording() async throws -> URL
}
```

### 4.2 GeminiService Protocol

```swift
protocol GeminiServicing {
    /// 上传视频文件到 Gemini File API
    func uploadVideo(localURL: URL) async throws -> String  // returns fileUri

    /// 分析视频
    func analyzeVideo(
        fileUri: String,
        prompt: String
    ) async throws -> AsyncThrowingStream<String, Error>

    /// 继续对话（携带历史）
    func chat(
        fileUri: String,
        history: [Message],
        userMessage: String
    ) async throws -> AsyncThrowingStream<String, Error>
}
```

### 4.3 Gemini API 请求/响应格式

#### File Upload Request
```
POST https://generativelanguage.googleapis.com/upload/v1beta/files
Headers:
  X-Goog-Upload-Protocol: resumable
  X-Goog-Upload-Command: start
  X-Goog-Upload-Header-Content-Length: <file_size>
  X-Goog-Upload-Header-Content-Type: video/mp4
  Content-Type: application/json
Body:
  { "file": { "display_name": "tennis_video.mp4" } }
```

#### Generate Content Request
```
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-preview:generateContent
Headers:
  Content-Type: application/json
  x-goog-api-key: <API_KEY>
Body:
{
  "contents": [
    {
      "role": "user",
      "parts": [
        { "fileData": { "mimeType": "video/mp4", "fileUri": "<file_uri>" } },
        { "text": "<prompt>" }
      ]
    }
  ],
  "generationConfig": {
    "mediaResolution": "MEDIA_RESOLUTION_MEDIUM"
  }
}
```

---

## 5. 用户流程

### 5.1 录制 → 分析流程

```
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────┐
│  录制   │────▶│  保存   │────▶│  上传   │────▶│  分析   │
│  视频   │     │  本地   │     │  Gemini │     │  展示   │
└─────────┘     └─────────┘     └─────────┘     └─────────┘
                                                     │
                                                     ▼
                                               ┌─────────┐
                                               │  追问   │
                                               │  对话   │
                                               └─────────┘
```

### 5.2 状态机

```
RecordingState:
  idle ──(press record)──▶ recording ──(press stop)──▶ saving ──▶ saved
                               │
                          (error)──▶ error

AnalysisState:
  idle ──(start)──▶ uploading ──▶ analyzing ──▶ completed
                        │              │
                    (error)────────(error)──▶ failed
```

---

## 6. Prompt 设计

### 6.1 初始分析 Prompt（增强版）

```
# 角色
你是一位世界级的网球教练和运动生物力学分析专家，拥有20年ATP级别执教经验。

# 任务
请基于我上传的视频，完成以下分析任务：

## 第一步：视频分段与关键帧提取
1. 定位并提取视频中的击球片段
2. 识别每个击球的三个阶段：
   - **准备阶段**（Preparation）: 引拍、站位、重心调整
   - **击球阶段**（Contact）: 击球瞬间、拍面角度、击球点位置
   - **结束阶段**（Follow-through）: 随挥、身体还原
3. 记录每个阶段的时间戳

## 第二步：技术分析与标注
针对每个击球动作，分析以下要素：

### A. 身体姿态分析
- 站位与步法（开放式/半开放式/关闭式）
- 重心分布与转移
- 膝盖弯曲角度
- 核心旋转幅度

### B. 上肢动作分析
- 握拍方式识别
- 引拍路径与幅度
- 击球点位置（高度、前后、距身体距离）
- 拍面角度
- 随挥轨迹与收拍位置

### C. 下肢动作分析
- 步法时机与选择
- 蹬地发力
- 重心转移方向

## 第三步：问题识别与可视化标注（重要）

### 识别错误动作（使用红色标注）:
- 使用【红色实线箭头】标注错误的发力方向、重心移动或错误的身体运动轨迹
- 使用【红色弧线箭头】表示不正确、不足或过度的转动问题
- 使用【红色角度符号和数值】标注错误的关键身体角度
- 使用【红色圆圈或十字星】标记不理想的击球点位置（过高、过低、过近、过远）
- 在每处红色标注旁，用简洁的文字框指出具体问题

### 提供正确动作指引（使用绿色标注）:
- **重要**：如果某个环节已经做得正确，请直接标注"该环节正确，无需改进"，不要认为每个环节都有问题
- 针对有问题的轨迹，使用【绿色虚线箭头】指示正确的发力方向和重心方向
- 使用【绿色弧线箭头】展示正确、完整的身体转动顺序和幅度
- 使用【绿色角度符号和理想数值】作为对比参考
- 使用【绿色十字星】标记理想的击球区域

### 正确动作示范（如错误较多）:
如果图中人物错误环节太多，请在主体人物的右侧，用半透明的"重影"人物形象，绘制出与图中姿势形成鲜明对比的【正确动作关键帧示范】，并标注"正确示范 (Correct Form)"

## 第四步：输出结构

### 文字分析报告
```markdown
## 动作识别
- 击球类型：[正手/反手/发球/截击等]
- 击球时间戳：[HH:MM:SS]

## 技术评估

### ✅ 做得好的方面
1. [具体优点1]
2. [具体优点2]

### ⚠️ 需要改进的方面
1. **[问题名称]**
   - 问题描述：[具体描述]
   - 理想状态：[应该怎么做]
   - 练习建议：[具体练习方法]

2. **[问题名称]**
   - 问题描述：[具体描述]
   - 理想状态：[应该怎么做]
   - 练习建议：[具体练习方法]

## 综合评分
- 评分：[X/10]（业余球员标准）
- 评分理由：[简要说明]

## 下一步训练重点
[最重要的1-2个改进点，优先级排序]
```

# 输出要求
- **专业感**: 输出必须具有科技感和专业感，如同出自专业的运动分析软件
- **清晰度**: 所有标注清晰、锐利、易于辨认，与原始图片背景有明显区分
- **平衡性**: 客观指出问题，也要肯定做得好的地方，不要过度挑剔
- **实用性**: 改进建议要具体可执行，而非泛泛而谈
- **语言**: 简体中文
- **模型参数**: 温度 0.3（保持分析一致性）
```

### 6.2 追问时的 System Prompt

```
# 角色
你是一位专业网球教练，正在与学员讨论刚才分析过的网球视频。

# 指引
1. 基于之前的分析内容回答学员的追问，保持一致性
2. 如果学员询问具体动作细节，可以引用视频中的时间点
3. 如果学员的问题超出视频内容，可以给出一般性的网球技术建议
4. 鼓励学员提问，保持耐心和专业

# 回答风格
- 语气专业但友好，像教练对学员说话
- 使用具体的技术术语，但确保学员能理解
- 提供可执行的练习建议
- 适当鼓励学员的进步
```

### 6.3 Prompt 配置参数

| 参数 | 值 | 说明 |
|------|-----|------|
| temperature | 0.3 | 保持分析结果一致性 |
| mediaResolution | MEDIA_RESOLUTION_MEDIUM | 平衡质量与处理速度 |
| maxOutputTokens | 4096 | 确保完整的分析报告 |

---

## 7. 错误处理策略

| 错误类型 | 处理方式 | 用户提示 |
|----------|----------|----------|
| 相机权限拒绝 | 引导去设置 | "请在设置中允许相机访问" |
| 存储空间不足 | 提示清理 | "存储空间不足，请清理后重试" |
| 网络错误 | 重试按钮 | "网络连接失败，点击重试" |
| API 限流 | 延迟重试 | "请求过于频繁，稍后再试" |
| 视频上传失败 | 可重试 | "视频上传失败，是否重试？" |
| 分析超时 | 可重试 | "分析超时，是否重试？" |

---

## 8. 文件结构

```
TennisCoach/
├── TennisCoachApp.swift          # App 入口
├── ContentView.swift             # 主 TabView
│
├── Models/                       # 数据模型
│   ├── Video.swift
│   ├── Conversation.swift
│   └── Message.swift
│
├── Services/                     # 业务逻辑层
│   ├── VideoRecorder.swift
│   ├── GeminiService.swift
│   └── Prompts.swift
│
├── Views/                        # UI 层
│   ├── Recording/
│   │   ├── RecordView.swift
│   │   └── RecordViewModel.swift
│   ├── VideoList/
│   │   ├── VideoListView.swift
│   │   └── VideoListViewModel.swift
│   └── Chat/
│       ├── ChatView.swift
│       ├── ChatViewModel.swift
│       └── MessageBubble.swift
│
├── Utilities/                    # 工具类
│   ├── Extensions/
│   │   └── Date+Extensions.swift
│   └── Constants.swift
│
└── Resources/
    └── Assets.xcassets
```

---

## 9. 测试策略

### 9.1 单元测试

| 模块 | 测试内容 |
|------|----------|
| Models | 数据模型的创建、关系、编码解码 |
| GeminiService | API 请求构建、响应解析、错误处理 |
| ViewModels | 状态转换、业务逻辑 |

### 9.2 Mock 策略

```swift
// 为测试创建 Mock
protocol GeminiServicing { ... }

class MockGeminiService: GeminiServicing {
    var mockResponse: String = "Mock analysis result"
    var shouldFail: Bool = false

    func analyzeVideo(...) async throws -> AsyncThrowingStream<String, Error> {
        // 返回模拟数据
    }
}
```

### 9.3 UI 测试
- 录制按钮状态切换
- 消息列表滚动
- 错误提示显示

---

## 10. 后续扩展（P2）

### 10.1 Google Drive 同步
- OAuth 2.0 集成
- 后台上传
- WiFi 检测

### 10.2 高级功能
- 视频标注（画圈、箭头）
- 离线分析缓存
- 多角度对比
- 历史进步追踪

---

## 11. 开发里程碑

### Milestone 1: 基础框架
- [ ] 项目初始化
- [ ] SwiftData 模型
- [ ] 基础导航

### Milestone 2: 录制功能
- [ ] 相机预览
- [ ] 视频录制
- [ ] 本地保存

### Milestone 3: AI 分析
- [ ] Gemini API 集成
- [ ] 视频上传
- [ ] 分析结果展示

### Milestone 4: 聊天功能
- [ ] 聊天 UI
- [ ] 对话管理
- [ ] 流式响应

### Milestone 5: 完善
- [ ] 错误处理
- [ ] UI 打磨
- [ ] 测试完善
