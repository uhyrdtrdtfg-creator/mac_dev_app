# Mac Dev App — 行业调研与产品设计参考文档

> 本文档面向 AI 辅助开发，系统梳理了行业内现有 Mac 端开发者工具集 App 的功能、架构和设计模式，为构建一款新的 Mac Dev App 提供完整的参考框架。

---

## 1. 行业现有产品全景

### 1.1 核心竞品概览

| 产品 | 平台 | 技术栈 | 开源 | 定价模式 | 工具数量 |
|------|------|--------|------|----------|----------|
| **DevUtils** | macOS 独占 | Swift (原生) | 否 | 免费 3 工具 + 付费全功能 ($14) | 47+ |
| **DevToys** | macOS / Windows / Linux | Swift (Mac 版) / .NET (Win) | 是 (MIT) | 免费 | 30+ 默认 |
| **DevTools-X** | macOS / Windows / Linux | Tauri + React + Rust | 是 | 免费 | 41+ |
| **CyberChef** | Web | JavaScript | 是 (Apache 2.0) | 免费 | 300+ operations |
| **RapidAPI for Mac** (原 Paw) | macOS 独占 | 原生 | 否 | 免费个人版 | API 调试专精 |
| **NativeRest** | macOS / Windows / Linux | 原生 (各平台) | 是 | 免费 + 付费 Pro | API 调试专精 |
| **Bruno** | macOS / Windows / Linux | Electron | 是 (MIT) | 免费开源 | API 调试专精 |
| **Hoppscotch** | Web / 桌面 | Vue.js | 是 | 免费 | API 调试专精 |

### 1.2 市场定位分析

行业内产品可分为两大类：

- **综合工具集型**（DevUtils、DevToys、DevTools-X）：将多种开发小工具集成在一个 App 内，覆盖编码/解码、格式化、生成器、转换器等场景。核心卖点是"一站式"和"离线隐私安全"。
- **API 调试专精型**（RapidAPI/Paw、NativeRest、Bruno、Postman）：专注于 HTTP 请求构建、发送、测试和文档化。功能更深但领域更窄。

**市场机会**：目前尚无一款产品能很好地将"综合工具集"与"接口调试"深度融合在同一个原生 Mac App 中。这正是新产品的差异化切入点。

---

## 2. 功能模块深度拆解

### 2.1 加解密工具模块

#### 2.1.1 行业现状

DevToys 提供的加密相关工具包括：Hash & Checksum 生成器、HMAC 生成器、RSA 密钥生成器、bcrypt 生成器、TOTP/OTP 生成器。DevUtils 提供 Hash Generator（MD5/SHA1/SHA256/SHA512）。CyberChef 提供了最全面的加密操作，覆盖 AES、DES、Blowfish、ChaCha、RSA、XOR 等多种算法。

#### 2.1.2 推荐实现功能清单

**对称加密**

| 功能 | 说明 | 参数 |
|------|------|------|
| AES 加密/解密 | 最常用的对称加密 | 模式：ECB/CBC/CTR/GCM；密钥长度：128/192/256 bit；填充：PKCS7/NoPadding；输入/输出格式：Hex/Base64/UTF-8 |
| DES / 3DES 加密/解密 | 遗留系统兼容 | 模式：ECB/CBC；填充：PKCS5/PKCS7 |
| ChaCha20 加密/解密 | 现代流加密 | Nonce、Key |

**非对称加密**

| 功能 | 说明 | 参数 |
|------|------|------|
| RSA 密钥对生成 | 生成公钥/私钥对 | 密钥长度：1024/2048/4096 bit；格式：PEM/DER/PKCS#1/PKCS#8 |
| RSA 加密/解密 | 公钥加密、私钥解密 | 填充：PKCS1v1.5/OAEP(SHA-1/SHA-256)；输入/输出格式：Hex/Base64 |
| RSA 签名/验签 | 数据完整性验证 | 算法：SHA256withRSA/SHA512withRSA |

**哈希与摘要**

| 功能 | 说明 |
|------|------|
| MD5 | 常见但已不推荐用于安全场景 |
| SHA-1 / SHA-256 / SHA-512 | SHA-2 系列 |
| SHA-3 (Keccak) | 最新标准 |
| HMAC | 带密钥的哈希，支持上述所有算法 |
| bcrypt / scrypt / Argon2 | 密码哈希函数 |
| CRC32 | 校验和 |

**其他加密工具**

