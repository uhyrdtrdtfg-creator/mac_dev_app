import Foundation

public enum ConnectionProtocol: String, CaseIterable, Identifiable, Sendable {
    case webSocket = "WebSocket"
    case sse = "SSE"
    public var id: String { rawValue }
}

public enum ConnectionState: Sendable, Equatable {
    case disconnected
    case connecting
    case connected
    case error(String)

    public static func == (lhs: ConnectionState, rhs: ConnectionState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected): true
        case (.connecting, .connecting): true
        case (.connected, .connected): true
        case (.error(let a), .error(let b)): a == b
        default: false
        }
    }

    public var isConnected: Bool {
        if case .connected = self { return true }
        return false
    }

    public var label: String {
        switch self {
        case .disconnected: "Disconnected"
        case .connecting: "Connecting..."
        case .connected: "Connected"
        case .error(let msg): "Error: \(msg)"
        }
    }

    public var color: String {
        switch self {
        case .disconnected: "secondary"
        case .connecting: "orange"
        case .connected: "green"
        case .error: "red"
        }
    }
}

public struct WSMessage: Identifiable, Sendable {
    public let id = UUID()
    public let text: String
    public let isOutgoing: Bool
    public let timestamp: Date
    public let eventType: String?

    public init(text: String, isOutgoing: Bool, timestamp: Date, eventType: String?) {
        self.text = text
        self.isOutgoing = isOutgoing
        self.timestamp = timestamp
        self.eventType = eventType
    }
}

@Observable
@MainActor
public final class WebSocketClient {
    public var state: ConnectionState = .disconnected
    public var messages: [WSMessage] = []

    private var webSocketTask: URLSessionWebSocketTask?
    private var sseStreamTask: Task<Void, Never>?

    public init() {}

    // MARK: - WebSocket

    public func connectWebSocket(to urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            state = .error("Invalid URL")
            return
        }
        disconnect()
        state = .connecting
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        // Verify connection with ping, then start receiving
        webSocketTask?.sendPing { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    self.state = .error(error.localizedDescription)
                } else {
                    self.state = .connected
                    self.startReceivingWebSocket()
                }
            }
        }
    }

    private func startReceivingWebSocket() {
        guard let task = webSocketTask else { return }
        task.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch result {
                case .success(let message):
                    switch message {
                    case .string(let text):
                        self.messages.append(WSMessage(text: text, isOutgoing: false, timestamp: Date(), eventType: nil))
                    case .data(let data):
                        let text = String(data: data, encoding: .utf8) ?? "(binary: \(data.count) bytes)"
                        self.messages.append(WSMessage(text: text, isOutgoing: false, timestamp: Date(), eventType: nil))
                    @unknown default:
                        break
                    }
                    self.startReceivingWebSocket()
                case .failure(let error):
                    if self.state.isConnected {
                        self.state = .error(error.localizedDescription)
                    }
                }
            }
        }
    }

    public func sendWebSocket(_ text: String) {
        guard state.isConnected else { return }
        let message = URLSessionWebSocketTask.Message.string(text)
        webSocketTask?.send(message) { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }
                if let error {
                    self.state = .error(error.localizedDescription)
                } else {
                    self.messages.append(WSMessage(text: text, isOutgoing: true, timestamp: Date(), eventType: nil))
                }
            }
        }
    }

    // MARK: - SSE

    public func connectSSE(to urlString: String) {
        let trimmed = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed) else {
            state = .error("Invalid URL")
            return
        }
        disconnect()
        state = .connecting

        var request = URLRequest(url: url)
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        sseStreamTask = Task { [weak self] in
            do {
                let (bytes, response) = try await URLSession.shared.bytes(for: request)
                guard let httpResponse = response as? HTTPURLResponse else {
                    await MainActor.run {
                        self?.state = .error("Invalid response")
                    }
                    return
                }
                guard httpResponse.statusCode == 200 else {
                    await MainActor.run {
                        self?.state = .error("HTTP \(httpResponse.statusCode)")
                    }
                    return
                }
                await MainActor.run {
                    self?.state = .connected
                }

                var eventType = ""
                var data = ""
                var eventId = ""

                for try await line in bytes.lines {
                    if Task.isCancelled { break }

                    if line.hasPrefix("event:") {
                        eventType = String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
                    } else if line.hasPrefix("data:") {
                        let d = String(line.dropFirst(5)).trimmingCharacters(in: .whitespaces)
                        data += data.isEmpty ? d : "\n" + d
                    } else if line.hasPrefix("id:") {
                        eventId = String(line.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                    } else if line.isEmpty && !data.isEmpty {
                        let display: String
                        if !eventType.isEmpty && !eventId.isEmpty {
                            display = "[\(eventType) #\(eventId)] \(data)"
                        } else if !eventType.isEmpty {
                            display = "[\(eventType)] \(data)"
                        } else if !eventId.isEmpty {
                            display = "[#\(eventId)] \(data)"
                        } else {
                            display = data
                        }
                        let type = eventType.isEmpty ? nil : eventType
                        await MainActor.run {
                            self?.messages.append(WSMessage(text: display, isOutgoing: false, timestamp: Date(), eventType: type))
                        }
                        eventType = ""
                        data = ""
                        eventId = ""
                    }
                }
            } catch {
                if !Task.isCancelled {
                    await MainActor.run {
                        if self?.state != .disconnected {
                            self?.state = .error(error.localizedDescription)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Common

    public func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        sseStreamTask?.cancel()
        sseStreamTask = nil
        if state != .disconnected {
            state = .disconnected
        }
    }

    public func clearMessages() {
        messages.removeAll()
    }
}
