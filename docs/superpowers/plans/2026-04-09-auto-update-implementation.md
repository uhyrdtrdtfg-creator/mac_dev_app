# DevToolkit 自动更新 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add silent auto-update to DevToolkit using Sparkle framework + GitHub Actions CI/CD pipeline for automated build/sign/notarize/release.

**Architecture:** Sparkle SPUUpdater runs in silent mode — checks for updates on launch + hourly polling, downloads in background, installs on quit. GitHub Actions workflow triggered by git tags or manual dispatch builds the app, signs with Developer ID, notarizes with Apple, generates Sparkle EdDSA signature, updates appcast.xml, and creates a GitHub Release.

**Tech Stack:** Sparkle 2.x (SPM), GitHub Actions (macOS runner), xcodebuild, xcrun notarytool, EdDSA signing

---

### Task 1: Generate EdDSA Key Pair

This is a prerequisite — the public key goes into Info.plist, the private key goes into GitHub Secrets.

**Files:**
- No file changes — local tool execution only

- [ ] **Step 1: Install Sparkle tools locally**

We need Sparkle's `generate_keys` and `sign_update` CLI tools. Clone and build them:

```bash
cd /tmp
git clone https://github.com/sparkle-project/Sparkle.git --depth 1
cd Sparkle
swift build -c release --product generate_keys
swift build -c release --product sign_update
```

If swift build doesn't work for these tools (they may require Xcode project build), use the pre-built binary from the latest Sparkle GitHub Release instead:

```bash
cd /tmp
curl -L -o Sparkle.tar.xz https://github.com/sparkle-project/Sparkle/releases/latest/download/Sparkle-2.7.5.tar.xz
tar -xf Sparkle.tar.xz
# Tools are in: /tmp/bin/generate_keys and /tmp/bin/sign_update
```

- [ ] **Step 2: Generate the EdDSA key pair**

```bash
/tmp/bin/generate_keys
```

This outputs:
- A **private key** stored in the macOS Keychain (retrieve it with `generate_keys -x`)
- A **public key** printed to stdout — copy this string, it looks like: `dW5pcX...base64...==`

Save both values:
```bash
# Export private key for GitHub Secrets
/tmp/bin/generate_keys -x
# Copy the output — this is SPARKLE_PRIVATE_KEY

# The public key was printed during generation — this is SUPublicEDKey
```

- [ ] **Step 3: Record the keys**

Write down:
- **Public key** → will be added to Info.plist as `SUPublicEDKey` in Task 2
- **Private key** → will be added to GitHub Secrets as `SPARKLE_PRIVATE_KEY` in Task 5

- [ ] **Step 4: Commit (no file changes)**

No commit needed — keys are stored externally (Keychain + GitHub Secrets).

---

### Task 2: Add Sparkle Dependency and Configure Info.plist

**Files:**
- Modify: `project.yml`
- Modify: `MacDevApp/Info.plist`

- [ ] **Step 1: Add Sparkle SPM package to project.yml**

In `project.yml`, add Sparkle to the `packages` section and as a dependency of the main target:

```yaml
packages:
  DevAppCore:
    path: Packages/DevAppCore
  CryptoTools:
    path: Packages/CryptoTools
  ConversionTools:
    path: Packages/ConversionTools
  APIClient:
    path: Packages/APIClient
  Sparkle:
    url: https://github.com/sparkle-project/Sparkle
    from: "2.6.0"
```

And add to the target dependencies:

```yaml
    dependencies:
      - package: DevAppCore
      - package: CryptoTools
      - package: ConversionTools
      - package: APIClient
      - package: Sparkle
```

- [ ] **Step 2: Add Sparkle keys to Info.plist**

Add these keys to `MacDevApp/Info.plist` inside the `<dict>`:

```xml
    <key>SUFeedURL</key>
    <string>https://raw.githubusercontent.com/xiaobo1107/mac_dev_app/main/appcast.xml</string>
    <key>SUPublicEDKey</key>
    <string>PASTE_PUBLIC_KEY_FROM_TASK_1_HERE</string>
    <key>SUEnableAutomaticChecks</key>
    <true/>
```

Note: Replace `xiaobo1107/mac_dev_app` with the actual GitHub owner/repo if different. Replace `PASTE_PUBLIC_KEY_FROM_TASK_1_HERE` with the actual public key from Task 1.

- [ ] **Step 3: Regenerate Xcode project**

```bash
cd /Users/xiaobo/mac_dev_app
xcodegen generate
```

