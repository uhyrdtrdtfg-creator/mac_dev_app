import SwiftUI
import DevAppCore

public struct RSACryptorView: View {
    @State private var mode: Mode = .encryptDecrypt
    @State private var keyBits: RSAKeyBits = .bits2048
    @State private var padding: RSAPadding = .oaepSHA256
    @State private var signatureAlgorithm: RSASignatureAlgorithm = .sha256
    @State private var publicKeyPEM = ""
    @State private var privateKeyPEM = ""
    @State private var input = ""
    @State private var output = ""
    @State private var outputFormat: OutputFormat = .base64
    @State private var errorMessage: String?
    @State private var verifyResult: Bool?
    @State private var isGenerating = false

    enum Mode: String, CaseIterable, Identifiable {
        case encryptDecrypt = "Encrypt / Decrypt"
        case signVerify = "Sign / Verify"
        var id: String { rawValue }
    }

    enum OutputFormat: String, CaseIterable, Identifiable {
        case hex = "Hex"; case base64 = "Base64"
        var id: String { rawValue }
    }

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("RSA").font(.title2).fontWeight(.semibold)
                Text("Asymmetric crypto — generate keys, encrypt/decrypt, sign/verify").font(.subheadline).foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { m in Text(m.rawValue).tag(m) }
                }
                .pickerStyle(.segmented)
                .fixedSize()

                Picker("Key Size", selection: $keyBits) {
                    ForEach(RSAKeyBits.allCases) { b in Text("\(b.rawValue) bit").tag(b) }
                }
                .pickerStyle(.menu)
                .fixedSize()

                if mode == .encryptDecrypt {
                    Picker("Padding", selection: $padding) {
                        ForEach(RSAPadding.allCases) { p in Text(p.rawValue).tag(p) }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                } else {
                    Picker("Algorithm", selection: $signatureAlgorithm) {
                        ForEach(RSASignatureAlgorithm.allCases) { a in Text(a.rawValue).tag(a) }
                    }
                    .pickerStyle(.menu)
                    .fixedSize()
                }

                Picker("Output Format", selection: $outputFormat) {
                    ForEach(OutputFormat.allCases) { f in Text(f.rawValue).tag(f) }
                }
                .pickerStyle(.segmented)
                .fixedSize()

                Spacer()

                Button { generateKeys() } label: {
                    Label("Generate Keys", systemImage: "key")
                }
                .buttonStyle(.bordered)
                .disabled(isGenerating)
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
            if mode == .signVerify, let verifyResult {
                Label(
                    verifyResult ? "Signature is valid" : "Signature is NOT valid",
                    systemImage: verifyResult ? "checkmark.seal.fill" : "xmark.seal.fill"
                )
                .font(.caption.bold())
                .foregroundStyle(verifyResult ? .green : .red)
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(mode == .encryptDecrypt ? "Plaintext" : "Message").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                    TextEditor(text: $input).font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden).padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                VStack(spacing: 8) {
                    Spacer()
                    if mode == .encryptDecrypt {
                        Button { encrypt() } label: { Label("Encrypt", systemImage: "lock") }.buttonStyle(.bordered).tint(.blue)
                        Button { decrypt() } label: { Label("Decrypt", systemImage: "lock.open") }.buttonStyle(.bordered)
                    } else {
                        Button { sign() } label: { Label("Sign", systemImage: "signature") }.buttonStyle(.bordered).tint(.blue)
                        Button { verify() } label: { Label("Verify", systemImage: "checkmark.seal") }.buttonStyle(.bordered)
                    }
                    Spacer()
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack { Text(mode == .encryptDecrypt ? "Ciphertext" : "Signature").font(.caption).foregroundStyle(.secondary).textCase(.uppercase); Spacer(); CopyButton(text: output) }
                    TextEditor(text: $output).font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden).padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .onChange(of: mode) { verifyResult = nil; errorMessage = nil }
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
            output = encode(encrypted)
        } catch { errorMessage = error.localizedDescription }
    }

    private func decrypt() {
        errorMessage = nil
        guard let ciphertext = decodeOutput() else { return }
        do { input = try RSACryptor.decrypt(ciphertext: ciphertext, privateKeyPEM: privateKeyPEM, padding: padding) }
        catch { errorMessage = error.localizedDescription }
    }

    private func sign() {
        errorMessage = nil; verifyResult = nil
        do {
            let signature = try RSACryptor.sign(message: input, privateKeyPEM: privateKeyPEM, algorithm: signatureAlgorithm)
            output = encode(signature)
        } catch { errorMessage = error.localizedDescription }
    }

    private func verify() {
        errorMessage = nil; verifyResult = nil
        guard let signature = decodeOutput() else { return }
        do { verifyResult = try RSACryptor.verify(message: input, signature: signature, publicKeyPEM: publicKeyPEM, algorithm: signatureAlgorithm) }
        catch { errorMessage = error.localizedDescription }
    }

    private func encode(_ data: Data) -> String {
        switch outputFormat {
        case .hex: data.map { String(format: "%02x", $0) }.joined()
        case .base64: data.base64EncodedString()
        }
    }

    private func decodeOutput() -> Data? {
        switch outputFormat {
        case .hex:
            guard let d = Data(hexString: output) else { errorMessage = "Invalid hex."; return nil }
            return d
        case .base64:
            guard let d = Data(base64Encoded: output) else { errorMessage = "Invalid Base64."; return nil }
            return d
        }
    }
}

extension RSACryptorView {
    public static let descriptor = ToolDescriptor(
        id: "rsa-cryptor", name: "RSA Encrypt/Decrypt", icon: "key", category: .crypto,
        searchKeywords: ["rsa", "asymmetric", "public key", "private key", "encrypt", "decrypt", "sign", "verify", "signature", "非对称", "公钥", "私钥", "签名", "验签"]
    )
}
