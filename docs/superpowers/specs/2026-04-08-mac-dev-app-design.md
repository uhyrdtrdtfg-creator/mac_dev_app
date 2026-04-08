# Mac Dev App — 设计规格文档

> 一款原生 macOS 开发者工具集应用，集成加解密、HTTP 接口调试和常用转换工具。

---

## 1. 产品概述

### 1.1 定位

面向中国及全球开发者的一站式 macOS 原生开发者工具集，将"综合工具集"与"接口调试"深度融合在同一个原生 App 中。

### 1.2 核心决策

| 项目 | 决策 |
|------|------|
| 范围 | 完整 P0（11 项功能） |
| 最低系统 | macOS 26（Tahoe），采用 Liquid Glass 设计语言 |
| 分发方式 | 先直接分发（官网/Homebrew），后续上架 Mac App Store |
| 界面语言 | 中英双语，跟随系统语言自动切换 |
| 持久化 | SwiftData |
| 架构 | 统一 App + 模块化 Swift Package |

---

## 2. P0 功能清单

1. AES 加密/解密（ECB/CBC/GCM，128/192/256 bit）
2. RSA 密钥对生成 + 加密/解密
3. Hash 生成器（MD5/SHA-1/SHA-256/SHA-512）
4. HMAC 生成器
5. HTTP 接口调试（GET/POST/PUT/DELETE + Headers + JSON Body + 响应展示）
6. Unix 时间戳转换（双向 + 时区 + 实时显示）
7. URL Encode/Decode
8. Base64 编码/解码（文本 + 图片）
9. JSON 格式化/校验
10. 侧边栏导航 + 全局搜索
11. 深色/浅色主题（跟随系统 + Liquid Glass）

---

## 3. 架构设计

### 3.1 项目结构

```
MacDevApp/
├── MacDevApp/                    # 主 App target
│   ├── App/                      # App 入口、窗口管理
│   ├── Navigation/               # 侧边栏、搜索、路由
│   ├── Theme/                    # Liquid Glass 主题、深色/浅色
│   └── Resources/                # 本地化字符串（.xcstrings）、Assets
│
├── Packages/
│   ├── DevAppCore/               # 共享基础层
│   │   ├── ToolProtocol          # 所有工具的统一协议
│   │   ├── InputOutputView       # 通用双面板视图组件
│   │   ├── Localization          # 国际化工具
│   │   └── Extensions            # 通用 Swift 扩展
│   │
│   ├── CryptoTools/              # 加解密模块
│   │   ├── AES/                  # AES 加密/解密
│   │   ├── RSA/                  # RSA 密钥生成 + 加密/解密
│   │   ├── Hash/                 # MD5/SHA-1/SHA-256/SHA-512
│   │   └── HMAC/                 # HMAC 生成器
│   │
│   ├── APIClient/                # 接口调试模块
│   │   ├── RequestEditor/        # 请求编辑（URL/Headers/Body/Auth）
│   │   ├── ResponseViewer/       # 响应展示（Body/Headers/Timeline）
│   │   ├── Collections/          # 请求集合管理（基础版）
│   │   └── Models/               # SwiftData 模型
│   │
│   └── ConversionTools/          # 转换工具模块
│       ├── UnixTimestamp/        # 时间戳转换
│       ├── URLCodec/             # URL Encode/Decode
│       ├── Base64Codec/          # Base64 编码/解码
│       └── JSONFormatter/        # JSON 格式化/校验
```

### 3.2 模块依赖关系

```
主 App → DevAppCore, CryptoTools, APIClient, ConversionTools
CryptoTools → DevAppCore
APIClient → DevAppCore
ConversionTools → DevAppCore
```

模块之间不互相依赖，只依赖 DevAppCore。

### 3.3 核心协议

```swift
protocol DevTool: Identifiable, View {
    var id: String { get }
    var name: LocalizedStringKey { get }
    var icon: String { get }           // SF Symbol name
    var category: ToolCategory { get }
    
    // body 由 View 协议提供，无需额外声明
}

enum ToolCategory: String, CaseIterable {
    case crypto       // 加解密
    case apiClient    // 接口调试
    case conversion   // 转换工具
}
```

主 App 通过 `DevTool` 协议发现和渲染所有工具，侧边栏按 `ToolCategory` 分组展示。

---

## 4. 界面设计

### 4.1 整体布局：经典侧边栏导航

使用 SwiftUI `NavigationSplitView` 两栏布局：

- **左侧侧边栏**：顶部搜索栏 + 按分类分组的工具列表（加解密 / 接口调试 / 转换工具）
- **右侧主内容区**：选中工具的完整界面

侧边栏支持 Liquid Glass 半透明效果，工具列表支持模糊搜索过滤。

### 4.2 加密/转换工具布局：左右双面板

所有加密工具和转换工具共用统一布局：

