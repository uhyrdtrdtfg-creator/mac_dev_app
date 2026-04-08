import SwiftUI
import DevAppCore

struct ContentView: View {
    var body: some View {
        NavigationSplitView {
            Text("Sidebar")
        } detail: {
            Text("Select a tool")
        }
        .frame(minWidth: 800, minHeight: 600)
    }
}
