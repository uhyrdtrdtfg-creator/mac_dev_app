import SwiftUI
import DevAppCore

public struct HMACGeneratorView: View {
    @State private var message = ""
    @State private var key = ""
    @State private var algorithm: HMACAlgorithm = .sha256
    @State private var outputFormat: HMACOutputFormat = .hex
    @State private var output = ""

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("HMAC Generator")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("Generate HMAC authentication codes")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Picker("Algorithm", selection: $algorithm) {
                    ForEach(HMACAlgorithm.allCases) { algo in
                        Text(algo.rawValue).tag(algo)
                    }
                }
                .pickerStyle(.menu)
                .fixedSize()

                Picker("Output Format", selection: $outputFormat) {
                    ForEach(HMACOutputFormat.allCases) { fmt in
                        Text(fmt.rawValue).tag(fmt)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Key")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                TextField("Enter secret key...", text: $key)
                    .font(.system(.body, design: .monospaced))
                    .textFieldStyle(.plain)
                    .padding(8)
                    .background(.fill.tertiary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Message")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    TextEditor(text: $message)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Output")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                        Spacer()
                        CopyButton(text: output)
                    }
                    TextEditor(text: .constant(output))
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .onChange(of: message) { _, _ in updateOutput() }
        .onChange(of: key) { _, _ in updateOutput() }
        .onChange(of: algorithm) { _, _ in updateOutput() }
        .onChange(of: outputFormat) { _, _ in updateOutput() }
    }

    private func updateOutput() {
        guard !message.isEmpty, !key.isEmpty else {
            output = ""
            return
        }
        output = HMACGenerator.generate(message: message, keyString: key, algorithm: algorithm, outputFormat: outputFormat)
    }
}

extension HMACGeneratorView {
    public static let descriptor = ToolDescriptor(
        id: "hmac-generator",
        name: "HMAC Generator",
        icon: "key.horizontal",
        category: .crypto,
        searchKeywords: ["hmac", "mac", "authentication", "code", "密钥", "认证"]
    )
}