```
┌──────────────────────────────────────────────────┐
│ 工具标题 + 描述                                    │
├──────────────────────────────────────────────────┤
│ 参数配置栏（模式/密钥长度/填充/格式等下拉选择）        │
├──────────────────────────────────────────────────┤
│ 密钥/IV 输入区（仅加密工具）          [🎲 随机生成]  │
├───────────────────┬──┬───────────────────────────┤
│                   │  │                           │
│     输入面板       │→│      输出面板               │
│                   │←│                           │
│                   │  │                    [📋]   │
└───────────────────┴──┴───────────────────────────┘
```

- 顶部：参数配置（下拉菜单行）
- 中部（仅加密工具）：密钥和 IV 输入 + 随机生成按钮
- 下方左右分栏：输入面板 ↔ 操作按钮 ↔ 输出面板
- 输出面板右上角：复制到剪贴板按钮
- 输入变化时输出实时刷新（转换工具），加密工具点击按钮触发

### 4.3 HTTP 接口调试布局：上下分栏

```
┌──────────────────────────────────────────────────┐
│ [GET ▾] [https://api.example.com/users   ] [发送] │
├──────────────────────────────────────────────────┤
│ [Params] [Headers] [Body] [Auth]                  │
│                                                   │
│ Key-Value 参数编辑表格 / JSON Body 编辑器           │
│                                                   │
├──────────── ⋯ 可拖拽分割线 ⋯ ────────────────────┤
│ 200 OK  247ms  1.2KB                              │
│ [Body] [Headers] [Cookies] [Timeline]             │
│                                                   │
│ JSON 树状结构展示 / Raw 文本                        │
│                                                   │
└──────────────────────────────────────────────────┘
```

- URL 栏：HTTP 方法下拉 + URL 输入 + 发送按钮
- 上半部：请求编辑区，Tab 切换 Params / Headers / Body / Auth
- 下半部：响应展示区，Tab 切换 Body / Headers / Cookies / Timeline
- 中间：可拖拽分割线调整上下比例
- 响应状态栏：状态码（颜色编码）+ 耗时 + 响应大小

---

## 5. 数据模型

### 5.1 SwiftData 模型（HTTP 模块）

```swift
@Model class HTTPRequest {
    var id: UUID
    var name: String
    var method: String          // GET/POST/PUT/DELETE/PATCH/HEAD/OPTIONS
    var url: String
    var headers: [KeyValuePair]
    var body: RequestBody?
    var authType: AuthType?
    var collection: HTTPCollection?
    var createdAt: Date
    var lastExecutedAt: Date?
}

@Model class HTTPCollection {
    var id: UUID
    var name: String
    var requests: [HTTPRequest]
    var parentCollection: HTTPCollection?
}

@Model class HTTPHistory {
    var id: UUID
    var request: HTTPRequest
    var responseStatus: Int
    var responseBody: Data
    var responseHeaders: [KeyValuePair]
    var duration: TimeInterval
    var executedAt: Date
}
```

### 5.2 辅助类型

注意：SwiftData 不直接支持带关联值的枚举属性。以下类型使用 `Codable` 序列化为 JSON 字符串存储在 SwiftData 模型中（通过 `@Attribute(.transformable)` 或手动 JSON 编解码）。

```swift
struct KeyValuePair: Codable, Hashable {
    var key: String
    var value: String
    var isEnabled: Bool
}

enum RequestBody: Codable {
    case json(String)
    case formData([KeyValuePair])
    case raw(String)
    case binary(Data)
}

enum AuthType: Codable {
    case bearerToken(String)
    case basicAuth(username: String, password: String)
    case apiKey(key: String, value: String, addTo: APIKeyLocation)
}

enum APIKeyLocation: String, Codable {
    case header, queryParam
}
```

---

## 6. 技术实现

### 6.1 技术栈

| 维度 | 方案 |
|------|------|
| 语言 | Swift |
| UI 框架 | SwiftUI (macOS 26+, Liquid Glass) |
| 加密 — AES GCM | Apple CryptoKit `AES.GCM` |
| 加密 — AES ECB/CBC | CommonCrypto via C bridge |
| 加密 — RSA | Security.framework (`SecKeyCreateRandomKey`, `SecKeyEncrypt`) |
| 哈希 — MD5/SHA-1 | CryptoKit `Insecure.MD5` / `Insecure.SHA1` |
| 哈希 — SHA-256/512 | CryptoKit `SHA256` / `SHA512` |
| HMAC | CryptoKit `HMAC` |
| 网络请求 | URLSession (Foundation) |
| 数据持久化 | SwiftData |
| 国际化 | String Catalog (.xcstrings) |
| 构建 | Xcode + Swift Package Manager |

### 6.2 国际化