| 功能 | 说明 |
|------|------|
| JWT 调试器 | 解码 Header/Payload，验证签名（HS256/RS256） |
| TOTP/HOTP 生成器 | 基于时间/计数器的一次性密码 |
| 证书查看器 | 解析 X.509 证书，显示颁发者、有效期、公钥等信息 |
| PEM/DER 格式互转 | 证书和密钥格式转换 |

#### 2.1.3 UI 设计参考

DevToys 和 DevUtils 的加密工具 UI 模式一致：上方为输入区域（文本/文件），中间为参数配置区（算法选择、密钥输入、模式选择等），下方为输出区域。CyberChef 采用"食谱"模式——用户将操作拖拽到中间面板串联，支持多步操作链式处理。

**推荐 UI 方案**：采用双面板布局（Input / Output），中间配置栏。支持文本输入和文件拖拽两种模式。在 RSA 工具中提供 Tab 切换："密钥生成" / "加密" / "解密" / "签名" / "验签"。

---

### 2.2 接口调试工具模块

#### 2.2.1 行业现状

RapidAPI for Mac（原 Paw）是 macOS 原生 API 客户端标杆，以原生性能和动态值（Dynamic Values）著称。Bruno 以 Git 友好的文件存储方式受到开发者欢迎，将 API 集合存储为本地文件而非云端。NativeRest 强调 100% 原生、轻量启动、低内存占用。Hoppscotch 则以极简 Web UI 和即开即用为卖点。

#### 2.2.2 推荐实现功能清单

**核心请求功能**

| 功能 | 说明 |
|------|------|
| HTTP 方法支持 | GET / POST / PUT / PATCH / DELETE / HEAD / OPTIONS |
| 请求头编辑 | Key-Value 表格编辑，支持常用头部快速选择 |
| 请求体类型 | JSON / Form Data / Multipart / Raw / Binary / GraphQL |
| URL 参数编辑 | 可视化 Query String 编辑，自动拼接到 URL |
| 认证方式 | Bearer Token / Basic Auth / OAuth 2.0 / API Key / Digest |

**响应展示**

| 功能 | 说明 |
|------|------|
| 状态码 + 耗时 + 大小 | 顶部醒目展示 |
| Body 预览 | JSON 树状结构可折叠展示 / Raw / HTML 渲染预览 |
| Headers 查看 | 响应头 Key-Value 列表 |
| Cookies 查看 | 自动解析 Set-Cookie |
| 响应时间线 | DNS / TCP / TLS / 首字节 / 总耗时分段展示 |

**组织与管理**

| 功能 | 说明 |
|------|------|
| 集合 (Collection) | 文件夹树状结构组织请求，支持最多 8 层嵌套 |
| 环境变量 | 多环境切换（Dev / Staging / Prod），变量引用语法 `{{variable}}` |
| 请求历史 | 自动记录每次请求，可回溯 |
| 导入/导出 | 支持 Postman Collection / OpenAPI (Swagger) / cURL / HAR |

**高级特性**

| 功能 | 说明 |
|------|------|
| Pre-request Script | 请求前执行脚本（如动态签名、Token 刷新） |
| 断言测试 | 对响应进行断言检查（状态码、JSON Path、Header 值） |
| 代码生成 | 将请求转换为 cURL / Swift / Python / JavaScript / Java / Go 等代码 |
| WebSocket 调试 | 建立 WS 连接，发送/接收消息 |
| SSE 调试 | Server-Sent Events 流式响应查看 |
| gRPC 支持 | Protocol Buffers 定义导入，gRPC 请求调试 |
| Mock Server | 本地快速创建 Mock API 返回固定响应 |

#### 2.2.3 UI 设计参考

RapidAPI/Paw 采用经典三栏布局：左侧请求列表树、中间请求编辑区、右下响应展示区。Bruno 则使用类 VS Code 的 Tab 页签模式，每个请求一个 Tab。NativeRest 界面简洁，请求和响应上下分布。

**推荐 UI 方案**：左侧为集合树 + 搜索 + 环境切换，主区域上部为请求编辑（URL 栏 + 方法选择 + 发送按钮 + Tab 切换 Params/Headers/Body/Auth/Scripts），下部为响应展示（Tab 切换 Body/Headers/Cookies/Timeline）。支持多 Tab 同时打开多个请求。

---

### 2.3 常用转换工具模块

#### 2.3.1 Unix Time 时间戳转换

