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
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            registerAllTools()
        }
    }

    private func registerAllTools() {
        // Tools will be registered as they are implemented.
    }

    @ViewBuilder
    private func toolView(for id: String) -> some View {
        ContentUnavailableView(
            "Tool Not Found",
            systemImage: "questionmark.circle",
            description: Text("Tool '\(id)' is not yet implemented.")
        )
    }
}