- 使用 Xcode String Catalog (.xcstrings)
- 所有用户可见字符串使用 `LocalizedStringKey`
- 支持语言：简体中文 (zh-Hans)、英文 (en)
- 工具名称、描述、参数标签、错误提示全部纳入国际化
- 跟随系统语言自动切换

### 6.3 主题系统

- 跟随系统 `colorScheme`，Liquid Glass 自动适配深色/浅色
- 代码/密文区域使用等宽字体 `Font.system(.body, design: .monospaced)`
- 输入/输出面板使用统一的 `InputOutputStyle` 视图修饰器
- 状态码颜色编码：2xx 绿色、3xx 蓝色、4xx 橙色、5xx 红色

---

## 7. 各工具详细规格

### 7.1 AES 加密/解密

- **模式**：ECB / CBC / GCM（P0 范围，CTR 留待 P1）
- **密钥长度**：128 / 192 / 256 bit
- **填充**：PKCS7 / NoPadding
- **输入格式**：UTF-8 文本 / Hex / Base64
- **输出格式**：Hex / Base64
- **额外功能**：随机密钥/IV 生成按钮，一键复制

### 7.2 RSA 工具

- **密钥生成**：1024 / 2048 / 4096 bit，输出格式 PEM
- **加密/解密**：公钥加密、私钥解密
- **填充**：PKCS1v1.5 / OAEP (SHA-256)
- **输入/输出格式**：Hex / Base64
- **UI**：密钥对生成区在上方，加密/解密用左右双面板

### 7.3 Hash 生成器

- **算法**：MD5 / SHA-1 / SHA-256 / SHA-512
- **输入**：文本输入 + 文件拖拽
- **输出**：同时展示所有算法的结果（列表形式）
- **额外功能**：大小写切换（uppercase/lowercase hex）、一键复制单行

### 7.4 HMAC 生成器

- **算法**：HMAC-MD5 / HMAC-SHA1 / HMAC-SHA256 / HMAC-SHA512
- **输入**：消息文本 + 密钥
- **输出格式**：Hex / Base64

### 7.5 HTTP 接口调试

- **请求方法**：GET / POST / PUT / PATCH / DELETE / HEAD / OPTIONS
- **请求头**：Key-Value 表格编辑，支持启用/禁用单行
- **请求体**：JSON / Form Data / Raw / Binary
- **认证**：Bearer Token / Basic Auth / API Key
- **URL 参数**：可视化 Key-Value 编辑，自动同步到 URL
- **响应展示**：
  - Body：JSON 语法高亮 + 折叠 / Raw 文本
  - Headers：Key-Value 列表
  - Cookies：解析 Set-Cookie
  - Timeline：DNS / TCP / TLS / 首字节 / 总耗时分段
- **数据管理**：
  - 请求集合（文件夹树状结构）
  - 请求历史（自动记录）
  - SwiftData 持久化

### 7.6 Unix 时间戳转换

- **时间戳 → 可读时间**：自动识别秒/毫秒
- **可读时间 → 时间戳**：输出秒和毫秒
- **实时显示**：当前 Unix 时间戳实时跳动
- **时区**：下拉选择，同时展示 UTC 和所选时区
- **输出格式**：ISO 8601 / RFC 2822 / yyyy-MM-dd HH:mm:ss
- **双向实时联动**：输入变化时输出立即刷新

### 7.7 URL Encode/Decode

- **编码标准**：RFC 3986 / application/x-www-form-urlencoded
- **左右面板**：左侧原文 ↔ 右侧编码结果，实时双向转换
- **URL 解析器**：将完整 URL 拆解为 Protocol / Host / Port / Path / Query / Fragment

### 7.8 Base64 编码/解码

- **文本模式**：左侧原文 ↔ 右侧 Base64，实时双向转换
- **图片模式**：拖入图片生成 Base64 data URI，反向解码 Base64 预览图片
- **选项**：标准 Base64 / URL-safe Base64

### 7.9 JSON 格式化/校验

- **格式化**：美化（可选缩进 2/4 空格或 Tab）
- **压缩**：移除所有空白
- **校验**：语法检查，错误行高亮定位
- **左右面板**：左侧输入 ↔ 右侧格式化结果
- **额外功能**：JSON 路径显示（点击节点显示 JSONPath）

---

## 8. 交互设计原则

1. **实时预览**：转换工具输入变化时输出立即刷新，无需点击按钮
2. **全局搜索**：侧边栏顶部搜索栏，模糊匹配工具名称和描述
3. **离线优先**：所有功能离线可用，敏感数据不离开本机
4. **一键复制**：所有输出区域提供复制到剪贴板按钮
5. **拖拽支持**：文件拖入对应工具自动处理（如图片→Base64、文件→Hash）
6. **收藏夹**：用户可将常用工具标记为收藏，侧边栏顶部快速访问
7. **键盘友好**：⌘K 全局搜索、Tab 在面板间切换