**行业参考**：DevUtils 的 Unix Time Converter 支持时区选择，免费版即可使用，是其招牌功能之一。DevToys 提供日期格式转换器。

**推荐实现功能**

| 功能 | 说明 |
|------|------|
| 时间戳 → 可读时间 | 输入 Unix 时间戳（秒/毫秒自动识别），展示多种格式的可读时间 |
| 可读时间 → 时间戳 | 输入日期时间，输出对应的 Unix 时间戳（秒和毫秒） |
| 当前时间实时显示 | 实时跳动显示当前 Unix 时间戳和对应的可读时间 |
| 时区支持 | 下拉选择时区，同时展示 UTC 和本地时间 |
| 多格式输出 | ISO 8601 / RFC 2822 / 自定义格式（yyyy-MM-dd HH:mm:ss 等） |
| 时间差计算 | 输入两个时间戳，计算差值（天/时/分/秒） |
| 批量转换 | 粘贴多行时间戳，一次性批量转换 |

**UI 要点**：上方实时滚动的"Now"区域；中间双栏（时间戳输入 ↔ 可读时间输入）实时双向联动；下方展示多种格式化输出。

#### 2.3.2 URL Encode / Decode

**行业参考**：DevUtils 支持 RFC 3986 和 Form Data 两种编码标准，并提供 URL Parser 功能将 URL 拆解为 scheme / host / path / query / fragment。DevToys 提供 URL 编码解码。CyberChef 的 URL Encode/Decode 可串联在操作链中使用。

**推荐实现功能**

| 功能 | 说明 |
|------|------|
| URL Encode | 编码特殊字符为 %XX 格式 |
| URL Decode | 解码 %XX 回原始字符 |
| 编码标准选择 | RFC 3986 / application/x-www-form-urlencoded |
| 部分编码 | 可选仅编码特定字符集（空格、中文、全部非 ASCII） |
| URL 解析器 | 将完整 URL 拆解为各组成部分（Protocol / Host / Port / Path / Query / Fragment） |
| Query 参数编辑器 | 可视化编辑 URL 的 Query 参数（Key-Value 表格），实时生成完整 URL |

#### 2.3.3 其他推荐转换工具（扩展完整度）

根据 DevUtils / DevToys / CyberChef 的共同高频功能，建议同时规划以下转换工具：

| 工具 | 说明 | 优先级 |
|------|------|--------|
| Base64 编码/解码 | 文本和图片的 Base64 转换 | P0（必做） |
| JSON 格式化/校验 | 美化、压缩、语法校验 | P0 |
| JSON ↔ YAML 转换 | 双向转换 | P1 |
| JSON ↔ CSV 转换 | 数据格式互转 | P2 |
| HTML 实体编码/解码 | `&amp;` ↔ `&` | P1 |
| 进制转换 | 二进制/八进制/十进制/十六进制互转 | P1 |
| 颜色格式转换 | HEX / RGB / HSL / CMYK 互转 + 颜色预览 | P2 |
| UUID/ULID 生成与解码 | 批量生成 + 版本解析 | P1 |
| 正则表达式测试器 | 实时匹配高亮 + 分组捕获展示 | P1 |
| Markdown 预览 | 实时渲染 Markdown | P2 |
| Cron 表达式解析 | 解释 cron 表达式含义 + 显示未来执行时间 | P2 |
| 文本比较 (Diff) | 双栏文本对比，高亮差异 | P2 |
| 代码格式化 | JSON / SQL / XML / HTML / CSS / JS 美化和压缩 | P1 |
| 字符串大小写转换 | camelCase / snake_case / PascalCase / UPPER / lower / kebab-case | P2 |

---

## 3. 产品设计与架构建议

### 3.1 整体架构

```
┌─────────────────────────────────────────────────────────┐
│                     Mac Dev App                          │
├──────────┬──────────────────────────────────────────────┤
│          │                                              │
│  侧边栏   │              主内容区                        │
│          │                                              │
│ ┌──────┐ │  ┌────────────────────────────────────────┐  │
│ │ 搜索  │ │  │           工具内容区域                   │  │
│ └──────┘ │  │                                        │  │
│          │  │  ┌──────────┐    ┌──────────┐          │  │
│ 加解密    │  │  │  输入面板  │    │  输出面板  │          │  │
│  ├ AES   │  │  │          │    │          │          │  │
│  ├ RSA   │  │  └──────────┘    └──────────┘          │  │
│  ├ Hash  │  │                                        │  │
│  └ JWT   │  │  ┌──────────────────────────┐          │  │
│          │  │  │       参数配置区域         │          │  │
│ 接口调试  │  │  └──────────────────────────┘          │  │
│  └ HTTP  │  │                                        │  │
│          │  └────────────────────────────────────────┘  │
│ 转换工具  │                                              │
│  ├ 时间戳 │                                              │
│  ├ URL   │                                              │
│  ├ Base64│                                              │
│  └ JSON  │                                              │
│          │                                              │
│ 收藏夹 ⭐ │                                              │
│          │                                              │
└──────────┴──────────────────────────────────────────────┘
```

