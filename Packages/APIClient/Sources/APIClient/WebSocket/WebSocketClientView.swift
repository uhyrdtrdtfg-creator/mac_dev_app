import SwiftUI
import DevAppCore

public struct WebSocketClientView: View {
    @State private var client = WebSocketClient()
    @State private var urlString = "wss://echo.websocket.org"
    @State private var selectedProtocol: ConnectionProtocol = .webSocket
    @State private var messageText = ""
    @State private var autoScroll = true

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Connection bar
            connectionBar
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()

            // Message area
            messageArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Input bar (WebSocket only)
            if selectedProtocol == .webSocket && client.state.isConnected {
                Divider()
                sendBar
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Connection Bar

    private var connectionBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                // Protocol picker
                Picker("Protocol", selection: $selectedProtocol) {
                    ForEach(ConnectionProtocol.allCases) { proto in
                        Text(proto.rawValue).tag(proto)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 180)
                .disabled(client.state.isConnected || client.state == .connecting)

                // URL field
                TextField(selectedProtocol == .webSocket ? "wss://..." : "https://...", text: $urlString)
                    .textFieldStyle(.roundedBorder)
                    .disabled(client.state.isConnected || client.state == .connecting)
                    .onSubmit { connect() }

                // Connect / Disconnect
                if client.state.isConnected || client.state == .connecting {
                    Button("Disconnect") {
                        client.disconnect()
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                } else {
                    Button("Connect") {
                        connect()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            // Status + controls row
            HStack(spacing: 8) {
                statusIndicator

                Spacer()

                Text("\(client.messages.count) messages")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.checkbox)
                    .font(.caption)

                Button {
                    client.clearMessages()
                } label: {
                    Label("Clear", systemImage: "trash")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private var statusIndicator: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(client.state.label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var statusColor: Color {
        switch client.state {
        case .disconnected: .secondary
        case .connecting: .orange
        case .connected: .green
        case .error: .red
        }
    }

    // MARK: - Message Area

    private var messageArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    if client.messages.isEmpty {
                        emptyState
                    } else {
                        ForEach(client.messages) { msg in
                            messageRow(msg)
                                .id(msg.id)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .onChange(of: client.messages.count) {
                if autoScroll, let last = client.messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(last.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer(minLength: 60)
            Image(systemName: selectedProtocol == .webSocket ? "bolt.horizontal" : "antenna.radiowaves.left.and.right")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text(client.state.isConnected
                 ? (selectedProtocol == .webSocket ? "Connected. Send a message below." : "Connected. Waiting for events...")
                 : "Enter a URL and connect to start")
                .font(.callout)
                .foregroundStyle(.tertiary)
            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity)
    }

    private func messageRow(_ msg: WSMessage) -> some View {
        HStack(alignment: .top, spacing: 8) {
            // Direction indicator
            Image(systemName: msg.isOutgoing ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                .foregroundStyle(msg.isOutgoing ? .blue : .green)
                .font(.caption)
                .padding(.top, 3)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(msg.isOutgoing ? "Sent" : "Received")
                        .font(.caption2)
                        .fontWeight(.medium)
                        .foregroundStyle(msg.isOutgoing ? .blue : .green)

                    if let eventType = msg.eventType {
                        Text(eventType)
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(.purple.opacity(0.15))
                            .clipShape(Capsule())
                            .foregroundStyle(.purple)
                    }

                    Text(msg.timestamp, format: .dateTime.hour().minute().second().secondFraction(.fractional(3)))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                Text(msg.text)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Spacer(minLength: 0)

            CopyButton(text: msg.text)
                .controlSize(.mini)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(msg.isOutgoing ? Color.blue.opacity(0.04) : Color.green.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Send Bar

    private var sendBar: some View {
        HStack(spacing: 8) {
            TextField("Type a message...", text: $messageText)
                .textFieldStyle(.roundedBorder)
                .onSubmit { sendMessage() }

            Button {
                sendMessage()
            } label: {
                Image(systemName: "paperplane.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    // MARK: - Actions

    private func connect() {
        switch selectedProtocol {
        case .webSocket:
            client.connectWebSocket(to: urlString)
        case .sse:
            client.connectSSE(to: urlString)
        }
    }

    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        client.sendWebSocket(text)
        messageText = ""
    }
}

extension WebSocketClientView {
    public static let descriptor = ToolDescriptor(
        id: "websocket-sse",
        name: "WebSocket / SSE",
        icon: "bolt.horizontal",
        category: .apiClient,
        searchKeywords: ["websocket", "sse", "realtime", "stream", "event", "push"]
    )
}
