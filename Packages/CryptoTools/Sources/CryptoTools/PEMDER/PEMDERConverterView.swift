import SwiftUI
import AppKit
import UniformTypeIdentifiers
import DevAppCore

public struct PEMDERConverterView: View {
    @State private var pemText = ""
    @State private var derText = ""
    @State private var derFormat: DERFormat = .base64
    @State private var selectedLabel: PEMLabel = .certificate
    @State private var detectedLabel: String?
    @State private var blockCount = 0
    @State private var byteCount = 0
    @State private var errorMessage: String?

    enum DERFormat: String, CaseIterable, Identifiable {
        case base64 = "Base64"
        case hex = "Hex"
        var id: String { rawValue }
    }

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PEM ↔ DER Converter").font(.title2).fontWeight(.semibold)
                Text("Convert between PEM armor (Base64 text) and binary DER encoding for certificates and keys")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                    .font(.callout).foregroundStyle(.orange)
            }

            HStack(alignment: .top, spacing: 12) {
                // Left: PEM
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("PEM").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                        Spacer()
                        CopyButton(text: pemText)
                    }
                    TextEditor(text: $pemText)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 220)
                        .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                    HStack {
                        Button { convertPEMToDER() } label: { Label("PEM → DER", systemImage: "arrow.right") }
                            .buttonStyle(.bordered).tint(.blue)
                        if let detectedLabel {
                            Text(captionText(for: detectedLabel))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }

                // Right: DER
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("DER").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                        Picker("Format", selection: $derFormat) {
                            ForEach(DERFormat.allCases) { f in Text(f.rawValue).tag(f) }
                        }
                        .pickerStyle(.segmented).labelsHidden().fixedSize()
                        Spacer()
                        if byteCount > 0 {
                            Text("\(byteCount) bytes").font(.caption).foregroundStyle(.secondary)
                        }
                        CopyButton(text: derText)
                    }
                    TextEditor(text: $derText)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 220)
                        .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                    HStack {
                        Button { convertDERToPEM() } label: { Label("DER → PEM", systemImage: "arrow.left") }
                            .buttonStyle(.bordered).tint(.blue)
                        Picker("Label", selection: $selectedLabel) {
                            ForEach(PEMLabel.allCases) { label in Text(label.displayName).tag(label) }
                        }
                        .pickerStyle(.menu).fixedSize()
                        Spacer()
                        Button { openDERFile() } label: { Label("Open…", systemImage: "folder") }
                            .buttonStyle(.bordered)
                        Button { saveDERFile() } label: { Label("Save…", systemImage: "square.and.arrow.down") }
                            .buttonStyle(.bordered)
                            .disabled(currentDERData() == nil)
                    }
                }
            }
        }
        .padding()
        .onChange(of: derFormat) { _, _ in reformatDER() }
    }

    private func captionText(for label: String) -> String {
        var text = "Detected label: \(label)"
        if blockCount > 1 { text += " (\(blockCount) PEM blocks found, converted the first)" }
        return text
    }

    // MARK: - Conversion

    private func convertPEMToDER() {
        errorMessage = nil
        do {
            let result = try PEMDERConverter.decodePEM(pemText)
            detectedLabel = result.label
            blockCount = result.blockCount
            byteCount = result.der.count
            derText = encode(result.der)
            if let label = PEMLabel(rawValue: result.label) { selectedLabel = label }
        } catch {
            detectedLabel = nil
            blockCount = 0
            errorMessage = error.localizedDescription
        }
    }

    private func convertDERToPEM() {
        errorMessage = nil
        guard let der = currentDERData() else {
            errorMessage = derFormat == .base64 ? "Invalid Base64 in DER panel." : "Invalid hex in DER panel."
            return
        }
        byteCount = der.count
        let label: PEMLabel
        if let detected = PEMDERConverter.detectLabel(for: der) {
            label = detected
            selectedLabel = detected
            detectedLabel = detected.rawValue
            blockCount = 1
        } else {
            label = selectedLabel
            detectedLabel = nil
        }
        pemText = PEMDERConverter.derToPEM(der, label: label)
    }

    // MARK: - DER text helpers

    private func currentDERData() -> Data? {
        let cleaned = derText.components(separatedBy: .whitespacesAndNewlines).joined()
        guard !cleaned.isEmpty else { return nil }
        switch derFormat {
        case .base64: return Data(base64Encoded: cleaned)
        case .hex: return Data(hexString: cleaned)
        }
    }

    private func encode(_ data: Data) -> String {
        switch derFormat {
        case .base64: data.base64EncodedString()
        case .hex: data.map { String(format: "%02x", $0) }.joined()
        }
    }

    private func reformatDER() {
        // Re-encode the panel when the format picker changes, if the current text parses
        // in the *other* format.
        let cleaned = derText.components(separatedBy: .whitespacesAndNewlines).joined()
        guard !cleaned.isEmpty else { return }
        let data: Data? = switch derFormat {
        case .base64: Data(hexString: cleaned)
        case .hex: Data(base64Encoded: cleaned)
        }
        if let data {
            derText = encode(data)
            byteCount = data.count
        }
    }

    // MARK: - File IO

    private func openDERFile() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        var types: [UTType] = []
        if let der = UTType(filenameExtension: "der") { types.append(der) }
        if let cer = UTType(filenameExtension: "cer") { types.append(cer) }
        if !types.isEmpty { panel.allowedContentTypes = types }
        panel.allowsOtherFileTypes = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let data = try? Data(contentsOf: url) else {
            errorMessage = "Could not read \(url.lastPathComponent)."
            return
        }
        errorMessage = nil
        byteCount = data.count
        derText = encode(data)
        if let detected = PEMDERConverter.detectLabel(for: data) {
            selectedLabel = detected
            detectedLabel = detected.rawValue
        } else {
            detectedLabel = nil
        }
        blockCount = 0
    }

    private func saveDERFile() {
        guard let data = currentDERData() else { return }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = selectedLabel == .certificate ? "certificate.der" : "data.der"
        if let der = UTType(filenameExtension: "der") { panel.allowedContentTypes = [der] }
        panel.allowsOtherFileTypes = true
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            try data.write(to: url)
            errorMessage = nil
        } catch {
            errorMessage = "Could not save file: \(error.localizedDescription)"
        }
    }
}

extension PEMDERConverterView {
    public static let descriptor = ToolDescriptor(
        id: "pem-der", name: "PEM ↔ DER", icon: "doc.badge.gearshape", category: .crypto,
        searchKeywords: ["pem", "der", "certificate", "x509", "convert", "证书", "格式转换"]
    )
}
