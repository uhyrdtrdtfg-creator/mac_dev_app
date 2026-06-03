import SwiftUI
import DevAppCore

public struct CompressionView: View {
    @State private var algorithm: CompressionAlgorithm = .zlib
    @State private var compressMode = true
    @State private var input = ""
    @State private var output = ""
    @State private var stats: String?
    @State private var errorMessage: String?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Compression").font(.title2).fontWeight(.semibold)
                Text("Compress text to Base64 or decompress, using zlib / LZFSE / LZ4 / LZMA")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            HStack(spacing: 16) {
                Picker("Mode", selection: $compressMode) {
                    Text("Compress").tag(true)
                    Text("Decompress").tag(false)
                }.pickerStyle(.segmented).frame(width: 220)
                Picker("Algorithm", selection: $algorithm) {
                    ForEach(CompressionAlgorithm.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.menu).fixedSize()
                if let stats { Text(stats).font(.caption).foregroundStyle(.secondary) }
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "xmark.circle").font(.callout).foregroundStyle(.red)
            }

            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(compressMode ? "Text" : "Base64").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                    TextEditor(text: $input)
                        .font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden)
                        .frame(minHeight: 180)
                        .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(compressMode ? "Base64" : "Text").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                        Spacer()
                        CopyButton(text: output)
                    }
                    TextEditor(text: .constant(output))
                        .font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden)
                        .frame(minHeight: 180)
                        .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .onChange(of: input) { _, _ in run() }
        .onChange(of: algorithm) { _, _ in run() }
        .onChange(of: compressMode) { _, _ in run() }
    }

    private func run() {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            output = ""; stats = nil; errorMessage = nil; return
        }
        do {
            if compressMode {
                let result = try CompressionTool.compress(text: input, algorithm: algorithm)
                output = result.base64
                stats = String(format: "%d → %d bytes (%.0f%%)", result.originalBytes, result.compressedBytes, result.ratio * 100)
            } else {
                output = try CompressionTool.decompress(base64: input, algorithm: algorithm)
                stats = nil
            }
            errorMessage = nil
        } catch {
            output = ""; stats = nil
            errorMessage = error.localizedDescription
        }
    }
}

extension CompressionView {
    public static let descriptor = ToolDescriptor(
        id: "compression",
        name: "Compression",
        icon: "archivebox",
        category: .developer,
        searchKeywords: ["compress", "decompress", "zlib", "deflate", "gzip", "lzfse", "lz4", "lzma", "压缩", "解压"]
    )
}
