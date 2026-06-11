import SwiftUI
import UniformTypeIdentifiers

struct MultipartBodyEditor: View {
    @Binding var parts: [MultipartPart]

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                Color.clear.frame(width: 36)
                Text("Name")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 12)
                Color.clear.frame(width: 110)
                Text("Value")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 12)
                Color.clear.frame(width: 36)
            }
            .padding(.vertical, 8)
            .background(.fill.quaternary)

            Divider()

            ForEach($parts) { $part in
                MultipartPartRow(part: $part) {
                    parts.removeAll { $0.id == part.id }
                }
                Divider()
            }

            Button {
                parts.append(MultipartPart())
            } label: {
                Label("Add", systemImage: "plus")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
        }
        .background(.fill.tertiary)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))
    }
}

private struct MultipartPartRow: View {
    @Binding var part: MultipartPart
    let onDelete: () -> Void

    @State private var showFileImporter = false

    private var isFile: Bool {
        if case .file = part.kind { return true }
        return false
    }

    private var kindSelection: Binding<Bool> {
        Binding(
            get: { isFile },
            set: { wantsFile in
                guard wantsFile != isFile else { return }
                part.kind = wantsFile ? .file(path: "", filename: "", mimeType: "") : .text("")
            }
        )
    }

    private var textValue: Binding<String> {
        Binding(
            get: { if case .text(let value) = part.kind { value } else { "" } },
            set: { part.kind = .text($0) }
        )
    }

    private var mimeType: Binding<String> {
        Binding(
            get: { if case .file(_, _, let mime) = part.kind { mime } else { "" } },
            set: { if case .file(let path, let filename, _) = part.kind { part.kind = .file(path: path, filename: filename, mimeType: $0) } }
        )
    }

    var body: some View {
        HStack(spacing: 0) {
            Toggle("", isOn: $part.isEnabled)
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 36)

            TextField("Name", text: $part.name)
                .textFieldStyle(.plain)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)

            Picker("", selection: kindSelection) {
                Text("Text").tag(false)
                Text("File").tag(true)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .controlSize(.small)
            .frame(width: 110)

            Divider().frame(height: 24)

            if isFile {
                fileControls
            } else {
                TextField("Value", text: textValue)
                    .textFieldStyle(.plain)
                    .font(.system(.body, design: .monospaced))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
            }

            Button {
                onDelete()
            } label: {
                Image(systemName: "minus.circle.fill")
                    .foregroundStyle(.quaternary)
            }
            .buttonStyle(.plain)
            .frame(width: 36)
        }
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item]) { result in
            if case .success(let url) = result {
                part.kind = .file(path: url.path, filename: url.lastPathComponent, mimeType: MultipartEncoder.mimeType(forPath: url.path))
            }
        }
    }

    @ViewBuilder
    private var fileControls: some View {
        HStack(spacing: 8) {
            Button("Choose File…") { showFileImporter = true }
                .controlSize(.small)

            if case .file(let path, let filename, _) = part.kind, !path.isEmpty {
                Text(filename.isEmpty ? (path as NSString).lastPathComponent : filename)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .help(path)
                if let size = FileInfo.size(atPath: path) {
                    Text(FileInfo.format(bytes: size))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Label("Missing", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                TextField("MIME type", text: mimeType)
                    .textFieldStyle(.plain)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 80)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
    }
}

struct BinaryBodyEditor: View {
    @Binding var filePath: String
    @Binding var mimeType: String

    @State private var showFileImporter = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Button("Choose File…") { showFileImporter = true }
                if !filePath.isEmpty {
                    Text((filePath as NSString).lastPathComponent)
                        .font(.callout)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    if let size = FileInfo.size(atPath: filePath) {
                        Text(FileInfo.format(bytes: size))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Label("File not found — it may have been moved or deleted", systemImage: "exclamationmark.triangle")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            }

            if filePath.isEmpty {
                ContentUnavailableView("No File Selected", systemImage: "doc.badge.plus", description: Text("The file is read when the request is sent."))
            } else {
                Text(filePath)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                HStack(spacing: 8) {
                    Text("Content-Type")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("application/octet-stream", text: $mimeType)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.caption, design: .monospaced))
                        .frame(maxWidth: 280)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fileImporter(isPresented: $showFileImporter, allowedContentTypes: [.item]) { result in
            if case .success(let url) = result {
                filePath = url.path
                mimeType = MultipartEncoder.mimeType(forPath: url.path)
            }
        }
    }
}

enum FileInfo {
    static func size(atPath path: String) -> Int? {
        (try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? Int
    }

    static func format(bytes: Int) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(bytes), countStyle: .file)
    }
}