- [ ] **Step 4: Verify Sparkle resolves**

```bash
cd /Users/xiaobo/mac_dev_app
xcodebuild -resolvePackageDependencies -project MacDevApp.xcodeproj -scheme MacDevApp
```

Expected: resolves successfully with Sparkle downloaded.

- [ ] **Step 5: Commit**

```bash
git add project.yml MacDevApp/Info.plist
git commit -m "feat: add Sparkle dependency and update feed configuration"
```

---

### Task 3: Integrate SPUUpdater in the App

**Files:**
- Modify: `MacDevApp/MacDevAppApp.swift`

- [ ] **Step 1: Add UpdaterManager and integrate into app**

Edit `MacDevApp/MacDevAppApp.swift` to the following:

```swift
import SwiftUI
import SwiftData
import Sparkle
import DevAppCore
import CryptoTools
import ConversionTools
import APIClient

@MainActor
final class UpdaterManager {
    private let controller: SPUStandardUpdaterController

    init() {
        self.controller = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        self.controller.updater.automaticallyChecksForUpdates = true
        self.controller.updater.automaticallyDownloadsUpdates = true
        self.controller.updater.updateCheckInterval = 3600 // 1 hour
    }

    func start() {
        do {
            try controller.updater.start()
        } catch {
            print("Sparkle updater failed to start: \(error)")
        }
    }
}

@main
struct MacDevAppApp: App {
    private let updaterManager = UpdaterManager()

    init() {
        // Disable smart quotes/dashes globally — critical for a developer tool
        UserDefaults.standard.set(false, forKey: "NSAutomaticQuoteSubstitutionEnabled")
        UserDefaults.standard.set(false, forKey: "NSAutomaticDashSubstitutionEnabled")
        UserDefaults.standard.set(false, forKey: "NSAutomaticTextReplacementEnabled")
        UserDefaults.standard.set(false, forKey: "NSAutomaticSpellingCorrectionEnabled")
        UserDefaults.standard.set(false, forKey: "NSAutomaticTextCompletionEnabled")

        updaterManager.start()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            HTTPRequestModel.self,
            HTTPCollectionModel.self,
            HTTPHistoryModel.self,
            SavedRequestModel.self
        ])
        .windowStyle(.automatic)
        .defaultSize(width: 1100, height: 750)
    }
}
```

Key points:
- `SPUStandardUpdaterController` must be retained (stored as property)
- `startingUpdater: false` — we call `start()` manually after configuration
- `automaticallyDownloadsUpdates = true` — silent download
- `updateCheckInterval = 3600` — hourly polling
- Sparkle handles "install on quit" automatically in this mode

- [ ] **Step 2: Build and verify**

```bash
cd /Users/xiaobo/mac_dev_app
xcodebuild build -project MacDevApp.xcodeproj -scheme MacDevApp -destination 'platform=macOS' 2>&1 | tail -5
```

Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add MacDevApp/MacDevAppApp.swift
git commit -m "feat: integrate Sparkle silent auto-updater"
```

---

### Task 4: Create Initial appcast.xml

**Files:**
- Create: `appcast.xml` (repo root)

- [ ] **Step 1: Create empty appcast.xml**

Create `appcast.xml` at the repo root with an empty channel (GitHub Actions will populate it):

```xml
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
  <channel>
    <title>DevToolkit Updates</title>
    <language>en</language>
  </channel>
</rss>
```

- [ ] **Step 2: Commit**

```bash
git add appcast.xml
git commit -m "feat: add initial appcast.xml for Sparkle updates"
```

---

### Task 5: Create GitHub Actions Release Workflow

**Files:**
- Create: `.github/workflows/release.yml`
- Create: `scripts/update_appcast.py`

- [ ] **Step 1: Create the update_appcast.py helper script**

This script inserts a new version entry into appcast.xml. Create `scripts/update_appcast.py`:

```python
#!/usr/bin/env python3
"""Insert a new release item into appcast.xml."""
import sys
import xml.etree.ElementTree as ET
from datetime import datetime, timezone