### 3.2 技术选型建议

| 维度 | 推荐方案 | 理由 |
|------|----------|------|
| 语言 | Swift | 原生性能，macOS 生态最佳选择（DevUtils 和 DevToys Mac 版均使用 Swift） |
| UI 框架 | SwiftUI | Apple 最新 UI 框架；NavigationSplitView 天然适合侧边栏导航；macOS 26 引入 Liquid Glass 设计语言 |
| 加密库 | Apple CryptoKit + Security.framework | 系统原生加密框架，覆盖 AES/SHA/RSA/ECC 等；对于更多算法可辅以 OpenSSL via SwiftPM |
| 网络请求 | URLSession (Foundation) | 系统原生，支持 HTTP/2、证书校验、代理设置 |
| 编辑器组件 | 集成 Monaco Editor (WebView) 或使用 SwiftUI 原生 TextEditor | API 请求体编辑和代码生成需要语法高亮 |
| 数据持久化 | SwiftData 或 Core Data | 保存请求历史、集合、环境变量 |
| 构建 | Xcode + Swift Package Manager | 标准 macOS 开发工具链 |

### 3.3 核心交互设计原则

根据对竞品的分析，以下是被验证有效的交互模式：

1. **剪贴板智能检测**（DevUtils / DevToys 核心特性）：监听系统剪贴板，自动识别内容类型（JSON 字符串、Unix 时间戳、Base64 编码文本、URL 等），以灯泡图标提示最匹配的工具。这是 DevUtils 最受用户好评的特性之一。

2. **全局搜索**：顶部搜索栏可快速模糊搜索所有工具名称和描述，按回车直接跳转。

3. **离线优先**：所有工具离线可用，敏感数据（如加密密钥、API Token）永远不离开本机。这是 DevUtils 和 DevToys 共同强调的隐私卖点。

4. **实时预览**：输入变化时输出立即刷新，无需点击"转换"按钮（CyberChef 和 DevUtils 均采用此模式）。

5. **收藏夹机制**：用户可将常用工具标记为收藏，在侧边栏顶部快速访问。

6. **深色/浅色主题**：跟随系统设置，同时支持手动切换。

### 3.4 macOS 深度集成建议

| 特性 | 说明 |
|------|------|
| 菜单栏驻留 (Menu Bar) | 提供菜单栏图标，点击弹出迷你面板，快速执行高频操作（如粘贴内容自动检测） |
| 全局快捷键 | 如 `⌥ + Space` 呼出浮动窗口 |
| Spotlight 集成 | 通过 Shortcuts / Spotlight 搜索直接跳转到特定工具 |
| 拖拽支持 | 文件拖入窗口自动处理（如拖入图片自动 Base64 编码） |
| Share Extension | 在 Safari 等应用中右键将内容发送到 Dev App 处理 |
| 多窗口支持 | 支持同时打开多个工具窗口并排工作 |

---

## 4. 差异化竞争策略

基于调研，以下是新产品可以超越现有竞品的方向：

### 4.1 功能差异化

| 策略 | 说明 |
|------|------|
| 加密工具深度 | 现有竞品的加密工具相对浅层（多为 Hash 和 Base64）。深入支持 AES/RSA/ECC 的完整工作流（密钥生成→加密→解密→签名→验签→证书解析）可以形成明显差异。 |
| 工具 + API 调试融合 | 在 API 调试中直接调用加密工具（如请求签名、响应解密），打通两个模块的壁垒。 |
| 操作链/管道模式 | 借鉴 CyberChef 的 Recipe 概念，允许用户将多个转换操作串联（如：Base64 Decode → JSON Format → 提取字段），超越竞品的单工具模式。 |
| 中文开发者友好 | 界面中文化，文档中文化，时间戳工具内置中国时区快捷选项，URL 编码默认处理中文字符等。 |

