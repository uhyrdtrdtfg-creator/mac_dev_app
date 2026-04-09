import SwiftUI
import DevAppCore
import CryptoTools
import ConversionTools
import APIClient

struct ContentView: View {
    @State private var registry = ToolRegistry()

    var body: some View {
        NavigationSplitView {
            SidebarView(registry: registry)
        } detail: {
            if let toolID = registry.selectedToolID {
                if toolID == "http-client" {
                    toolView(for: toolID)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        toolView(for: toolID)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            } else {
                WelcomeView()
            }
        }
        .frame(minWidth: 900, minHeight: 650)
        .onAppear {
            registerAllTools()
        }
    }

    private func registerAllTools() {
        registry.registerAll([
            // Crypto
            HashGeneratorView.descriptor,
            HMACGeneratorView.descriptor,
            AESCryptorView.descriptor,
            RSACryptorView.descriptor,
            // API Client
            APIClientView.descriptor,
            // Conversion
            TimestampConverterView.descriptor,
            URLCodecView.descriptor,
            Base64CodecView.descriptor,
            JSONFormatterView.descriptor,
            UUIDGeneratorView.descriptor,
            RandomStringGeneratorView.descriptor,
            BaseConverterView.descriptor,
            HTMLEntityCodecView.descriptor,
            StringEscaperView.descriptor,
            StringCaseConverterView.descriptor,
            HexAsciiConverterView.descriptor,
            LineSorterView.descriptor,
            TextAnalyzerView.descriptor,
            LoremIpsumGeneratorView.descriptor,
            JSONYamlView.descriptor,
        ])
    }

    @ViewBuilder
    private func toolView(for id: String) -> some View {
        switch id {
        case "hash-generator": HashGeneratorView()
        case "hmac-generator": HMACGeneratorView()
        case "aes-cryptor": AESCryptorView()
        case "rsa-cryptor": RSACryptorView()
        case "http-client": APIClientView()
        case "timestamp-converter": TimestampConverterView()
        case "url-codec": URLCodecView()
        case "base64-codec": Base64CodecView()
        case "json-formatter": JSONFormatterView()
        case "uuid-generator": UUIDGeneratorView()
        case "random-string": RandomStringGeneratorView()
        case "base-converter": BaseConverterView()
        case "html-entity": HTMLEntityCodecView()
        case "string-escape": StringEscaperView()
        case "string-case": StringCaseConverterView()
        case "hex-ascii": HexAsciiConverterView()
        case "line-sort": LineSorterView()
        case "text-analyzer": TextAnalyzerView()
        case "lorem-ipsum": LoremIpsumGeneratorView()
        case "json-yaml": JSONYamlView()
        default:
            ContentUnavailableView(
                "Tool Not Found",
                systemImage: "questionmark.circle",
                description: Text("Tool '\(id)' is not available.")
            )
        }
    }
}

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "chevron.left.slash.chevron.right")
                .font(.system(size: 56, weight: .thin))
                .foregroundStyle(.blue.gradient)

            VStack(spacing: 8) {
                Text("DevToolkit")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Your all-in-one developer companion")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            Divider()
                .frame(width: 200)
                .padding(.vertical, 4)

            HStack(spacing: 40) {
                featureItem(icon: "lock.shield.fill", title: "Crypto", description: "AES, RSA, Hash, HMAC", color: .blue)
                featureItem(icon: "network", title: "API Client", description: "HTTP requests & responses", color: .green)
                featureItem(icon: "arrow.2.squarepath", title: "Conversion", description: "Base64, URL, JSON, Time", color: .orange)
            }

            Text("Select a tool from the sidebar to get started")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .padding(.top, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func featureItem(icon: String, title: String, description: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 28))
                .foregroundStyle(color.gradient)
                .frame(width: 52, height: 52)
                .background(color.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 12))

            Text(title)
                .font(.headline)

            Text(description)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(width: 140)
    }
}