def main():
    if len(sys.argv) != 6:
        print("Usage: update_appcast.py <appcast_path> <version> <build_number> <ed_signature> <length>")
        sys.exit(1)

    appcast_path, version, build_number, ed_signature, length = sys.argv[1:]

    # GitHub repo info from environment
    import os
    repo = os.environ.get("GITHUB_REPOSITORY", "xiaobo1107/mac_dev_app")

    download_url = f"https://github.com/{repo}/releases/download/v{version}/DevToolkit.zip"
    pub_date = datetime.now(timezone.utc).strftime("%a, %d %b %Y %H:%M:%S %z")

    sparkle_ns = "http://www.andymatuschak.org/xml-namespaces/sparkle"
    ET.register_namespace("sparkle", sparkle_ns)
    ET.register_namespace("dc", "http://purl.org/dc/elements/1.1/")

    tree = ET.parse(appcast_path)
    channel = tree.find("channel")

    item = ET.SubElement(channel, "item")
    ET.SubElement(item, "title").text = f"Version {version}"
    ET.SubElement(item, f"{{{sparkle_ns}}}version").text = build_number
    ET.SubElement(item, f"{{{sparkle_ns}}}shortVersionString").text = version
    ET.SubElement(item, f"{{{sparkle_ns}}}minimumSystemVersion").text = "26.0"
    ET.SubElement(item, "pubDate").text = pub_date

    enclosure = ET.SubElement(item, "enclosure")
    enclosure.set("url", download_url)
    enclosure.set("type", "application/octet-stream")
    enclosure.set(f"{{{sparkle_ns}}}edSignature", ed_signature)
    enclosure.set("length", length)

    ET.indent(tree, space="    ")
    tree.write(appcast_path, encoding="utf-8", xml_declaration=True)

if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Create the GitHub Actions workflow**

Create `.github/workflows/release.yml`:

