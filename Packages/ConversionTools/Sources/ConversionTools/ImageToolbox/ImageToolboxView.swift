import SwiftUI
import AppKit
import DevAppCore
import UniformTypeIdentifiers

public struct ImageToolboxView: View {
    @State private var image: NSImage?
    @State private var format: ImageFormat = .png
    @State private var quality: Double = 0.8
    @State private var isDragOver = false
    @State private var status: String?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Image Toolbox").font(.title2).fontWeight(.semibold)
                Text("Compress, convert format, copy Base64 Data URL, and export favicon (.ico) / .icns")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Button { pasteImage() } label: { Label("Paste", systemImage: "doc.on.clipboard") }
                    .buttonStyle(.borderedProminent).keyboardShortcut("v", modifiers: .command)
                Button { openImage() } label: { Label("Open", systemImage: "folder") }
                    .buttonStyle(.bordered)
                if image != nil {
                    Button { image = nil; status = nil } label: { Label("Clear", systemImage: "xmark") }
                        .buttonStyle(.bordered)
                }
                Spacer()
                if let status { Text(status).font(.caption).foregroundStyle(.secondary) }
            }

            HStack(alignment: .top, spacing: 16) {
                // Preview
                ZStack {
                    RoundedRectangle(cornerRadius: 10).fill(.background.secondary)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(isDragOver ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isDragOver ? 2 : 1))
                    if let image {
                        Image(nsImage: image).resizable().aspectRatio(contentMode: .fit).padding(8)
                    } else {
                        VStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled").font(.system(size: 36)).foregroundStyle(.tertiary)
                            Text("Drop / paste / open an image").font(.callout).foregroundStyle(.tertiary)
                        }
                    }
                }
                .frame(width: 280, height: 280)
                .onDrop(of: [.image, .fileURL], isTargeted: $isDragOver) { providers in handleDrop(providers); return true }

                // Controls
                VStack(alignment: .leading, spacing: 14) {
                    if let image {
                        let (w, h) = ImageProcessor.pixelSize(of: image)
                        infoRow("Dimensions", "\(w) × \(h) px")
                        if let pngData = ImageProcessor.encode(image, format: .png) {
                            infoRow("PNG size", byteString(pngData.count))
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Output Format").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
                        Picker("Format", selection: $format) {
                            ForEach(ImageFormat.allCases) { Text($0.rawValue).tag($0) }
                        }.pickerStyle(.segmented)

                        if format.supportsQuality {
                            HStack {
                                Text("Quality").font(.caption).foregroundStyle(.secondary)
                                Slider(value: $quality, in: 0.1...1.0)
                                Text("\(Int(quality * 100))%").font(.caption.monospacedDigit()).frame(width: 40)
                            }
                            if let image, let data = ImageProcessor.encode(image, format: format, quality: quality) {
                                infoRow("\(format.rawValue) size", byteString(data.count))
                            }
                        }
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Button { saveConverted() } label: { Label("Save as \(format.rawValue)…", systemImage: "square.and.arrow.down") }
                        Button { copyDataURL() } label: { Label("Copy Base64 Data URL", systemImage: "link") }
                        Button { exportICO() } label: { Label("Export favicon (.ico)", systemImage: "app.badge") }
                        Button { exportICNS() } label: { Label("Export .icns", systemImage: "app.gift") }
                    }
                    .buttonStyle(.bordered)
                    .disabled(image == nil)

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
            Text(value).font(.system(.body, design: .monospaced))
            Spacer()
        }
    }

    private func byteString(_ bytes: Int) -> String {
        if bytes < 1024 { return "\(bytes) B" }
        if bytes < 1024 * 1024 { return String(format: "%.1f KB", Double(bytes) / 1024) }
        return String(format: "%.2f MB", Double(bytes) / (1024 * 1024))
    }

    // MARK: - Input

    private func pasteImage() {
        guard let img = NSPasteboard.general.readObjects(forClasses: [NSImage.self])?.first as? NSImage else {
            status = "No image in clipboard"; return
        }
        image = img; status = nil
    }

    private func openImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg, .tiff, .heic, .gif, .bmp]
        if panel.runModal() == .OK, let url = panel.url, let img = NSImage(contentsOf: url) {
            image = img; status = nil
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers where provider.canLoadObject(ofClass: NSImage.self) {
            _ = provider.loadObject(ofClass: NSImage.self) { img, _ in
                if let img = img as? NSImage { DispatchQueue.main.async { image = img; status = nil } }
            }
            return
        }
    }

    // MARK: - Output

    private func saveConverted() {
        guard let image, let data = ImageProcessor.encode(image, format: format, quality: quality) else { return }
        save(data, suggestedName: "image.\(format.fileExtension)", type: format)
    }

    private func copyDataURL() {
        guard let image, let url = ImageProcessor.dataURL(image, format: format, quality: quality) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(url, forType: .string)
        status = "Data URL copied (\(byteString(url.count)))"
    }

    private func exportICO() {
        guard let image, let data = ImageProcessor.icoData(image) else { return }
        save(data, suggestedName: "favicon.ico", type: nil)
    }

    private func exportICNS() {
        guard let image, let data = ImageProcessor.icnsData(image) else { return }
        save(data, suggestedName: "icon.icns", type: nil)
    }

    private func save(_ data: Data, suggestedName: String, type: ImageFormat?) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        if let type {
            switch type {
            case .png: panel.allowedContentTypes = [.png]
            case .jpeg: panel.allowedContentTypes = [.jpeg]
            case .tiff: panel.allowedContentTypes = [.tiff]
            case .heic: panel.allowedContentTypes = [.heic]
            }
        }
        if panel.runModal() == .OK, let url = panel.url {
            do { try data.write(to: url); status = "Saved \(url.lastPathComponent) (\(byteString(data.count)))" }
            catch { status = "Save failed: \(error.localizedDescription)" }
        }
    }
}

extension ImageToolboxView {
    public static let descriptor = ToolDescriptor(
        id: "image-toolbox",
        name: "Image Toolbox",
        icon: "photo.stack",
        category: .generators,
        searchKeywords: ["image", "compress", "convert", "resize", "favicon", "ico", "icns", "base64", "dataurl", "png", "jpeg", "heic", "图片", "压缩", "图标"]
    )
}
