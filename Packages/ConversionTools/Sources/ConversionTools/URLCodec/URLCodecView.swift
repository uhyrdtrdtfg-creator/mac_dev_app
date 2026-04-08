import SwiftUI
import DevAppCore

public struct URLCodecView: View {
    @State private var input = ""
    @State private var output = ""
    @State private var standard: URLEncodingStandard = .rfc3986
    @State private var parsedComponents: URLComponents?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            InputOutputView(title: "URL Encode / Decode", description: "Encode and decode URLs with RFC 3986 or Form Data standard", input: $input, output: $output, inputLabel: "Decoded", outputLabel: "Encoded") {
                Picker("Standard", selection: $standard) { ForEach(URLEncodingStandard.allCases) { s in Text(s.rawValue).tag(s) } }.pickerStyle(.segmented).frame(width: 250)
            }

            if let components = parsedComponents {
                Divider()
                Text("URL Components").font(.headline)
                VStack(alignment: .leading, spacing: 4) {
                    componentRow("Scheme", components.scheme)
                    componentRow("Host", components.host)
                    componentRow("Port", components.port.map(String.init))
                    componentRow("Path", components.path.isEmpty ? nil : components.path)
                    componentRow("Fragment", components.fragment)
                    if let items = components.queryItems, !items.isEmpty {
                        Text("Query Parameters").font(.caption).foregroundStyle(.secondary).textCase(.uppercase).padding(.top, 4)
                        ForEach(items, id: \.name) { item in
                            HStack { Text(item.name).font(.system(.body, design: .monospaced)).foregroundStyle(.blue); Text("=").foregroundStyle(.secondary); Text(item.value ?? "").font(.system(.body, design: .monospaced)) }
                        }
                    }
                }
                .padding().background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .onChange(of: input) { _, _ in output = URLCodec.encode(input, standard: standard); parsedComponents = URLCodec.parse(input) }
        .onChange(of: standard) { _, _ in output = URLCodec.encode(input, standard: standard) }
    }

    private func componentRow(_ label: String, _ value: String?) -> some View {
        Group {
            if let value, !value.isEmpty {
                HStack { Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 70, alignment: .trailing); Text(value).font(.system(.body, design: .monospaced)).textSelection(.enabled) }
            }
        }
    }
}

extension URLCodecView {
    public static let descriptor = ToolDescriptor(id: "url-codec", name: "URL Encode/Decode", icon: "link", category: .conversion, searchKeywords: ["url", "encode", "decode", "percent", "uri", "编码", "解码"])
}
