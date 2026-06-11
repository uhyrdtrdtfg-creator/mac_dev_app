import SwiftUI
import DevAppCore

public struct ChaCha20CryptorView: View {
    @State private var input = ""
    @State private var output = ""
    @State private var keyHex = ""
    @State private var nonceHex = ""
    @State private var tagHex = ""
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
                Text("ChaCha20-Poly1305 Encrypt / Decrypt").font(.title2).fontWeight(.semibold)
                Text("AEAD stream cipher with 256-bit key, 96-bit nonce, and 128-bit authentication tag").font(.subheadline).foregroundStyle(.secondary)
            }

            Picker("Output Format", selection: $outputFormat) {
                ForEach(OutputFormat.allCases) { f in Text(f.rawValue).tag(f) }
            }
            .pickerStyle(.segmented)
            .fixedSize()

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Key (Hex)").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                    TextField("Enter 32-byte key in hex...", text: $keyHex).font(.system(.body, design: .monospaced)).textFieldStyle(.plain).padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                VStack { Spacer(); Button("Random") { keyHex = ChaCha20Cryptor.generateRandomKey().map { String(format: "%02x", $0) }.joined() }.buttonStyle(.bordered) }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Nonce (Hex)").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                    TextField("Enter 12-byte nonce in hex...", text: $nonceHex).font(.system(.body, design: .monospaced)).textFieldStyle(.plain).padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                VStack { Spacer(); Button("Random") { nonceHex = ChaCha20Cryptor.generateRandomNonce().map { String(format: "%02x", $0) }.joined() }.buttonStyle(.bordered) }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Tag (Hex)").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                TextField("Authentication tag, filled on encrypt...", text: $tagHex).font(.system(.body, design: .monospaced)).textFieldStyle(.plain).padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
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

    private func encrypt() {
        errorMessage = nil
        guard let key = Data(hexString: keyHex), key.count == 32 else { errorMessage = "Invalid key. Expected 64 hex characters (32 bytes)."; return }
        var nonce: Data?
        if !nonceHex.isEmpty {
            guard let n = Data(hexString: nonceHex), n.count == 12 else { errorMessage = "Invalid nonce. Expected 24 hex characters (12 bytes)."; return }
            nonce = n
        }
        do {
            let result = try ChaCha20Cryptor.encrypt(plaintext: input, key: key, nonce: nonce)
            nonceHex = result.nonce.map { String(format: "%02x", $0) }.joined()
            tagHex = result.tag.map { String(format: "%02x", $0) }.joined()
            switch outputFormat {
            case .hex: output = result.ciphertext.map { String(format: "%02x", $0) }.joined()
            case .base64: output = result.ciphertext.base64EncodedString()
            }
        } catch { errorMessage = error.localizedDescription }
    }

    private func decrypt() {
        errorMessage = nil
        guard let key = Data(hexString: keyHex), key.count == 32 else { errorMessage = "Invalid key. Expected 64 hex characters (32 bytes)."; return }
        guard let nonce = Data(hexString: nonceHex), nonce.count == 12 else { errorMessage = "Invalid nonce. Expected 24 hex characters (12 bytes)."; return }
        guard let tag = Data(hexString: tagHex), tag.count == 16 else { errorMessage = "Invalid tag. Expected 32 hex characters (16 bytes)."; return }
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let ciphertext: Data
        switch outputFormat {
        case .hex: guard let d = Data(hexString: trimmed) else { errorMessage = "Invalid hex."; return }; ciphertext = d
        case .base64: guard let d = Data(base64Encoded: trimmed) else { errorMessage = "Invalid Base64."; return }; ciphertext = d
        }
        do { input = try ChaCha20Cryptor.decrypt(ciphertext: ciphertext, key: key, nonce: nonce, tag: tag) }
        catch { errorMessage = error.localizedDescription }
    }
}

extension ChaCha20CryptorView {
    public static let descriptor = ToolDescriptor(
        id: "chacha20", name: "ChaCha20-Poly1305", icon: "bolt.shield", category: .crypto,
        searchKeywords: ["chacha20", "poly1305", "stream cipher", "aead", "encrypt", "decrypt", "流加密"]
    )
}
