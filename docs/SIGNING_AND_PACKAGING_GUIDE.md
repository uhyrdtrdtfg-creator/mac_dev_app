# macOS App 签名、公证与打包踩坑指南

> 记录 DevToolkit 从开发到分发过程中遇到的所有签名和打包问题。

---

## 一、证书类型区分

| 证书类型 | 用途 | 获取方式 |
|---------|------|---------|
| Apple Development | 开发调试 | Xcode 自动创建 |
| **Developer ID Application** | **App Store 外分发** | 需手动创建 |
| Developer ID Installer | pkg 安装包 | 需手动创建 |

### 坑 1：Apple Development ≠ Developer ID

开发证书（`Apple Development: xxx`）**不能**用于分发。必须创建 `Developer ID Application` 证书。

**创建方法**：Xcode → Settings → Accounts → Manage Certificates → + → Developer ID Application

### 坑 2：无 Developer ID 证书时的替代方案

自签名分发（用户首次需右键→打开）：
```bash
codesign --force --deep --sign "Apple Development: xxx" App.app
```

---

## 二、完整打包流程

### 步骤 1：Archive

```bash
xcodebuild archive \
  -project MacDevApp.xcodeproj \
  -scheme MacDevApp \
  -archivePath build/DevToolkit.xcarchive \
  -destination 'generic/platform=macOS' \
  CODE_SIGN_IDENTITY="Developer ID Application: bo xiao (4257SFGRFK)" \
  DEVELOPMENT_TEAM=4257SFGRFK \
  OTHER_CODE_SIGN_FLAGS="--options runtime"
```

> **`--options runtime`** 是公证必需的 Hardened Runtime 标志，不加会被 Apple 拒绝。

### 步骤 2：Export

需要 `ExportOptions.plist`：

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "...">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>4257SFGRFK</string>
    <key>signingStyle</key>
    <string>automatic</string>
    <key>signingCertificate</key>
    <string>Developer ID Application</string>
</dict>
</plist>
```

```bash
xcodebuild -exportArchive \
  -archivePath build/DevToolkit.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist build/ExportOptions.plist
```

### 步骤 3：打包 DMG

```bash
mkdir -p /tmp/dmg-build
cp -R build/export/DevToolkit.app /tmp/dmg-build/
ln -s /Applications /tmp/dmg-build/Applications
hdiutil create -volname "DevToolkit" \
  -srcfolder /tmp/dmg-build -ov -format UDZO \
  ~/Desktop/DevToolkit.dmg
rm -rf /tmp/dmg-build
```

### 步骤 4：公证 (Notarize)

```bash
xcrun notarytool submit ~/Desktop/DevToolkit.dmg \
  --keychain-profile "notarytool" --wait
```

### 步骤 5：Staple

```bash
xcrun stapler staple ~/Desktop/DevToolkit.dmg
```

---

## 三、踩坑记录

### 坑 3：公证凭证未存储

```
Error: No Keychain password item found for profile: notarytool
```

**原因**：首次公证需要先存储 App-Specific Password。

**解决**：
1. 在 https://appleid.apple.com/account/manage 生成 App-Specific Password
2. 存储到钥匙串：
```bash
xcrun notarytool store-credentials "notarytool" \
  --apple-id your@email.com --team-id TEAM_ID
```

### 坑 4：打包时反复弹出密码输入框

**原因**：每次 `codesign` 访问钥匙串中的私钥都需要授权。

**解决方案 A**（GUI）：
1. 打开钥匙串访问
2. 找到 Developer ID 对应的私钥
3. 双击 → 访问控制 → 允许所有应用程序访问

**解决方案 B**（命令行）：
```bash
security set-key-partition-list -S apple-tool:,apple:,codesign: \
  -s -k "登录密码" ~/Library/Keychains/login.keychain-db
```

### 坑 5：SPM Target 名称冲突

```
multiple packages ('apiclient', 'cryptotools') declare targets
with a conflicting name: 'CCommonCrypto'
```

**原因**：两个 Package 都有名为 `CCommonCrypto` 的 C target。

**解决**：重命名其中一个为 `CCommonCryptoAPI`（Package.swift + module.modulemap + import 都要改）。

### 坑 6：Executable is missing

```
The application cannot be opened because its executable is missing.
```

**原因**：`clean build` 后 DerivedData 中的 .app 被清理，旧路径失效。

**解决**：用 `find` 定位最新的 .app：
```bash
find ~/Library/Developer/Xcode/DerivedData/MacDevApp* \
  -name "DevToolkit.app" -path "*/Debug/*"
```

### 坑 7：swift-tools-version 6.1 不支持 .macOS(.v26)

```
'v26' is unavailable
```

**原因**：`.macOS(.v26)` 需要 PackageDescription 6.2+。

**解决**：将 `swift-tools-version: 6.1` 改为 `swift-tools-version: 6.2`。

### 坑 8：Swift 6 Sendable 限制

```
static property 'cachedToken' is not concurrency-safe
because it is nonisolated global shared mutable state
```

**解决**：使用 `nonisolated(unsafe)` 标记：
```swift
nonisolated(unsafe) private static var cachedToken: ...
```

### 坑 9：SourceKit IDE 诊断 vs 实际编译

SourceKit 持续报 `No such module 'DevAppCore'` 等错误，但 `swift build` 和 `xcodebuild` 都成功。

**原因**：SourceKit 对本地 SPM Package 的模块解析不完善，属于 IDE 层面问题。

**处理**：忽略这些诊断，以命令行 build 结果为准。

---

## 四、macOS 特有问题

### 坑 10：智能引号破坏 JSON

macOS 默认开启 Smart Quotes，自动将 `"` 转为 `""`。

