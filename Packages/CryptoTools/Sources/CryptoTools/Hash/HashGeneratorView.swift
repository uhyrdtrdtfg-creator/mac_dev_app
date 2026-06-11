import SwiftUI
import AppKit
import DevAppCore

public struct HashGeneratorView: View {
    @State private var input = ""
    @State private var uppercase = false
    @State private var results: [HashAlgorithm: String] = [:]

    // File checksum
    @State private var fileName: String?
    @State private var fileResults: [HashAlgorithm: String] = [:]
    @State private var expected = ""

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Hash Generator")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Generate MD5, SHA-1, SHA-256, SHA-512, SHA3-256, SHA3-512, CRC32 hashes")
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
                                .frame(width: 70, alignment: .leading)
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

            Divider().padding(.vertical, 4)

            // File checksum
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("File Checksum")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.secondary).textCase(.uppercase)
                    Spacer()
                    Button {
                        chooseFile()
                    } label: {
                        Label(fileName ?? "Choose File…", systemImage: "doc.badge.plus")
                    }
                }

                if !fileResults.isEmpty {
                    ForEach(HashAlgorithm.allCases) { algorithm in
                        let value = displayValue(fileResults[algorithm])
                        HStack {
                            Text(algorithm.rawValue).font(.caption).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
                            Text(value).font(.system(.body, design: .monospaced))
                                .textSelection(.enabled).lineLimit(1).truncationMode(.middle)
                            if matchesExpected(value) {
                                Image(systemName: "checkmark.seal.fill").foregroundStyle(.green)
                            }
                            Spacer()
                            CopyButton(text: value)
                        }
                        .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 6))
                    }

                    TextField("Expected checksum to compare…", text: $expected)
                        .font(.system(.caption, design: .monospaced))
                        .textFieldStyle(.plain)
                        .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .onChange(of: input) { _, _ in updateHashes() }
        .onChange(of: uppercase) { _, _ in updateHashes() }
    }

    private func displayValue(_ raw: String?) -> String {
        guard let raw else { return "" }
        return uppercase ? raw.uppercased() : raw
    }

    private func matchesExpected(_ value: String) -> Bool {
        let trimmed = expected.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return value.caseInsensitiveCompare(trimmed) == .orderedSame
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? Data(contentsOf: url) else { return }
        fileName = url.lastPathComponent
        fileResults = HashGenerator.hashAll(data: data)
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
        searchKeywords: ["hash", "md5", "sha", "sha1", "sha256", "sha512", "sha3", "crc", "crc32", "digest", "checksum", "哈希", "摘要"]
    )
}
