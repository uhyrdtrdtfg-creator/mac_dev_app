import SwiftUI
import DevAppCore

public struct TripleDESCryptorView: View {
    @State private var input = ""
    @State private var output = ""
    @State private var keyHex = ""
    @State private var ivHex = ""
    @State private var mode: TripleDESMode = .cbc
    @State private var padding: TripleDESPadding = .pkcs7
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
                Text("3DES Encrypt / Decrypt").font(.title2).fontWeight(.semibold)
                Text("Triple DES symmetric encryption with ECB and CBC modes").font(.subheadline).foregroundStyle(.secondary)
                Text("3DES is legacy — prefer AES for new systems").font(.caption).foregroundStyle(.orange)
            }

            HStack(spacing: 16) {
                Picker("Mode", selection: $mode) {
                    ForEach(TripleDESMode.allCases) { m in Text(m.rawValue).tag(m) }
                }
                .pickerStyle(.menu)
                .fixedSize()

                Picker("Padding", selection: $padding) {
                    ForEach(TripleDESPadding.allCases) { p in Text(p.rawValue).tag(p) }
                }
                .pickerStyle(.menu)
                .fixedSize()

                Picker("Output Format", selection: $outputFormat) {
                    ForEach(OutputFormat.allCases) { f in Text(f.rawValue).tag(f) }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Key (Hex, 24 bytes)").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                    TextField("Enter key in hex...", text: $keyHex).font(.system(.body, design: .monospaced)).textFieldStyle(.plain).padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                if mode != .ecb {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("IV (Hex, 8 bytes)").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
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
        keyHex = TripleDESCryptor.generateRandomKey().hexString()
        if mode != .ecb {
            ivHex = TripleDESCryptor.generateRandomIV().hexString()
        }
    }

    private func encrypt() {
        errorMessage = nil
        guard let key = Data(hexString: keyHex), key.count == 24 else { errorMessage = "Invalid key. Expected 48 hex characters (24 bytes)."; return }
        let iv: Data? = mode != .ecb ? Data(hexString: ivHex) : nil
        if mode == .cbc, iv?.count != 8 { errorMessage = "Invalid IV. Expected 16 hex characters (8 bytes)."; return }
        do {
            let result = try TripleDESCryptor.encrypt(plaintext: input, key: key, mode: mode, iv: iv, padding: padding)
            switch outputFormat {
            case .hex: output = result.ciphertext.hexString()
            case .base64: output = result.ciphertext.base64EncodedString()
            }
        } catch { errorMessage = error.localizedDescription }
    }

    private func decrypt() {
        errorMessage = nil
        guard let key = Data(hexString: keyHex), key.count == 24 else { errorMessage = "Invalid key. Expected 48 hex characters (24 bytes)."; return }
        let ciphertext: Data
        switch outputFormat {
        case .hex: guard let d = Data(hexString: output) else { errorMessage = "Invalid hex."; return }; ciphertext = d
        case .base64: guard let d = Data(base64Encoded: output) else { errorMessage = "Invalid Base64."; return }; ciphertext = d
        }
        let iv = Data(hexString: ivHex)
        do { input = try TripleDESCryptor.decrypt(ciphertext: ciphertext, key: key, mode: mode, iv: iv, padding: padding) }
        catch { errorMessage = error.localizedDescription }
    }
}

extension TripleDESCryptorView {
    public static let descriptor = ToolDescriptor(
        id: "triple-des", name: "3DES Encrypt/Decrypt", icon: "lock.square", category: .crypto,
        searchKeywords: ["3des", "des", "triple des", "legacy", "encrypt", "decrypt", "对称加密"]
    )
}
