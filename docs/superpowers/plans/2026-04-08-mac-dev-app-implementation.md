# Mac Dev App Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native macOS 26 developer toolkit app with crypto tools, HTTP client, and conversion utilities using SwiftUI + Liquid Glass.

**Architecture:** Modular Swift Package monorepo. Main app target provides sidebar navigation and tool routing. Four local packages — DevAppCore (shared protocol/views), CryptoTools, ConversionTools, APIClient — each expose tool implementations conforming to a shared `DevTool` protocol. Packages depend only on DevAppCore, never on each other.

**Tech Stack:** Swift, SwiftUI (macOS 26+), CryptoKit, Security.framework, CommonCrypto (C bridge), URLSession, SwiftData, String Catalog (.xcstrings), Xcode + SPM.

**Parallelization:** After Phase 1 (Tasks 1-3), Phase 2 (Tasks 4-7) and Phase 3 (Tasks 8-11) can run in parallel. Phase 4 (Tasks 12-16) is sequential internally but can run in parallel with Phases 2-3. Task 17 runs last.

---

## Phase 1: Foundation

### Task 1: Project Scaffolding

**Files:**
- Create: `MacDevApp/MacDevAppApp.swift`
- Create: `MacDevApp/ContentView.swift`
- Create: `MacDevApp/Info.plist`
- Create: `Packages/DevAppCore/Package.swift`
- Create: `Packages/DevAppCore/Sources/DevAppCore/DevTool.swift`
- Create: `Packages/CryptoTools/Package.swift`
- Create: `Packages/CryptoTools/Sources/CryptoTools/CryptoToolsExports.swift`
- Create: `Packages/ConversionTools/Package.swift`
- Create: `Packages/ConversionTools/Sources/ConversionTools/ConversionToolsExports.swift`
- Create: `Packages/APIClient/Package.swift`
- Create: `Packages/APIClient/Sources/APIClient/APIClientExports.swift`
- Create: `project.yml` (xcodegen spec)

- [ ] **Step 1: Install xcodegen if needed**

Run: `brew list xcodegen || brew install xcodegen`
Expected: xcodegen available at command line

- [ ] **Step 2: Create DevAppCore package**

Create `Packages/DevAppCore/Package.swift`:

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "DevAppCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "DevAppCore", targets: ["DevAppCore"])
    ],
    targets: [
        .target(name: "DevAppCore"),
        .testTarget(name: "DevAppCoreTests", dependencies: ["DevAppCore"])
    ]
)
```

Create `Packages/DevAppCore/Sources/DevAppCore/DevTool.swift`:

```swift
import SwiftUI

public enum ToolCategory: String, CaseIterable, Identifiable, Sendable {
    case crypto
    case apiClient
    case conversion

    public var id: String { rawValue }

    public var displayName: LocalizedStringKey {
        switch self {
        case .crypto: "Crypto"
        case .apiClient: "API Client"
        case .conversion: "Conversion"
        }
    }

    public var icon: String {
        switch self {
        case .crypto: "lock.shield"
        case .apiClient: "network"
        case .conversion: "arrow.2.squarepath"
        }
    }
}

public protocol DevTool: Identifiable, View {
    var id: String { get }
    var name: LocalizedStringKey { get }
    var icon: String { get }
    var category: ToolCategory { get }
    var searchKeywords: [String] { get }
}
```

Create empty test file `Packages/DevAppCore/Tests/DevAppCoreTests/DevAppCoreTests.swift`:

```swift
import Testing
@testable import DevAppCore

@Test func toolCategoryHasAllCases() {
    #expect(ToolCategory.allCases.count == 3)
}
```

- [ ] **Step 3: Create CryptoTools package**

Create `Packages/CryptoTools/Package.swift`:

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "CryptoTools",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "CryptoTools", targets: ["CryptoTools"])
    ],
    dependencies: [
        .package(path: "../DevAppCore")
    ],
    targets: [
        .target(
            name: "CCommonCrypto",
            cSettings: [.headerSearchPath("include")]
        ),
        .target(
            name: "CryptoTools",
            dependencies: ["DevAppCore", "CCommonCrypto"]
        ),
        .testTarget(name: "CryptoToolsTests", dependencies: ["CryptoTools"])
    ]
)
```

Create CommonCrypto C bridge — `Packages/CryptoTools/Sources/CCommonCrypto/include/module.modulemap`:

```
module CCommonCrypto {
    header "shim.h"
    link "System"
    export *
}
```

Create `Packages/CryptoTools/Sources/CCommonCrypto/include/shim.h`:

```c
#pragma once
#include <CommonCrypto/CommonCrypto.h>
```

Create `Packages/CryptoTools/Sources/CCommonCrypto/shim.c`:

```c
// Empty file required by SPM for C targets
```

Create `Packages/CryptoTools/Sources/CryptoTools/CryptoToolsExports.swift`:

```swift
// CryptoTools module — re-exports for convenience
@_exported import DevAppCore
```

Create `Packages/CryptoTools/Tests/CryptoToolsTests/CryptoToolsTests.swift`:

```swift
import Testing
@testable import CryptoTools

@Test func moduleImports() {
    // Verify CryptoTools compiles and links correctly
    #expect(true)
}
```

- [ ] **Step 4: Create ConversionTools package**

Create `Packages/ConversionTools/Package.swift`:

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "ConversionTools",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ConversionTools", targets: ["ConversionTools"])
    ],
    dependencies: [
        .package(path: "../DevAppCore")
    ],
    targets: [
        .target(name: "ConversionTools", dependencies: ["DevAppCore"]),
        .testTarget(name: "ConversionToolsTests", dependencies: ["ConversionTools"])
    ]
)
```

Create `Packages/ConversionTools/Sources/ConversionTools/ConversionToolsExports.swift`:

```swift
@_exported import DevAppCore
```

Create `Packages/ConversionTools/Tests/ConversionToolsTests/ConversionToolsTests.swift`:

```swift
import Testing
@testable import ConversionTools

@Test func moduleImports() {
    #expect(true)
}
```

- [ ] **Step 5: Create APIClient package**

Create `Packages/APIClient/Package.swift`:

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "APIClient",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "APIClient", targets: ["APIClient"])
    ],
    dependencies: [
        .package(path: "../DevAppCore")
    ],
    targets: [
        .target(name: "APIClient", dependencies: ["DevAppCore"]),
        .testTarget(name: "APIClientTests", dependencies: ["APIClient"])
    ]
)
```

Create `Packages/APIClient/Sources/APIClient/APIClientExports.swift`:

```swift
@_exported import DevAppCore
```

Create `Packages/APIClient/Tests/APIClientTests/APIClientTests.swift`:

```swift
import Testing
@testable import APIClient

@Test func moduleImports() {
    #expect(true)
}
```

- [ ] **Step 6: Create xcodegen project spec and generate Xcode project**

Create `project.yml`:

```yaml
name: MacDevApp
options:
  bundleIdPrefix: com.macdevapp
  deploymentTarget:
    macOS: "26.0"
  xcodeVersion: "16.0"
  createIntermediateGroups: true

packages:
  DevAppCore:
    path: Packages/DevAppCore
  CryptoTools:
    path: Packages/CryptoTools
  ConversionTools:
    path: Packages/ConversionTools
  APIClient:
    path: Packages/APIClient

targets:
  MacDevApp:
    type: application
    platform: macOS
    sources:
      - MacDevApp
    dependencies:
      - package: DevAppCore
      - package: CryptoTools
      - package: ConversionTools
      - package: APIClient
    settings:
      PRODUCT_BUNDLE_IDENTIFIER: com.macdevapp.MacDevApp
      PRODUCT_NAME: Mac Dev App
      MARKETING_VERSION: "1.0.0"
      CURRENT_PROJECT_VERSION: 1
      SWIFT_VERSION: "6.0"
      MACOSX_DEPLOYMENT_TARGET: "26.0"
      INFOPLIST_FILE: MacDevApp/Info.plist
      GENERATE_INFOPLIST_FILE: false
```

Create `MacDevApp/Info.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>$(EXECUTABLE_NAME)</string>
    <key>CFBundleIdentifier</key>
    <string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>$(PRODUCT_NAME)</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$(MARKETING_VERSION)</string>
    <key>CFBundleVersion</key>
    <string>$(CURRENT_PROJECT_VERSION)</string>
    <key>LSMinimumSystemVersion</key>
    <string>$(MACOSX_DEPLOYMENT_TARGET)</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>zh-Hans</string>
    </array>
</dict>
</plist>
```

Create `MacDevApp/MacDevAppApp.swift`:

```swift
import SwiftUI
import DevAppCore
import CryptoTools
import ConversionTools
import APIClient

@main
struct MacDevAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.automatic)
    }
}
```

Create `MacDevApp/ContentView.swift`:

```swift
import SwiftUI
import DevAppCore

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            Text("Sidebar")
        } detail: {
            Text("Select a tool")
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}
```

Run: `cd /Users/xiaobo/mac_dev_app && xcodegen generate`
Expected: `⚙️  Generated MacDevApp.xcodeproj`

- [ ] **Step 7: Verify all packages compile**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/DevAppCore && swift build`
Expected: Build Succeeded

Run: `cd /Users/xiaobo/mac_dev_app/Packages/CryptoTools && swift build`
Expected: Build Succeeded

Run: `cd /Users/xiaobo/mac_dev_app/Packages/ConversionTools && swift build`
Expected: Build Succeeded

Run: `cd /Users/xiaobo/mac_dev_app/Packages/APIClient && swift build`
Expected: Build Succeeded

- [ ] **Step 8: Run all package tests**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/DevAppCore && swift test`
Expected: All tests passed

Run: `cd /Users/xiaobo/mac_dev_app/Packages/CryptoTools && swift test`
Expected: All tests passed

- [ ] **Step 9: Add .gitignore and commit**

Create `.gitignore`:

```
# Xcode
*.xcodeproj/xcuserdata/
*.xcworkspace/xcuserdata/
DerivedData/
*.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/
build/

# Swift Package Manager
.build/
.swiftpm/

# macOS
.DS_Store

# Superpowers
.superpowers/
```

Run:
```bash
git add .gitignore project.yml MacDevApp/ Packages/
git commit -m "feat: scaffold project with 4 Swift packages and xcodegen spec"
```

---

### Task 2: DevAppCore — Shared Components

**Files:**
- Create: `Packages/DevAppCore/Sources/DevAppCore/ToolDescriptor.swift`
- Create: `Packages/DevAppCore/Sources/DevAppCore/InputOutputView.swift`
- Create: `Packages/DevAppCore/Sources/DevAppCore/CopyButton.swift`
- Create: `Packages/DevAppCore/Sources/DevAppCore/HexUtils.swift`
- Modify: `Packages/DevAppCore/Sources/DevAppCore/DevTool.swift`
- Test: `Packages/DevAppCore/Tests/DevAppCoreTests/HexUtilsTests.swift`

- [ ] **Step 1: Write failing tests for HexUtils**

Create `Packages/DevAppCore/Tests/DevAppCoreTests/HexUtilsTests.swift`:

```swift
import Testing
import Foundation
@testable import DevAppCore

@Test func dataToHexLowercase() {
    let data = Data([0xDE, 0xAD, 0xBE, 0xEF])
    #expect(data.hexString(uppercase: false) == "deadbeef")
}

@Test func dataToHexUppercase() {
    let data = Data([0xDE, 0xAD, 0xBE, 0xEF])
    #expect(data.hexString(uppercase: true) == "DEADBEEF")
}

@Test func hexToData() {
    let hex = "deadbeef"
    let data = Data(hexString: hex)
    #expect(data == Data([0xDE, 0xAD, 0xBE, 0xEF]))
}

@Test func hexToDataUppercase() {
    let hex = "DEADBEEF"
    let data = Data(hexString: hex)
    #expect(data == Data([0xDE, 0xAD, 0xBE, 0xEF]))
}

@Test func hexToDataInvalidReturnsNil() {
    let hex = "zzzz"
    let data = Data(hexString: hex)
    #expect(data == nil)
}

@Test func hexToDataOddLengthReturnsNil() {
    let hex = "abc"
    let data = Data(hexString: hex)
    #expect(data == nil)
}

@Test func emptyDataToHex() {
    let data = Data()
    #expect(data.hexString(uppercase: false) == "")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/DevAppCore && swift test`
Expected: FAIL — `hexString` and `Data(hexString:)` not defined

- [ ] **Step 3: Implement HexUtils**

Create `Packages/DevAppCore/Sources/DevAppCore/HexUtils.swift`:

```swift
import Foundation

extension Data {
    public func hexString(uppercase: Bool = false) -> String {
        let format = uppercase ? "%02X" : "%02x"
        return map { String(format: format, $0) }.joined()
    }

    public init?(hexString: String) {
        let hex = hexString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hex.count.isMultiple(of: 2) else { return nil }

        var data = Data(capacity: hex.count / 2)
        var index = hex.startIndex
        while index < hex.endIndex {
            let nextIndex = hex.index(index, offsetBy: 2)
            guard let byte = UInt8(hex[index..<nextIndex], radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }
        self = data
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/DevAppCore && swift test`
Expected: All tests passed

- [ ] **Step 5: Create ToolDescriptor for sidebar registration**

Create `Packages/DevAppCore/Sources/DevAppCore/ToolDescriptor.swift`:

```swift
import SwiftUI

public struct ToolDescriptor: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: LocalizedStringKey
    public let icon: String
    public let category: ToolCategory
    public let searchKeywords: [String]

    public init(
        id: String,
        name: LocalizedStringKey,
        icon: String,
        category: ToolCategory,
        searchKeywords: [String]
    ) {
        self.id = id
        self.name = name
        self.icon = icon
        self.category = category
        self.searchKeywords = searchKeywords
    }

    public static func == (lhs: ToolDescriptor, rhs: ToolDescriptor) -> Bool {
        lhs.id == rhs.id
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
```

- [ ] **Step 6: Create InputOutputView shared component**

Create `Packages/DevAppCore/Sources/DevAppCore/InputOutputView.swift`:

```swift
import SwiftUI

public struct InputOutputView<ConfigContent: View>: View {
    let title: LocalizedStringKey
    let description: LocalizedStringKey
    @Binding var input: String
    @Binding var output: String
    let inputLabel: LocalizedStringKey
    let outputLabel: LocalizedStringKey
    let configContent: () -> ConfigContent

    public init(
        title: LocalizedStringKey,
        description: LocalizedStringKey,
        input: Binding<String>,
        output: Binding<String>,
        inputLabel: LocalizedStringKey = "Input",
        outputLabel: LocalizedStringKey = "Output",
        @ViewBuilder configContent: @escaping () -> ConfigContent = { EmptyView() }
    ) {
        self.title = title
        self.description = description
        self._input = input
        self._output = output
        self.inputLabel = inputLabel
        self.outputLabel = outputLabel
        self.configContent = configContent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Config area
            configContent()

            // Input / Output panels
            HStack(spacing: 12) {
                // Input panel
                VStack(alignment: .leading, spacing: 4) {
                    Text(inputLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    TextEditor(text: $input)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Output panel
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(outputLabel)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        CopyButton(text: output)
                    }
                    TextEditor(text: .constant(output))
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
    }
}
```

- [ ] **Step 7: Create CopyButton**

Create `Packages/DevAppCore/Sources/DevAppCore/CopyButton.swift`:

```swift
import SwiftUI
import AppKit

public struct CopyButton: View {
    let text: String
    @State private var copied = false

    public init(text: String) {
        self.text = text
    }

    public var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied = true
            Task {
                try? await Task.sleep(for: .seconds(1.5))
                copied = false
            }
        } label: {
            Label(
                copied ? "Copied" : "Copy",
                systemImage: copied ? "checkmark" : "doc.on.doc"
            )
            .font(.caption)
        }
        .buttonStyle(.borderless)
        .foregroundStyle(copied ? .green : .secondary)
    }
}
```

