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
        case hex = "Hex"; case base64 = "Base64"
        var id: String { rawValue }
    }

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("RSA Encrypt / Decrypt").font(.title2).fontWeight(.semibold)
                Text("Asymmetric encryption — generate keys, encrypt with public key, decrypt with private key").font(.subheadline).foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Picker("Key Size", selection: $keyBits) { ForEach(RSAKeyBits.allCases) { b in Text("\(b.rawValue) bit").tag(b) } }.pickerStyle(.menu).frame(width: 140)
                Picker("Padding", selection: $padding) { ForEach(RSAPadding.allCases) { p in Text(p.rawValue).tag(p) } }.pickerStyle(.menu).frame(width: 180)
                Picker("Output", selection: $outputFormat) { ForEach(OutputFormat.allCases) { f in Text(f.rawValue).tag(f) } }.pickerStyle(.segmented).frame(width: 150)
                Spacer()
                Button { generateKeys() } label: { Label("Generate Keys", systemImage: "key") }.buttonStyle(.bordered).disabled(isGenerating)
            }

            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text("Public Key (PEM)").font(.caption).foregroundStyle(.secondary).textCase(.uppercase); Spacer(); CopyButton(text: publicKeyPEM) }
                    TextEditor(text: $publicKeyPEM).font(.system(size: 10, design: .monospaced)).scrollContentBackground(.hidden).padding(6).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8)).frame(height: 80)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text("Private Key (PEM)").font(.caption).foregroundStyle(.secondary).textCase(.uppercase); Spacer(); CopyButton(text: privateKeyPEM) }
                    TextEditor(text: $privateKeyPEM).font(.system(size: 10, design: .monospaced)).scrollContentBackground(.hidden).padding(6).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8)).frame(height: 80)
                }
            }

            if let errorMessage { Text(errorMessage).font(.caption).foregroundStyle(.red) }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Plaintext").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                    TextEditor(text: $input).font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden).padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                VStack(spacing: 8) {
                    Spacer()
                    Button { encrypt() } label: { Label("Encrypt", systemImage: "lock") }.buttonStyle(.bordered).tint(.blue)
                    Button { decrypt() } label: { Label("Decrypt", systemImage: "lock.open") }.buttonStyle(.bordered)
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text("Ciphertext").font(.caption).foregroundStyle(.secondary).textCase(.uppercase); Spacer(); CopyButton(text: output) }
                    TextEditor(text: .constant(output)).font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden).padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
    }

    private func generateKeys() {
        isGenerating = true; errorMessage = nil
        Task {
            do { let kp = try RSACryptor.generateKeyPair(bits: keyBits.rawValue); publicKeyPEM = kp.publicKeyPEM; privateKeyPEM = kp.privateKeyPEM }
            catch { errorMessage = error.localizedDescription }
            isGenerating = false
        }
    }

    private func encrypt() {
        errorMessage = nil
        do {
            let encrypted = try RSACryptor.encrypt(plaintext: input, publicKeyPEM: publicKeyPEM, padding: padding)
            switch outputFormat { case .hex: output = encrypted.map { String(format: "%02x", $0) }.joined(); case .base64: output = encrypted.base64EncodedString() }
        } catch { errorMessage = error.localizedDescription }
    }

    private func decrypt() {
        errorMessage = nil
        let ciphertext: Data
        switch outputFormat {
        case .hex: guard let d = Data(hexString: output) else { errorMessage = "Invalid hex."; return }; ciphertext = d
        case .base64: guard let d = Data(base64Encoded: output) else { errorMessage = "Invalid Base64."; return }; ciphertext = d
        }
        do { input = try RSACryptor.decrypt(ciphertext: ciphertext, privateKeyPEM: privateKeyPEM, padding: padding) }
        catch { errorMessage = error.localizedDescription }
    }
}

extension RSACryptorView {
    public static let descriptor = ToolDescriptor(
        id: "rsa-cryptor", name: "RSA Encrypt/Decrypt", icon: "key", category: .crypto,
        searchKeywords: ["rsa", "asymmetric", "public key", "private key", "encrypt", "decrypt", "非对称", "公钥", "私钥"]
    )
}
