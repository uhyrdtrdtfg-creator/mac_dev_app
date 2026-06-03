import SwiftUI
import DevAppCore

public struct CertificateInspectorView: View {
    @State private var input = ""
    @State private var info: CertificateInfo?
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Certificate / PEM Viewer")
                    .font(.title2).fontWeight(.semibold)
                Text("Parse an X.509 certificate and inspect subject, issuer, validity, SAN and fingerprints")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Certificate (PEM or Base64 DER)")
                    .font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                TextEditor(text: $input)
                    .font(.system(.body, design: .monospaced))
                    .scrollContentBackground(.hidden)
                    .frame(minHeight: 120)
                    .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(.orange)
            }

            if let info {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(info.fields) { field in
                        HStack(alignment: .top) {
                            Text(field.label).font(.caption).foregroundStyle(.secondary)
                                .frame(width: 130, alignment: .leading)
                            Text(field.value).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                            Spacer()
                        }
                        .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    fingerprintRow("SHA-256", info.sha256Fingerprint)
                    fingerprintRow("SHA-1", info.sha1Fingerprint)
                }
            }
        }
        .padding()
        .onChange(of: input) { _, _ in parse() }
    }

    private func fingerprintRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top) {
            Text("\(label) FP").font(.caption).foregroundStyle(.secondary)
                .frame(width: 130, alignment: .leading)
            Text(value).font(.system(.caption, design: .monospaced)).textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
            CopyButton(text: value)
        }
        .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func parse() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { info = nil; errorMessage = nil; return }
        do {
            info = try CertificateInspector.inspect(trimmed)
            errorMessage = nil
        } catch {
            info = nil
            errorMessage = error.localizedDescription
        }
    }
}

extension CertificateInspectorView {
    public static let descriptor = ToolDescriptor(
        id: "cert-viewer",
        name: "Certificate Viewer",
        icon: "checkmark.seal",
        category: .crypto,
        searchKeywords: ["certificate", "cert", "x509", "pem", "der", "ssl", "tls", "证书", "指纹"]
    )
}