- [ ] **Step 8: Verify build and commit**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/DevAppCore && swift build && swift test`
Expected: Build Succeeded, All tests passed

```bash
git add Packages/DevAppCore/
git commit -m "feat: add DevAppCore shared components — HexUtils, InputOutputView, CopyButton, ToolDescriptor"
```

---

### Task 3: App Shell — Sidebar Navigation & Search

**Files:**
- Create: `MacDevApp/Navigation/ToolRegistry.swift`
- Create: `MacDevApp/Navigation/SidebarView.swift`
- Modify: `MacDevApp/ContentView.swift`
- Modify: `MacDevApp/MacDevAppApp.swift`

- [ ] **Step 1: Create ToolRegistry**

Create `MacDevApp/Navigation/ToolRegistry.swift`:

```swift
import SwiftUI
import DevAppCore

@Observable
final class ToolRegistry {
    private(set) var descriptors: [ToolDescriptor] = []
    var selectedToolID: String?
    var searchText: String = ""

    var filteredDescriptors: [ToolDescriptor] {
        guard !searchText.isEmpty else { return descriptors }
        let query = searchText.lowercased()
        return descriptors.filter { descriptor in
            descriptor.searchKeywords.contains { $0.lowercased().contains(query) }
        }
    }

    func descriptors(for category: ToolCategory) -> [ToolDescriptor] {
        filteredDescriptors.filter { $0.category == category }
    }

    func register(_ descriptor: ToolDescriptor) {
        guard !descriptors.contains(where: { $0.id == descriptor.id }) else { return }
        descriptors.append(descriptor)
    }

    func registerAll(_ newDescriptors: [ToolDescriptor]) {
        for d in newDescriptors { register(d) }
    }
}
```

- [ ] **Step 2: Create SidebarView**

Create `MacDevApp/Navigation/SidebarView.swift`:

```swift
import SwiftUI
import DevAppCore

struct SidebarView: View {
    @Bindable var registry: ToolRegistry

    var body: some View {
        List(selection: $registry.selectedToolID) {
            ForEach(ToolCategory.allCases) { category in
                let tools = registry.descriptors(for: category)
                if !tools.isEmpty {
                    Section(category.displayName) {
                        ForEach(tools) { descriptor in
                            Label(descriptor.name, systemImage: descriptor.icon)
                                .tag(descriptor.id)
                        }
                    }
                }
            }
        }
        .searchable(text: $registry.searchText, prompt: "Search tools...")
        .navigationTitle("Mac Dev App")
    }
}
```

- [ ] **Step 3: Update ContentView with navigation routing**

Replace `MacDevApp/ContentView.swift`:

```swift
import SwiftUI
import DevAppCore
import CryptoTools
import ConversionTools
import APIClient

struct ContentView: View {
    @State private var registry = ToolRegistry()

