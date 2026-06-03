# DevToolkit

A native macOS developer toolkit that combines crypto tools, HTTP client, and conversion utilities in one app.

Built with Swift 6, SwiftUI, and Liquid Glass (macOS 26+). Designed for developers who need fast, offline, privacy-first tools.

![macOS 26+](https://img.shields.io/badge/macOS-26%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6-orange)
![License](https://img.shields.io/badge/license-MIT-green)

---

## Features

### Crypto Tools (7)
| Tool | Description |
|------|-------------|
| **AES Encrypt/Decrypt** | ECB/CBC/GCM modes, 128/192/256-bit keys, PKCS7 padding |
| **RSA Encrypt/Decrypt** | Key generation (1024-4096 bit), PKCS1/OAEP padding, PEM format |
| **Hash Generator** | MD5, SHA-1, SHA-256, SHA-512, uppercase toggle + file checksum compare |
| **HMAC Generator** | HMAC-MD5/SHA1/SHA256/SHA512, Hex/Base64 output |
| **JWT Decoder** | Decode header/payload, inspect claims, verify HS256/384/512 & RS256/384/512 |
| **Certificate Viewer** | Parse X.509 PEM/DER — subject, issuer, validity, SAN, SHA-1/256 fingerprints |
| **Key Derivation** | PBKDF2 & HKDF (SHA-1/256/512), configurable salt, iterations, length |

### HTTP Client
| Feature | Description |
|---------|-------------|
| **Request Editor** | GET/POST/PUT/PATCH/DELETE/HEAD/OPTIONS with Params/Headers/Body/Auth/Scripts tabs |
| **Response Viewer** | Pretty/Raw body, Headers, Cookies, Rewrite tabs |
| **Pre/Post Scripts** | JavaScriptCore engine with full Postman `pm.*` API compatibility |
| **CryptoJS Support** | SHA256, SHA1, HMAC, AES-ECB backed by native CryptoKit |
| **cURL Import/Export** | Paste cURL to fill request, export request as cURL |
| **Response Rewrite** | Manual edit or JavaScript script to transform responses (auto-run) |
| **Request History** | Auto-save with full restore (URL, headers, body, scripts) |
| **Saved APIs** | Name + tag management, search, filter by tag |
| **Import/Export** | Postman Collection v2.1 (with scripts) + cURL batch import |
| **{{variable}}** | Template substitution from `pm.environment` in headers/URL/body |
| **Request Chains** | Sequential multi-step API workflows |

### Conversion Tools (18)
| Tool | Description |
|------|-------------|
| **Unix Timestamp** | Bidirectional conversion + live clock + timezone |
| **URL Encode/Decode** | RFC 3986 / Form Data + URL parser |
| **Base64 Encode/Decode** | Standard / URL-safe, bidirectional |
| **JSON Formatter** | Format / minify / validate + JSONPath query (`$.a.b[0]`, `[*]`) |
| **JSON - YAML** | Bidirectional converter, pure Swift YAML parser |
| **JSON - CSV** | Bidirectional, header inference, RFC 4180 quoting |
| **JSON - TOML** | Bidirectional — tables, nested tables, arrays of tables |
| **UUID Generator** | Batch generate + decode UUID version/variant |
| **Random String** | Configurable charset, length, batch generation |
| **Number Base Converter** | Binary / Octal / Decimal / Hex |
| **HTML Entity** | Encode/decode named + numeric entities, bidirectional |
| **String Escape** | Backslash escape/unescape, bidirectional |
| **String Case Converter** | camelCase / snake_case / PascalCase / kebab-case / UPPER / lower / Title |
| **Hex/ASCII Converter** | Bidirectional hex to ASCII text |
| **Line Sort & Dedup** | Sort / reverse / shuffle / deduplicate lines |
| **Text Analyzer** | Characters / words / lines / sentences / paragraphs / bytes |
| **Lorem Ipsum** | Generate placeholder text (words / sentences / paragraphs) |
| **Text Diff** | Side-by-side comparison with LCS line diffing |

### Developer Tools (7)
| Tool | Description |
|------|-------------|
| **Regex Tester** | Live matches, capture groups, replacement, i/s/m/x flags |
| **Cron Parser** | Parse 5-field cron → human description + next run times |
| **Color Converter** | HEX ↔ RGB ↔ HSL ↔ HSB, picker, WCAG contrast (AA/AAA) |
| **SQL Formatter** | Beautify / minify with keyword uppercasing |
| **Unicode Inspector** | Code points, names, categories, UTF-8/16 bytes, invisible-char detection |
| **Compression** | zlib / LZFSE / LZ4 / LZMA compress & decompress (Base64), shows ratio |
| **.env ↔ JSON** | `.env` / `.ini` / `.properties` ↔ JSON, `[section]` → nested objects |

### Generators (2)
| Tool | Description |
|------|-------------|
| **QR Code** | Generate (correction levels, save PNG) + scan image via Vision |
| **JSON → Code** | Generate Swift structs, TypeScript interfaces, or Go structs from JSON |

### Other Tools (3)
| Tool | Description |
|------|-------------|
| **Markdown Preview** | Live rendering with GFM support (tables, code blocks, task lists) |
| **Image to Text (OCR)** | Apple Vision, paste/drag/open, Chinese/English/Japanese/Korean |
| **Translator** | Microsoft free API (no key), 30 languages, auto-detect |

---

## Architecture

```
MacDevApp/                    # Main app target (SwiftUI)
Packages/
  DevAppCore/                 # Shared protocols, views, utilities
  CryptoTools/                # AES, RSA, Hash, HMAC, JWT, Certificate, KDF
  ConversionTools/            # Conversion, Developer & Generator tools
  APIClient/                  # HTTP client, WebSocket, Mock server, scripts
```

Modules depend only on `DevAppCore`, never on each other.

Press **⌘K** anywhere to open the command palette and jump to any tool. Right-click a tool in the sidebar to add it to **Favorites**; recently used tools surface automatically.

---

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Swift 6 (strict concurrency) |
| UI | SwiftUI + Liquid Glass (macOS 26) |
| Crypto | Apple CryptoKit + CommonCrypto + Security.framework |
| Scripting | JavaScriptCore with Postman `pm.*` compatibility |
| Persistence | SwiftData |
| Networking | URLSession |
| OCR | Apple Vision (VNRecognizeTextRequest) |
| Translation | Microsoft Edge Translator API (free) |
| Markdown | Pure Swift parser + WKWebView renderer |
| YAML | Pure Swift parser/emitter (no dependencies) |
| Diff | LCS (Longest Common Subsequence) algorithm |
| Build | Xcode + Swift Package Manager + xcodegen |
| Distribution | Developer ID signing + Apple Notarization + Sparkle auto-update |

---

## Build

### Prerequisites
- macOS 26+
- Xcode 16+
- [xcodegen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`)

### Steps

```bash
git clone https://github.com/uhyrdtrdtfg-creator/mac_dev_app.git
cd mac_dev_app
xcodegen generate
open MacDevApp.xcodeproj
# Build and run (Cmd+R)
```

### Run Tests

```bash
cd Packages/DevAppCore && swift test
cd Packages/CryptoTools && swift test
cd Packages/ConversionTools && swift test
cd Packages/APIClient && swift test
```

---

## Package & Distribute

See [docs/SIGNING_AND_PACKAGING_GUIDE.md](docs/SIGNING_AND_PACKAGING_GUIDE.md) for the full signing, notarization, and packaging guide (including 16 pitfalls and solutions).

Quick build:

```bash
# Archive + Export + DMG + Notarize + Staple
xcodebuild archive -project MacDevApp.xcodeproj -scheme MacDevApp \
  -archivePath build/DevToolkit.xcarchive \
  -destination 'generic/platform=macOS' \
  CODE_SIGN_IDENTITY="Developer ID Application: ..." \
  DEVELOPMENT_TEAM=... OTHER_CODE_SIGN_FLAGS="--options runtime"

xcodebuild -exportArchive -archivePath build/DevToolkit.xcarchive \
  -exportPath build/export -exportOptionsPlist build/ExportOptions.plist

hdiutil create -volname "DevToolkit" -srcfolder build/export -ov -format UDZO ~/Desktop/DevToolkit.dmg
xcrun notarytool submit ~/Desktop/DevToolkit.dmg --keychain-profile "notarytool" --wait
xcrun stapler staple ~/Desktop/DevToolkit.dmg
```

---

## Documentation

- [Development Log](docs/DEVELOPMENT_LOG.md) — Full build record of all 24 tools
- [Signing & Packaging Guide](docs/SIGNING_AND_PACKAGING_GUIDE.md) — Pitfalls and solutions
- [Design Spec](docs/superpowers/specs/2026-04-08-mac-dev-app-design.md) — Original design document
- [Implementation Plan](docs/superpowers/plans/2026-04-08-mac-dev-app-implementation.md) — Task-by-task plan

---

## License

MIT
