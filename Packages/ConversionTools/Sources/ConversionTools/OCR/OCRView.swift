import SwiftUI
import AppKit
import DevAppCore
import UniformTypeIdentifiers

public struct OCRView: View {
    @State private var image: NSImage?
    @State private var recognizedText = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var isDragOver = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Image to Text (OCR)")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Paste from clipboard, drag & drop, or open an image to extract text")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            // Toolbar
            HStack(spacing: 10) {
                Button {
                    pasteFromClipboard()
                } label: {
                    Label("Paste Image", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("v", modifiers: .command)

                Button {
                    openFile()
                } label: {
                    Label("Open File", systemImage: "folder")
                }
                .buttonStyle(.bordered)

                if image != nil {
                    Button {
                        image = nil; recognizedText = ""; errorMessage = nil
                    } label: {
                        Label("Clear", systemImage: "xmark")
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                if isProcessing {
                    ProgressView()
                        .controlSize(.small)
                    Text("Recognizing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let errorMessage {
                    Label(errorMessage, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            // Content: Image + Text
            HStack(spacing: 16) {
                // Image panel
                VStack(alignment: .leading, spacing: 6) {
                    Text("IMAGE")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.secondary)

                    ZStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.background.secondary)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isDragOver ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: isDragOver ? 2 : 1)
                            )

                        if let image {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .padding(8)
                        } else {
                            VStack(spacing: 12) {
                                Image(systemName: "photo.on.rectangle.angled")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.tertiary)
                                Text("Drop image here or paste from clipboard")
                                    .font(.callout)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .onDrop(of: [.image, .fileURL], isTargeted: $isDragOver) { providers in
                        handleDrop(providers)
                        return true
                    }
                }

                // Text panel
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("RECOGNIZED TEXT")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                        Spacer()
                        if !recognizedText.isEmpty {
                            CopyButton(text: recognizedText)
                        }
                    }
                    TextEditor(text: $recognizedText)
                        .font(.system(.body, design: .monospaced))
                        .scrollContentBackground(.hidden)
                        .padding(10)
                        .background(.fill.tertiary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(.separator, lineWidth: 0.5)
                        )
                }
            }
        }
        .padding(20)
    }

    // MARK: - Actions

    private func pasteFromClipboard() {
        guard let img = OCRService.imageFromPasteboard() else {
            errorMessage = "No image found in clipboard"
            return
        }
        setImageAndRecognize(img)
    }

    private func openFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image, .png, .jpeg, .tiff, .bmp, .gif, .webP]
        panel.allowsMultipleSelection = false
        panel.begin { result in
            if result == .OK, let url = panel.url, let img = NSImage(contentsOf: url) {
                setImageAndRecognize(img)
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) {
        for provider in providers {
            if provider.canLoadObject(ofClass: NSImage.self) {
                _ = provider.loadObject(ofClass: NSImage.self) { img, _ in
                    if let img = img as? NSImage {
                        DispatchQueue.main.async { setImageAndRecognize(img) }
                    }
                }
                return
            }
            // Try file URL
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
                if let data = data as? Data, let url = URL(dataRepresentation: data, relativeTo: nil),
                   let img = NSImage(contentsOf: url) {
                    DispatchQueue.main.async { setImageAndRecognize(img) }
                }
            }
        }
    }

    private func setImageAndRecognize(_ img: NSImage) {
        image = img
        errorMessage = nil
        recognizedText = ""
        isProcessing = true
        Task {
            let result = await OCRService.recognizeText(from: img)
            isProcessing = false
            switch result {
            case .success(let text): recognizedText = text
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
    }
}

extension OCRView {
    public static let descriptor = ToolDescriptor(
        id: "ocr",
        name: "Image to Text (OCR)",
        icon: "text.viewfinder",
        category: .conversion,
        searchKeywords: ["ocr", "image", "text", "recognize", "extract", "图片", "识别", "文字"]
    )
}