    var body: some View {
        NavigationSplitView {
            SidebarView(registry: registry)
        } detail: {
            if let toolID = registry.selectedToolID {
                toolView(for: toolID)
            } else {
                ContentUnavailableView(
                    "Select a Tool",
                    systemImage: "wrench.and.screwdriver",
                    description: Text("Choose a tool from the sidebar to get started.")
                )
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            registerAllTools()
        }
    }

    private func registerAllTools() {
        // Tools will be registered as they are implemented.
        // Each module provides a static list of ToolDescriptors.
    }

    @ViewBuilder
    private func toolView(for id: String) -> some View {
        // Tool views will be added as they are implemented.
        ContentUnavailableView(
            "Tool Not Found",
            systemImage: "questionmark.circle",
            description: Text("Tool '\(id)' is not yet implemented.")
        )
    }
}
```

- [ ] **Step 4: Build and verify**

Run: `cd /Users/xiaobo/mac_dev_app && xcodegen generate && xcodebuild -project MacDevApp.xcodeproj -scheme MacDevApp -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

If xcodebuild is not available or fails due to macOS 26 SDK, verify with:
Run: `cd /Users/xiaobo/mac_dev_app/Packages/DevAppCore && swift build`
Expected: Build Succeeded

- [ ] **Step 5: Commit**

```bash
git add MacDevApp/ 
git commit -m "feat: add app shell with sidebar navigation, tool registry, and search"
```

---

## Phase 2: Crypto Tools (parallelizable after Phase 1)

### Task 4: Hash Generator

**Files:**
- Create: `Packages/CryptoTools/Sources/CryptoTools/Hash/HashGenerator.swift`
- Create: `Packages/CryptoTools/Sources/CryptoTools/Hash/HashGeneratorView.swift`
- Test: `Packages/CryptoTools/Tests/CryptoToolsTests/HashGeneratorTests.swift`

- [ ] **Step 1: Write failing tests for HashGenerator**

Create `Packages/CryptoTools/Tests/CryptoToolsTests/HashGeneratorTests.swift`:

```swift
import Testing
import Foundation
@testable import CryptoTools

@Test func md5Hash() {
    let result = HashGenerator.hash("Hello, World!", algorithm: .md5)
    #expect(result == "65a8e27d8879283831b664bd8b7f0ad4")
}

@Test func sha1Hash() {
    let result = HashGenerator.hash("Hello, World!", algorithm: .sha1)
    #expect(result == "0a0a9f2a6772942557ab5355d76af442f8f65e01")
}

@Test func sha256Hash() {
    let result = HashGenerator.hash("Hello, World!", algorithm: .sha256)
    #expect(result == "dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f")
}

@Test func sha512Hash() {
    let result = HashGenerator.hash("Hello, World!", algorithm: .sha512)
    #expect(result == "374d794a95cdcfd8b35993185fef9ba368f160d8daf432d08ba9f1ed1e5abe6cc69291e0fa2fe0006a52570ef18c19def4e617c33ce52ef0a6e5fbe318cb0387")
}

@Test func emptyStringHash() {
    let result = HashGenerator.hash("", algorithm: .md5)
    #expect(result == "d41d8cd98f00b204e9800998ecf8427e")
}

@Test func hashAllAlgorithms() {
    let results = HashGenerator.hashAll("test")
    #expect(results.count == 4)
    #expect(results[.md5] != nil)
    #expect(results[.sha1] != nil)
    #expect(results[.sha256] != nil)
    #expect(results[.sha512] != nil)
}

@Test func hashData() {
    let data = Data("Hello, World!".utf8)
    let result = HashGenerator.hash(data: data, algorithm: .sha256)
    #expect(result == "dffd6021bb2bd5b0af676290809ec3a53191dd81c7f70a4b28688a362182986f")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/CryptoTools && swift test`
Expected: FAIL — `HashGenerator` not defined

- [ ] **Step 3: Implement HashGenerator**

Create `Packages/CryptoTools/Sources/CryptoTools/Hash/HashGenerator.swift`:

```swift
import Foundation
import CryptoKit

public enum HashAlgorithm: String, CaseIterable, Identifiable, Sendable {
    case md5 = "MD5"
    case sha1 = "SHA-1"
    case sha256 = "SHA-256"
    case sha512 = "SHA-512"

    public var id: String { rawValue }
}

public enum HashGenerator {
    public static func hash(_ string: String, algorithm: HashAlgorithm) -> String {
        hash(data: Data(string.utf8), algorithm: algorithm)
    }

    public static func hash(data: Data, algorithm: HashAlgorithm) -> String {
        switch algorithm {
        case .md5:
            Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
        case .sha1:
            Insecure.SHA1.hash(data: data).map { String(format: "%02x", $0) }.joined()
        case .sha256:
            SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        case .sha512:
            SHA512.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
    }

    public static func hashAll(_ string: String) -> [HashAlgorithm: String] {
        hashAll(data: Data(string.utf8))
    }

    public static func hashAll(data: Data) -> [HashAlgorithm: String] {
        var results: [HashAlgorithm: String] = [:]
        for algorithm in HashAlgorithm.allCases {
            results[algorithm] = hash(data: data, algorithm: algorithm)
        }
        return results
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/CryptoTools && swift test`
Expected: All tests passed

- [ ] **Step 5: Create HashGeneratorView**

Create `Packages/CryptoTools/Sources/CryptoTools/Hash/HashGeneratorView.swift`:

```swift
import SwiftUI
import DevAppCore

public struct HashGeneratorView: View {
    @State private var input = ""
    @State private var uppercase = false
    @State private var results: [HashAlgorithm: String] = [:]

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Hash Generator")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Generate MD5, SHA-1, SHA-256, SHA-512 hashes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Options
            HStack {
                Toggle("Uppercase", isOn: $uppercase)
                    .toggleStyle(.checkbox)
            }

            HStack(alignment: .top, spacing: 12) {
                // Input panel
                VStack(alignment: .leading, spacing: 4) {
                    Text("Input")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    TextEditor(text: $input)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Output panel
                VStack(alignment: .leading, spacing: 8) {
                    Text("Output")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    ForEach(HashAlgorithm.allCases) { algorithm in
                        HStack {
                            Text(algorithm.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .leading)
                            Text(displayResult(for: algorithm))
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            CopyButton(text: displayResult(for: algorithm))
                        }
                        .padding(8)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .padding()
        .onChange(of: input) { _, _ in updateHashes() }
        .onChange(of: uppercase) { _, _ in updateHashes() }
    }

    private func displayResult(for algorithm: HashAlgorithm) -> String {
        guard let result = results[algorithm] else { return "" }
        return uppercase ? result.uppercased() : result
    }

    private func updateHashes() {
        results = HashGenerator.hashAll(input)
    }
}
```

- [ ] **Step 6: Add tool descriptor for registration**

Add to the bottom of `Packages/CryptoTools/Sources/CryptoTools/Hash/HashGeneratorView.swift`:

```swift
extension HashGeneratorView {
    public static let descriptor = ToolDescriptor(
        id: "hash-generator",
        name: "Hash Generator",
        icon: "number",
        category: .crypto,
        searchKeywords: ["hash", "md5", "sha", "sha1", "sha256", "sha512", "digest", "checksum", "哈希", "摘要"]
    )
}
```

- [ ] **Step 7: Commit**

```bash
git add Packages/CryptoTools/Sources/CryptoTools/Hash/ Packages/CryptoTools/Tests/CryptoToolsTests/HashGeneratorTests.swift
git commit -m "feat: add Hash generator with MD5/SHA-1/SHA-256/SHA-512"
```

---

### Task 5: HMAC Generator

**Files:**
- Create: `Packages/CryptoTools/Sources/CryptoTools/HMAC/HMACGenerator.swift`
- Create: `Packages/CryptoTools/Sources/CryptoTools/HMAC/HMACGeneratorView.swift`
- Test: `Packages/CryptoTools/Tests/CryptoToolsTests/HMACGeneratorTests.swift`

- [ ] **Step 1: Write failing tests for HMACGenerator**

Create `Packages/CryptoTools/Tests/CryptoToolsTests/HMACGeneratorTests.swift`:

```swift
import Testing
import Foundation
@testable import CryptoTools

// Test vectors from RFC 2202 / RFC 4231
@Test func hmacMD5() {
    let result = HMACGenerator.generate(
        message: "Hi There",
        key: Data(repeating: 0x0b, count: 16),
        algorithm: .md5
    )
    #expect(result == "9294727a3638bb1c13f48ef8158bfc9d")
}

@Test func hmacSHA256() {
    let key = Data("key".utf8)
    let result = HMACGenerator.generate(
        message: "The quick brown fox jumps over the lazy dog",
        key: key,
        algorithm: .sha256
    )
    #expect(result == "f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8")
}

@Test func hmacSHA512WithStringKey() {
    let result = HMACGenerator.generate(
        message: "Hello",
        keyString: "secret",
        algorithm: .sha512
    )
    #expect(!result.isEmpty)
    #expect(result.count == 128) // SHA-512 produces 64 bytes = 128 hex chars
}

@Test func hmacSHA1() {
    let key = Data("key".utf8)
    let result = HMACGenerator.generate(
        message: "The quick brown fox jumps over the lazy dog",
        key: key,
        algorithm: .sha1
    )
    #expect(result == "de7c9b85b8b78aa6bc8a7a36f70a90701c9db4d9")
}

@Test func hmacOutputBase64() {
    let key = Data("key".utf8)
    let result = HMACGenerator.generate(
        message: "The quick brown fox jumps over the lazy dog",
        key: key,
        algorithm: .sha256,
        outputFormat: .base64
    )
    #expect(result == "97yD9DAzhCSxMpjmqm+xQ+9NWaFJRhdZl0edvC0aPNg=")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/CryptoTools && swift test`
Expected: FAIL — `HMACGenerator` not defined

- [ ] **Step 3: Implement HMACGenerator**

Create `Packages/CryptoTools/Sources/CryptoTools/HMAC/HMACGenerator.swift`:

```swift
import Foundation
import CryptoKit

public enum HMACAlgorithm: String, CaseIterable, Identifiable, Sendable {
    case md5 = "HMAC-MD5"
    case sha1 = "HMAC-SHA1"
    case sha256 = "HMAC-SHA256"
    case sha512 = "HMAC-SHA512"

    public var id: String { rawValue }
}

public enum HMACOutputFormat: String, CaseIterable, Identifiable, Sendable {
    case hex = "Hex"
    case base64 = "Base64"

    public var id: String { rawValue }
}

public enum HMACGenerator {
    public static func generate(
        message: String,
        keyString: String,
        algorithm: HMACAlgorithm,
        outputFormat: HMACOutputFormat = .hex
    ) -> String {
        generate(
            message: message,
            key: Data(keyString.utf8),
            algorithm: algorithm,
            outputFormat: outputFormat
        )
    }

    public static func generate(
        message: String,
        key: Data,
        algorithm: HMACAlgorithm,
        outputFormat: HMACOutputFormat = .hex
    ) -> String {
        let messageData = Data(message.utf8)
        let symmetricKey = SymmetricKey(data: key)
        let authData: Data

        switch algorithm {
        case .md5:
            let auth = CryptoKit.HMAC<Insecure.MD5>.authenticationCode(for: messageData, using: symmetricKey)
            authData = Data(auth)
        case .sha1:
            let auth = CryptoKit.HMAC<Insecure.SHA1>.authenticationCode(for: messageData, using: symmetricKey)
            authData = Data(auth)
        case .sha256:
            let auth = CryptoKit.HMAC<SHA256>.authenticationCode(for: messageData, using: symmetricKey)
            authData = Data(auth)
        case .sha512:
            let auth = CryptoKit.HMAC<SHA512>.authenticationCode(for: messageData, using: symmetricKey)
            authData = Data(auth)
        }

        switch outputFormat {
        case .hex:
            return authData.map { String(format: "%02x", $0) }.joined()
        case .base64:
            return authData.base64EncodedString()
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/CryptoTools && swift test`
Expected: All tests passed

- [ ] **Step 5: Create HMACGeneratorView**

Create `Packages/CryptoTools/Sources/CryptoTools/HMAC/HMACGeneratorView.swift`:

```swift
import SwiftUI
import DevAppCore

public struct HMACGeneratorView: View {
    @State private var message = ""
    @State private var key = ""
    @State private var algorithm: HMACAlgorithm = .sha256
    @State private var outputFormat: HMACOutputFormat = .hex
    @State private var output = ""

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("HMAC Generator")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Generate HMAC authentication codes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Config
            HStack(spacing: 16) {
                Picker("Algorithm", selection: $algorithm) {
                    ForEach(HMACAlgorithm.allCases) { algo in
                        Text(algo.rawValue).tag(algo)
                    }
                }
                .pickerStyle(.menu)
                .frame(width: 200)

                Picker("Output", selection: $outputFormat) {
                    ForEach(HMACOutputFormat.allCases) { fmt in
                        Text(fmt.rawValue).tag(fmt)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            // Key input
            VStack(alignment: .leading, spacing: 4) {
                Text("Key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                TextField("Enter secret key...", text: $key)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(.fill.tertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Input / Output
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Message")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    TextEditor(text: $message)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Output")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        CopyButton(text: output)
                    }
                    TextEditor(text: .constant(output))
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .onChange(of: message) { _, _ in updateOutput() }
        .onChange(of: key) { _, _ in updateOutput() }
        .onChange(of: algorithm) { _, _ in updateOutput() }
        .onChange(of: outputFormat) { _, _ in updateOutput() }
    }

    private func updateOutput() {
        guard !message.isEmpty, !key.isEmpty else {
            output = ""
            return
        }
        output = HMACGenerator.generate(
            message: message,
            keyString: key,
            algorithm: algorithm,
            outputFormat: outputFormat
        )
    }
}

extension HMACGeneratorView {
    public static let descriptor = ToolDescriptor(
        id: "hmac-generator",
        name: "HMAC Generator",
        icon: "key.horizontal",
        category: .crypto,
        searchKeywords: ["hmac", "mac", "authentication", "code", "密钥", "认证"]
    )
}
```

- [ ] **Step 6: Commit**

```bash
git add Packages/CryptoTools/Sources/CryptoTools/HMAC/ Packages/CryptoTools/Tests/CryptoToolsTests/HMACGeneratorTests.swift
git commit -m "feat: add HMAC generator with MD5/SHA1/SHA256/SHA512 + Hex/Base64 output"
```

---

### Task 6: AES Encryption/Decryption

**Files:**
- Create: `Packages/CryptoTools/Sources/CryptoTools/AES/AESCryptor.swift`
- Create: `Packages/CryptoTools/Sources/CryptoTools/AES/AESCryptorView.swift`
- Test: `Packages/CryptoTools/Tests/CryptoToolsTests/AESCryptorTests.swift`

- [ ] **Step 1: Write failing tests for AESCryptor**

Create `Packages/CryptoTools/Tests/CryptoToolsTests/AESCryptorTests.swift`:

```swift
import Testing
import Foundation
@testable import CryptoTools

@Test func aesGCMEncryptDecryptRoundTrip() throws {
    let plaintext = "Hello, World!"
    let key = AESCryptor.generateRandomKey(bits: 256)

    let encrypted = try AESCryptor.encrypt(
        plaintext: plaintext,
        key: key,
        mode: .gcm
    )
    let decrypted = try AESCryptor.decrypt(
        ciphertext: encrypted.ciphertext,
        key: key,
        mode: .gcm,
        iv: encrypted.iv,
        tag: encrypted.tag
    )
    #expect(decrypted == plaintext)
}

@Test func aesCBCEncryptDecryptRoundTrip() throws {
    let plaintext = "Hello, World! This is a test."
    let key = AESCryptor.generateRandomKey(bits: 256)
    let iv = AESCryptor.generateRandomIV()

    let encrypted = try AESCryptor.encrypt(
        plaintext: plaintext,
        key: key,
        mode: .cbc,
        iv: iv,
        padding: .pkcs7
    )
    let decrypted = try AESCryptor.decrypt(
        ciphertext: encrypted.ciphertext,
        key: key,
        mode: .cbc,
        iv: iv,
        padding: .pkcs7
    )
    #expect(decrypted == plaintext)
}

@Test func aesECBEncryptDecryptRoundTrip() throws {
    let plaintext = "Hello, World! This is a test."
    let key = AESCryptor.generateRandomKey(bits: 128)

    let encrypted = try AESCryptor.encrypt(
        plaintext: plaintext,
        key: key,
        mode: .ecb,
        padding: .pkcs7
    )
    let decrypted = try AESCryptor.decrypt(
        ciphertext: encrypted.ciphertext,
        key: key,
        mode: .ecb,
        padding: .pkcs7
    )
    #expect(decrypted == plaintext)
}

@Test func aesKeyGeneration128() {
    let key = AESCryptor.generateRandomKey(bits: 128)
    #expect(key.count == 16)
}

@Test func aesKeyGeneration256() {
    let key = AESCryptor.generateRandomKey(bits: 256)
    #expect(key.count == 32)
}

@Test func aesIVGeneration() {
    let iv = AESCryptor.generateRandomIV()
    #expect(iv.count == 16)
}

@Test func aesInvalidKeySize() {
    let key = Data(repeating: 0, count: 15) // invalid
    #expect(throws: AESError.self) {
        try AESCryptor.encrypt(plaintext: "test", key: key, mode: .cbc)
    }
}

@Test func aesOutputFormatBase64() throws {
    let plaintext = "Hello"
    let key = AESCryptor.generateRandomKey(bits: 256)

    let encrypted = try AESCryptor.encrypt(
        plaintext: plaintext,
        key: key,
        mode: .gcm
    )
    // Ciphertext should be valid Data
    #expect(!encrypted.ciphertext.isEmpty)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/CryptoTools && swift test`
Expected: FAIL — `AESCryptor` not defined

- [ ] **Step 3: Implement AESCryptor**

Create `Packages/CryptoTools/Sources/CryptoTools/AES/AESCryptor.swift`:

```swift
import Foundation
import CryptoKit
import CCommonCrypto

public enum AESMode: String, CaseIterable, Identifiable, Sendable {
    case ecb = "ECB"
    case cbc = "CBC"
    case gcm = "GCM"

    public var id: String { rawValue }
}

public enum AESPadding: String, CaseIterable, Identifiable, Sendable {
    case pkcs7 = "PKCS7"
    case noPadding = "None"

    public var id: String { rawValue }
}

public enum AESKeyBits: Int, CaseIterable, Identifiable, Sendable {
    case bits128 = 128
    case bits192 = 192
    case bits256 = 256

    public var id: Int { rawValue }
    public var byteCount: Int { rawValue / 8 }
}

public enum AESError: Error, LocalizedError {
    case invalidKeySize
    case invalidIVSize
    case encryptionFailed(status: Int32)
    case decryptionFailed(status: Int32)
    case missingIV
    case missingTag
    case gcmFailed(underlying: Error)

    public var errorDescription: String? {
        switch self {
        case .invalidKeySize: "Invalid key size. Must be 16, 24, or 32 bytes."
        case .invalidIVSize: "Invalid IV size. Must be 16 bytes for CBC, 12 bytes for GCM."
        case .encryptionFailed(let s): "Encryption failed with status \(s)"
        case .decryptionFailed(let s): "Decryption failed with status \(s)"
        case .missingIV: "IV is required for CBC and GCM modes."
        case .missingTag: "Authentication tag is required for GCM decryption."
        case .gcmFailed(let e): "GCM operation failed: \(e.localizedDescription)"
        }
    }
}

public struct AESResult: Sendable {
    public let ciphertext: Data
    public let iv: Data?
    public let tag: Data?
}

public enum AESCryptor {
    // MARK: - Key / IV Generation

    public static func generateRandomKey(bits: Int) -> Data {
        let byteCount = bits / 8
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        return Data(bytes)
    }

    public static func generateRandomIV(byteCount: Int = 16) -> Data {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, byteCount, &bytes)
        return Data(bytes)
    }

    // MARK: - Encrypt

    public static func encrypt(
        plaintext: String,
        key: Data,
        mode: AESMode,
        iv: Data? = nil,
        padding: AESPadding = .pkcs7
    ) throws -> AESResult {
        let data = Data(plaintext.utf8)
        return try encrypt(data: data, key: key, mode: mode, iv: iv, padding: padding)
    }

    public static func encrypt(
        data: Data,
        key: Data,
        mode: AESMode,
        iv: Data? = nil,
        padding: AESPadding = .pkcs7
    ) throws -> AESResult {
        guard [16, 24, 32].contains(key.count) else {
            throw AESError.invalidKeySize
        }

        switch mode {
        case .gcm:
            return try encryptGCM(data: data, key: key)
        case .cbc:
            guard let iv else { throw AESError.missingIV }
            guard iv.count == 16 else { throw AESError.invalidIVSize }
            return try encryptCommonCrypto(data: data, key: key, iv: iv, ecb: false, padding: padding)
        case .ecb:
            return try encryptCommonCrypto(data: data, key: key, iv: Data(repeating: 0, count: 16), ecb: true, padding: padding)
        }
    }

    // MARK: - Decrypt

    public static func decrypt(
        ciphertext: Data,
        key: Data,
        mode: AESMode,
        iv: Data? = nil,
        padding: AESPadding = .pkcs7,
        tag: Data? = nil
    ) throws -> String {
        guard [16, 24, 32].contains(key.count) else {
            throw AESError.invalidKeySize
        }

        let decryptedData: Data
        switch mode {
        case .gcm:
            guard let iv else { throw AESError.missingIV }
            guard let tag else { throw AESError.missingTag }
            decryptedData = try decryptGCM(ciphertext: ciphertext, key: key, iv: iv, tag: tag)
        case .cbc:
            guard let iv else { throw AESError.missingIV }
            guard iv.count == 16 else { throw AESError.invalidIVSize }
            decryptedData = try decryptCommonCrypto(data: ciphertext, key: key, iv: iv, ecb: false, padding: padding)
        case .ecb:
            decryptedData = try decryptCommonCrypto(data: ciphertext, key: key, iv: Data(repeating: 0, count: 16), ecb: true, padding: padding)
        }

        guard let result = String(data: decryptedData, encoding: .utf8) else {
            return decryptedData.base64EncodedString()
        }
        return result
    }

    // MARK: - GCM (CryptoKit)

    private static func encryptGCM(data: Data, key: Data) throws -> AESResult {
        do {
            let symmetricKey = SymmetricKey(data: key)
            let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
            return AESResult(
                ciphertext: sealedBox.ciphertext,
                iv: Data(sealedBox.nonce),
                tag: sealedBox.tag
            )
        } catch {
            throw AESError.gcmFailed(underlying: error)
        }
    }

    private static func decryptGCM(ciphertext: Data, key: Data, iv: Data, tag: Data) throws -> Data {
        do {
            let symmetricKey = SymmetricKey(data: key)
            let nonce = try AES.GCM.Nonce(data: iv)
            let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: ciphertext, tag: tag)
            return try AES.GCM.open(sealedBox, using: symmetricKey)
        } catch {
            throw AESError.gcmFailed(underlying: error)
        }
    }

    // MARK: - ECB / CBC (CommonCrypto)

    private static func encryptCommonCrypto(
        data: Data,
        key: Data,
        iv: Data,
        ecb: Bool,
        padding: AESPadding
    ) throws -> AESResult {
        let options: UInt32 = {
            var opts: UInt32 = 0
            if ecb { opts |= UInt32(kCCOptionECBMode) }
            if padding == .pkcs7 { opts |= UInt32(kCCOptionPKCS7Padding) }
            return opts
        }()

        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var bytesEncrypted = 0

        let status = buffer.withUnsafeMutableBytes { bufferPtr in
            data.withUnsafeBytes { dataPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(
                            CCOperation(kCCEncrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(options),
                            keyPtr.baseAddress, key.count,
                            ivPtr.baseAddress,
                            dataPtr.baseAddress, data.count,
                            bufferPtr.baseAddress, bufferSize,
                            &bytesEncrypted
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else {
            throw AESError.encryptionFailed(status: status)
        }

        buffer.count = bytesEncrypted
        return AESResult(ciphertext: buffer, iv: ecb ? nil : iv, tag: nil)
    }

    private static func decryptCommonCrypto(
        data: Data,
        key: Data,
        iv: Data,
        ecb: Bool,
        padding: AESPadding
    ) throws -> Data {
        let options: UInt32 = {
            var opts: UInt32 = 0
            if ecb { opts |= UInt32(kCCOptionECBMode) }
            if padding == .pkcs7 { opts |= UInt32(kCCOptionPKCS7Padding) }
            return opts
        }()

        let bufferSize = data.count + kCCBlockSizeAES128
        var buffer = Data(count: bufferSize)
        var bytesDecrypted = 0

        let status = buffer.withUnsafeMutableBytes { bufferPtr in
            data.withUnsafeBytes { dataPtr in
                key.withUnsafeBytes { keyPtr in
                    iv.withUnsafeBytes { ivPtr in
                        CCCrypt(
                            CCOperation(kCCDecrypt),
                            CCAlgorithm(kCCAlgorithmAES),
                            CCOptions(options),
                            keyPtr.baseAddress, key.count,
                            ivPtr.baseAddress,
                            dataPtr.baseAddress, data.count,
                            bufferPtr.baseAddress, bufferSize,
                            &bytesDecrypted
                        )
                    }
                }
            }
        }

        guard status == kCCSuccess else {
            throw AESError.decryptionFailed(status: status)
        }

        buffer.count = bytesDecrypted
        return buffer
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/CryptoTools && swift test`
Expected: All tests passed

- [ ] **Step 5: Create AESCryptorView**

Create `Packages/CryptoTools/Sources/CryptoTools/AES/AESCryptorView.swift`:

```swift
import SwiftUI
import DevAppCore

public struct AESCryptorView: View {
    @State private var input = ""
    @State private var output = ""
    @State private var keyHex = ""
    @State private var ivHex = ""
    @State private var mode: AESMode = .cbc
    @State private var keyBits: AESKeyBits = .bits256
    @State private var padding: AESPadding = .pkcs7
    @State private var outputFormat: OutputFormat = .base64
    @State private var errorMessage: String?

    enum OutputFormat: String, CaseIterable, Identifiable {
        case hex = "Hex"
        case base64 = "Base64"
        var id: String { rawValue }
    }

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("AES Encrypt / Decrypt")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Symmetric encryption with ECB, CBC, and GCM modes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Config bar
            HStack(spacing: 16) {
                Picker("Mode", selection: $mode) {
                    ForEach(AESMode.allCases) { m in Text(m.rawValue).tag(m) }
                }
                .pickerStyle(.menu)
                .frame(width: 120)

                Picker("Key Size", selection: $keyBits) {
                    ForEach(AESKeyBits.allCases) { b in Text("\(b.rawValue) bit").tag(b) }
                }
                .pickerStyle(.menu)
                .frame(width: 140)

                if mode != .gcm {
                    Picker("Padding", selection: $padding) {
                        ForEach(AESPadding.allCases) { p in Text(p.rawValue).tag(p) }
                    }
                    .pickerStyle(.menu)
                    .frame(width: 130)
                }

                Picker("Output", selection: $outputFormat) {
                    ForEach(OutputFormat.allCases) { f in Text(f.rawValue).tag(f) }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)
            }

            // Key / IV
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Key (Hex)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    TextField("Enter key in hex...", text: $keyHex)
                        .font(.system(.body, design: .monospaced))
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                if mode != .ecb {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("IV (Hex)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        TextField("Enter IV in hex...", text: $ivHex)
                            .font(.system(.body, design: .monospaced))
                            .textFieldStyle(.plain)
                            .padding(8)
                            .background(.fill.tertiary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }

                VStack {
                    Spacer()
                    Button("Random") {
                        generateRandomKeyIV()
                    }
                    .buttonStyle(.bordered)
                }
            }

            // Error message
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Input / Output panels
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Input")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    TextEditor(text: $input)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                // Action buttons
                VStack(spacing: 8) {
                    Spacer()
                    Button {
                        encrypt()
                    } label: {
                        Label("Encrypt", systemImage: "lock")
                    }
                    .buttonStyle(.bordered)
                    .tint(.blue)

                    Button {
                        decrypt()
                    } label: {
                        Label("Decrypt", systemImage: "lock.open")
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Output")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        CopyButton(text: output)
                    }
                    TextEditor(text: .constant(output))
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
    }

    private func generateRandomKeyIV() {
        let key = AESCryptor.generateRandomKey(bits: keyBits.rawValue)
        keyHex = key.map { String(format: "%02x", $0) }.joined()
        if mode != .ecb {
            let ivSize = mode == .gcm ? 12 : 16
            let iv = AESCryptor.generateRandomIV(byteCount: ivSize)
            ivHex = iv.map { String(format: "%02x", $0) }.joined()
        }
    }

    private func encrypt() {
        errorMessage = nil
        guard let key = Data(hexString: keyHex), key.count == keyBits.byteCount else {
            errorMessage = "Invalid key. Expected \(keyBits.byteCount * 2) hex characters."
            return
        }

        let iv: Data? = mode != .ecb ? Data(hexString: ivHex) : nil
        if mode == .cbc, iv?.count != 16 {
            errorMessage = "Invalid IV. Expected 32 hex characters (16 bytes)."
            return
        }

        do {
            let result = try AESCryptor.encrypt(
                plaintext: input,
                key: key,
                mode: mode,
                iv: iv,
                padding: padding
            )
            switch outputFormat {
            case .hex:
                output = result.ciphertext.map { String(format: "%02x", $0) }.joined()
            case .base64:
                output = result.ciphertext.base64EncodedString()
            }
            // For GCM, append nonce and tag info
            if mode == .gcm, let nonce = result.iv, let tag = result.tag {
                ivHex = nonce.map { String(format: "%02x", $0) }.joined()
                output += "\n[Tag: \(tag.map { String(format: "%02x", $0) }.joined())]"
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func decrypt() {
        errorMessage = nil
        guard let key = Data(hexString: keyHex), key.count == keyBits.byteCount else {
            errorMessage = "Invalid key."
            return
        }

        // Parse output to get ciphertext (and tag for GCM)
        var ciphertextStr = output
        var tagData: Data?
        if mode == .gcm, let tagRange = output.range(of: "\\[Tag: ([a-fA-F0-9]+)\\]", options: .regularExpression) {
            let tagHex = String(output[tagRange]).replacingOccurrences(of: "[Tag: ", with: "").replacingOccurrences(of: "]", with: "")
            tagData = Data(hexString: tagHex)
            ciphertextStr = String(output[output.startIndex..<tagRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let ciphertext: Data
        switch outputFormat {
        case .hex:
            guard let data = Data(hexString: ciphertextStr) else {
                errorMessage = "Invalid hex ciphertext."
                return
            }
            ciphertext = data
        case .base64:
            guard let data = Data(base64Encoded: ciphertextStr) else {
                errorMessage = "Invalid Base64 ciphertext."
                return
            }
            ciphertext = data
        }

        let iv = Data(hexString: ivHex)

        do {
            let plaintext = try AESCryptor.decrypt(
                ciphertext: ciphertext,
                key: key,
                mode: mode,
                iv: iv,
                padding: padding,
                tag: tagData
            )
            input = plaintext
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension AESCryptorView {
    public static let descriptor = ToolDescriptor(
        id: "aes-cryptor",
        name: "AES Encrypt/Decrypt",
        icon: "lock.rectangle",
        category: .crypto,
        searchKeywords: ["aes", "encrypt", "decrypt", "symmetric", "cbc", "ecb", "gcm", "加密", "解密", "对称"]
    )
}
```

- [ ] **Step 6: Commit**

```bash
git add Packages/CryptoTools/Sources/CryptoTools/AES/ Packages/CryptoTools/Tests/CryptoToolsTests/AESCryptorTests.swift
git commit -m "feat: add AES encrypt/decrypt with ECB/CBC/GCM modes"
```

---

### Task 7: RSA Tools

**Files:**
- Create: `Packages/CryptoTools/Sources/CryptoTools/RSA/RSACryptor.swift`
- Create: `Packages/CryptoTools/Sources/CryptoTools/RSA/RSACryptorView.swift`
- Test: `Packages/CryptoTools/Tests/CryptoToolsTests/RSACryptorTests.swift`

- [ ] **Step 1: Write failing tests for RSACryptor**

Create `Packages/CryptoTools/Tests/CryptoToolsTests/RSACryptorTests.swift`:

```swift
import Testing
import Foundation
@testable import CryptoTools

@Test func rsaKeyGeneration2048() throws {
    let keyPair = try RSACryptor.generateKeyPair(bits: 2048)
    #expect(!keyPair.publicKeyPEM.isEmpty)
    #expect(!keyPair.privateKeyPEM.isEmpty)
    #expect(keyPair.publicKeyPEM.hasPrefix("-----BEGIN PUBLIC KEY-----"))
    #expect(keyPair.privateKeyPEM.hasPrefix("-----BEGIN RSA PRIVATE KEY-----"))
}

@Test func rsaKeyGeneration4096() throws {
    let keyPair = try RSACryptor.generateKeyPair(bits: 4096)
    #expect(!keyPair.publicKeyPEM.isEmpty)
    #expect(!keyPair.privateKeyPEM.isEmpty)
}

@Test func rsaEncryptDecryptRoundTrip() throws {
    let keyPair = try RSACryptor.generateKeyPair(bits: 2048)
    let plaintext = "Hello, RSA!"

    let encrypted = try RSACryptor.encrypt(
        plaintext: plaintext,
        publicKeyPEM: keyPair.publicKeyPEM,
        padding: .oaepSHA256
    )
    #expect(!encrypted.isEmpty)

    let decrypted = try RSACryptor.decrypt(
        ciphertext: encrypted,
        privateKeyPEM: keyPair.privateKeyPEM,
        padding: .oaepSHA256
    )
    #expect(decrypted == plaintext)
}

@Test func rsaEncryptDecryptPKCS1() throws {
    let keyPair = try RSACryptor.generateKeyPair(bits: 2048)
    let plaintext = "Test PKCS1"

    let encrypted = try RSACryptor.encrypt(
        plaintext: plaintext,
        publicKeyPEM: keyPair.publicKeyPEM,
        padding: .pkcs1
    )
    let decrypted = try RSACryptor.decrypt(
        ciphertext: encrypted,
        privateKeyPEM: keyPair.privateKeyPEM,
        padding: .pkcs1
    )
    #expect(decrypted == plaintext)
}

@Test func rsaInvalidKeyThrows() {
    #expect(throws: RSAError.self) {
        try RSACryptor.encrypt(
            plaintext: "test",
            publicKeyPEM: "not-a-key",
            padding: .oaepSHA256
        )
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/CryptoTools && swift test`
Expected: FAIL — `RSACryptor` not defined

- [ ] **Step 3: Implement RSACryptor**

Create `Packages/CryptoTools/Sources/CryptoTools/RSA/RSACryptor.swift`:

```swift
import Foundation
import Security

public enum RSAKeyBits: Int, CaseIterable, Identifiable, Sendable {
    case bits1024 = 1024
    case bits2048 = 2048
    case bits4096 = 4096

    public var id: Int { rawValue }
}

public enum RSAPadding: String, CaseIterable, Identifiable, Sendable {
    case pkcs1 = "PKCS1 v1.5"
    case oaepSHA256 = "OAEP SHA-256"

    public var id: String { rawValue }

    var secPadding: SecPadding {
        switch self {
        case .pkcs1: .PKCS1
        case .oaepSHA256: .OAEP
        }
    }

    var algorithm: SecKeyAlgorithm {
        switch self {
        case .pkcs1: .rsaEncryptionPKCS1
        case .oaepSHA256: .rsaEncryptionOAEPSHA256
        }
    }

    var decryptAlgorithm: SecKeyAlgorithm {
        algorithm
    }
}

public enum RSAError: Error, LocalizedError {
    case keyGenerationFailed(OSStatus)
    case invalidPEM
    case encryptionFailed(Error?)
    case decryptionFailed(Error?)
    case keyCreationFailed

    public var errorDescription: String? {
        switch self {
        case .keyGenerationFailed(let s): "Key generation failed with status \(s)"
        case .invalidPEM: "Invalid PEM key format"
        case .encryptionFailed(let e): "Encryption failed: \(e?.localizedDescription ?? "unknown")"
        case .decryptionFailed(let e): "Decryption failed: \(e?.localizedDescription ?? "unknown")"
        case .keyCreationFailed: "Failed to create SecKey from PEM"
        }
    }
}

public struct RSAKeyPair: Sendable {
    public let publicKeyPEM: String
    public let privateKeyPEM: String
}

public enum RSACryptor {
    // MARK: - Key Generation

    public static func generateKeyPair(bits: Int) throws -> RSAKeyPair {
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeySizeInBits as String: bits,
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw RSAError.keyGenerationFailed(-1)
        }

        guard let publicKey = SecKeyCopyPublicKey(privateKey) else {
            throw RSAError.keyGenerationFailed(-2)
        }

        let publicPEM = try exportKeyToPEM(publicKey, isPublic: true)
        let privatePEM = try exportKeyToPEM(privateKey, isPublic: false)

        return RSAKeyPair(publicKeyPEM: publicPEM, privateKeyPEM: privatePEM)
    }

    // MARK: - Encrypt / Decrypt

    public static func encrypt(
        plaintext: String,
        publicKeyPEM: String,
        padding: RSAPadding
    ) throws -> Data {
        let key = try secKey(fromPEM: publicKeyPEM, isPublic: true)
        let data = Data(plaintext.utf8)

        var error: Unmanaged<CFError>?
        guard let encrypted = SecKeyCreateEncryptedData(key, padding.algorithm, data as CFData, &error) else {
            throw RSAError.encryptionFailed(error?.takeRetainedValue())
        }
        return encrypted as Data
    }

    public static func decrypt(
        ciphertext: Data,
        privateKeyPEM: String,
        padding: RSAPadding
    ) throws -> String {
        let key = try secKey(fromPEM: privateKeyPEM, isPublic: false)

        var error: Unmanaged<CFError>?
        guard let decrypted = SecKeyCreateDecryptedData(key, padding.decryptAlgorithm, ciphertext as CFData, &error) else {
            throw RSAError.decryptionFailed(error?.takeRetainedValue())
        }

        guard let result = String(data: decrypted as Data, encoding: .utf8) else {
            throw RSAError.decryptionFailed(nil)
        }
        return result
    }

    // MARK: - PEM Helpers

    private static func exportKeyToPEM(_ key: SecKey, isPublic: Bool) throws -> String {
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(key, &error) else {
            throw RSAError.keyGenerationFailed(-3)
        }

        let base64 = (data as Data).base64EncodedString(options: [.lineLength64Characters, .endLineWithLineFeed])
        let header = isPublic ? "-----BEGIN PUBLIC KEY-----" : "-----BEGIN RSA PRIVATE KEY-----"
        let footer = isPublic ? "-----END PUBLIC KEY-----" : "-----END RSA PRIVATE KEY-----"

        return "\(header)\n\(base64)\n\(footer)"
    }

    private static func secKey(fromPEM pem: String, isPublic: Bool) throws -> SecKey {
        let header = isPublic ? "-----BEGIN PUBLIC KEY-----" : "-----BEGIN RSA PRIVATE KEY-----"
        let footer = isPublic ? "-----END PUBLIC KEY-----" : "-----END RSA PRIVATE KEY-----"

        let base64 = pem
            .replacingOccurrences(of: header, with: "")
            .replacingOccurrences(of: footer, with: "")
            .replacingOccurrences(of: "\n", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let data = Data(base64Encoded: base64) else {
            throw RSAError.invalidPEM
        }

        let keyClass = isPublic ? kSecAttrKeyClassPublic : kSecAttrKeyClassPrivate
        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeRSA,
            kSecAttrKeyClass as String: keyClass,
        ]

        var error: Unmanaged<CFError>?
        guard let key = SecKeyCreateWithData(data as CFData, attributes as CFDictionary, &error) else {
            throw RSAError.keyCreationFailed
        }
        return key
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/CryptoTools && swift test`
Expected: All tests passed

- [ ] **Step 5: Create RSACryptorView**

Create `Packages/CryptoTools/Sources/CryptoTools/RSA/RSACryptorView.swift`:

```swift
import SwiftUI
import DevAppCore

public struct RSACryptorView: View {
    @State private var keyBits: RSAKeyBits = .bits2048
    @State private var padding: RSAPadding = .oaepSHA256
    @State private var publicKeyPEM = ""
    @State private var privateKeyPEM = ""
    @State private var input = ""
    @State private var output = ""
    @State private var outputFormat: OutputFormat = .base64
    @State private var errorMessage: String?
    @State private var isGenerating = false

    enum OutputFormat: String, CaseIterable, Identifiable {
        case hex = "Hex"
        case base64 = "Base64"
        var id: String { rawValue }
    }

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("RSA Encrypt / Decrypt")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Asymmetric encryption — generate keys, encrypt with public key, decrypt with private key")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Config
            HStack(spacing: 16) {
                Picker("Key Size", selection: $keyBits) {
                    ForEach(RSAKeyBits.allCases) { b in Text("\(b.rawValue) bit").tag(b) }
                }
                .pickerStyle(.menu)
                .frame(width: 140)

                Picker("Padding", selection: $padding) {
                    ForEach(RSAPadding.allCases) { p in Text(p.rawValue).tag(p) }
                }
                .pickerStyle(.menu)
                .frame(width: 180)

                Picker("Output", selection: $outputFormat) {
                    ForEach(OutputFormat.allCases) { f in Text(f.rawValue).tag(f) }
                }
                .pickerStyle(.segmented)
                .frame(width: 150)

                Spacer()

                Button {
                    generateKeys()
                } label: {
                    Label("Generate Keys", systemImage: "key")
                }
                .buttonStyle(.bordered)
                .disabled(isGenerating)
            }

            // Keys
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Public Key (PEM)")
                            .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                        Spacer()
                        CopyButton(text: publicKeyPEM)
                    }
                    TextEditor(text: $publicKeyPEM)
                        .font(.system(size: 10, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(height: 80)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Private Key (PEM)")
                            .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                        Spacer()
                        CopyButton(text: privateKeyPEM)
                    }
                    TextEditor(text: $privateKeyPEM)
                        .font(.system(size: 10, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(6)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .frame(height: 80)
                }
            }

            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red)
            }

            // Input / Output
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Plaintext")
                        .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                    TextEditor(text: $input)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(spacing: 8) {
                    Spacer()
                    Button { encrypt() } label: {
                        Label("Encrypt", systemImage: "lock")
                    }
                    .buttonStyle(.bordered).tint(.blue)

                    Button { decrypt() } label: {
                        Label("Decrypt", systemImage: "lock.open")
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Ciphertext")
                            .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                        Spacer()
                        CopyButton(text: output)
                    }
                    TextEditor(text: .constant(output))
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
    }

    private func generateKeys() {
        isGenerating = true
        errorMessage = nil
        Task {
            do {
                let keyPair = try RSACryptor.generateKeyPair(bits: keyBits.rawValue)
                publicKeyPEM = keyPair.publicKeyPEM
                privateKeyPEM = keyPair.privateKeyPEM
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }

    private func encrypt() {
        errorMessage = nil
        do {
            let encrypted = try RSACryptor.encrypt(
                plaintext: input,
                publicKeyPEM: publicKeyPEM,
                padding: padding
            )
            switch outputFormat {
            case .hex: output = encrypted.map { String(format: "%02x", $0) }.joined()
            case .base64: output = encrypted.base64EncodedString()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func decrypt() {
        errorMessage = nil
        let ciphertext: Data
        switch outputFormat {
        case .hex:
            guard let d = Data(hexString: output) else {
                errorMessage = "Invalid hex ciphertext."
                return
            }
            ciphertext = d
        case .base64:
            guard let d = Data(base64Encoded: output) else {
                errorMessage = "Invalid Base64 ciphertext."
                return
            }
            ciphertext = d
        }

        do {
            input = try RSACryptor.decrypt(
                ciphertext: ciphertext,
                privateKeyPEM: privateKeyPEM,
                padding: padding
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

extension RSACryptorView {
    public static let descriptor = ToolDescriptor(
        id: "rsa-cryptor",
        name: "RSA Encrypt/Decrypt",
        icon: "key",
        category: .crypto,
        searchKeywords: ["rsa", "asymmetric", "public key", "private key", "encrypt", "decrypt", "非对称", "公钥", "私钥"]
    )
}
```

- [ ] **Step 6: Commit**

```bash
git add Packages/CryptoTools/Sources/CryptoTools/RSA/ Packages/CryptoTools/Tests/CryptoToolsTests/RSACryptorTests.swift
git commit -m "feat: add RSA key generation + encrypt/decrypt with PKCS1/OAEP"
```

---

## Phase 3: Conversion Tools (parallelizable after Phase 1)

### Task 8: Base64 Codec

**Files:**
- Create: `Packages/ConversionTools/Sources/ConversionTools/Base64/Base64Codec.swift`
- Create: `Packages/ConversionTools/Sources/ConversionTools/Base64/Base64CodecView.swift`
- Test: `Packages/ConversionTools/Tests/ConversionToolsTests/Base64CodecTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Packages/ConversionTools/Tests/ConversionToolsTests/Base64CodecTests.swift`:

```swift
import Testing
import Foundation
@testable import ConversionTools

@Test func base64Encode() {
    #expect(Base64Codec.encode("Hello, World!") == "SGVsbG8sIFdvcmxkIQ==")
}

@Test func base64Decode() {
    #expect(Base64Codec.decode("SGVsbG8sIFdvcmxkIQ==") == "Hello, World!")
}

@Test func base64EncodeEmpty() {
    #expect(Base64Codec.encode("") == "")
}

@Test func base64DecodeInvalid() {
    #expect(Base64Codec.decode("!!!invalid!!!") == nil)
}

@Test func base64URLSafeEncode() {
    // Standard base64 would use + and /
    let input = "subjects?_d"
    let standard = Base64Codec.encode(input, urlSafe: false)
    let urlSafe = Base64Codec.encode(input, urlSafe: true)
    #expect(!urlSafe.contains("+"))
    #expect(!urlSafe.contains("/"))
    // URL-safe should decode back correctly
    #expect(Base64Codec.decode(urlSafe, urlSafe: true) == input)
}

@Test func base64EncodeChinese() {
    let input = "你好世界"
    let encoded = Base64Codec.encode(input)
    let decoded = Base64Codec.decode(encoded)
    #expect(decoded == input)
}

@Test func base64EncodeImage() {
    // Minimal 1x1 PNG
    let pngData = Data([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A
    ])
    let encoded = Base64Codec.encodeData(pngData)
    let decoded = Base64Codec.decodeToData(encoded)
    #expect(decoded == pngData)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/ConversionTools && swift test`
Expected: FAIL — `Base64Codec` not defined

- [ ] **Step 3: Implement Base64Codec**

Create `Packages/ConversionTools/Sources/ConversionTools/Base64/Base64Codec.swift`:

```swift
import Foundation

public enum Base64Codec {
    public static func encode(_ string: String, urlSafe: Bool = false) -> String {
        let data = Data(string.utf8)
        return encodeData(data, urlSafe: urlSafe)
    }

    public static func encodeData(_ data: Data, urlSafe: Bool = false) -> String {
        var result = data.base64EncodedString()
        if urlSafe {
            result = result
                .replacingOccurrences(of: "+", with: "-")
                .replacingOccurrences(of: "/", with: "_")
                .replacingOccurrences(of: "=", with: "")
        }
        return result
    }

    public static func decode(_ base64: String, urlSafe: Bool = false) -> String? {
        guard let data = decodeToData(base64, urlSafe: urlSafe) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    public static func decodeToData(_ base64: String, urlSafe: Bool = false) -> Data? {
        var input = base64
        if urlSafe {
            input = input
                .replacingOccurrences(of: "-", with: "+")
                .replacingOccurrences(of: "_", with: "/")
            // Re-add padding
            let remainder = input.count % 4
            if remainder > 0 {
                input += String(repeating: "=", count: 4 - remainder)
            }
        }
        return Data(base64Encoded: input)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/ConversionTools && swift test`
Expected: All tests passed

- [ ] **Step 5: Create Base64CodecView**

Create `Packages/ConversionTools/Sources/ConversionTools/Base64/Base64CodecView.swift`:

```swift
import SwiftUI
import DevAppCore
import UniformTypeIdentifiers

public struct Base64CodecView: View {
    @State private var input = ""
    @State private var output = ""
    @State private var urlSafe = false
    @State private var isImageMode = false
    @State private var imageData: Data?

    public init() {}

    public var body: some View {
        InputOutputView(
            title: "Base64 Encode / Decode",
            description: "Encode and decode Base64 strings and images",
            input: $input,
            output: $output,
            inputLabel: "Plain Text",
            outputLabel: "Base64"
        ) {
            HStack(spacing: 16) {
                Toggle("URL-safe", isOn: $urlSafe)
                    .toggleStyle(.checkbox)
                Toggle("Image mode", isOn: $isImageMode)
                    .toggleStyle(.checkbox)
            }
        }
        .onChange(of: input) { _, _ in encode() }
        .onChange(of: urlSafe) { _, _ in encode() }
        .onChange(of: output) { _, newValue in
            // Only auto-decode if user manually edited output
        }
    }

    private func encode() {
        guard !input.isEmpty else {
            output = ""
            return
        }
        output = Base64Codec.encode(input, urlSafe: urlSafe)
    }
}

extension Base64CodecView {
    public static let descriptor = ToolDescriptor(
        id: "base64-codec",
        name: "Base64 Encode/Decode",
        icon: "doc.text",
        category: .conversion,
        searchKeywords: ["base64", "encode", "decode", "编码", "解码", "image", "图片"]
    )
}
```

- [ ] **Step 6: Commit**

```bash
git add Packages/ConversionTools/Sources/ConversionTools/Base64/ Packages/ConversionTools/Tests/ConversionToolsTests/Base64CodecTests.swift
git commit -m "feat: add Base64 encode/decode with URL-safe support"
```

---

### Task 9: URL Encode/Decode

**Files:**
- Create: `Packages/ConversionTools/Sources/ConversionTools/URLCodec/URLCodec.swift`
- Create: `Packages/ConversionTools/Sources/ConversionTools/URLCodec/URLCodecView.swift`
- Test: `Packages/ConversionTools/Tests/ConversionToolsTests/URLCodecTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Packages/ConversionTools/Tests/ConversionToolsTests/URLCodecTests.swift`:

```swift
import Testing
import Foundation
@testable import ConversionTools

@Test func urlEncodeRFC3986() {
    let result = URLCodec.encode("hello world&foo=bar", standard: .rfc3986)
    #expect(result == "hello%20world%26foo%3Dbar")
}

@Test func urlEncodeFormData() {
    let result = URLCodec.encode("hello world&foo=bar", standard: .formData)
    #expect(result == "hello+world%26foo%3Dbar")
}

@Test func urlDecode() {
    let result = URLCodec.decode("hello%20world%26foo%3Dbar")
    #expect(result == "hello world&foo=bar")
}

@Test func urlDecodeFormData() {
    let result = URLCodec.decode("hello+world")
    #expect(result == "hello world")
}

@Test func urlEncodeChinese() {
    let result = URLCodec.encode("你好", standard: .rfc3986)
    #expect(result == "%E4%BD%A0%E5%A5%BD")
}

@Test func urlDecodeChinese() {
    let result = URLCodec.decode("%E4%BD%A0%E5%A5%BD")
    #expect(result == "你好")
}

@Test func urlParseComponents() {
    let components = URLCodec.parse("https://user:pass@example.com:8080/path/to?key=value&a=b#section")
    #expect(components?.scheme == "https")
    #expect(components?.host == "example.com")
    #expect(components?.port == 8080)
    #expect(components?.path == "/path/to")
    #expect(components?.queryItems?.count == 2)
    #expect(components?.fragment == "section")
}

@Test func urlParseNil() {
    let components = URLCodec.parse("")
    #expect(components == nil)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/ConversionTools && swift test`
Expected: FAIL — `URLCodec` not defined

- [ ] **Step 3: Implement URLCodec**

Create `Packages/ConversionTools/Sources/ConversionTools/URLCodec/URLCodec.swift`:

```swift
import Foundation

public enum URLEncodingStandard: String, CaseIterable, Identifiable, Sendable {
    case rfc3986 = "RFC 3986"
    case formData = "Form Data"

    public var id: String { rawValue }
}

public enum URLCodec {
    public static func encode(_ string: String, standard: URLEncodingStandard = .rfc3986) -> String {
        switch standard {
        case .rfc3986:
            var allowed = CharacterSet.urlQueryAllowed
            allowed.remove(charactersIn: "!*'();:@&=+$,/?#[]% ")
            return string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
        case .formData:
            var allowed = CharacterSet.alphanumerics
            allowed.insert(charactersIn: "-._~")
            let encoded = string.addingPercentEncoding(withAllowedCharacters: allowed) ?? string
            return encoded.replacingOccurrences(of: "%20", with: "+")
        }
    }

    public static func decode(_ string: String) -> String {
        let plusDecoded = string.replacingOccurrences(of: "+", with: " ")
        return plusDecoded.removingPercentEncoding ?? string
    }

    public static func parse(_ urlString: String) -> URLComponents? {
        guard !urlString.isEmpty else { return nil }
        return URLComponents(string: urlString)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/ConversionTools && swift test`
Expected: All tests passed

- [ ] **Step 5: Create URLCodecView**

Create `Packages/ConversionTools/Sources/ConversionTools/URLCodec/URLCodecView.swift`:

```swift
import SwiftUI
import DevAppCore

public struct URLCodecView: View {
    @State private var input = ""
    @State private var output = ""
    @State private var standard: URLEncodingStandard = .rfc3986
    @State private var parsedComponents: URLComponents?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InputOutputView(
                title: "URL Encode / Decode",
                description: "Encode and decode URLs with RFC 3986 or Form Data standard",
                input: $input,
                output: $output,
                inputLabel: "Decoded",
                outputLabel: "Encoded"
            ) {
                Picker("Standard", selection: $standard) {
                    ForEach(URLEncodingStandard.allCases) { s in
                        Text(s.rawValue).tag(s)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
            }

            // URL Parser section
            if let components = parsedComponents {
                Divider()
                Text("URL Components")
                    .font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    componentRow("Scheme", components.scheme)
                    componentRow("Host", components.host)
                    componentRow("Port", components.port.map(String.init))
                    componentRow("Path", components.path.isEmpty ? nil : components.path)
                    componentRow("Fragment", components.fragment)
                    if let items = components.queryItems, !items.isEmpty {
                        Text("Query Parameters")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .padding(.top, 4)
                        ForEach(items, id: \.name) { item in
                            HStack {
                                Text(item.name)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.blue)
                                Text("=")
                                    .foregroundStyle(.secondary)
                                Text(item.value ?? "")
                                    .font(.system(.body, design: .monospaced))
                            }
                        }
                    }
                }
                .padding()
                .background(.fill.tertiary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .onChange(of: input) { _, _ in
            output = URLCodec.encode(input, standard: standard)
            parsedComponents = URLCodec.parse(input)
        }
        .onChange(of: standard) { _, _ in
            output = URLCodec.encode(input, standard: standard)
        }
    }

    private func componentRow(_ label: String, _ value: String?) -> some View {
        Group {
            if let value, !value.isEmpty {
                HStack {
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(width: 70, alignment: .trailing)
                    Text(value)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }
            }
        }
    }
}

extension URLCodecView {
    public static let descriptor = ToolDescriptor(
        id: "url-codec",
        name: "URL Encode/Decode",
        icon: "link",
        category: .conversion,
        searchKeywords: ["url", "encode", "decode", "percent", "uri", "编码", "解码"]
    )
}
```

- [ ] **Step 6: Commit**

```bash
git add Packages/ConversionTools/Sources/ConversionTools/URLCodec/ Packages/ConversionTools/Tests/ConversionToolsTests/URLCodecTests.swift
git commit -m "feat: add URL encode/decode with RFC 3986/Form Data + URL parser"
```

---

### Task 10: JSON Formatter

**Files:**
- Create: `Packages/ConversionTools/Sources/ConversionTools/JSONFormatter/JSONFormatter.swift`
- Create: `Packages/ConversionTools/Sources/ConversionTools/JSONFormatter/JSONFormatterView.swift`
- Test: `Packages/ConversionTools/Tests/ConversionToolsTests/JSONFormatterTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Packages/ConversionTools/Tests/ConversionToolsTests/JSONFormatterTests.swift`:

```swift
import Testing
import Foundation
@testable import ConversionTools

@Test func jsonFormat2Spaces() {
    let input = #"{"name":"Alice","age":30}"#
    let result = JSONFormatter.format(input, indent: .spaces2)
    let expected = """
    {
      "age" : 30,
      "name" : "Alice"
    }
    """
    #expect(result.output == expected)
    #expect(result.error == nil)
}

@Test func jsonFormat4Spaces() {
    let input = #"{"a":1}"#
    let result = JSONFormatter.format(input, indent: .spaces4)
    let expected = """
    {
        "a" : 1
    }
    """
    #expect(result.output == expected)
    #expect(result.error == nil)
}

@Test func jsonMinify() {
    let input = """
    {
      "name" : "Alice",
      "age" : 30
    }
    """
    let result = JSONFormatter.minify(input)
    #expect(result.output != nil)
    #expect(result.output?.contains("\n") == false)
    #expect(result.output?.contains(" ") == false || result.output?.contains("\" ") == false)
    #expect(result.error == nil)
}

@Test func jsonValidateValid() {
    let input = #"{"valid": true}"#
    let result = JSONFormatter.validate(input)
    #expect(result.isValid == true)
    #expect(result.error == nil)
}

@Test func jsonValidateInvalid() {
    let input = #"{"invalid": }"#
    let result = JSONFormatter.validate(input)
    #expect(result.isValid == false)
    #expect(result.error != nil)
}

@Test func jsonFormatInvalid() {
    let input = "not json at all"
    let result = JSONFormatter.format(input, indent: .spaces2)
    #expect(result.output == nil)
    #expect(result.error != nil)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/ConversionTools && swift test`
Expected: FAIL — `JSONFormatter` not defined

- [ ] **Step 3: Implement JSONFormatter**

Create `Packages/ConversionTools/Sources/ConversionTools/JSONFormatter/JSONFormatter.swift`:

```swift
import Foundation

public enum JSONIndent: String, CaseIterable, Identifiable, Sendable {
    case spaces2 = "2 Spaces"
    case spaces4 = "4 Spaces"
    case tab = "Tab"

    public var id: String { rawValue }
}

public struct JSONFormatResult: Sendable {
    public let output: String?
    public let error: String?
}

public struct JSONValidationResult: Sendable {
    public let isValid: Bool
    public let error: String?
}

public enum JSONFormatter {
    public static func format(_ input: String, indent: JSONIndent = .spaces2) -> JSONFormatResult {
        guard let data = input.data(using: .utf8) else {
            return JSONFormatResult(output: nil, error: "Invalid UTF-8 string")
        }

        do {
            let object = try JSONSerialization.jsonObject(with: data)
            let options: JSONSerialization.WritingOptions = {
                var opts: JSONSerialization.WritingOptions = [.prettyPrinted, .sortedKeys]
                return opts
            }()
            let formatted = try JSONSerialization.data(withJSONObject: object, options: options)
            var result = String(data: formatted, encoding: .utf8) ?? ""

            // Adjust indentation
            switch indent {
            case .spaces2:
                break // Foundation default is 2 spaces
            case .spaces4:
                result = result.replacingOccurrences(of: "  ", with: "    ")
            case .tab:
                result = result.replacingOccurrences(of: "  ", with: "\t")
            }

            return JSONFormatResult(output: result, error: nil)
        } catch {
            return JSONFormatResult(output: nil, error: error.localizedDescription)
        }
    }

    public static func minify(_ input: String) -> JSONFormatResult {
        guard let data = input.data(using: .utf8) else {
            return JSONFormatResult(output: nil, error: "Invalid UTF-8 string")
        }

        do {
            let object = try JSONSerialization.jsonObject(with: data)
            let minified = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
            let result = String(data: minified, encoding: .utf8) ?? ""
            return JSONFormatResult(output: result, error: nil)
        } catch {
            return JSONFormatResult(output: nil, error: error.localizedDescription)
        }
    }

    public static func validate(_ input: String) -> JSONValidationResult {
        guard let data = input.data(using: .utf8) else {
            return JSONValidationResult(isValid: false, error: "Invalid UTF-8 string")
        }

        do {
            _ = try JSONSerialization.jsonObject(with: data)
            return JSONValidationResult(isValid: true, error: nil)
        } catch {
            return JSONValidationResult(isValid: false, error: error.localizedDescription)
        }
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/ConversionTools && swift test`
Expected: All tests passed

- [ ] **Step 5: Create JSONFormatterView**

Create `Packages/ConversionTools/Sources/ConversionTools/JSONFormatter/JSONFormatterView.swift`:

```swift
import SwiftUI
import DevAppCore

public struct JSONFormatterView: View {
    @State private var input = ""
    @State private var output = ""
    @State private var indent: JSONIndent = .spaces2
    @State private var validationError: String?

    public init() {}

    public var body: some View {
        InputOutputView(
            title: "JSON Formatter",
            description: "Format, minify, and validate JSON",
            input: $input,
            output: $output,
            inputLabel: "Input JSON",
            outputLabel: "Formatted"
        ) {
            HStack(spacing: 16) {
                Picker("Indent", selection: $indent) {
                    ForEach(JSONIndent.allCases) { i in Text(i.rawValue).tag(i) }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)

                Button("Minify") {
                    let result = JSONFormatter.minify(input)
                    if let minified = result.output {
                        output = minified
                    }
                    validationError = result.error
                }
                .buttonStyle(.bordered)

                if let validationError {
                    Label(validationError, systemImage: "xmark.circle")
                        .font(.caption)
                        .foregroundStyle(.red)
                } else if !input.isEmpty {
                    Label("Valid JSON", systemImage: "checkmark.circle")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }
        }
        .onChange(of: input) { _, _ in formatJSON() }
        .onChange(of: indent) { _, _ in formatJSON() }
    }

    private func formatJSON() {
        guard !input.isEmpty else {
            output = ""
            validationError = nil
            return
        }
        let result = JSONFormatter.format(input, indent: indent)
        output = result.output ?? ""
        validationError = result.error
    }
}

extension JSONFormatterView {
    public static let descriptor = ToolDescriptor(
        id: "json-formatter",
        name: "JSON Formatter",
        icon: "curlybraces",
        category: .conversion,
        searchKeywords: ["json", "format", "beautify", "minify", "validate", "格式化", "校验"]
    )
}
```

- [ ] **Step 6: Commit**

```bash
git add Packages/ConversionTools/Sources/ConversionTools/JSONFormatter/ Packages/ConversionTools/Tests/ConversionToolsTests/JSONFormatterTests.swift
git commit -m "feat: add JSON formatter with format/minify/validate"
```

---

### Task 11: Unix Timestamp Converter

**Files:**
- Create: `Packages/ConversionTools/Sources/ConversionTools/UnixTimestamp/TimestampConverter.swift`
- Create: `Packages/ConversionTools/Sources/ConversionTools/UnixTimestamp/TimestampConverterView.swift`
- Test: `Packages/ConversionTools/Tests/ConversionToolsTests/TimestampConverterTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Packages/ConversionTools/Tests/ConversionToolsTests/TimestampConverterTests.swift`:

```swift
import Testing
import Foundation
@testable import ConversionTools

@Test func timestampToDateUTC() {
    let result = TimestampConverter.toDate(timestamp: 0, timeZone: .gmt)
    #expect(result.iso8601 == "1970-01-01T00:00:00Z")
}

@Test func timestampToDateKnownValue() {
    // 2024-01-01 00:00:00 UTC = 1704067200
    let result = TimestampConverter.toDate(timestamp: 1704067200, timeZone: .gmt)
    #expect(result.iso8601 == "2024-01-01T00:00:00Z")
}

@Test func dateToTimestamp() {
    let ts = TimestampConverter.toTimestamp(
        year: 2024, month: 1, day: 1,
        hour: 0, minute: 0, second: 0,
        timeZone: .gmt
    )
    #expect(ts == 1704067200)
}

@Test func autoDetectSeconds() {
    // 10-digit number = seconds
    #expect(TimestampConverter.detectUnit("1704067200") == .seconds)
}

@Test func autoDetectMilliseconds() {
    // 13-digit number = milliseconds
    #expect(TimestampConverter.detectUnit("1704067200000") == .milliseconds)
}

@Test func millisecondsToDate() {
    let result = TimestampConverter.toDate(timestamp: 1704067200000, isMilliseconds: true, timeZone: .gmt)
    #expect(result.iso8601 == "2024-01-01T00:00:00Z")
}

@Test func formatCustom() {
    let result = TimestampConverter.toDate(timestamp: 1704067200, timeZone: .gmt)
    #expect(result.custom == "2024-01-01 00:00:00")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/ConversionTools && swift test`
Expected: FAIL — `TimestampConverter` not defined

- [ ] **Step 3: Implement TimestampConverter**

Create `Packages/ConversionTools/Sources/ConversionTools/UnixTimestamp/TimestampConverter.swift`:

```swift
import Foundation

public enum TimestampUnit: String, Sendable {
    case seconds
    case milliseconds
}

public struct TimestampResult: Sendable {
    public let iso8601: String
    public let rfc2822: String
    public let custom: String  // yyyy-MM-dd HH:mm:ss
    public let date: Date
}

public enum TimestampConverter {
    public static func detectUnit(_ input: String) -> TimestampUnit {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count >= 13 {
            return .milliseconds
        }
        return .seconds
    }

    public static func toDate(
        timestamp: Int64,
        isMilliseconds: Bool = false,
        timeZone: TimeZone = .current
    ) -> TimestampResult {
        let seconds: TimeInterval = isMilliseconds
            ? Double(timestamp) / 1000.0
            : Double(timestamp)
        let date = Date(timeIntervalSince1970: seconds)

        let iso8601Formatter = ISO8601DateFormatter()
        iso8601Formatter.timeZone = timeZone

        let rfc2822Formatter = DateFormatter()
        rfc2822Formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        rfc2822Formatter.timeZone = timeZone
        rfc2822Formatter.locale = Locale(identifier: "en_US_POSIX")

        let customFormatter = DateFormatter()
        customFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        customFormatter.timeZone = timeZone

        return TimestampResult(
            iso8601: iso8601Formatter.string(from: date),
            rfc2822: rfc2822Formatter.string(from: date),
            custom: customFormatter.string(from: date),
            date: date
        )
    }

    public static func toTimestamp(
        year: Int, month: Int, day: Int,
        hour: Int, minute: Int, second: Int,
        timeZone: TimeZone = .current
    ) -> Int64? {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        guard let date = calendar.date(from: components) else { return nil }
        return Int64(date.timeIntervalSince1970)
    }

    public static func currentTimestamp() -> Int64 {
        Int64(Date().timeIntervalSince1970)
    }

    public static func currentTimestampMillis() -> Int64 {
        Int64(Date().timeIntervalSince1970 * 1000)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/ConversionTools && swift test`
Expected: All tests passed

- [ ] **Step 5: Create TimestampConverterView**

Create `Packages/ConversionTools/Sources/ConversionTools/UnixTimestamp/TimestampConverterView.swift`:

```swift
import SwiftUI
import DevAppCore

public struct TimestampConverterView: View {
    @State private var timestampInput = ""
    @State private var dateTimeInput = ""
    @State private var selectedTimeZone: TimeZone = .current
    @State private var nowTimestamp: Int64 = 0
    @State private var result: TimestampResult?
    @State private var timer: Timer?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Unix Timestamp Converter")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Convert between Unix timestamps and human-readable dates")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Live clock
            HStack {
                Text("Now:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(nowTimestamp)")
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.medium)
                    .foregroundStyle(.blue)
                CopyButton(text: "\(nowTimestamp)")
            }
            .padding(10)
            .background(.fill.tertiary)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Timezone picker
            Picker("Time Zone", selection: $selectedTimeZone) {
                Text("UTC").tag(TimeZone.gmt)
                Text("Local (\(TimeZone.current.identifier))").tag(TimeZone.current)
            }
            .pickerStyle(.segmented)
            .frame(width: 400)

            // Conversion panels
            HStack(alignment: .top, spacing: 12) {
                // Timestamp input
                VStack(alignment: .leading, spacing: 4) {
                    Text("Timestamp")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    TextField("Enter Unix timestamp...", text: $timestampInput)
                        .font(.system(.title3, design: .monospaced))
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    if let result {
                        VStack(alignment: .leading, spacing: 6) {
                            formatRow("ISO 8601", result.iso8601)
                            formatRow("RFC 2822", result.rfc2822)
                            formatRow("Custom", result.custom)
                        }
                        .padding(.top, 8)
                    }
                }

                // Date/time input
                VStack(alignment: .leading, spacing: 4) {
                    Text("Date & Time")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    TextField("yyyy-MM-dd HH:mm:ss", text: $dateTimeInput)
                        .font(.system(.title3, design: .monospaced))
                        .textFieldStyle(.plain)
                        .padding(10)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .onAppear { startTimer() }
        .onDisappear { timer?.invalidate() }
        .onChange(of: timestampInput) { _, newValue in
            convertTimestamp(newValue)
        }
        .onChange(of: dateTimeInput) { _, newValue in
            convertDateTime(newValue)
        }
        .onChange(of: selectedTimeZone) { _, _ in
            convertTimestamp(timestampInput)
        }
    }

    private func formatRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 70, alignment: .trailing)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
            Spacer()
            CopyButton(text: value)
        }
    }

    private func startTimer() {
        nowTimestamp = TimestampConverter.currentTimestamp()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            nowTimestamp = TimestampConverter.currentTimestamp()
        }
    }

    private func convertTimestamp(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Int64(trimmed) else {
            result = nil
            return
        }
        let unit = TimestampConverter.detectUnit(trimmed)
        result = TimestampConverter.toDate(
            timestamp: value,
            isMilliseconds: unit == .milliseconds,
            timeZone: selectedTimeZone
        )
        if let result {
            dateTimeInput = result.custom
        }
    }

    private func convertDateTime(_ input: String) {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.timeZone = selectedTimeZone
        guard let date = formatter.date(from: input) else { return }
        let ts = Int64(date.timeIntervalSince1970)
        timestampInput = "\(ts)"
    }
}

extension TimestampConverterView {
    public static let descriptor = ToolDescriptor(
        id: "timestamp-converter",
        name: "Unix Timestamp",
        icon: "clock",
        category: .conversion,
        searchKeywords: ["unix", "timestamp", "time", "date", "epoch", "时间戳", "时间"]
    )
}
```

- [ ] **Step 6: Commit**

```bash
git add Packages/ConversionTools/Sources/ConversionTools/UnixTimestamp/ Packages/ConversionTools/Tests/ConversionToolsTests/TimestampConverterTests.swift
git commit -m "feat: add Unix timestamp converter with live clock and timezone support"
```

---

## Phase 4: API Client

### Task 12: HTTP Client — SwiftData Models

**Files:**
- Create: `Packages/APIClient/Sources/APIClient/Models/SupportTypes.swift`
- Create: `Packages/APIClient/Sources/APIClient/Models/HTTPRequestModel.swift`
- Create: `Packages/APIClient/Sources/APIClient/Models/HTTPCollectionModel.swift`
- Create: `Packages/APIClient/Sources/APIClient/Models/HTTPHistoryModel.swift`
- Test: `Packages/APIClient/Tests/APIClientTests/SupportTypesTests.swift`

- [ ] **Step 1: Write failing tests for support types**

Create `Packages/APIClient/Tests/APIClientTests/SupportTypesTests.swift`:

```swift
import Testing
import Foundation
@testable import APIClient

@Test func keyValuePairCodable() throws {
    let pair = KeyValuePair(key: "Content-Type", value: "application/json", isEnabled: true)
    let data = try JSONEncoder().encode(pair)
    let decoded = try JSONDecoder().decode(KeyValuePair.self, from: data)
    #expect(decoded.key == "Content-Type")
    #expect(decoded.value == "application/json")
    #expect(decoded.isEnabled == true)
}

@Test func requestBodyJSONCodable() throws {
    let body = RequestBody.json(#"{"key": "value"}"#)
    let data = try JSONEncoder().encode(body)
    let decoded = try JSONDecoder().decode(RequestBody.self, from: data)
    if case .json(let str) = decoded {
        #expect(str == #"{"key": "value"}"#)
    } else {
        Issue.record("Expected .json case")
    }
}

@Test func authTypeBearerCodable() throws {
    let auth = AuthType.bearerToken("my-token")
    let data = try JSONEncoder().encode(auth)
    let decoded = try JSONDecoder().decode(AuthType.self, from: data)
    if case .bearerToken(let token) = decoded {
        #expect(token == "my-token")
    } else {
        Issue.record("Expected .bearerToken case")
    }
}

@Test func authTypeBasicCodable() throws {
    let auth = AuthType.basicAuth(username: "user", password: "pass")
    let data = try JSONEncoder().encode(auth)
    let decoded = try JSONDecoder().decode(AuthType.self, from: data)
    if case .basicAuth(let u, let p) = decoded {
        #expect(u == "user")
        #expect(p == "pass")
    } else {
        Issue.record("Expected .basicAuth case")
    }
}

@Test func httpMethodAllCases() {
    #expect(HTTPMethod.allCases.count == 7)
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/APIClient && swift test`
Expected: FAIL — types not defined

- [ ] **Step 3: Implement support types**

Create `Packages/APIClient/Sources/APIClient/Models/SupportTypes.swift`:

```swift
import Foundation

public struct KeyValuePair: Codable, Hashable, Identifiable, Sendable {
    public var id = UUID()
    public var key: String
    public var value: String
    public var isEnabled: Bool

    public init(key: String = "", value: String = "", isEnabled: Bool = true) {
        self.key = key
        self.value = value
        self.isEnabled = isEnabled
    }
}

public enum HTTPMethod: String, CaseIterable, Identifiable, Codable, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
    case head = "HEAD"
    case options = "OPTIONS"

    public var id: String { rawValue }

    public var color: String {
        switch self {
        case .get: "green"
        case .post: "orange"
        case .put: "blue"
        case .patch: "purple"
        case .delete: "red"
        case .head: "gray"
        case .options: "gray"
        }
    }
}

public enum RequestBody: Codable, Sendable {
    case json(String)
    case formData([KeyValuePair])
    case raw(String)
    case binary(Data)
}

public enum AuthType: Codable, Sendable {
    case bearerToken(String)
    case basicAuth(username: String, password: String)
    case apiKey(key: String, value: String, addTo: APIKeyLocation)
}

public enum APIKeyLocation: String, Codable, Sendable {
    case header
    case queryParam
}
```

- [ ] **Step 4: Implement SwiftData models**

Create `Packages/APIClient/Sources/APIClient/Models/HTTPRequestModel.swift`:

```swift
import Foundation
import SwiftData

@Model
public final class HTTPRequestModel {
    public var id: UUID
    public var name: String
    public var method: String
    public var url: String
    public var headersJSON: Data?      // Encoded [KeyValuePair]
    public var bodyJSON: Data?         // Encoded RequestBody
    public var authJSON: Data?         // Encoded AuthType
    public var collection: HTTPCollectionModel?
    public var createdAt: Date
    public var lastExecutedAt: Date?

    public init(
        name: String = "New Request",
        method: String = "GET",
        url: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.method = method
        self.url = url
        self.createdAt = Date()
    }

    // MARK: - Codable helpers

    public var headers: [KeyValuePair] {
        get {
            guard let data = headersJSON else { return [] }
            return (try? JSONDecoder().decode([KeyValuePair].self, from: data)) ?? []
        }
        set {
            headersJSON = try? JSONEncoder().encode(newValue)
        }
    }

    public var body: RequestBody? {
        get {
            guard let data = bodyJSON else { return nil }
            return try? JSONDecoder().decode(RequestBody.self, from: data)
        }
        set {
            bodyJSON = try? JSONEncoder().encode(newValue)
        }
    }

    public var auth: AuthType? {
        get {
            guard let data = authJSON else { return nil }
            return try? JSONDecoder().decode(AuthType.self, from: data)
        }
        set {
            authJSON = try? JSONEncoder().encode(newValue)
        }
    }
}
```

Create `Packages/APIClient/Sources/APIClient/Models/HTTPCollectionModel.swift`:

```swift
import Foundation
import SwiftData

@Model
public final class HTTPCollectionModel {
    public var id: UUID
    public var name: String
    @Relationship(deleteRule: .cascade, inverse: \HTTPRequestModel.collection)
    public var requests: [HTTPRequestModel]
    public var parentCollection: HTTPCollectionModel?
    public var createdAt: Date

    public init(name: String = "New Collection") {
        self.id = UUID()
        self.name = name
        self.requests = []
        self.createdAt = Date()
    }
}
```

Create `Packages/APIClient/Sources/APIClient/Models/HTTPHistoryModel.swift`:

```swift
import Foundation
import SwiftData

@Model
public final class HTTPHistoryModel {
    public var id: UUID
    public var requestMethod: String
    public var requestURL: String
    public var requestHeadersJSON: Data?
    public var requestBodyJSON: Data?
    public var responseStatus: Int
    public var responseBody: Data?
    public var responseHeadersJSON: Data?
    public var duration: TimeInterval
    public var responseSize: Int
    public var executedAt: Date

    public init(
        requestMethod: String,
        requestURL: String,
        responseStatus: Int,
        duration: TimeInterval,
        responseSize: Int
    ) {
        self.id = UUID()
        self.requestMethod = requestMethod
        self.requestURL = requestURL
        self.responseStatus = responseStatus
        self.duration = duration
        self.responseSize = responseSize
        self.executedAt = Date()
    }
}
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/APIClient && swift test`
Expected: All tests passed

- [ ] **Step 6: Commit**

```bash
git add Packages/APIClient/Sources/APIClient/Models/ Packages/APIClient/Tests/APIClientTests/SupportTypesTests.swift
git commit -m "feat: add HTTP client SwiftData models and support types"
```

---

### Task 13: HTTP Client — Networking Service

**Files:**
- Create: `Packages/APIClient/Sources/APIClient/Networking/HTTPClientService.swift`
- Test: `Packages/APIClient/Tests/APIClientTests/HTTPClientServiceTests.swift`

- [ ] **Step 1: Write failing tests**

Create `Packages/APIClient/Tests/APIClientTests/HTTPClientServiceTests.swift`:

```swift
import Testing
import Foundation
@testable import APIClient

@Test func buildURLRequestGET() throws {
    let request = try HTTPClientService.buildURLRequest(
        method: .get,
        url: "https://example.com/api?page=1",
        headers: [KeyValuePair(key: "Accept", value: "application/json")],
        queryParams: [],
        body: nil,
        auth: nil
    )
    #expect(request.httpMethod == "GET")
    #expect(request.url?.absoluteString == "https://example.com/api?page=1")
    #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
}

@Test func buildURLRequestPOSTJSON() throws {
    let body = RequestBody.json(#"{"name":"test"}"#)
    let request = try HTTPClientService.buildURLRequest(
        method: .post,
        url: "https://example.com/api",
        headers: [],
        queryParams: [],
        body: body,
        auth: nil
    )
    #expect(request.httpMethod == "POST")
    #expect(request.httpBody == Data(#"{"name":"test"}"#.utf8))
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
}

@Test func buildURLRequestWithBearerAuth() throws {
    let auth = AuthType.bearerToken("my-token-123")
    let request = try HTTPClientService.buildURLRequest(
        method: .get,
        url: "https://example.com/api",
        headers: [],
        queryParams: [],
        body: nil,
        auth: auth
    )
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer my-token-123")
}

@Test func buildURLRequestWithBasicAuth() throws {
    let auth = AuthType.basicAuth(username: "user", password: "pass")
    let request = try HTTPClientService.buildURLRequest(
        method: .get,
        url: "https://example.com/api",
        headers: [],
        queryParams: [],
        body: nil,
        auth: auth
    )
    let expected = "Basic " + Data("user:pass".utf8).base64EncodedString()
    #expect(request.value(forHTTPHeaderField: "Authorization") == expected)
}

@Test func buildURLRequestWithQueryParams() throws {
    let params = [
        KeyValuePair(key: "page", value: "1"),
        KeyValuePair(key: "limit", value: "20")
    ]
    let request = try HTTPClientService.buildURLRequest(
        method: .get,
        url: "https://example.com/api",
        headers: [],
        queryParams: params,
        body: nil,
        auth: nil
    )
    let url = request.url!.absoluteString
    #expect(url.contains("page=1"))
    #expect(url.contains("limit=20"))
}

@Test func buildURLRequestDisabledHeader() throws {
    let headers = [
        KeyValuePair(key: "Accept", value: "application/json", isEnabled: true),
        KeyValuePair(key: "X-Debug", value: "true", isEnabled: false)
    ]
    let request = try HTTPClientService.buildURLRequest(
        method: .get,
        url: "https://example.com/api",
        headers: headers,
        queryParams: [],
        body: nil,
        auth: nil
    )
    #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    #expect(request.value(forHTTPHeaderField: "X-Debug") == nil)
}

@Test func invalidURLThrows() {
    #expect(throws: HTTPClientError.self) {
        try HTTPClientService.buildURLRequest(
            method: .get,
            url: "",
            headers: [],
            queryParams: [],
            body: nil,
            auth: nil
        )
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/APIClient && swift test`
Expected: FAIL — `HTTPClientService` not defined

- [ ] **Step 3: Implement HTTPClientService**

Create `Packages/APIClient/Sources/APIClient/Networking/HTTPClientService.swift`:

```swift
import Foundation

public enum HTTPClientError: Error, LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case noResponse

    public var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL"
        case .requestFailed(let e): "Request failed: \(e.localizedDescription)"
        case .noResponse: "No response received"
        }
    }
}

public struct HTTPResponse: Sendable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data
    public let duration: TimeInterval
    public let bodySize: Int
    public let cookies: [String]

    public var statusColor: String {
        switch statusCode {
        case 200..<300: "green"
        case 300..<400: "blue"
        case 400..<500: "orange"
        default: "red"
        }
    }
}

public enum HTTPClientService {
    public static func buildURLRequest(
        method: HTTPMethod,
        url: String,
        headers: [KeyValuePair],
        queryParams: [KeyValuePair],
        body: RequestBody?,
        auth: AuthType?
    ) throws -> URLRequest {
        guard var components = URLComponents(string: url), !url.isEmpty else {
            throw HTTPClientError.invalidURL
        }

        // Add query params
        let enabledParams = queryParams.filter(\.isEnabled)
        if !enabledParams.isEmpty {
            var items = components.queryItems ?? []
            items.append(contentsOf: enabledParams.map { URLQueryItem(name: $0.key, value: $0.value) })
            components.queryItems = items
        }

        guard let finalURL = components.url else {
            throw HTTPClientError.invalidURL
        }

        var request = URLRequest(url: finalURL)
        request.httpMethod = method.rawValue

        // Headers
        for header in headers where header.isEnabled && !header.key.isEmpty {
            request.setValue(header.value, forHTTPHeaderField: header.key)
        }

        // Body
        if let body {
            switch body {
            case .json(let json):
                request.httpBody = Data(json.utf8)
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
                }
            case .formData(let pairs):
                let encoded = pairs.filter(\.isEnabled)
                    .map { "\($0.key)=\($0.value)" }
                    .joined(separator: "&")
                request.httpBody = Data(encoded.utf8)
                if request.value(forHTTPHeaderField: "Content-Type") == nil {
                    request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                }
            case .raw(let text):
                request.httpBody = Data(text.utf8)
            case .binary(let data):
                request.httpBody = data
            }
        }

        // Auth
        if let auth {
            switch auth {
            case .bearerToken(let token):
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            case .basicAuth(let username, let password):
                let credentials = Data("\(username):\(password)".utf8).base64EncodedString()
                request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
            case .apiKey(let key, let value, let location):
                switch location {
                case .header:
                    request.setValue(value, forHTTPHeaderField: key)
                case .queryParam:
                    if var comps = URLComponents(url: finalURL, resolvingAgainstBaseURL: false) {
                        var items = comps.queryItems ?? []
                        items.append(URLQueryItem(name: key, value: value))
                        comps.queryItems = items
                        if let newURL = comps.url {
                            request.url = newURL
                        }
                    }
                }
            }
        }

        return request
    }

    public static func send(_ request: URLRequest) async throws -> HTTPResponse {
        let start = Date()
        let (data, response) = try await URLSession.shared.data(for: request)
        let duration = Date().timeIntervalSince(start)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPClientError.noResponse
        }

        let headers = Dictionary(
            uniqueKeysWithValues: httpResponse.allHeaderFields.compactMap { key, value in
                guard let k = key as? String, let v = value as? String else { return nil }
                return (k, v)
            }
        )

        let cookies = (headers["Set-Cookie"] ?? "")
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        return HTTPResponse(
            statusCode: httpResponse.statusCode,
            headers: headers,
            body: data,
            duration: duration,
            bodySize: data.count,
            cookies: cookies
        )
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/APIClient && swift test`
Expected: All tests passed

- [ ] **Step 5: Commit**

```bash
git add Packages/APIClient/Sources/APIClient/Networking/ Packages/APIClient/Tests/APIClientTests/HTTPClientServiceTests.swift
git commit -m "feat: add HTTP client networking service with request builder"
```

---

### Task 14: HTTP Client — Request Editor UI

**Files:**
- Create: `Packages/APIClient/Sources/APIClient/RequestEditor/URLBar.swift`
- Create: `Packages/APIClient/Sources/APIClient/RequestEditor/HeadersEditor.swift`
- Create: `Packages/APIClient/Sources/APIClient/RequestEditor/BodyEditor.swift`
- Create: `Packages/APIClient/Sources/APIClient/RequestEditor/AuthEditor.swift`
- Create: `Packages/APIClient/Sources/APIClient/RequestEditor/KeyValueEditor.swift`
- Create: `Packages/APIClient/Sources/APIClient/RequestEditor/RequestEditorView.swift`

- [ ] **Step 1: Create KeyValueEditor (shared component)**

Create `Packages/APIClient/Sources/APIClient/RequestEditor/KeyValueEditor.swift`:

```swift
import SwiftUI

struct KeyValueEditor: View {
    @Binding var pairs: [KeyValuePair]
    let keyPlaceholder: String
    let valuePlaceholder: String

    init(
        pairs: Binding<[KeyValuePair]>,
        keyPlaceholder: String = "Key",
        valuePlaceholder: String = "Value"
    ) {
        self._pairs = pairs
        self.keyPlaceholder = keyPlaceholder
        self.valuePlaceholder = valuePlaceholder
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 0) {
                Toggle("", isOn: .constant(true))
                    .labelsHidden()
                    .frame(width: 30)
                    .hidden()
                Text(keyPlaceholder)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 8)
                Text(valuePlaceholder)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 8)
                Spacer().frame(width: 30)
            }
            .padding(.vertical, 4)

            Divider()

            // Rows
            ForEach($pairs) { $pair in
                HStack(spacing: 0) {
                    Toggle("", isOn: $pair.isEnabled)
                        .labelsHidden()
                        .frame(width: 30)
                    TextField(keyPlaceholder, text: $pair.key)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .padding(4)
                    TextField(valuePlaceholder, text: $pair.value)
                        .textFieldStyle(.plain)
                        .font(.system(.body, design: .monospaced))
                        .padding(4)
                    Button {
                        pairs.removeAll { $0.id == pair.id }
                    } label: {
                        Image(systemName: "minus.circle")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .frame(width: 30)
                }
                .padding(.vertical, 2)
                Divider()
            }

            // Add row
            Button {
                pairs.append(KeyValuePair())
            } label: {
                Label("Add", systemImage: "plus")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .padding(8)
        }
        .background(.fill.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
```

- [ ] **Step 2: Create URLBar**

Create `Packages/APIClient/Sources/APIClient/RequestEditor/URLBar.swift`:

```swift
import SwiftUI

struct URLBar: View {
    @Binding var method: HTTPMethod
    @Binding var url: String
    let onSend: () -> Void
    let isSending: Bool

    var body: some View {
        HStack(spacing: 8) {
            Picker("", selection: $method) {
                ForEach(HTTPMethod.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 100)

            TextField("Enter URL...", text: $url)
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.plain)
                .padding(8)
                .background(.fill.tertiary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .onSubmit { onSend() }

            Button(action: onSend) {
                if isSending {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Text("Send")
                        .fontWeight(.medium)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isSending || url.isEmpty)
        }
    }
}
```

- [ ] **Step 3: Create HeadersEditor, BodyEditor, AuthEditor**

Create `Packages/APIClient/Sources/APIClient/RequestEditor/HeadersEditor.swift`:

```swift
import SwiftUI

struct HeadersEditor: View {
    @Binding var headers: [KeyValuePair]

    var body: some View {
        KeyValueEditor(
            pairs: $headers,
            keyPlaceholder: "Header",
            valuePlaceholder: "Value"
        )
    }
}
```

Create `Packages/APIClient/Sources/APIClient/RequestEditor/BodyEditor.swift`:

```swift
import SwiftUI

enum BodyType: String, CaseIterable, Identifiable {
    case none = "None"
    case json = "JSON"
    case formData = "Form Data"
    case raw = "Raw"

    var id: String { rawValue }
}

struct BodyEditor: View {
    @Binding var bodyType: BodyType
    @Binding var jsonBody: String
    @Binding var formDataPairs: [KeyValuePair]
    @Binding var rawBody: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Type", selection: $bodyType) {
                ForEach(BodyType.allCases) { t in Text(t.rawValue).tag(t) }
            }
            .pickerStyle(.segmented)
            .frame(width: 350)

            switch bodyType {
            case .none:
                ContentUnavailableView("No Body", systemImage: "doc")
            case .json:
                TextEditor(text: $jsonBody)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(.fill.tertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            case .formData:
                KeyValueEditor(pairs: $formDataPairs, keyPlaceholder: "Key", valuePlaceholder: "Value")
            case .raw:
                TextEditor(text: $rawBody)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .background(.fill.tertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
```

Create `Packages/APIClient/Sources/APIClient/RequestEditor/AuthEditor.swift`:

```swift
import SwiftUI

enum AuthMethod: String, CaseIterable, Identifiable {
    case none = "None"
    case bearer = "Bearer Token"
    case basic = "Basic Auth"
    case apiKey = "API Key"

    var id: String { rawValue }
}

struct AuthEditor: View {
    @Binding var authMethod: AuthMethod
    @Binding var bearerToken: String
    @Binding var basicUsername: String
    @Binding var basicPassword: String
    @Binding var apiKeyName: String
    @Binding var apiKeyValue: String
    @Binding var apiKeyLocation: APIKeyLocation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("Auth", selection: $authMethod) {
                ForEach(AuthMethod.allCases) { m in Text(m.rawValue).tag(m) }
            }
            .pickerStyle(.segmented)
            .frame(width: 400)

            switch authMethod {
            case .none:
                ContentUnavailableView("No Authentication", systemImage: "lock.open")
            case .bearer:
                TextField("Token", text: $bearerToken)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(.fill.tertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            case .basic:
                HStack {
                    TextField("Username", text: $basicUsername)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    SecureField("Password", text: $basicPassword)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            case .apiKey:
                HStack {
                    TextField("Key Name", text: $apiKeyName)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    TextField("Value", text: $apiKeyValue)
                        .textFieldStyle(.plain)
                        .padding(8)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    Picker("Add to", selection: $apiKeyLocation) {
                        Text("Header").tag(APIKeyLocation.header)
                        Text("Query").tag(APIKeyLocation.queryParam)
                    }
                    .frame(width: 120)
                }
            }
        }
    }
}
```

- [ ] **Step 4: Create RequestEditorView**

Create `Packages/APIClient/Sources/APIClient/RequestEditor/RequestEditorView.swift`:

```swift
import SwiftUI

enum RequestTab: String, CaseIterable, Identifiable {
    case params = "Params"
    case headers = "Headers"
    case body = "Body"
    case auth = "Auth"

    var id: String { rawValue }
}

struct RequestEditorView: View {
    @Binding var method: HTTPMethod
    @Binding var url: String
    @Binding var queryParams: [KeyValuePair]
    @Binding var headers: [KeyValuePair]
    @Binding var bodyType: BodyType
    @Binding var jsonBody: String
    @Binding var formDataPairs: [KeyValuePair]
    @Binding var rawBody: String
    @Binding var authMethod: AuthMethod
    @Binding var bearerToken: String
    @Binding var basicUsername: String
    @Binding var basicPassword: String
    @Binding var apiKeyName: String
    @Binding var apiKeyValue: String
    @Binding var apiKeyLocation: APIKeyLocation
    let isSending: Bool
    let onSend: () -> Void

    @State private var selectedTab: RequestTab = .params

    var body: some View {
        VStack(spacing: 0) {
            URLBar(method: $method, url: $url, onSend: onSend, isSending: isSending)
                .padding(12)

            Picker("", selection: $selectedTab) {
                ForEach(RequestTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 12)

            Divider().padding(.top, 8)

            ScrollView {
                Group {
                    switch selectedTab {
                    case .params:
                        KeyValueEditor(pairs: $queryParams, keyPlaceholder: "Parameter", valuePlaceholder: "Value")
                    case .headers:
                        HeadersEditor(headers: $headers)
                    case .body:
                        BodyEditor(bodyType: $bodyType, jsonBody: $jsonBody, formDataPairs: $formDataPairs, rawBody: $rawBody)
                    case .auth:
                        AuthEditor(
                            authMethod: $authMethod,
                            bearerToken: $bearerToken,
                            basicUsername: $basicUsername,
                            basicPassword: $basicPassword,
                            apiKeyName: $apiKeyName,
                            apiKeyValue: $apiKeyValue,
                            apiKeyLocation: $apiKeyLocation
                        )
                    }
                }
                .padding(12)
            }
        }
    }
}
```

- [ ] **Step 5: Build and commit**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/APIClient && swift build`
Expected: Build Succeeded

```bash
git add Packages/APIClient/Sources/APIClient/RequestEditor/
git commit -m "feat: add HTTP request editor UI — URL bar, headers, body, auth"
```

---

### Task 15: HTTP Client — Response Viewer UI

**Files:**
- Create: `Packages/APIClient/Sources/APIClient/ResponseViewer/ResponseView.swift`
- Create: `Packages/APIClient/Sources/APIClient/ResponseViewer/JSONTreeView.swift`
- Create: `Packages/APIClient/Sources/APIClient/ResponseViewer/StatusBadge.swift`

- [ ] **Step 1: Create StatusBadge**

Create `Packages/APIClient/Sources/APIClient/ResponseViewer/StatusBadge.swift`:

```swift
import SwiftUI

struct StatusBadge: View {
    let statusCode: Int
    let duration: TimeInterval
    let size: Int

