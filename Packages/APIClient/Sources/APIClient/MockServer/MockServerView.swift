import SwiftUI
import DevAppCore

public struct MockServerView: View {
    @State private var server = MockHTTPServer.shared
    @State private var showAddRoute = false
    @State private var editingRoute: MockRoute?

    public init() {}

    public var body: some View {
        HSplitView {
            // Left: Routes + Controls
            VStack(spacing: 0) {
                serverControls
                    .padding(12)

                Divider()

                routeList
            }
            .frame(minWidth: 400, idealWidth: 500)

            // Right: Request Log
            VStack(spacing: 0) {
                logHeader
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)

                Divider()

                requestLogView
            }
            .frame(minWidth: 300, idealWidth: 400)
        }
        .sheet(isPresented: $showAddRoute) {
            RouteEditorSheet(route: nil) { newRoute in
                server.routes.append(newRoute)
            }
        }
        .sheet(item: $editingRoute) { route in
            RouteEditorSheet(route: route) { updated in
                if let idx = server.routes.firstIndex(where: { $0.id == updated.id }) {
                    server.routes[idx] = updated
                }
            }
        }
    }

    // MARK: - Server Controls

    private var serverControls: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(server.isRunning ? .green : .secondary)
                        .frame(width: 8, height: 8)
                    Text(server.isRunning ? "Running" : "Stopped")
                        .font(.caption)
                        .foregroundStyle(server.isRunning ? .primary : .secondary)
                }

                Spacer()

                HStack(spacing: 4) {
                    Text("Port:")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Port", value: $server.port, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 70)
                        .disabled(server.isRunning)
                }

                if server.isRunning {
                    Button("Stop") {
                        server.stop()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button("Start") {
                        server.start()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }

            if server.isRunning {
                HStack(spacing: 8) {
                    Text(server.baseURL)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    CopyButton(text: server.baseURL)
                    Spacer()
                }
            }

            if let error = server.errorMessage {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                        .font(.caption)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                    Spacer()
                }
            }
        }
    }

    // MARK: - Route List

    private var routeList: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Routes")
                    .font(.headline)
                Spacer()
                Button {
                    showAddRoute = true
                } label: {
                    Label("Add Route", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            if server.routes.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "point.topleft.down.to.point.bottomright.curvepath")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("No routes configured")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                    Text("Add a route to get started")
                        .font(.caption)
                        .foregroundStyle(.quaternary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(server.routes) { route in
                            routeRow(route)
                        }
                    }
                    .padding(8)
                }
            }
        }
    }

    private func routeRow(_ route: MockRoute) -> some View {
        HStack(spacing: 8) {
            Text(route.method)
                .font(.system(.caption, design: .monospaced))
                .fontWeight(.bold)
                .foregroundStyle(methodColor(route.method))
                .frame(width: 50, alignment: .leading)

            Text(route.path)
                .font(.system(.caption, design: .monospaced))
                .lineLimit(1)

            if route.isSSE {
                Text("SSE")
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.purple.opacity(0.15))
                    .clipShape(Capsule())
                    .foregroundStyle(.purple)
            }

            Spacer()

            Text("\(route.statusCode)")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(statusColor(route.statusCode))

            Button {
                editingRoute = route
            } label: {
                Image(systemName: "pencil")
                    .font(.caption2)
            }
            .buttonStyle(.borderless)

            Button {
                server.routes.removeAll { $0.id == route.id }
            } label: {
                Image(systemName: "trash")
                    .font(.caption2)
                    .foregroundStyle(.red)
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.secondary.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func methodColor(_ method: String) -> Color {
        switch method.uppercased() {
        case "GET": .green
        case "POST": .blue
        case "PUT": .orange
        case "PATCH": .yellow
        case "DELETE": .red
        default: .secondary
        }
    }

    private func statusColor(_ code: Int) -> Color {
        switch code {
        case 200..<300: .green
        case 300..<400: .blue
        case 400..<500: .orange
        case 500..<600: .red
        default: .secondary
        }
    }

    // MARK: - Log Header

    private var logHeader: some View {
        HStack {
            Text("Request Log")
                .font(.headline)
            Spacer()
            Text("\(server.requestLog.count)")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button {
                server.clearLog()
            } label: {
                Label("Clear", systemImage: "trash")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    // MARK: - Request Log

    private var requestLogView: some View {
        Group {
            if server.requestLog.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text(server.isRunning ? "Waiting for requests..." : "Start the server to receive requests")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(server.requestLog) { req in
                            requestRow(req)
                        }
                    }
                    .padding(8)
                }
            }
        }
    }

    private func requestRow(_ req: MockRequest) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(req.matched ? .green : .orange)
                .frame(width: 6, height: 6)

            Text(req.method)
                .font(.system(.caption2, design: .monospaced))
                .fontWeight(.bold)
                .foregroundStyle(methodColor(req.method))
                .frame(width: 44, alignment: .leading)

            Text(req.path)
                .font(.system(.caption2, design: .monospaced))
                .lineLimit(1)

            Spacer()

            if let status = req.responseStatus {
                Text("\(status)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(statusColor(status))
            }

            Text(req.timestamp, format: .dateTime.hour().minute().second())
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(req.matched ? Color.clear : Color.orange.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - Route Editor Sheet

struct RouteEditorSheet: View {
    let existingRoute: MockRoute?
    let onSave: (MockRoute) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var method = "GET"
    @State private var path = "/"
    @State private var statusCode = 200
    @State private var responseBody = "{\"message\": \"ok\"}"
    @State private var contentType = "application/json"
    @State private var isSSE = false
    @State private var isWebSocket = false
    @State private var wsEchoMode = true
    @State private var wsAutoMessages: [String] = []
    @State private var sseEvents: [SSEEvent] = []
    @State private var sseIntervalMs = 1000

    private let methods = ["GET", "POST", "PUT", "PATCH", "DELETE", "HEAD", "OPTIONS"]

    init(route: MockRoute?, onSave: @escaping (MockRoute) -> Void) {
        self.existingRoute = route
        self.onSave = onSave
    }

    var body: some View {
        VStack(spacing: 0) {
            // Title
            HStack {
                Text(existingRoute == nil ? "Add Route" : "Edit Route")
                    .font(.headline)
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                Button("Save") { save() }
                    .buttonStyle(.borderedProminent)
                    .disabled(path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Method + Path
                    HStack(spacing: 8) {
                        Picker("Method", selection: $method) {
                            ForEach(methods, id: \.self) { m in
                                Text(m).tag(m)
                            }
                        }
                        .frame(width: 120)

                        TextField("/path", text: $path)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Status Code
                    HStack {
                        Text("Status Code:")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        TextField("200", value: $statusCode, format: .number)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 80)
                    }

                    // Endpoint type
                    HStack(spacing: 16) {
                        Toggle("SSE", isOn: $isSSE)
                            .toggleStyle(.checkbox)
                            .font(.caption)
                            .onChange(of: isSSE) { _, on in if on { isWebSocket = false } }
                        Toggle("WebSocket", isOn: $isWebSocket)
                            .toggleStyle(.checkbox)
                            .font(.caption)
                            .onChange(of: isWebSocket) { _, on in if on { isSSE = false } }
                    }

                    if isWebSocket {
                        wsConfigSection
                    } else if isSSE {
                        sseConfigSection
                    } else {
                        regularResponseSection
                    }
                }
                .padding()
            }
        }
        .frame(width: 550, height: 500)
        .onAppear {
            if let route = existingRoute {
                method = route.method
                path = route.path
                statusCode = route.statusCode
                responseBody = route.responseBody
                contentType = route.contentType
                isSSE = route.isSSE
                isWebSocket = route.isWebSocket
                wsEchoMode = route.wsEchoMode
                wsAutoMessages = route.wsAutoMessages
                sseEvents = route.sseEvents
                sseIntervalMs = route.sseIntervalMs
            }
        }
    }

    private var regularResponseSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Content-Type:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("application/json", text: $contentType)
                    .textFieldStyle(.roundedBorder)
            }

            Text("Response Body:")
                .font(.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $responseBody)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 150)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))
        }
    }

    private var sseConfigSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Event Interval (ms):")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("1000", value: $sseIntervalMs, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 80)
            }

            HStack {
                Text("SSE Events:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    sseEvents.append(SSEEvent())
                } label: {
                    Label("Add Event", systemImage: "plus")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            if sseEvents.isEmpty {
                Text("No events configured. The response body will be used as a single event.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.vertical, 4)

                Text("Response Body (fallback):")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextEditor(text: $responseBody)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))
            } else {
                ForEach($sseEvents) { $event in
                    HStack(alignment: .top, spacing: 8) {
                        VStack(alignment: .leading, spacing: 4) {
                            TextField("Event type", text: $event.eventType)
                                .textFieldStyle(.roundedBorder)
                                .font(.caption)
                            TextField("Data", text: $event.data)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(.caption, design: .monospaced))
                        }
                        Button {
                            sseEvents.removeAll { $0.id == event.id }
                        } label: {
                            Image(systemName: "trash")
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.borderless)
                    }
                    .padding(6)
                    .background(Color.secondary.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private var wsConfigSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Echo Mode (reply received messages)", isOn: $wsEchoMode)
                .font(.caption)

            Text("Echo Response Template (use {{message}} for received text):")
                .font(.caption)
                .foregroundStyle(.secondary)
            TextEditor(text: $responseBody)
                .font(.system(.body, design: .monospaced))
                .frame(minHeight: 60)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(.separator, lineWidth: 0.5))

            HStack {
                Text("Auto-send on connect:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    wsAutoMessages.append("{\"type\": \"welcome\"}")
                } label: {
                    Label("Add", systemImage: "plus").font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            ForEach(Array(wsAutoMessages.enumerated()), id: \.offset) { idx, _ in
                HStack {
                    TextField("Message", text: Binding(
                        get: { wsAutoMessages.indices.contains(idx) ? wsAutoMessages[idx] : "" },
                        set: { if wsAutoMessages.indices.contains(idx) { wsAutoMessages[idx] = $0 } }
                    ))
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))
                    Button {
                        if wsAutoMessages.indices.contains(idx) { wsAutoMessages.remove(at: idx) }
                    } label: {
                        Image(systemName: "trash").font(.caption).foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
    }

    private func save() {
        let route = MockRoute(
            id: existingRoute?.id ?? UUID(),
            method: method,
            path: path,
            statusCode: statusCode,
            responseBody: responseBody,
            contentType: contentType,
            headers: existingRoute?.headers ?? [:],
            isSSE: isSSE,
            isWebSocket: isWebSocket,
            sseEvents: sseEvents,
            sseIntervalMs: sseIntervalMs,
            wsEchoMode: wsEchoMode,
            wsAutoMessages: wsAutoMessages
        )
        onSave(route)
        dismiss()
    }
}

extension MockServerView {
    public static let descriptor = ToolDescriptor(
        id: "mock-server",
        name: "Mock Server",
        icon: "server.rack",
        category: .apiClient,
        searchKeywords: ["mock", "server", "local", "fake", "endpoint"]
    )
}
