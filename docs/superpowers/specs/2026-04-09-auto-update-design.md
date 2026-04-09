# DevToolkit 自动更新设计文档

**日期**: 2026-04-09
**状态**: 已批准

## 概述

为 DevToolkit macOS 应用实现静默自动更新功能。使用 Sparkle 框架作为客户端更新引擎，GitHub Actions 实现全自动构建发布流水线，GitHub Releases 托管更新包，appcast.xml 通过 repo raw URL 提供版本元数据。

## 需求

- 静默更新：后台自动下载，用户退出时替换，下次启动即为新版
- 启动时检查 + 每小时轮询
- 支持 git tag 推送自动触发 + 手动触发发布
- Developer ID 签名 + Apple 公证 + EdDSA 签名验证
- 更新包托管在 GitHub Releases

## 架构

### 整体流程

```
客户端:
  App 启动
    → SPUUpdater 初始化（静默模式）
    → 检查 GitHub repo raw URL 上的 appcast.xml
    → 发现新版本 → 后台下载 ZIP
    → 验证 EdDSA 签名
    → 用户退出时 → 原子替换 .app bundle → 下次启动即为新版

服务端 (GitHub Actions):
  推送 tag v*.*.* 或手动触发
    → macOS runner
    → xcodebuild archive → 签名 → 公证 → staple
    → 压缩为 ZIP → Sparkle EdDSA 签名
    → 生成/更新 appcast.xml
    → 创建 GitHub Release（附带 ZIP）
    → 提交 appcast.xml 到 repo
```

## 客户端：Sparkle 集成

### 依赖引入

在 `project.yml` 中添加 Sparkle 作为 SPM remote package：

```yaml
packages:
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle
    from: "2.6.0"
```

主 target 添加依赖：

```yaml
dependencies:
  - package: Sparkle
```

### App 初始化

在 `MacDevAppApp.swift` 中创建 UpdaterManager，配置 SPUUpdater 静默更新模式：

```swift
import Sparkle

@MainActor
final class UpdaterManager {
    let updater: SPUUpdater

    init() {
        let controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.updater = controller.updater
        self.updater.automaticallyChecksForUpdates = true
        self.updater.automaticallyDownloadsUpdates = true
        self.updater.updateCheckInterval = 3600 // 每小时
    }

    func start() {
        updater.startUpdater()
    }
}
```

在 `@main App` 的 `init()` 中调用 `UpdaterManager().start()`。

### Info.plist 新增配置

| Key | 值 | 说明 |
|-----|-----|------|
| `SUFeedURL` | `https://raw.githubusercontent.com/{owner}/{repo}/main/appcast.xml` | appcast 地址 |
| `SUPublicEDKey` | EdDSA 公钥字符串 | 验证更新包签名 |
| `SUEnableAutomaticChecks` | `YES` | 默认开启自动检查 |

### 更新行为

- 启动时自动检查 + 每小时轮询（`updateCheckInterval = 3600`）
- `automaticallyDownloadsUpdates = true` — 发现新版后静默下载
- Sparkle 内置"退出时安装"机制 — 下载完成后等用户退出 app 时自动替换
- 无需额外 UI，静默模式下 Sparkle 不弹窗

## 服务端：GitHub Actions CI/CD

### 触发方式

```yaml
on:
  push:
    tags: ['v*.*.*']        # tag 推送自动触发
  workflow_dispatch:         # 手动触发
    inputs:
      version:
        description: '版本号 (如 1.1.0)'
        required: true
```

### Pipeline 步骤

1. **Checkout 代码**
2. **安装证书**
   - 从 GitHub Secrets 解码 .p12 证书 → 导入临时 Keychain
   - 配置 notarytool 凭据
3. **构建**
   - xcodebuild archive（Developer ID 签名）
   - xcodebuild -exportArchive → .app
4. **公证**
   - ZIP 压缩 .app
   - `xcrun notarytool submit` → 等待完成
   - `xcrun stapler staple .app`
5. **打包最终产物**
   - 重新 ZIP（staple 后的版本）
6. **Sparkle 签名**
   - 用 Sparkle 的 `sign_update` 工具生成 EdDSA 签名
   - 输出 edSignature 和 length
7. **更新 appcast.xml**
   - 插入新版本条目（版本号、下载 URL、EdDSA 签名、文件大小、发布日期）
8. **发布**
   - 创建 GitHub Release + 上传 ZIP
   - 提交更新后的 appcast.xml 到 repo

### GitHub Secrets 配置

| Secret 名称 | 内容 |
|---|---|
| `DEVELOPER_ID_CERTIFICATE_P12` | 证书 .p12 文件的 Base64 编码 |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | .p12 的导出密码 |
| `APPLE_ID` | Apple ID 邮箱 |
| `APPLE_ID_PASSWORD` | App-Specific Password |
| `APPLE_TEAM_ID` | `4257SFGRFK` |
| `SPARKLE_PRIVATE_KEY` | EdDSA 私钥 |

### appcast.xml 格式

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle">
  <channel>
    <title>DevToolkit Updates</title>
    <item>
      <title>Version 1.1.0</title>
      <sparkle:version>2</sparkle:version>
      <sparkle:shortVersionString>1.1.0</sparkle:shortVersionString>
      <sparkle:minimumSystemVersion>26.0</sparkle:minimumSystemVersion>
      <pubDate>Wed, 09 Apr 2026 12:00:00 +0000</pubDate>
      <enclosure
        url="https://github.com/{owner}/{repo}/releases/download/v1.1.0/DevToolkit.zip"
        type="application/octet-stream"
        sparkle:edSignature="..."
        length="..."
      />
    </item>
  </channel>
</rss>
```

托管方式：直接放在 repo 根目录，通过 raw URL 访问。

## EdDSA 密钥管理

- 首次用 Sparkle 自带的 `generate_keys` 工具生成 EdDSA 密钥对
- 私钥存入 GitHub Secrets（`SPARKLE_PRIVATE_KEY`），仅 CI/CD 使用
- 公钥写入 Info.plist 的 `SUPublicEDKey` 字段，随 app 分发

## 版本号管理

- 版本号来源于 git tag（如 `v1.1.0`）
- GitHub Actions 从 tag 提取版本号，构建时通过 `MARKETING_VERSION` 和 `CURRENT_PROJECT_VERSION` 注入
- `project.yml` 中的版本号作为开发期间的默认值，发布时由 CI 覆盖

## 发布流程（开发者视角）

```bash
# 方式一：tag 触发
git tag v1.1.0
git push origin v1.1.0
# → Actions 自动构建、签名、公证、发布

# 方式二：手动触发
# → GitHub Actions 页面 → Run workflow → 输入版本号 1.1.0
```

## 安全保障

- 下载的更新包必须通过 EdDSA 签名验证（Sparkle 内置）
- 更新包本身已经过 Apple 公证（Hardened Runtime + notarization）
- 双重验证：Apple 代码签名 + Sparkle EdDSA 签名

## 涉及的文件变更

| 文件 | 变更 |
|------|------|
| `project.yml` | 添加 Sparkle SPM 依赖 |
| `MacDevApp/Info.plist` | 添加 SUFeedURL、SUPublicEDKey、SUEnableAutomaticChecks |
| `MacDevApp/MacDevAppApp.swift` | 添加 UpdaterManager，启动时初始化 Sparkle |
| `.github/workflows/release.yml` | 新建：完整 CI/CD 发布流水线 |
| `appcast.xml` | 新建：版本元数据 feed（由 CI 自动维护） |