    var statusColor: Color {
        switch statusCode {
        case 200..<300: .green
        case 300..<400: .blue
        case 400..<500: .orange
        default: .red
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text("\(statusCode)")
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .foregroundStyle(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 4))

            Text(String(format: "%.0fms", duration * 1000))
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(formattedSize)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var formattedSize: String {
        if size < 1024 {
            return "\(size) B"
        } else if size < 1024 * 1024 {
            return String(format: "%.1f KB", Double(size) / 1024)
        } else {
            return String(format: "%.1f MB", Double(size) / 1024 / 1024)
        }
    }
}
```

- [ ] **Step 2: Create JSONTreeView**

Create `Packages/APIClient/Sources/APIClient/ResponseViewer/JSONTreeView.swift`:

```swift
import SwiftUI

struct JSONTreeView: View {
    let jsonString: String

    var body: some View {
        ScrollView {
            Text(prettyJSON)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
        }
        .background(.fill.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var prettyJSON: String {
        guard let data = jsonString.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data),
              let pretty = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let result = String(data: pretty, encoding: .utf8) else {
            return jsonString
        }
        return result
    }
}
```

- [ ] **Step 3: Create ResponseView**

Create `Packages/APIClient/Sources/APIClient/ResponseViewer/ResponseView.swift`:

```swift
import SwiftUI
import DevAppCore

enum ResponseTab: String, CaseIterable, Identifiable {
    case body = "Body"
    case headers = "Headers"
    case cookies = "Cookies"