```yaml
name: Build, Notarize & Release

on:
  push:
    tags: ['v*.*.*']
  workflow_dispatch:
    inputs:
      version:
        description: 'Version number (e.g. 1.1.0)'
        required: true

permissions:
  contents: write

env:
  APP_NAME: DevToolkit
  SCHEME: MacDevApp
  PROJECT: MacDevApp.xcodeproj

jobs:
  release:
    runs-on: macos-15
    steps:
      - name: Checkout
        uses: actions/checkout@v4
        with:
          fetch-depth: 0
          token: ${{ secrets.GITHUB_TOKEN }}

      - name: Determine version
        id: version
        run: |
          if [ "${{ github.event_name }}" = "workflow_dispatch" ]; then
            VERSION="${{ github.event.inputs.version }}"
          else
            VERSION="${GITHUB_REF_NAME#v}"
          fi
          # Build number: total commit count
          BUILD_NUMBER=$(git rev-list --count HEAD)
          echo "version=$VERSION" >> "$GITHUB_OUTPUT"
          echo "build_number=$BUILD_NUMBER" >> "$GITHUB_OUTPUT"
          echo "tag=v$VERSION" >> "$GITHUB_OUTPUT"
          echo "Version: $VERSION, Build: $BUILD_NUMBER"

      - name: Install certificates
        env:
          P12_BASE64: ${{ secrets.DEVELOPER_ID_CERTIFICATE_P12 }}
          P12_PASSWORD: ${{ secrets.DEVELOPER_ID_CERTIFICATE_PASSWORD }}
        run: |
          # Create temporary keychain
          KEYCHAIN_PATH="$RUNNER_TEMP/build.keychain-db"
          KEYCHAIN_PASSWORD="$(openssl rand -base64 32)"

          security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
          security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
          security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

          # Import certificate
          CERT_PATH="$RUNNER_TEMP/certificate.p12"
          echo "$P12_BASE64" | base64 --decode > "$CERT_PATH"
          security import "$CERT_PATH" -P "$P12_PASSWORD" \
            -A -t cert -f pkcs12 \
            -k "$KEYCHAIN_PATH"

          # Allow codesign access without prompts
          security set-key-partition-list -S apple-tool:,apple:,codesign: \
            -s -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"

          # Add to search list
          security list-keychains -d user -s "$KEYCHAIN_PATH" $(security list-keychains -d user | tr -d '"')

      - name: Setup notarytool credentials
        env:
          APPLE_ID: ${{ secrets.APPLE_ID }}
          APPLE_ID_PASSWORD: ${{ secrets.APPLE_ID_PASSWORD }}
          APPLE_TEAM_ID: ${{ secrets.APPLE_TEAM_ID }}
        run: |
          xcrun notarytool store-credentials "notarytool" \
            --apple-id "$APPLE_ID" \
            --password "$APPLE_ID_PASSWORD" \
            --team-id "$APPLE_TEAM_ID"

      - name: Resolve dependencies
        run: |
          xcodebuild -resolvePackageDependencies \
            -project "$PROJECT" -scheme "$SCHEME"

      - name: Archive
        env:
          VERSION: ${{ steps.version.outputs.version }}
          BUILD_NUMBER: ${{ steps.version.outputs.build_number }}
        run: |
          xcodebuild archive \
            -project "$PROJECT" \
            -scheme "$SCHEME" \
            -archivePath build/$APP_NAME.xcarchive \
            -destination 'generic/platform=macOS' \
            CODE_SIGN_IDENTITY="Developer ID Application" \
            DEVELOPMENT_TEAM=${{ secrets.APPLE_TEAM_ID }} \
            OTHER_CODE_SIGN_FLAGS="--options runtime" \
            MARKETING_VERSION="$VERSION" \
            CURRENT_PROJECT_VERSION="$BUILD_NUMBER"

      - name: Export
        run: |
          xcodebuild -exportArchive \
            -archivePath build/$APP_NAME.xcarchive \
            -exportPath build/export \
            -exportOptionsPlist build/ExportOptions.plist

      - name: Notarize
        run: |
          # ZIP for notarization
          cd build/export
          zip -r -y "../$APP_NAME-notarize.zip" "$APP_NAME.app"
          cd ../..

          # Submit and wait
          xcrun notarytool submit "build/$APP_NAME-notarize.zip" \
            --keychain-profile "notarytool" --wait

          # Staple the app
          xcrun stapler staple "build/export/$APP_NAME.app"

      - name: Create release ZIP
        run: |
          cd build/export
          zip -r -y "../$APP_NAME.zip" "$APP_NAME.app"
          cd ../..
          echo "ZIP_PATH=build/$APP_NAME.zip" >> "$GITHUB_ENV"

      - name: Install Sparkle tools
        run: |
          SPARKLE_VERSION="2.7.5"
          curl -L -o /tmp/Sparkle.tar.xz \
            "https://github.com/sparkle-project/Sparkle/releases/download/$SPARKLE_VERSION/Sparkle-$SPARKLE_VERSION.tar.xz"
          mkdir -p /tmp/sparkle
          tar -xf /tmp/Sparkle.tar.xz -C /tmp/sparkle
          echo "SPARKLE_BIN=/tmp/sparkle/bin" >> "$GITHUB_ENV"

      - name: Sign update with Sparkle EdDSA
        env:
          SPARKLE_PRIVATE_KEY: ${{ secrets.SPARKLE_PRIVATE_KEY }}
        run: |
          # sign_update reads the private key from env var SPARKLE_KEY or stdin
          SIGN_OUTPUT=$(echo "$SPARKLE_PRIVATE_KEY" | "$SPARKLE_BIN/sign_update" "$ZIP_PATH")
          echo "Sparkle signature output: $SIGN_OUTPUT"

          # Parse: sparkle:edSignature="..." length="..."
          ED_SIGNATURE=$(echo "$SIGN_OUTPUT" | sed -n 's/.*sparkle:edSignature="\([^"]*\)".*/\1/p')
          LENGTH=$(echo "$SIGN_OUTPUT" | sed -n 's/.*length="\([^"]*\)".*/\1/p')

          echo "ed_signature=$ED_SIGNATURE" >> "$GITHUB_ENV"
          echo "length=$LENGTH" >> "$GITHUB_ENV"

      - name: Update appcast.xml
        env:
          VERSION: ${{ steps.version.outputs.version }}
          BUILD_NUMBER: ${{ steps.version.outputs.build_number }}
        run: |
          python3 scripts/update_appcast.py appcast.xml \
            "$VERSION" "$BUILD_NUMBER" "$ed_signature" "$length"
          cat appcast.xml

      - name: Create tag (if manual dispatch)
        if: github.event_name == 'workflow_dispatch'
        env:
          TAG: ${{ steps.version.outputs.tag }}
        run: |
          git tag "$TAG"
          git push origin "$TAG"

      - name: Commit appcast.xml
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add appcast.xml
          git diff --cached --quiet && echo "No changes to commit" || \
            git commit -m "chore: update appcast.xml for v${{ steps.version.outputs.version }}"
          git push origin HEAD:main

      - name: Create GitHub Release
        env:
          GH_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          TAG: ${{ steps.version.outputs.tag }}
          VERSION: ${{ steps.version.outputs.version }}
        run: |
          gh release create "$TAG" "$ZIP_PATH" \
            --title "DevToolkit v$VERSION" \
            --generate-notes

      - name: Cleanup keychain
        if: always()
        run: |
          KEYCHAIN_PATH="$RUNNER_TEMP/build.keychain-db"
          security delete-keychain "$KEYCHAIN_PATH" 2>/dev/null || true
```

