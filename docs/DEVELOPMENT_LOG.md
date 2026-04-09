# DevToolkit 开发日志

> macOS 原生开发者工具集应用，从零到发布的完整记录。
> 开发时间：2026-04-08 ~ 2026-04-09

---

## 项目概览

| 项目 | 数值 |
|------|------|
| 工具总数 | 24 个 |
| 源文件数 | 70+ |
| 测试数量 | 110+ |
| Git 提交 | 50+ |
| 技术栈 | Swift 6 / SwiftUI / macOS 26 / SwiftData |
| 架构 | 4 个 Swift Package（DevAppCore / CryptoTools / ConversionTools / APIClient） |

---

## Phase 1：基础架构搭建

### 1.1 项目脚手架
- 使用 xcodegen 生成 Xcode 项目
- 4 个本地 Swift Package：DevAppCore、CryptoTools、ConversionTools、APIClient
- CommonCrypto C bridge（用于 AES-ECB）
- swift-tools-version 从 6.1 升级到 6.2（解决 `.macOS(.v26)` 不可用问题）

### 1.2 DevAppCore 共享组件
- `DevTool` 协议 + `ToolCategory` 枚举
- `ToolDescriptor` — 工具注册描述符
- `InputOutputView` — 通用双面板布局（后升级为双向可编辑）
- `CopyButton` — 复制到剪贴板按钮（胶囊样式 + 动画）
- `HexUtils` — Data ↔ Hex 互转

### 1.3 App Shell
- `NavigationSplitView` 两栏布局
- `ToolRegistry` — 工具注册 + 搜索 + 分类过滤
- `SidebarView` — 彩色图标分类侧边栏
- `WelcomeView` — 品牌欢迎页

---

## Phase 2：加密工具模块（CryptoTools）

| 工具 | 功能 | 测试 |
|------|------|------|
| Hash Generator | MD5/SHA-1/SHA-256/SHA-512，大小写切换 | 7 tests |
| HMAC Generator | HMAC-MD5/SHA1/SHA256/SHA512，Hex/Base64 输出 | 5 tests |
| AES Encrypt/Decrypt | ECB/CBC/GCM，128/192/256-bit，PKCS7/NoPadding | 8 tests |
| RSA Encrypt/Decrypt | 密钥生成 1024/2048/4096-bit，PKCS1/OAEP，PEM 格式 | 4 tests |

---

## Phase 3：转换工具模块（ConversionTools）

### 第一批（P0 核心）
| 工具 | 功能 |
|------|------|
| Unix Timestamp | 双向转换 + 实时时钟 + 时区切换 |
| URL Encode/Decode | RFC 3986 / Form Data + URL 解析器 |
| Base64 Encode/Decode | 标准/URL-safe，文本+图片 |
| JSON Formatter | 格式化/压缩/校验，2/4空格/Tab |

### 第二批（Quick Wins，工具数 9→19）
| 工具 | 功能 |
|------|------|
| UUID Generator | 批量生成 + 解码 |
| Random String Generator | 可配置字符集/长度 |
| Number Base Converter | 二/八/十/十六进制互转 |
| HTML Entity Encode/Decode | 命名+数字实体 |
| String Escape/Unescape | 反斜杠序列 |
| String Case Converter | 7 种命名风格互转 |
| Hex/ASCII Converter | 十六进制 ↔ ASCII |
| Line Sort & Deduplicate | 排序/去重/反转/打乱 |
| Text Analyzer | 字数/字符/行/句/段/字节统计 |
| Lorem Ipsum Generator | 词/句/段落占位文本 |

### 第三批（进阶工具，工具数 19→24）
| 工具 | 功能 |
|------|------|
| JSON ↔ YAML | 纯 Swift 实现，双向实时转换 |
| Markdown Preview | WKWebView 渲染，GFM 支持，深色/浅色自适应 |
| Text Diff | LCS 算法，侧面板+行级差异高亮 |
| Image to Text (OCR) | Apple Vision，粘贴/拖拽/打开文件，中英日韩 |
| Translator | Microsoft 免费 API，30 种语言，自动检测 |