    var id: String { rawValue }
}

struct ResponseView: View {
    let response: HTTPResponse?
    let error: String?
    @State private var selectedTab: ResponseTab = .body

    var body: some View {
        VStack(spacing: 0) {
            if let response {
                // Status bar
                HStack {
                    StatusBadge(
                        statusCode: response.statusCode,
                        duration: response.duration,
                        size: response.bodySize
                    )
                    Spacer()
                    CopyButton(text: String(data: response.body, encoding: .utf8) ?? "")
                }
                .padding(12)

                Picker("", selection: $selectedTab) {
                    ForEach(ResponseTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12)

                Divider().padding(.top, 8)

                switch selectedTab {
                case .body:
                    let bodyString = String(data: response.body, encoding: .utf8) ?? ""
                    if isJSON(bodyString) {
                        JSONTreeView(jsonString: bodyString)
                            .padding(12)
                    } else {
                        ScrollView {
                            Text(bodyString)
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                        }
                    }
                case .headers:
                    List {
                        ForEach(Array(response.headers.sorted(by: { $0.key < $1.key })), id: \.key) { key, value in
                            HStack {
                                Text(key)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.blue)
                                Spacer()
                                Text(value)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                case .cookies:
                    if response.cookies.isEmpty {
                        ContentUnavailableView("No Cookies", systemImage: "tray")
                    } else {
                        List(response.cookies, id: \.self) { cookie in
                            Text(cookie)
                                .font(.system(.body, design: .monospaced))
                        }
                    }
                }
            } else if let error {
                ContentUnavailableView {
                    Label("Request Failed", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(error)
                }
            } else {
                ContentUnavailableView(
                    "No Response",
                    systemImage: "arrow.up.circle",
                    description: Text("Send a request to see the response")
                )
            }
        }
    }

    private func isJSON(_ string: String) -> Bool {
        guard let data = string.data(using: .utf8) else { return false }
        return (try? JSONSerialization.jsonObject(with: data)) != nil
    }
}
```

- [ ] **Step 4: Build and commit**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/APIClient && swift build`
Expected: Build Succeeded

```bash
git add Packages/APIClient/Sources/APIClient/ResponseViewer/
git commit -m "feat: add HTTP response viewer — status badge, JSON tree, headers, cookies"
```

---

### Task 16: HTTP Client — Full Integration View

**Files:**
- Create: `Packages/APIClient/Sources/APIClient/APIClientView.swift`

- [ ] **Step 1: Create APIClientView combining all components**

Create `Packages/APIClient/Sources/APIClient/APIClientView.swift`:

```swift
import SwiftUI
import DevAppCore

public struct APIClientView: View {
    // Request state
    @State private var method: HTTPMethod = .get
    @State private var url = ""
    @State private var queryParams: [KeyValuePair] = [KeyValuePair()]
    @State private var headers: [KeyValuePair] = [KeyValuePair()]
    @State private var bodyType: BodyType = .none
    @State private var jsonBody = ""
    @State private var formDataPairs: [KeyValuePair] = [KeyValuePair()]
    @State private var rawBody = ""

    // Auth state
    @State private var authMethod: AuthMethod = .none
    @State private var bearerToken = ""
    @State private var basicUsername = ""
    @State private var basicPassword = ""
    @State private var apiKeyName = ""
    @State private var apiKeyValue = ""
    @State private var apiKeyLocation: APIKeyLocation = .header

    // Response state
    @State private var response: HTTPResponse?
    @State private var errorMessage: String?
    @State private var isSending = false
    @State private var dividerPosition: CGFloat = 0.5

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 4) {
                Text("HTTP Client")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Send HTTP requests and inspect responses")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(12)

            GeometryReader { geometry in
                VSplitView {
                    // Request editor (top)
                    RequestEditorView(
                        method: $method,
                        url: $url,
                        queryParams: $queryParams,
                        headers: $headers,
                        bodyType: $bodyType,
                        jsonBody: $jsonBody,
                        formDataPairs: $formDataPairs,
                        rawBody: $rawBody,
                        authMethod: $authMethod,
                        bearerToken: $bearerToken,
                        basicUsername: $basicUsername,
                        basicPassword: $basicPassword,
                        apiKeyName: $apiKeyName,
                        apiKeyValue: $apiKeyValue,
                        apiKeyLocation: $apiKeyLocation,
                        isSending: isSending,
                        onSend: sendRequest
                    )
                    .frame(minHeight: 200)

                    // Response viewer (bottom)
                    ResponseView(response: response, error: errorMessage)
                        .frame(minHeight: 150)
                }
            }
        }
    }

    private func sendRequest() {
        isSending = true
        response = nil
        errorMessage = nil

        let currentBody: RequestBody? = {
            switch bodyType {
            case .none: nil
            case .json: .json(jsonBody)
            case .formData: .formData(formDataPairs)
            case .raw: .raw(rawBody)
            }
        }()

        let currentAuth: AuthType? = {
            switch authMethod {
            case .none: nil
            case .bearer: .bearerToken(bearerToken)
            case .basic: .basicAuth(username: basicUsername, password: basicPassword)
            case .apiKey: .apiKey(key: apiKeyName, value: apiKeyValue, addTo: apiKeyLocation)
            }
        }()

        Task {
            do {
                let request = try HTTPClientService.buildURLRequest(
                    method: method,
                    url: url,
                    headers: headers,
                    queryParams: queryParams,
                    body: currentBody,
                    auth: currentAuth
                )
                response = try await HTTPClientService.send(request)
            } catch {
                errorMessage = error.localizedDescription
            }
            isSending = false
        }
    }
}

extension APIClientView {
    public static let descriptor = ToolDescriptor(
        id: "http-client",
        name: "HTTP Client",
        icon: "network",
        category: .apiClient,
        searchKeywords: ["http", "api", "rest", "request", "get", "post", "接口", "调试", "请求"]
    )
}
```

- [ ] **Step 2: Build and commit**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/APIClient && swift build`
Expected: Build Succeeded

```bash
git add Packages/APIClient/Sources/APIClient/APIClientView.swift
git commit -m "feat: add full HTTP client view with request editor and response viewer"
```

---

## Phase 5: Integration

### Task 17: Wire Up All Tools, Search, and Theme

**Files:**
- Modify: `MacDevApp/Navigation/ToolRegistry.swift`
- Modify: `MacDevApp/ContentView.swift`
- Modify: `MacDevApp/MacDevAppApp.swift`

- [ ] **Step 1: Update ContentView to register and route all tools**

Replace `MacDevApp/ContentView.swift`:

```swift
import SwiftUI
import DevAppCore
import CryptoTools
import ConversionTools
import APIClient

struct ContentView: View {
    @State private var registry = ToolRegistry()

    var body: some View {
        NavigationSplitView {
            SidebarView(registry: registry)
                .glassEffect(.regular.interactive)
        } detail: {
            if let toolID = registry.selectedToolID {
                toolView(for: toolID)
            } else {
                ContentUnavailableView(
                    "Select a Tool",
                    systemImage: "wrench.and.screwdriver",
                    description: Text("Choose a tool from the sidebar to get started.")
                )
            }
        }
        .frame(minWidth: 900, minHeight: 650)
        .onAppear {
            registerAllTools()
        }
    }

    private func registerAllTools() {
        registry.registerAll([
            // Crypto
            HashGeneratorView.descriptor,
            HMACGeneratorView.descriptor,
            AESCryptorView.descriptor,
            RSACryptorView.descriptor,
            // API Client
            APIClientView.descriptor,
            // Conversion
            TimestampConverterView.descriptor,
            URLCodecView.descriptor,
            Base64CodecView.descriptor,
            JSONFormatterView.descriptor,
        ])
    }

    @ViewBuilder
    private func toolView(for id: String) -> some View {
        switch id {
        case "hash-generator": HashGeneratorView()
        case "hmac-generator": HMACGeneratorView()
        case "aes-cryptor": AESCryptorView()
        case "rsa-cryptor": RSACryptorView()
        case "http-client": APIClientView()
        case "timestamp-converter": TimestampConverterView()
        case "url-codec": URLCodecView()
        case "base64-codec": Base64CodecView()
        case "json-formatter": JSONFormatterView()
        default:
            ContentUnavailableView(
                "Tool Not Found",
                systemImage: "questionmark.circle",
                description: Text("Tool '\(id)' is not available.")
            )
        }
    }
}
```

- [ ] **Step 2: Update MacDevAppApp with SwiftData container**

Replace `MacDevApp/MacDevAppApp.swift`:

```swift
import SwiftUI
import SwiftData
import DevAppCore
import CryptoTools
import ConversionTools
import APIClient

@main
struct MacDevAppApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: [
            HTTPRequestModel.self,
            HTTPCollectionModel.self,
            HTTPHistoryModel.self
        ])
        .windowStyle(.automatic)
        .defaultSize(width: 1100, height: 750)
    }
}
```

- [ ] **Step 3: Regenerate Xcode project and verify build**

Run: `cd /Users/xiaobo/mac_dev_app && xcodegen generate`
Expected: Generated MacDevApp.xcodeproj

Run: `xcodebuild -project MacDevApp.xcodeproj -scheme MacDevApp -destination 'platform=macOS' build 2>&1 | tail -5`
Expected: BUILD SUCCEEDED

- [ ] **Step 4: Run all package tests**

Run: `cd /Users/xiaobo/mac_dev_app/Packages/DevAppCore && swift test`
Expected: All tests passed

Run: `cd /Users/xiaobo/mac_dev_app/Packages/CryptoTools && swift test`
Expected: All tests passed

Run: `cd /Users/xiaobo/mac_dev_app/Packages/ConversionTools && swift test`
Expected: All tests passed

Run: `cd /Users/xiaobo/mac_dev_app/Packages/APIClient && swift test`
Expected: All tests passed

- [ ] **Step 5: Commit**

```bash
git add MacDevApp/ project.yml
git commit -m "feat: wire up all tools — sidebar navigation, search, SwiftData, Liquid Glass"
```

---

## Dependency Graph

```
Task 1 (scaffolding)
  └─→ Task 2 (DevAppCore)
       └─→ Task 3 (App Shell)
            ├─→ Task 4 (Hash)          ─┐
            ├─→ Task 5 (HMAC)          ─┤
            ├─→ Task 6 (AES)           ─┤ Parallelizable
            ├─→ Task 7 (RSA)           ─┤
            ├─→ Task 8 (Base64)        ─┤
            ├─→ Task 9 (URL Codec)     ─┤
            ├─→ Task 10 (JSON)         ─┤
            ├─→ Task 11 (Timestamp)    ─┤
            └─→ Task 12 (HTTP Models)  ─┤
                 └─→ Task 13 (HTTP Net)─┤
                      └─→ Task 14 (Req) ┤
                           └─→ Task 15  ┤
                                └─→ 16 ─┘
                                     └─→ Task 17 (Integration)
```
