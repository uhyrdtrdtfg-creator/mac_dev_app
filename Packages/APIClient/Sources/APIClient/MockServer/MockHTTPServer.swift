import Foundation
import Network
import CCommonCryptoAPI

// MARK: - Models

public struct MockRoute: Identifiable, Sendable {
    public let id: UUID
    public var method: String
    public var path: String
    public var statusCode: Int
    public var responseBody: String
    public var contentType: String
    public var headers: [String: String]
    public var isSSE: Bool
    public var isWebSocket: Bool
    public var sseEvents: [SSEEvent]
    public var sseIntervalMs: Int
    public var wsEchoMode: Bool  // echo back received messages
    public var wsAutoMessages: [String]  // messages to send on connect

    public init(
        id: UUID = UUID(),
        method: String = "GET",
        path: String = "/",
        statusCode: Int = 200,
        responseBody: String = "{\"message\": \"ok\"}",
        contentType: String = "application/json",
        headers: [String: String] = [:],
        isSSE: Bool = false,
        isWebSocket: Bool = false,
        sseEvents: [SSEEvent] = [],
        sseIntervalMs: Int = 1000,
        wsEchoMode: Bool = true,
        wsAutoMessages: [String] = []
    ) {
        self.id = id
        self.method = method
        self.path = path
        self.statusCode = statusCode
        self.responseBody = responseBody
        self.contentType = contentType
        self.headers = headers
        self.isSSE = isSSE
        self.isWebSocket = isWebSocket
        self.sseEvents = sseEvents
        self.sseIntervalMs = sseIntervalMs
        self.wsEchoMode = wsEchoMode
        self.wsAutoMessages = wsAutoMessages
    }
}

public struct SSEEvent: Identifiable, Sendable {
    public let id: UUID
    public var eventType: String
    public var data: String

    public init(id: UUID = UUID(), eventType: String = "message", data: String = "{\"hello\": \"world\"}") {
        self.id = id
        self.eventType = eventType
        self.data = data
    }
}

public struct MockRequest: Identifiable, Sendable {
    public let id: UUID
    public let method: String
    public let path: String
    public let timestamp: Date
    public let matched: Bool
    public let responseStatus: Int?

    public init(
        id: UUID = UUID(),
        method: String,
        path: String,
        timestamp: Date = Date(),
        matched: Bool,
        responseStatus: Int? = nil
    ) {
        self.id = id
        self.method = method
        self.path = path
        self.timestamp = timestamp
        self.matched = matched
        self.responseStatus = responseStatus
    }
}

// MARK: - Server

@Observable
@MainActor
public final class MockHTTPServer {
    public static let shared = MockHTTPServer()

    public var isRunning = false
    public var port: UInt16 = 8080
    public var routes: [MockRoute] = [
        MockRoute(method: "GET", path: "/api/health", statusCode: 200, responseBody: "{\"status\": \"ok\"}", contentType: "application/json")
    ]
    public var requestLog: [MockRequest] = []
    public var errorMessage: String?

    private var listener: NWListener?
    private var activeConnections: [NWConnection] = []

    public init() {}

    public var baseURL: String {
        "http://localhost:\(port)"
    }

    public func start() {
        guard !isRunning else { return }
        errorMessage = nil

        do {
            let params = NWParameters.tcp
            let nwPort = NWEndpoint.Port(rawValue: port)!
            listener = try NWListener(using: params, on: nwPort)
        } catch {
            errorMessage = "Failed to create listener: \(error.localizedDescription)"
            return
        }

        listener?.stateUpdateHandler = { [weak self] state in
            Task { @MainActor [weak self] in
                guard let self else { return }
                switch state {
                case .ready:
                    self.isRunning = true
                    self.errorMessage = nil
                case .failed(let error):
                    self.errorMessage = "Listener failed: \(error.localizedDescription)"
                    self.isRunning = false
                case .cancelled:
                    self.isRunning = false
                default:
                    break
                }
            }
        }

        listener?.newConnectionHandler = { [weak self] connection in
            Task { @MainActor [weak self] in
                self?.handleConnection(connection)
            }
        }

        listener?.start(queue: .global(qos: .userInitiated))
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        for conn in activeConnections {
            conn.cancel()
        }
        activeConnections.removeAll()
        isRunning = false
    }

