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
                toolView(for: toolID)
            } else {
                ContentUnavailableView(
                    "Select a Tool",
                    systemImage: "wrench.and.screwdriver",
                    description: Text("Choose a tool from the sidebar to get started.")
                )
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
        default:
            ContentUnavailableView(
                "Tool Not Found",
                systemImage: "questionmark.circle",
                description: Text("Tool '\(id)' is not available.")
            )
        }
    }
}
