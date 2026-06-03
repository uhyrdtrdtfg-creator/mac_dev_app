import SwiftUI
import DevAppCore

public struct KeyDerivationView: View {
    @State private var function: KDFFunction = .pbkdf2
    @State private var hash: KDFHash = .sha256
    @State private var outputFormat: KDFOutputFormat = .hex
    @State private var password = ""
    @State private var salt = ""
    @State private var info = ""
    @State private var iterations = 100_000
    @State private var keyLength = 32
    @State private var output = ""
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Key Derivation")
                    .font(.title2).fontWeight(.semibold)
                Text("Derive keys with PBKDF2 or HKDF using native CommonCrypto / CryptoKit")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Picker("Function", selection: $function) {
                    ForEach(KDFFunction.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).fixedSize()
                Picker("Hash", selection: $hash) {
                    ForEach(KDFHash.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.menu).fixedSize()
                Picker("Output", selection: $outputFormat) {
                    ForEach(KDFOutputFormat.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).fixedSize()
            }

            labeledField(function == .hkdf ? "Input Key Material" : "Password", text: $password)
            labeledField("Salt", text: $salt)
            if function == .hkdf {
                labeledField("Info (context)", text: $info)
            }

            HStack(spacing: 16) {
                if function == .pbkdf2 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Iterations").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                        TextField("100000", value: $iterations, format: .number)
                            .textFieldStyle(.plain).frame(width: 120)
                            .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Key Length (bytes)").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                    TextField("32", value: $keyLength, format: .number)
                        .textFieldStyle(.plain).frame(width: 120)
                        .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Derived Key").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                    Spacer()
                    CopyButton(text: output)
                }
                Text(output.isEmpty ? "—" : output)
                    .font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .onChange(of: function) { _, _ in derive() }
        .onChange(of: hash) { _, _ in derive() }
        .onChange(of: outputFormat) { _, _ in derive() }
        .onChange(of: password) { _, _ in derive() }
        .onChange(of: salt) { _, _ in derive() }
        .onChange(of: info) { _, _ in derive() }
        .onChange(of: iterations) { _, _ in derive() }
        .onChange(of: keyLength) { _, _ in derive() }
    }

    private func labeledField(_ label: LocalizedStringKey, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
            TextField("", text: text)
                .font(.system(.body, design: .monospaced))
                .textFieldStyle(.plain)
                .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func derive() {
        guard !password.isEmpty else { output = ""; errorMessage = nil; return }
        do {
            let data: Data
            switch function {
            case .pbkdf2:
                data = try KeyDerivation.pbkdf2(password: password, salt: salt, iterations: iterations, keyLength: keyLength, hash: hash)
            case .hkdf:
                data = try KeyDerivation.hkdf(secret: password, salt: salt, info: info, keyLength: keyLength, hash: hash)
            }
            output = KeyDerivation.format(data, as: outputFormat)
            errorMessage = nil
        } catch {
            output = ""
            errorMessage = error.localizedDescription
        }
    }
}

extension KeyDerivationView {
    public static let descriptor = ToolDescriptor(
        id: "key-derivation",
        name: "Key Derivation",
        icon: "key.horizontal.fill",
        category: .crypto,
        searchKeywords: ["kdf", "pbkdf2", "hkdf", "derive", "key", "password", "salt", "密钥派生"]
    )
}
