import SwiftUI
import UniformTypeIdentifiers
import DevAppCore

public enum PlistConversionMode: String, CaseIterable, Identifiable, Sendable {
    case plistToJSON = "Plist → JSON"
    case jsonToPlist = "JSON → Plist"
    case plistToBinary = "Plist → Binary"
    case format = "Format / Validate"
    public var id: String { rawValue }
}

public struct PlistConverterView: View {
    @State private var input = ""
    @State private var output = ""
    @State private var mode: PlistConversionMode = .plistToJSON
    @State private var errorMessage: String?
    @State private var statusText: String?
    @State private var binaryData: Data?
    @State private var showingImporter = false
    @State private var showingExporter = false

    public init() {}

    public var body: some View {
        InputOutputView(title: "Plist Converter", description: "Convert between XML/binary property lists and JSON", input: $input, output: $output, inputLabel: "Input", outputLabel: outputLabel, toolID: "plist-converter") {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 12) {
                    Picker("Mode", selection: $mode) { ForEach(PlistConversionMode.allCases) { Text($0.rawValue).tag($0) } }.pickerStyle(.segmented).fixedSize()
                    Button("Open .plist…") { showingImporter = true }.buttonStyle(.bordered)
                    if mode == .plistToBinary {
                        Button("Save binary…") { showingExporter = true }.buttonStyle(.bordered).disabled(binaryData == nil)
                    }
                    if let errorMessage { Label(errorMessage, systemImage: "xmark.circle").font(.caption).foregroundStyle(.red).lineLimit(2) }
                    else if let statusText { Label(statusText, systemImage: "checkmark.circle").font(.caption).foregroundStyle(.green) }
                }
                Text("JSON mapping: <date> ↔ ISO8601 string, <data> → base64 string, integer/real/bool preserved. JSON null is rejected — plists have no null type.")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
        .onChange(of: input) { _, _ in convert() }
        .onChange(of: mode) { _, _ in convert() }
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.propertyList, .xmlPropertyList, .binaryPropertyList]) { result in
            switch result {
            case .success(let url): openPlist(at: url)
            case .failure(let error): errorMessage = error.localizedDescription
            }
        }
        .fileExporter(isPresented: $showingExporter, document: binaryData.map { BinaryPlistDocument(data: $0) }, contentType: .binaryPropertyList, defaultFilename: "converted.plist") { result in
            if case .failure(let error) = result { errorMessage = error.localizedDescription }
        }
    }

    private var outputLabel: LocalizedStringKey {
        switch mode {
        case .plistToJSON: "JSON"
        case .jsonToPlist: "XML Plist"
        case .plistToBinary: "Base64 (binary plist)"
        case .format: "Formatted XML Plist"
        }
    }

    private func convert() {
        binaryData = nil
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            output = ""; errorMessage = nil; statusText = nil; return
        }
        switch mode {
        case .plistToJSON: apply(PlistConverter.plistToJSON(input), status: "Valid plist")
        case .jsonToPlist: apply(PlistConverter.jsonToXML(input), status: "Valid JSON")
        case .format: apply(PlistConverter.formatXML(input), status: "Valid plist")
        case .plistToBinary:
            let result = PlistConverter.xmlToBinary(input)
            output = result.base64 ?? ""
            binaryData = result.data
            errorMessage = result.error
            statusText = result.error == nil ? "Valid plist — use Save binary… to export" : nil
        }
    }

    private func apply(_ result: PlistConvertResult, status: String) {
        output = result.output ?? ""
        errorMessage = result.error
        statusText = result.error == nil ? status : nil
    }

    private func openPlist(at url: URL) {
        let secured = url.startAccessingSecurityScopedResource()
        defer { if secured { url.stopAccessingSecurityScopedResource() } }
        do {
            let data = try Data(contentsOf: url)
            let result = PlistConverter.dataToXML(data)
            if let xml = result.output { input = xml }
            errorMessage = result.error
        } catch { errorMessage = error.localizedDescription }
    }
}

struct BinaryPlistDocument: FileDocument {
    static let readableContentTypes: [UTType] = [.binaryPropertyList, .propertyList]
    let data: Data

    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws { data = configuration.file.regularFileContents ?? Data() }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper { FileWrapper(regularFileWithContents: data) }
}

extension PlistConverterView {
    public static let descriptor = ToolDescriptor(id: "plist-converter", name: "Plist Converter", icon: "list.bullet.rectangle", category: .conversion, searchKeywords: ["plist", "property list", "xml", "binary", "json", "convert", "bplist", "macos", "ios", "属性列表", "转换"])
}