---

## Phase 4：HTTP 客户端模块（APIClient）

### 4.1 核心功能
- **请求编辑器**：URL Bar（方法颜色编码）+ Params/Headers/Body/Auth/Scripts 5 个 Tab
- **响应查看器**：Body（Pretty/Raw）/ Headers / Cookies / Rewrite 4 个 Tab
- **状态码描述**：20 种常见状态码（200 OK, 404 Not Found 等）
- **VSplitView**：上下分栏，可拖拽调整比例

### 4.2 cURL 支持
- **导入**：粘贴 cURL 命令自动填充所有字段
- **导出**：请求发送后生成可执行的 cURL 命令

### 4.3 Pre/Post Script（JavaScriptCore）
- **Pre-request Script**：请求前执行，可修改 URL/Headers/Body/Method
- **Post-request Script**：响应后执行，支持 `assert()` 断言测试
- **Console**：多参数 console.log，支持对象 JSON 序列化

### 4.4 Postman 兼容层
- **pm API**：`pm.environment.get/set/unset/has`，`pm.request.body.update()`，`pm.request.headers.upsert()`，`pm.request.url.query`
- **CryptoJS**：SHA256/SHA1/HMAC-SHA256/AES-ECB，全部 Swift CryptoKit 后端
- **浏览器 Polyfill**：`atob`/`btoa`/`TextEncoder`/`TextDecoder`/`crypto.getRandomValues`/`BigInt`
- **{{variable}} 模板**：Headers/URL/Body 中的 `{{var}}` 自动从 pm.environment 替换

### 4.5 响应改写（Rewrite）
- **手动模式**：编辑状态码、Headers、Body
- **脚本模式**：JavaScript 改写 `response.body`/`status`/`headers`
- **自动执行**：Rewrite Script 非空时每次请求自动运行

### 4.6 请求历史
- SwiftData 持久化
- 保存全部字段：URL、Method、Headers、Body、Scripts
- 点击恢复 + 重新发送

### 4.7 保存的 API + 标签
- 命名 + 多标签管理
- 标签过滤 + 搜索
- 导入：Postman Collection v2.1（含脚本）/ cURL
- 导出：Postman Collection v2.1 / DevToolkit JSON

---

## Phase 5：UI 优化

| 优化项 | 说明 |
|--------|------|
| App 图标 | Python PIL 生成，`</>` + 锁 + 网络信号 |
| Liquid Glass | macOS 26 侧边栏半透明效果 |
| 深色/浅色 | 跟随系统自动切换 |
| 禁用智能引号 | 全局关闭 Smart Quotes/Dashes/Autocorrect |
| 双向转换 | 所有编解码工具支持左右任意方向操作 |
| `.fixedSize()` | Picker 不再显示 "..." 截断 |
| 面板对齐 | 左右面板 label 行结构统一 |

---

## 技术亮点

1. **模块化架构**：4 个独立 Swift Package，模块间零耦合
2. **纯 Swift YAML 解析器**：无外部依赖，支持嵌套结构/注释/引号
3. **纯 Swift Markdown 渲染**：支持 GFM 表格/代码块/任务列表
4. **JavaScriptCore + Postman 兼容**：运行 Postman 加密脚本无需修改
5. **Microsoft 免费翻译 API**：无需 API Key，Edge 内置端点
6. **Apple Vision OCR**：离线中英日韩文字识别
7. **Developer ID 签名 + Apple 公证**：双击安装无安全警告

---

## 数据统计

```
源文件:    70+
测试文件:  28
测试用例:  110+
Git 提交:  50+
Swift Package: 4
工具数量:  24
支持语言:  中文/英文（跟随系统）
最低系统:  macOS 26
```