**解决**：在 App 启动时全局禁用：
```swift
init() {
    UserDefaults.standard.set(false, forKey: "NSAutomaticQuoteSubstitutionEnabled")
    UserDefaults.standard.set(false, forKey: "NSAutomaticDashSubstitutionEnabled")
    UserDefaults.standard.set(false, forKey: "NSAutomaticTextReplacementEnabled")
    UserDefaults.standard.set(false, forKey: "NSAutomaticSpellingCorrectionEnabled")
}
```

### 坑 11：空 Query 参数导致 URL 多出 `?=`

默认的 Params tab 有一个空 `KeyValuePair(key: "")`，被加入 URL 变成 `?=`，导致服务器签名校验失败。

**解决**：
1. `buildURLRequest` 过滤空 key：`queryParams.filter { $0.isEnabled && !$0.key.isEmpty }`
2. Pre-script 重建请求时传 `queryParams: []`

### 坑 12：`{{variable}}` 模板在 Pre-script 之前解析

模板解析放在了 Pre-script 执行之前，此时环境变量还没被设置。

**解决**：将模板解析移到 Pre-script 执行之后，在最终 URLRequest 上直接替换。

### 坑 13：console.log 只打印第一个参数

Swift 的 `@convention(block) (String)` 只接收一个参数，`console.log("label:", value)` 的 `value` 被丢弃。

**解决**：用 JS wrapper 替代 native block：
```javascript
var console = {
    log: function() {
        var parts = [];
        for (var i = 0; i < arguments.length; i++) {
            parts.push(String(arguments[i]));
        }
        __nativeLog(parts.join(' '));
    }
};
```

### 坑 14：NSUndoManager 崩溃 (SIGSEGV)

TextEditor 在快速脚本执行时触发 undo stack 相关的崩溃。

**关联**：Cmd+Z (Undo) 在脚本执行后的 TextEditor 上操作时 crash。属于 SwiftUI TextEditor 已知问题。

### 坑 15：Markdown 解析器 `#` 死循环

输入 `#`（不带空格）时，不匹配 heading 也不匹配 paragraph，`i` 永远不自增。

**解决**：添加安全守卫 `if i == startI { i += 1 }`。

### 坑 16：Text Diff ZStack 无法输入

用 `opacity(0.01)` 的 TextEditor 叠在 diff 结果上方，无法获得焦点。

**解决**：改为上下分栏 — 上方可编辑 TextEditor，下方 diff 结果。

---

## 五、一键打包脚本

将以上步骤合并为完整命令（设置好钥匙串权限后无需密码）：

```bash
cd /Users/xiaobo/mac_dev_app

# 1. Archive + Export + DMG
rm -rf build/DevToolkit.xcarchive build/export
xcodebuild archive -project MacDevApp.xcodeproj -scheme MacDevApp \
  -archivePath build/DevToolkit.xcarchive \
  -destination 'generic/platform=macOS' \
  CODE_SIGN_IDENTITY="Developer ID Application: bo xiao (4257SFGRFK)" \
  DEVELOPMENT_TEAM=4257SFGRFK \
  OTHER_CODE_SIGN_FLAGS="--options runtime"

xcodebuild -exportArchive \
  -archivePath build/DevToolkit.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist build/ExportOptions.plist

rm -rf /tmp/dmg-build && mkdir -p /tmp/dmg-build
cp -R build/export/DevToolkit.app /tmp/dmg-build/
ln -s /Applications /tmp/dmg-build/Applications
rm -f ~/Desktop/DevToolkit.dmg
hdiutil create -volname "DevToolkit" \
  -srcfolder /tmp/dmg-build -ov -format UDZO ~/Desktop/DevToolkit.dmg
rm -rf /tmp/dmg-build

# 2. Notarize + Staple
xcrun notarytool submit ~/Desktop/DevToolkit.dmg \
  --keychain-profile "notarytool" --wait
xcrun stapler staple ~/Desktop/DevToolkit.dmg

echo "Done! ~/Desktop/DevToolkit.dmg"
```

---

## 六、自动更新与发布

### 发布方式

**方式一：Tag 触发自动发布**

```bash
git tag v1.1.0
git push origin v1.1.0
```

GitHub Actions 自动执行：构建 → 签名 → 公证 → Sparkle 签名 → 创建 Release → 更新 appcast.xml。

**方式二：手动触发**

GitHub repo → Actions → "Build, Notarize & Release" → Run workflow → 输入版本号。

### 用户端更新流程

1. 应用启动时 + 每小时自动检查 appcast.xml
2. 发现新版本后静默下载 ZIP
3. 验证 EdDSA 签名
4. 用户退出应用时自动替换，下次启动即为新版

### 密钥管理

- **EdDSA 公钥**：写在 Info.plist 的 `SUPublicEDKey` 字段
- **EdDSA 私钥**：存在 GitHub Secrets 的 `SPARKLE_PRIVATE_KEY`
- **Developer ID 证书**：.p12 Base64 存在 GitHub Secrets

如需重新生成 EdDSA 密钥对：

```bash
# 从 Sparkle release 获取工具
/path/to/generate_keys        # 生成新密钥对
/path/to/generate_keys -x /path/to/output  # 导出私钥
```

更新后需同步修改 Info.plist 中的公钥和 GitHub Secrets 中的私钥。

---

更新时间：2026-04-09
