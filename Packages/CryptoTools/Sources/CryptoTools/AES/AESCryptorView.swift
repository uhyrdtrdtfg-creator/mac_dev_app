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
            VStack(alignment: .leading, spacing: 4) {
                Text("AES Encrypt / Decrypt").font(.title2).fontWeight(.semibold)
                Text("Symmetric encryption with ECB, CBC, and GCM modes").font(.subheadline).foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Picker("Mode", selection: $mode) {
                    ForEach(AESMode.allCases) { m in Text(m.rawValue).tag(m) }
                }
                .pickerStyle(.menu)
                .fixedSize()

                Picker("Key Size", selection: $keyBits) {
                    ForEach(AESKeyBits.allCases) { b in Text("\(b.rawValue) bit").tag(b) }
                }
                .pickerStyle(.menu)
                .fixedSize()

                if mode != .gcm {
                    Picker("Padding", selection: $padding) {
                        ForEach(AESPadding.allCases) { p in Text(p.rawValue).tag(p) }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                }

                Picker("Output Format", selection: $outputFormat) {
                    ForEach(OutputFormat.allCases) { f in Text(f.rawValue).tag(f) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Key (Hex)").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                    TextField("Enter key in hex...", text: $keyHex).font(.system(.body, design: .monospaced)).textFieldStyle(.plain).padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                if mode != .ecb {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("IV (Hex)").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                        TextField("Enter IV in hex...", text: $ivHex).font(.system(.body, design: .monospaced)).textFieldStyle(.plain).padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                VStack { Spacer(); Button("Random") { generateRandomKeyIV() }.buttonStyle(.bordered) }
            }

            if let errorMessage { Text(errorMessage).font(.caption).foregroundStyle(.red) }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Input").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                    TextEditor(text: $input).font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden).padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                VStack(spacing: 8) {
                    Spacer()
                    Button { encrypt() } label: { Label("Encrypt", systemImage: "lock") }.buttonStyle(.bordered).tint(.blue)
                    Button { decrypt() } label: { Label("Decrypt", systemImage: "lock.open") }.buttonStyle(.bordered)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text("Output").font(.caption).foregroundStyle(.secondary).textCase(.uppercase); Spacer(); CopyButton(text: output) }
                    TextEditor(text: .constant(output)).font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden).padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
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
        guard let key = Data(hexString: keyHex), key.count == keyBits.byteCount else { errorMessage = "Invalid key. Expected \(keyBits.byteCount * 2) hex characters."; return }
        let iv: Data? = mode != .ecb ? Data(hexString: ivHex) : nil
        if mode == .cbc, iv?.count != 16 { errorMessage = "Invalid IV. Expected 32 hex characters (16 bytes)."; return }
        do {
            let result = try AESCryptor.encrypt(plaintext: input, key: key, mode: mode, iv: iv, padding: padding)
            switch outputFormat {
            case .hex: output = result.ciphertext.map { String(format: "%02x", $0) }.joined()
            case .base64: output = result.ciphertext.base64EncodedString()
            }
            if mode == .gcm, let nonce = result.iv, let tag = result.tag {
                ivHex = nonce.map { String(format: "%02x", $0) }.joined()
                output += "\n[Tag: \(tag.map { String(format: "%02x", $0) }.joined())]"
            }
        } catch { errorMessage = error.localizedDescription }
    }

    private func decrypt() {
        errorMessage = nil
        guard let key = Data(hexString: keyHex), key.count == keyBits.byteCount else { errorMessage = "Invalid key."; return }
        var ciphertextStr = output
        var tagData: Data?
        if mode == .gcm, let tagRange = output.range(of: "\\[Tag: ([a-fA-F0-9]+)\\]", options: .regularExpression) {
            let tagHex = String(output[tagRange]).replacingOccurrences(of: "[Tag: ", with: "").replacingOccurrences(of: "]", with: "")
            tagData = Data(hexString: tagHex)
            ciphertextStr = String(output[output.startIndex..<tagRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        let ciphertext: Data
        switch outputFormat {
        case .hex: guard let d = Data(hexString: ciphertextStr) else { errorMessage = "Invalid hex."; return }; ciphertext = d
        case .base64: guard let d = Data(base64Encoded: ciphertextStr) else { errorMessage = "Invalid Base64."; return }; ciphertext = d
        }
        let iv = Data(hexString: ivHex)
        do { input = try AESCryptor.decrypt(ciphertext: ciphertext, key: key, mode: mode, iv: iv, padding: padding, tag: tagData) }
        catch { errorMessage = error.localizedDescription }
    }
}

extension AESCryptorView {
    public static let descriptor = ToolDescriptor(
        id: "aes-cryptor", name: "AES Encrypt/Decrypt", icon: "lock.rectangle", category: .crypto,
        searchKeywords: ["aes", "encrypt", "decrypt", "symmetric", "cbc", "ecb", "gcm", "加密", "解密", "对称"]
    )
}
