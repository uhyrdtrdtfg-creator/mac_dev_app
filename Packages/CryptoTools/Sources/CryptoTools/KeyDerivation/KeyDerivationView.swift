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
    @State private var bcryptCost = 10
    @State private var isHashing = false
    @State private var verifyHashInput = ""
    @State private var verifyPassword = ""
    @State private var verifyResult: Bool?
    @State private var verifyError: String?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Key Derivation")
                    .font(.title2).fontWeight(.semibold)
                Text("Derive keys with PBKDF2 or HKDF, or hash passwords with bcrypt")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Picker("Function", selection: $function) {
                    ForEach(KDFFunction.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).fixedSize()
                if function != .bcrypt {
                    Picker("Hash", selection: $hash) {
                        ForEach(KDFHash.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.menu).fixedSize()
                    Picker("Output", selection: $outputFormat) {
                        ForEach(KDFOutputFormat.allCases) { Text($0.rawValue).tag($0) }
                    }.pickerStyle(.segmented).fixedSize()
                }
            }

            labeledField(function == .hkdf ? "Input Key Material" : "Password", text: $password)
            if function == .bcrypt {
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Cost (2^n rounds)").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                        HStack(spacing: 8) {
                            Slider(value: Binding(get: { Double(bcryptCost) }, set: { bcryptCost = Int($0) }),
                                   in: Double(Bcrypt.costRange.lowerBound)...Double(Bcrypt.costRange.upperBound), step: 1)
                                .frame(width: 160)
                            Stepper(value: $bcryptCost, in: Bcrypt.costRange) {
                                Text("\(bcryptCost)").font(.system(.body, design: .monospaced)).frame(width: 24)
                            }
                        }
                    }
                    Button(action: runBcryptHash) {
                        if isHashing { ProgressView().controlSize(.small) } else { Text("Hash") }
                    }
                    .disabled(password.isEmpty || isHashing)
                }
            } else {
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
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(.orange)
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(function == .bcrypt ? "Bcrypt Hash" : "Derived Key")
                        .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                    Spacer()
                    CopyButton(text: output)
                }
                Text(output.isEmpty ? "—" : output)
                    .font(.system(.body, design: .monospaced)).textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if function == .bcrypt {
                Divider()
                Text("Verify a Hash").font(.headline)
                labeledField("Bcrypt Hash ($2a$ / $2b$)", text: $verifyHashInput)
                labeledField("Password", text: $verifyPassword)
                HStack(spacing: 12) {
                    Button("Verify", action: runBcryptVerify)
                        .disabled(verifyHashInput.isEmpty || isHashing)
                    if let verifyResult {
                        Label(verifyResult ? "Valid — password matches" : "Invalid — password does not match",
                              systemImage: verifyResult ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .font(.callout)
                            .foregroundStyle(verifyResult ? Color.green : Color.red)
                    }
                    if let verifyError {
                        Label(verifyError, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout).foregroundStyle(.orange)
                    }
                }
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
        // Bcrypt is too slow to recompute on every keystroke; it runs from the Hash button.
        if function == .bcrypt { output = ""; errorMessage = nil; return }
        guard !password.isEmpty else { output = ""; errorMessage = nil; return }
        do {
            let data: Data
            switch function {
            case .pbkdf2:
                data = try KeyDerivation.pbkdf2(password: password, salt: salt, iterations: iterations, keyLength: keyLength, hash: hash)
            case .hkdf:
                data = try KeyDerivation.hkdf(secret: password, salt: salt, info: info, keyLength: keyLength, hash: hash)
            case .bcrypt:
                return
            }
            output = KeyDerivation.format(data, as: outputFormat)
            errorMessage = nil
        } catch {
            output = ""
            errorMessage = error.localizedDescription
        }
    }

    private func runBcryptHash() {
        isHashing = true
        errorMessage = nil
        let pw = password, cost = bcryptCost
        Task.detached(priority: .userInitiated) {
            let result = Result { try Bcrypt.hash(password: pw, cost: cost) }
            await MainActor.run {
                switch result {
                case .success(let hash): output = hash
                case .failure(let error): output = ""; errorMessage = error.localizedDescription
                }
                isHashing = false
            }
        }
    }

    private func runBcryptVerify() {
        isHashing = true
        verifyResult = nil
        verifyError = nil
        let pw = verifyPassword, hashString = verifyHashInput.trimmingCharacters(in: .whitespacesAndNewlines)
        Task.detached(priority: .userInitiated) {
            let result = Result { try Bcrypt.verify(password: pw, hash: hashString) }
            await MainActor.run {
                switch result {
                case .success(let valid): verifyResult = valid
                case .failure(let error): verifyError = error.localizedDescription
                }
                isHashing = false
            }
        }
    }
}

extension KeyDerivationView {
    public static let descriptor = ToolDescriptor(
        id: "key-derivation",
        name: "Key Derivation",
        icon: "key.horizontal.fill",
        category: .crypto,
        searchKeywords: ["kdf", "pbkdf2", "hkdf", "bcrypt", "derive", "key", "password", "password hash", "salt", "密钥派生", "密码哈希"]
    )
}
