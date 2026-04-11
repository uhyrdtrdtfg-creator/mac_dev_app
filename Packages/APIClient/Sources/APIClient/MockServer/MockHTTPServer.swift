import Foundation
import Network

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
    public var sseEvents: [SSEEvent]
    public var sseIntervalMs: Int

    public init(
        id: UUID = UUID(),
        method: String = "GET",
        path: String = "/",
        statusCode: Int = 200,
        responseBody: String = "{\"message\": \"ok\"}",
        contentType: String = "application/json",
        headers: [String: String] = [:],
        isSSE: Bool = false,
        sseEvents: [SSEEvent] = [],
        sseIntervalMs: Int = 1000
    ) {
        self.id = id
        self.method = method
        self.path = path
        self.statusCode = statusCode
        self.responseBody = responseBody
        self.contentType = contentType
        self.headers = headers
        self.isSSE = isSSE
        self.sseEvents = sseEvents
        self.sseIntervalMs = sseIntervalMs
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
                    if route.isSSE {
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