### 4.2 体验差异化

| 策略 | 说明 |
|------|------|
| 原生 macOS 体验 | 使用 SwiftUI + Liquid Glass（macOS 26），超越 Electron/Tauri 类竞品的外观和性能。 |
| 启动速度 | 原生 App 冷启动 < 1 秒，对比 DevTools-X (Tauri) 或 Postman (Electron) 有明显优势。 |
| 内存占用 | 原生 App 内存占用通常是 Electron 应用的 1/5 到 1/10。 |
| 插件生态 | 提供 Swift Package 插件机制，允许社区贡献新工具（DevToys 已验证此模式可行）。 |

---

## 5. MVP 版本功能优先级

### P0 — 第一版必须实现（核心价值）

1. **AES 加密/解密**（ECB/CBC/GCM，128/256 bit）
2. **RSA 密钥对生成 + 加密/解密**
3. **Hash 生成器**（MD5/SHA-1/SHA-256/SHA-512）
4. **HMAC 生成器**
5. **HTTP 接口调试**（GET/POST/PUT/DELETE + Headers + JSON Body + 响应展示）
6. **Unix 时间戳转换**（双向 + 时区 + 实时显示）
7. **URL Encode/Decode**
8. **Base64 编码/解码**（文本 + 图片）
9. **JSON 格式化/校验**
10. **侧边栏导航 + 全局搜索**
11. **深色/浅色主题**

### P1 — 第二版增强

1. JWT 调试器
2. RSA 签名/验签
3. 环境变量 + 请求集合管理
4. 正则表达式测试器
5. HTML 实体编码/解码
6. 进制转换器
7. UUID/ULID 生成器
8. 代码格式化（SQL/XML/HTML/CSS/JS）
9. 剪贴板智能检测
10. 菜单栏快捷入口

### P2 — 第三版扩展

1. 证书查看器（X.509）
2. bcrypt / Argon2 密码哈希
3. TOTP/HOTP 生成器
4. WebSocket / SSE 调试
5. 操作链（Pipeline）模式
6. cURL 导入导出 + 代码生成
7. Cron 表达式解析
8. 文本 Diff 对比
9. 颜色格式转换
10. Mock Server
11. 插件机制

---

## 6. 参考资源

### 6.1 竞品官网

- DevUtils: https://devutils.com/
- DevToys: https://devtoys.app/
- DevTools-X: https://github.com/fosslife/devtools-x
- CyberChef: https://gchq.github.io/CyberChef/
- RapidAPI for Mac: https://paw.cloud/
- NativeRest: https://nativesoft.com/
- Bruno: https://www.usebruno.com/
- Hoppscotch: https://hoppscotch.io/

### 6.2 Apple 开发框架

- CryptoKit: https://developer.apple.com/documentation/cryptokit
- Security Framework: https://developer.apple.com/documentation/security
- SwiftUI NavigationSplitView: https://developer.apple.com/documentation/swiftui/navigationsplitview
- SwiftData: https://developer.apple.com/documentation/swiftdata

### 6.3 开源参考实现

- CocoaCryptoMac (RSA 示例): https://github.com/nikyoudale/CocoaCryptoMac
- RNCryptor (AES Swift 封装): https://github.com/RNCryptor/RNCryptor
- DevToys 源码: https://github.com/DevToys-app/DevToys

---

## 7. 术语表

| 术语 | 含义 |
|------|------|
| AES | Advanced Encryption Standard，高级加密标准（对称加密） |
| RSA | Rivest-Shamir-Adleman，非对称加密算法 |
| HMAC | Hash-based Message Authentication Code，基于哈希的消息认证码 |
| JWT | JSON Web Token，用于身份认证的令牌格式 |
| TOTP | Time-based One-Time Password，基于时间的一次性密码 |
| PEM/DER | 密钥/证书编码格式（PEM 为 Base64 文本，DER 为二进制） |
| OAEP | Optimal Asymmetric Encryption Padding，RSA 推荐填充方式 |
| PKCS | Public-Key Cryptography Standards，公钥加密标准系列 |
| RFC 3986 | URI 通用语法标准，定义 URL 编码规则 |
| Unix Timestamp | 自 1970-01-01 00:00:00 UTC 以来的秒数 |
| gRPC | Google 的远程过程调用框架 |
| SSE | Server-Sent Events，服务端推送事件 |
| Liquid Glass | macOS 26 / iOS 26 引入的新设计语言 |
