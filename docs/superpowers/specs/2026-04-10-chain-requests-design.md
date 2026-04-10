# HTTP Client 链式调用设计文档

**日期**: 2026-04-10
**状态**: 已批准

## 概述

在 DevToolkit 的 HTTP API Client 中实现链式请求（Chain Requests）功能。用户可以将多个 Saved Request 编排为有序的链，一键执行。步骤之间通过 pm.environment 共享数据，支持在 post-script/rewrite 中提取数据供后续步骤的 {{variable}} 模板使用。

## 需求

- Chain 作为独立的顶层数据模型，持久化保存到 SwiftData
- 从 Saved Requests 中选择请求组成有序的步骤链
- 同一个 SavedRequest 可被多个 Chain 引用，也可在同一 Chain 中出现多次
- 执行时按顺序串行执行每个步骤，复用完整的请求生命周期（Build → Pre-script → 模板解析 → 发送 → Post-script → Rewrite）
- 步骤间通过 pm.environment 传递数据（post-script 中 `pm.environment.set()` → 下一步的 `{{var}}` 模板）
- 某步骤失败（网络错误或 assert 失败）时立即停止
- 执行结果以列表概览展示（状态码、耗时），点击展开查看详细 request/response

## 数据模型

### ChainModel（SwiftData）

```
- id: UUID
- name: String
- steps: [ChainStepModel]  (有序，cascade delete)
- createdAt: Date
- updatedAt: Date
```

### ChainStepModel（SwiftData）

```
- id: UUID
- order: Int              (执行顺序，从 0 开始)
- savedRequestId: UUID    (引用 SavedRequest 的 ID，非 relationship)
- chain: ChainModel       (反向引用)
```

使用 `savedRequestId: UUID` 而非 SwiftData relationship 引用 SavedRequest：
- SavedRequest 被删除时不影响 Chain 结构（执行时检测到缺失请求会报错并停止）
- 同一个 SavedRequest 可在多个 Chain 和同一 Chain 中多次出现

### ChainRunResult（内存模型，不持久化）

```
- stepResults: [StepResult]
- startedAt: Date
- finishedAt: Date?
- status: .idle | .running(currentStep: Int) | .completed | .failed(atStep: Int)
```

### StepResult

```
- stepOrder: Int
- requestName: String
- requestMethod: String
- requestURL: String
- responseStatus: Int?
- duration: TimeInterval?
- error: String?
- httpResponse: HTTPResponse?
- consoleLogs: String
```

## 执行流程

Chain 执行复用现有的请求生命周期，唯一的步骤间数据桥梁是 EnvironmentStore（pm.environment）。

```
Chain 执行开始
  → 清空 EnvironmentStore（确保干净的起点）
  → 遍历 steps（按 order 排序）：
  
    Step N:
      1. 通过 savedRequestId 查找 SavedRequest
         → 找不到 → 标记失败，停止链
      2. 从 SavedRequest 还原请求参数（method, url, headers, body, auth, scripts）
      3. 执行完整请求生命周期（通过 RequestExecutor）：
         Build → Pre-script → 模板解析 {{var}} → 发送 → Post-script → Rewrite
      4. 检查结果：
         → 网络错误 → 标记失败，停止链
         → Post-script assert 失败 → 标记失败，停止链
         → 成功 → 记录 StepResult，继续下一步
      
    pm.environment 中保留了本步骤设置的变量
    → 下一步的 pre-script 和 {{var}} 可以读到这些变量
    
Chain 执行结束
  → 记录 finishedAt 和最终状态
```

## 提取 RequestExecutor

从 APIClientView.sendRequest() 中提取核心执行逻辑为独立的 RequestExecutor：

```swift
struct RequestExecutor {
    static func execute(
        method: HTTPMethod,
        url: String,
        headers: [KeyValuePair],
        queryParams: [KeyValuePair],
        body: RequestBody?,
        auth: AuthType?,
        preScript: String?,
        postScript: String?,
        rewriteScript: String?
    ) async -> ExecutionResult
}

struct ExecutionResult {
    let response: HTTPResponse?
    let error: String?
    let consoleLogs: String
    let assertionFailed: Bool
}
```

APIClientView.sendRequest() 和 ChainRunnerService 都调用此方法，避免重复逻辑。

## UI 设计

### 入口

在 API Client 工具栏（现有的 Save/Saved/History 按钮旁边）增加 "Chains" 按钮，打开 Chain 管理侧边栏。

### ChainListView（侧边栏）

- Chain 列表：名称 + 步骤数
- "New Chain" 按钮创建新链
- 点击 Chain → 打开 ChainEditorView
- 右键菜单删除 Chain

### ChainEditorView（主内容区）

```
┌─────────────────────────────────────────────┐
│  Chain: "用户登录流程"           [▶ Run]    │
├─────────────────────────────────────────────┤
│  Steps:                                     │
│  ┌─ 1. POST /api/login      [✕] [↑] [↓]  │
│  ├─ 2. GET  /api/profile     [✕] [↑] [↓]  │
│  └─ 3. PUT  /api/settings    [✕] [↑] [↓]  │
│                                             │
│  [+ Add Step]  (从 Saved Requests 中选择)   │
├─────────────────────────────────────────────┤
│  执行结果（Run 之后显示）:                   │
│  ┌─ ✅ 1. POST /api/login     200  120ms  │
│  ├─ ✅ 2. GET  /api/profile   200   85ms  │
│  └─ ❌ 3. PUT  /api/settings  403   92ms  │
│        Error: assert failed: "should be 200"│
│                                             │
│  点击某一步 → 展开 request/response 详情    │
└─────────────────────────────────────────────┘
```

### 交互

- **Add Step**：弹出 Saved Requests 选择列表（支持搜索），选中后追加到末尾
- **排序**：上下箭头调整步骤顺序（同时更新 order 值）
- **删除**：✕ 按钮移除步骤（不删除 SavedRequest 本身）
- **Run**：执行链，执行中显示进度（当前第几步），完成后显示结果列表
- **展开详情**：点击结果行展开显示 request headers/body + response headers/body + console logs

## 文件结构

### 新增文件

在 `Packages/APIClient/Sources/APIClient/` 下：

```
Models/
  ChainModel.swift          — ChainModel + ChainStepModel (SwiftData)
  ChainRunResult.swift      — ChainRunResult + StepResult (内存模型)

Networking/
  RequestExecutor.swift     — 从 sendRequest() 提取的独立执行逻辑

Chain/
  ChainListView.swift       — Chain 管理侧边栏
  ChainEditorView.swift     — 步骤编排 + 结果展示
  ChainRunnerService.swift  — 链式执行引擎
```

### 修改文件

| 文件 | 改动 |
|------|------|
| `APIClientView.swift` | 工具栏加 "Chains" 按钮；sendRequest() 改为调用 RequestExecutor |
| `APIClientExports.swift` | 导出 ChainModel、ChainStepModel 供主 app 使用 |
| `MacDevAppApp.swift` | modelContainer 添加 ChainModel、ChainStepModel |
