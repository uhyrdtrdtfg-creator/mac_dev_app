import SwiftUI
import DevAppCore

public struct JWTView: View {
    private enum Mode: String, CaseIterable {
        case decode = "Decode & Verify"
        case encode = "Encode & Sign"
    }

    @State private var mode: Mode = .decode

    // Decode mode
    @State private var token = ""
    @State private var secret = ""
    @State private var decoded: JWTDecoded?
    @State private var errorMessage: String?
    @State private var verification: JWTVerification?

    // Encode mode
    @State private var signAlgorithm: JWTAlgorithm = .hs256
    @State private var signPayload = "{\"sub\":\"1234567890\",\"name\":\"DevToolkit\",\"iat\":\(Int(Date().timeIntervalSince1970))}"
    @State private var signKey = ""
    @State private var customHeader = ""
    @State private var showCustomHeader = false
    @State private var signedToken: String?
    @State private var signError: String?
    @State private var selfCheck: JWTVerification?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("JWT Decoder & Signer")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Decode, verify, encode and sign JWTs with HS256/384/512 or RS256/384/512")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Picker("", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            switch mode {
            case .decode: decodeSection
            case .encode: encodeSection
            }
        }
        .padding()
        .onChange(of: token) { _, _ in decodeToken() }
        .onChange(of: secret) { _, _ in runVerification() }
        .onChange(of: mode) { _, _ in if mode == .encode { generateToken() } }
        .onChange(of: signPayload) { _, _ in generateToken() }
        .onChange(of: signAlgorithm) { _, _ in generateToken() }
        .onChange(of: signKey) { _, _ in generateToken() }
        .onChange(of: customHeader) { _, _ in generateToken() }
    }

    // MARK: - Decode & Verify

    @ViewBuilder
    private var decodeSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Encoded Token")
                .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
            TextEditor(text: $token)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 90)
                .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
        }

        if let error = errorMessage {
            Label(error, systemImage: "exclamationmark.triangle.fill")
                .font(.callout).foregroundStyle(.orange)
        }

        if let decoded {
            HStack(alignment: .top, spacing: 12) {
                jsonPanel("Header", decoded.headerJSON)
                jsonPanel("Payload", decoded.payloadJSON)
            }

            if !decoded.claims.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Registered Claims")
                        .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                    ForEach(decoded.claims) { claim in
                        HStack {
                            Text(claim.key).font(.caption).foregroundStyle(.secondary).frame(width: 150, alignment: .leading)
                            Text(claim.value).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                            if let note = claim.note {
                                Text(note).font(.caption.weight(.semibold))
                                    .foregroundStyle(note.contains("⚠️") ? .orange : .green)
                            }
                            Spacer()
                        }
                        .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Verify Signature — alg: \(decoded.algorithm)")
                    .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                TextField(decoded.algorithm.uppercased().hasPrefix("RS") ? "Paste PEM public key (-----BEGIN PUBLIC KEY-----)" : "HMAC secret", text: $secret, axis: .vertical)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1...6)
                    .textFieldStyle(.plain)
                    .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))

                if let verification {
                    verificationBadge(verification)
                }
            }
        }
    }

    // MARK: - Encode & Sign

    @ViewBuilder
    private var encodeSection: some View {
        Picker("Algorithm", selection: $signAlgorithm) {
            ForEach(JWTAlgorithm.allCases) { Text($0.rawValue).tag($0) }
        }
        .frame(maxWidth: 280)

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Payload")
                    .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                Spacer()
                Button("iat now") { setClaim("iat", offset: 0) }
                Button("nbf now") { setClaim("nbf", offset: 0) }
                Button("exp +1h") { setClaim("exp", offset: 3600) }
                Button("exp +24h") { setClaim("exp", offset: 86400) }
            }
            .controlSize(.small)
            TextEditor(text: $signPayload)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 110)
                .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
        }

        DisclosureGroup("Custom header (merged with alg/typ)", isExpanded: $showCustomHeader) {
            TextEditor(text: $customHeader)
                .font(.system(.body, design: .monospaced))
                .scrollContentBackground(.hidden)
                .frame(minHeight: 60)
                .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .font(.caption)

        VStack(alignment: .leading, spacing: 4) {
            Text(signAlgorithm.isHMAC ? "HMAC Secret" : "RSA Private Key")
                .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
            if signAlgorithm.isHMAC {
                TextField("Secret", text: $signKey)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.plain)
                    .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                TextEditor(text: $signKey)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 90)
                    .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                Text("PEM, PKCS#1 (-----BEGIN RSA PRIVATE KEY-----) or PKCS#8 (-----BEGIN PRIVATE KEY-----)")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }

        if let signError {
            Label(signError, systemImage: "exclamationmark.triangle.fill")
                .font(.callout).foregroundStyle(.orange)
        }

        if let signedToken {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Signed Token")
                        .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                    Spacer()
                    CopyButton(text: signedToken)
                }
                ScrollView {
                    Text(signedToken)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(minHeight: 70, maxHeight: 160)
                .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))

                if let selfCheck {
                    switch selfCheck {
                    case .valid:
                        Label("Self-check: signature verifies", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                    default:
                        Label("Self-check failed", systemImage: "xmark.seal.fill").foregroundStyle(.red)
                    }
                }
            }
        }
    }

    private func jsonPanel(_ title: LocalizedStringKey, _ json: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                Spacer()
                CopyButton(text: json)
            }
            ScrollView {
                Text(json)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 120, maxHeight: 240)
            .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private func verificationBadge(_ result: JWTVerification) -> some View {
        switch result {
        case .valid:
            Label("Signature verified", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
        case .invalid:
            Label("Signature invalid", systemImage: "xmark.seal.fill").foregroundStyle(.red)
        case .unsupported(let alg):
            Label("Unsupported algorithm: \(alg)", systemImage: "questionmark.circle").foregroundStyle(.secondary)
        case .missingKey:
            Label("Enter the key to verify", systemImage: "key").foregroundStyle(.secondary)
        case .error(let message):
            Label(message, systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
        }
    }

    private func decodeToken() {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            decoded = nil; errorMessage = nil; verification = nil; return
        }
        do {
            decoded = try JWTTool.decode(trimmed)
            errorMessage = nil
            runVerification()
        } catch {
            decoded = nil; verification = nil
            errorMessage = error.localizedDescription
        }
    }

    private func runVerification() {
        guard decoded != nil else { verification = nil; return }
        verification = JWTTool.verify(token, key: secret)
    }

    private func setClaim(_ key: String, offset: TimeInterval) {
        guard let obj = try? JSONSerialization.jsonObject(with: Data(signPayload.utf8)) as? [String: Any] else { return }
        var updated = obj
        updated[key] = Int(Date().timeIntervalSince1970 + offset)
        guard let data = try? JSONSerialization.data(withJSONObject: updated, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]) else { return }
        signPayload = String(decoding: data, as: UTF8.self)
    }

    private func generateToken() {
        guard mode == .encode else { return }
        guard !signKey.isEmpty else {
            signedToken = nil; selfCheck = nil
            signError = nil
            return
        }
        let (newToken, error) = JWTTool.sign(payloadJSON: signPayload, algorithm: signAlgorithm, key: signKey,
                                             extraHeader: customHeader.isEmpty ? nil : customHeader)
        signedToken = newToken
        signError = error
        if let newToken {
            let verifyKey = signAlgorithm.isHMAC ? signKey : (JWTTool.publicKeyPEM(fromPrivatePEM: signKey) ?? "")
            selfCheck = JWTTool.verify(newToken, key: verifyKey)
        } else {
            selfCheck = nil
        }
    }
}

extension JWTView {
    public static let descriptor = ToolDescriptor(
        id: "jwt",
        name: "JWT Decoder",
        icon: "person.badge.key.fill",
        category: .crypto,
        searchKeywords: ["jwt", "json web token", "bearer", "decode", "verify", "encode", "sign", "hs256", "rs256", "claims", "令牌", "鉴权", "签名"]
    )
}
