import SwiftUI
import DevAppCore

public struct HashGeneratorView: View {
    @State private var input = ""
    @State private var uppercase = false
    @State private var results: [HashAlgorithm: String] = [:]

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hash Generator")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Generate MD5, SHA-1, SHA-256, SHA-512 hashes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Toggle("Uppercase", isOn: $uppercase)
                    .toggleStyle(.checkbox)
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Input")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    TextEditor(text: $input)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Output")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    ForEach(HashAlgorithm.allCases) { algorithm in
                        HStack {
                            Text(algorithm.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .frame(width: 60, alignment: .leading)
                            Text(displayResult(for: algorithm))
                                .font(.system(.body, design: .monospaced))
                                .textSelection(.enabled)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            CopyButton(text: displayResult(for: algorithm))
                        }
                        .padding(8)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
        .padding()
        .onChange(of: input) { _, _ in updateHashes() }
        .onChange(of: uppercase) { _, _ in updateHashes() }
    }

    private func displayResult(for algorithm: HashAlgorithm) -> String {
        guard let result = results[algorithm] else { return "" }
        return uppercase ? result.uppercased() : result
    }

    private func updateHashes() {
        results = HashGenerator.hashAll(input)
    }
}

extension HashGeneratorView {
    public static let descriptor = ToolDescriptor(
        id: "hash-generator",
        name: "Hash Generator",
        icon: "number",
        category: .crypto,
        searchKeywords: ["hash", "md5", "sha", "sha1", "sha256", "sha512", "digest", "checksum", "哈希", "摘要"]
    )
}