    public func clearLog() {
        requestLog.removeAll()
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        activeConnections.append(connection)

        connection.stateUpdateHandler = { [weak self] state in
            if case .cancelled = state {
                Task { @MainActor [weak self] in
                    self?.activeConnections.removeAll { $0 === connection }
                }
            }
        }

        connection.start(queue: .global(qos: .userInitiated))

        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, error in
            Task { @MainActor [weak self] in
                guard let self, let data else {
                    connection.cancel()
                    return
                }

                let requestString = String(data: data, encoding: .utf8) ?? ""
                let (method, path) = self.parseHTTPRequest(requestString)
                let matchedRoute = self.findRoute(method: method, path: path)

                self.requestLog.insert(
                    MockRequest(
                        method: method,
                        path: path,
                        matched: matchedRoute != nil,
                        responseStatus: matchedRoute?.statusCode ?? 404
                    ),
                    at: 0
                )

                // Limit log to 200 entries
                if self.requestLog.count > 200 {
                    self.requestLog = Array(self.requestLog.prefix(200))
                }

                if let route = matchedRoute {
                    if route.isWebSocket {
                        self.handleWebSocketUpgrade(connection: connection, route: route, rawRequest: requestString)
                    } else if route.isSSE {
                        self.sendSSEResponse(connection: connection, route: route)
                    } else {
                        self.sendHTTPResponse(connection: connection, route: route)
                    }
                } else {
                    self.send404(connection: connection, path: path)
                }
            }
        }
    }

    private func parseHTTPRequest(_ raw: String) -> (String, String) {
        let lines = raw.components(separatedBy: "\r\n")
        guard let requestLine = lines.first else { return ("GET", "/") }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2 else { return ("GET", "/") }
        return (String(parts[0]), String(parts[1]))
    }

    private func findRoute(method: String, path: String) -> MockRoute? {
        // Strip query string for matching
        let cleanPath = path.components(separatedBy: "?").first ?? path
        return routes.first { route in
            route.method.uppercased() == method.uppercased() && route.path == cleanPath
        }
    }

    // MARK: - Response Building

    private func sendHTTPResponse(connection: NWConnection, route: MockRoute) {
        let bodyData = Data(route.responseBody.utf8)

        var headerLines = [
            "HTTP/1.1 \(route.statusCode) \(httpStatusText(route.statusCode))",
            "Content-Type: \(route.contentType)",
            "Content-Length: \(bodyData.count)",
            "Access-Control-Allow-Origin: *",
            "Connection: close",
        ]

        for (key, value) in route.headers {
            headerLines.append("\(key): \(value)")
        }

        let responseString = headerLines.joined(separator: "\r\n") + "\r\n\r\n"
        var responseData = Data(responseString.utf8)
        responseData.append(bodyData)

        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func sendSSEResponse(connection: NWConnection, route: MockRoute) {
        let headerLines = [
            "HTTP/1.1 200 OK",
            "Content-Type: text/event-stream",
            "Cache-Control: no-cache",
            "Access-Control-Allow-Origin: *",
            "Connection: keep-alive",
        ]

        let headerString = headerLines.joined(separator: "\r\n") + "\r\n\r\n"
        let headerData = Data(headerString.utf8)

        connection.send(content: headerData, completion: .contentProcessed { error in
            guard error == nil else {
                connection.cancel()
                return
            }

            let events = route.sseEvents.isEmpty
                ? [SSEEvent(eventType: "message", data: route.responseBody)]
                : route.sseEvents
            let intervalMs = route.sseIntervalMs

            // Stream events
            Task {
                for event in events {
                    var eventString = ""
                    if !event.eventType.isEmpty {
                        eventString += "event: \(event.eventType)\n"
                    }
                    for line in event.data.components(separatedBy: "\n") {
                        eventString += "data: \(line)\n"
                    }
                    eventString += "\n"

                    let eventData = Data(eventString.utf8)
                    connection.send(content: eventData, completion: .contentProcessed { _ in })

                    try? await Task.sleep(for: .milliseconds(intervalMs))
                }
                // After all events, close connection
                connection.cancel()
            }
        })
    }

    // MARK: - WebSocket Server

    private func handleWebSocketUpgrade(connection: NWConnection, route: MockRoute, rawRequest: String) {
        // Extract Sec-WebSocket-Key from headers
        guard let keyLine = rawRequest.components(separatedBy: "\r\n").first(where: {
            $0.lowercased().hasPrefix("sec-websocket-key:")
        }) else {
            send404(connection: connection, path: route.path)
            return
        }
        let wsKey = keyLine.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)

        // Compute accept key: Base64(SHA1(key + magic))
        let magic = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
        let combined = wsKey + magic
        let sha1Data = insecureSHA1(Data(combined.utf8))
        let acceptKey = sha1Data.base64EncodedString()

        // Send upgrade response
        let upgradeResponse = [
            "HTTP/1.1 101 Switching Protocols",
            "Upgrade: websocket",
            "Connection: Upgrade",
            "Sec-WebSocket-Accept: \(acceptKey)",
        ].joined(separator: "\r\n") + "\r\n\r\n"

        connection.send(content: Data(upgradeResponse.utf8), completion: .contentProcessed { [weak self] error in
            guard error == nil else { connection.cancel(); return }

            Task { @MainActor [weak self] in
                guard let self else { return }

                // Send auto messages
                for msg in route.wsAutoMessages where !msg.isEmpty {
                    let frame = self.buildWebSocketFrame(text: msg)
                    connection.send(content: frame, completion: .contentProcessed { _ in })
                    try? await Task.sleep(for: .milliseconds(100))
                }

                // Listen for incoming frames
                self.receiveWebSocketFrame(connection: connection, route: route)
            }
        })
    }

    private func receiveWebSocketFrame(connection: NWConnection, route: MockRoute) {
        connection.receive(minimumIncompleteLength: 2, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            Task { @MainActor [weak self] in
                guard let self, let data, !data.isEmpty else {
                    connection.cancel()
                    return
                }

                if let text = self.parseWebSocketFrame(data) {
                    // Log received message
                    self.requestLog.insert(
                        MockRequest(method: "WS", path: "← \(text.prefix(80))", matched: true, responseStatus: nil),
                        at: 0
                    )

                    // Echo mode: send back the message
                    if route.wsEchoMode {
                        let echoText = route.responseBody.isEmpty ? text : route.responseBody.replacingOccurrences(of: "{{message}}", with: text)
                        let frame = self.buildWebSocketFrame(text: echoText)
                        connection.send(content: frame, completion: .contentProcessed { _ in })

                        self.requestLog.insert(
                            MockRequest(method: "WS", path: "→ \(echoText.prefix(80))", matched: true, responseStatus: nil),
                            at: 0
                        )
                    }
                }

                let opcode = data[0] & 0x0F

                // Ping frame (0x9) → reply with pong (0xA)
                if opcode == 0x9 {
                    var pongFrame = Data([0x8A]) // FIN + pong opcode
                    let payloadLen = data.count > 2 ? Int(data[1] & 0x7F) : 0
                    pongFrame.append(UInt8(min(payloadLen, 125)))
                    // Copy ping payload to pong if any (unmasked)
                    if payloadLen > 0 && data.count > 6 {
                        let maskStart = 2
                        let mask = Array(data[maskStart..<maskStart+4])
                        var payload = Array(data[(maskStart+4)..<min(maskStart+4+payloadLen, data.count)])
                        for i in 0..<payload.count { payload[i] ^= mask[i % 4] }
                        pongFrame.append(contentsOf: payload)
                    }
                    connection.send(content: pongFrame, completion: .contentProcessed { _ in })
                    self.receiveWebSocketFrame(connection: connection, route: route)
                    return
                }

                // Close frame (0x8)
                if opcode == 0x8 {
                    let closeFrame = Data([0x88, 0x00])
                    connection.send(content: closeFrame, completion: .contentProcessed { _ in
                        connection.cancel()
                    })
                    return
                }

                // Continue receiving
                self.receiveWebSocketFrame(connection: connection, route: route)
            }
        }
    }

    private func buildWebSocketFrame(text: String) -> Data {
        let payload = Data(text.utf8)
        var frame = Data()

        // FIN + text opcode
        frame.append(0x81)

        // Length (server frames are NOT masked)
        if payload.count < 126 {
            frame.append(UInt8(payload.count))
        } else if payload.count <= 65535 {
            frame.append(126)
            frame.append(UInt8((payload.count >> 8) & 0xFF))
            frame.append(UInt8(payload.count & 0xFF))
        } else {
            frame.append(127)
            for i in (0..<8).reversed() {
                frame.append(UInt8((payload.count >> (i * 8)) & 0xFF))
            }
        }

        frame.append(payload)
        return frame
    }

    private func parseWebSocketFrame(_ data: Data) -> String? {
        guard data.count >= 2 else { return nil }
        let opcode = data[0] & 0x0F
        guard opcode == 0x1 else { return nil } // text frame only

        let masked = (data[1] & 0x80) != 0
        var payloadLength = UInt64(data[1] & 0x7F)
        var offset = 2

        if payloadLength == 126 {
            guard data.count >= 4 else { return nil }
            payloadLength = UInt64(data[2]) << 8 | UInt64(data[3])
            offset = 4
        } else if payloadLength == 127 {
            guard data.count >= 10 else { return nil }
            payloadLength = 0
            for i in 0..<8 {
                payloadLength |= UInt64(data[2 + i]) << UInt64((7 - i) * 8)
            }
            offset = 10
        }

        var maskKey: [UInt8] = []
        if masked {
            guard data.count >= offset + 4 else { return nil }
            maskKey = [data[offset], data[offset+1], data[offset+2], data[offset+3]]
            offset += 4
        }

        let end = min(offset + Int(payloadLength), data.count)
        guard end <= data.count else { return nil }
        var payload = Array(data[offset..<end])

        if masked {
            for i in 0..<payload.count {
                payload[i] ^= maskKey[i % 4]
            }
        }

        return String(bytes: payload, encoding: .utf8)
    }

    private func insecureSHA1(_ data: Data) -> Data {
        // Simple SHA-1 using CommonCrypto via CC_SHA1
        var hash = [UInt8](repeating: 0, count: 20)
        data.withUnsafeBytes { ptr in
            _ = CC_SHA1(ptr.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash)
    }

    private func send404(connection: NWConnection, path: String) {
        let body = "{\"error\": \"Not Found\", \"path\": \"\(path)\"}"
        let bodyData = Data(body.utf8)
        let response = [
            "HTTP/1.1 404 Not Found",
            "Content-Type: application/json",
            "Content-Length: \(bodyData.count)",
            "Access-Control-Allow-Origin: *",
            "Connection: close",
        ].joined(separator: "\r\n") + "\r\n\r\n"

        var responseData = Data(response.utf8)
        responseData.append(bodyData)

        connection.send(content: responseData, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func httpStatusText(_ code: Int) -> String {
        switch code {
        case 200: "OK"
        case 201: "Created"
        case 204: "No Content"
        case 301: "Moved Permanently"
        case 302: "Found"
        case 304: "Not Modified"
        case 400: "Bad Request"
        case 401: "Unauthorized"
        case 403: "Forbidden"
        case 404: "Not Found"
        case 405: "Method Not Allowed"
        case 409: "Conflict"
        case 422: "Unprocessable Entity"
        case 429: "Too Many Requests"
        case 500: "Internal Server Error"
        case 502: "Bad Gateway"
        case 503: "Service Unavailable"
        default: "OK"
        }
    }
}