- [ ] **Step 3: Verify workflow YAML syntax**

```bash
cd /Users/xiaobo/mac_dev_app
python3 -c "import yaml; yaml.safe_load(open('.github/workflows/release.yml'))" 2>/dev/null || \
  python3 -c "
import json, re
content = open('.github/workflows/release.yml').read()
print('YAML file created, length:', len(content), 'bytes')
print('Has on: trigger:', 'on:' in content)
print('Has jobs:', 'jobs:' in content)
print('Has release job:', 'release:' in content)
"
```

- [ ] **Step 4: Commit**

```bash
git add .github/workflows/release.yml scripts/update_appcast.py
git commit -m "feat: add GitHub Actions release workflow with notarization and Sparkle signing"
```

---

### Task 6: Configure GitHub Secrets

This task is manual — the developer must perform these steps in the GitHub web UI.

**Files:**
- No file changes

- [ ] **Step 1: Export the Developer ID certificate as .p12**

On the local Mac:
1. Open **Keychain Access**
2. Find **Developer ID Application: bo xiao (4257SFGRFK)**
3. Right-click → **Export Items...** → Save as `.p12` with a password
4. Base64 encode it:

```bash
base64 -i ~/Desktop/developer_id.p12 | pbcopy
```

- [ ] **Step 2: Get the Sparkle private key**

```bash
/tmp/bin/generate_keys -x
# Copy the output
```

- [ ] **Step 3: Add secrets to GitHub**

Go to the GitHub repo → Settings → Secrets and variables → Actions → New repository secret.

Add each secret:

| Name | Value |
|------|-------|
| `DEVELOPER_ID_CERTIFICATE_P12` | Base64 encoded .p12 from Step 1 |
| `DEVELOPER_ID_CERTIFICATE_PASSWORD` | The password used when exporting .p12 |
| `APPLE_ID` | Your Apple ID email |
| `APPLE_ID_PASSWORD` | App-Specific Password (from appleid.apple.com) |
| `APPLE_TEAM_ID` | `4257SFGRFK` |
| `SPARKLE_PRIVATE_KEY` | Private key from Step 2 |

- [ ] **Step 4: Verify secrets are configured**

Go to repo → Settings → Secrets → verify all 6 secrets are listed.

---

### Task 7: End-to-End Test

**Files:**
- No file changes (testing only)

- [ ] **Step 1: Push all changes to GitHub**

```bash
git push origin main
```

- [ ] **Step 2: Test manual workflow dispatch**

Go to GitHub repo → Actions → "Build, Notarize & Release" → Run workflow.

Enter version: `1.0.1`

Monitor the workflow run. Expected: all steps pass, a new Release `v1.0.1` appears with `DevToolkit.zip`, and `appcast.xml` is updated with the new version entry.

- [ ] **Step 3: Verify appcast.xml was updated**

```bash
git pull origin main
cat appcast.xml
```

Expected: contains an `<item>` for version `1.0.1` with valid `sparkle:edSignature` and `length` attributes.

- [ ] **Step 4: Test tag-triggered release**

```bash
git tag v1.0.2
git push origin v1.0.2
```

Monitor the workflow. Expected: same result as manual dispatch.

- [ ] **Step 5: Verify the app can detect updates**

1. Build and run the app locally (with version 1.0.0)
2. The Sparkle updater should check the appcast.xml
3. It should detect that 1.0.1/1.0.2 is available
4. Check Console.app for Sparkle-related log messages to confirm it's working

---

### Task 8: Final Cleanup and Documentation

**Files:**
- Modify: `docs/SIGNING_AND_PACKAGING_GUIDE.md` (add auto-update section)

- [ ] **Step 1: Add auto-update release instructions to the guide**

Append a new section to `docs/SIGNING_AND_PACKAGING_GUIDE.md`:

```markdown
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
/path/to/generate_keys -x     # 导出私钥
```

更新后需同步修改 Info.plist 中的公钥和 GitHub Secrets 中的私钥。
```

- [ ] **Step 2: Commit**

```bash
git add docs/SIGNING_AND_PACKAGING_GUIDE.md
git commit -m "docs: add auto-update release instructions"
```
