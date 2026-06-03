import SwiftUI
import DevAppCore

public struct JWTView: View {
    @State private var token = ""
    @State private var secret = ""
    @State private var decoded: JWTDecoded?
    @State private var errorMessage: String?
    @State private var verification: JWTVerification?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("JWT Decoder & Verifier")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Decode JWT header/payload, inspect claims, and verify HS256/384/512 or RS256/384/512 signatures")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

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
        .padding()
        .onChange(of: token) { _, _ in decodeToken() }
        .onChange(of: secret) { _, _ in runVerification() }
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
}

extension JWTView {
    public static let descriptor = ToolDescriptor(
        id: "jwt",
        name: "JWT Decoder",
        icon: "person.badge.key.fill",
        category: .crypto,
        searchKeywords: ["jwt", "json web token", "bearer", "decode", "verify", "claims", "令牌", "鉴权"]
    )
}
