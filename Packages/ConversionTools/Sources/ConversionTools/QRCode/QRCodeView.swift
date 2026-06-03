import SwiftUI
import AppKit
import DevAppCore
import UniformTypeIdentifiers

public struct QRCodeView: View {
    @State private var generateMode = true

    // Generate
    @State private var text = "https://example.com"
    @State private var correction: QRCorrectionLevel = .medium
    @State private var qrImage: NSImage?

    // Scan
    @State private var droppedImage: NSImage?
    @State private var decodedPayloads: [String] = []
    @State private var isDragOver = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("QR Code").font(.title2).fontWeight(.semibold)
                Text("Generate QR codes from text or scan an image to read its payload")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            Picker("Mode", selection: $generateMode) {
                Text("Generate").tag(true)
                Text("Scan").tag(false)
            }.pickerStyle(.segmented).frame(width: 240)

            if generateMode { generatePanel } else { scanPanel }
        }
        .padding()
    }

    // MARK: - Generate

    private var generatePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Content").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                TextEditor(text: $text)
                    .font(.system(.body, design: .monospaced)).scrollContentBackground(.hidden)
                    .frame(minHeight: 80)
                    .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Picker("Error Correction", selection: $correction) {
                    ForEach(QRCorrectionLevel.allCases) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).frame(width: 200)
                Spacer()
                if qrImage != nil {
                    Button { saveImage() } label: { Label("Save PNG", systemImage: "square.and.arrow.down") }
                        .buttonStyle(.bordered)
                }
            }

            if let qrImage {
                Image(nsImage: qrImage)
                    .interpolation(.none).resizable().aspectRatio(contentMode: .fit)
                    .frame(width: 240, height: 240)
                    .background(.white).clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .onAppear { regenerate() }
        .onChange(of: text) { _, _ in regenerate() }
        .onChange(of: correction) { _, _ in regenerate() }
    }

    private func regenerate() {
        qrImage = QRCodeService.generate(from: text, correction: correction)
    }

    private func saveImage() {
        guard let qrImage, let data = QRCodeService.pngData(from: qrImage) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.png]
        panel.nameFieldStringValue = "qrcode.png"
        if panel.runModal() == .OK, let url = panel.url {
            try? data.write(to: url)
        }
    }

    // MARK: - Scan

    private var scanPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Button { pasteImage() } label: { Label("Paste Image", systemImage: "doc.on.clipboard") }
                    .buttonStyle(.borderedProminent)
                Button { openImage() } label: { Label("Open File", systemImage: "folder") }
                    .buttonStyle(.bordered)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(.background.secondary)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(isDragOver ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isDragOver ? 2 : 1))
                if let droppedImage {
                    Image(nsImage: droppedImage).resizable().aspectRatio(contentMode: .fit).padding(8)
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "qrcode.viewfinder").font(.system(size: 36)).foregroundStyle(.tertiary)
                        Text("Drop a QR/barcode image here").font(.callout).foregroundStyle(.tertiary)
                    }
                }
            }
            .frame(height: 220)
            .onDrop(of: [.image, .fileURL], isTargeted: $isDragOver) { providers in handleDrop(providers); return true }

            if !decodedPayloads.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Decoded").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                    ForEach(Array(decodedPayloads.enumerated()), id: \.offset) { _, payload in
                        HStack {
                            Text(payload).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                            Spacer()
                            CopyButton(text: payload)
                        }
                        .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            } else if droppedImage != nil {
                Label("No QR/barcode found", systemImage: "xmark.circle").font(.callout).foregroundStyle(.orange)
            }
        }
    }

    private func pasteImage() {
        guard let img = NSPasteboard.general.readObjects(forClasses: [NSImage.self])?.first as? NSImage else { return }
        scan(img)
    }

    private func openImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg, .tiff]
        if panel.runModal() == .OK, let url = panel.url, let img = NSImage(contentsOf: url) { scan(img) }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers where provider.canLoadObject(ofClass: NSImage.self) {
            _ = provider.loadObject(ofClass: NSImage.self) { img, _ in
                if let img = img as? NSImage { DispatchQueue.main.async { scan(img) } }
            }
            return
        }
    }

    private func scan(_ img: NSImage) {
        droppedImage = img
        decodedPayloads = []
        Task {
            let payloads = await QRCodeService.decode(from: img)
            decodedPayloads = payloads
        }
    }
}

extension QRCodeView {
    public static let descriptor = ToolDescriptor(
        id: "qr-code",
        name: "QR Code",
        icon: "qrcode",
        category: .generators,
        searchKeywords: ["qr", "qrcode", "barcode", "generate", "scan", "decode", "二维码", "条形码"]
    )
}
