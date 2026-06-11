import Foundation
import Network

/// Minimal loopback HTTP listener for the OAuth authorization-code redirect.
/// Handles exactly one GET to /callback, validates state, replies with a tiny
/// HTML page, then shuts down.
public actor OAuthCallbackServer {
    public let port: UInt16
    public let expectedState: String

    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private var continuation: CheckedContinuation<String, Error>?
    private var startContinuation: CheckedContinuation<Void, Error>?
    private var pendingResult: Result<String, Error>?
    private var finished = false

    public init(port: UInt16, expectedState: String) {
        self.port = port
        self.expectedState = expectedState
    }

    public func start() async throws {
        guard listener == nil else { return }
        let params = NWParameters.tcp
        params.requiredLocalEndpoint = NWEndpoint.hostPort(host: .ipv4(.loopback), port: NWEndpoint.Port(rawValue: port)!)
        let listener = try NWListener(using: params)
        self.listener = listener

        listener.stateUpdateHandler = { [weak self] state in
            Task { await self?.handleListenerState(state) }
        }
        listener.newConnectionHandler = { [weak self] connection in
            Task { await self?.accept(connection) }
        }
        listener.start(queue: .global(qos: .userInitiated))

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            startContinuation = cont
        }
    }

    /// Awaits the single validated authorization code. Cancellation-aware.
    public func waitForCode() async throws -> String {
        if let result = pendingResult {
            pendingResult = nil
            return try result.get()
        }
        if finished { throw CancellationError() }
        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { cont in
                if let result = pendingResult {
                    pendingResult = nil
                    cont.resume(with: result)
                } else if finished {
                    cont.resume(throwing: CancellationError())
                } else {
                    continuation = cont
                }
            }
        } onCancel: {
            Task { await self.cancelWait() }
        }
    }

    public func stop() {
        finished = true
        continuation?.resume(throwing: CancellationError())
        continuation = nil
        shutdown()
    }

    // MARK: - Internals

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            startContinuation?.resume()
            startContinuation = nil
        case .failed(let error):
            startContinuation?.resume(throwing: OAuth2Error.callbackServerFailed(error.localizedDescription))
            startContinuation = nil
            finish(.failure(OAuth2Error.callbackServerFailed(error.localizedDescription)))
        case .cancelled:
            startContinuation?.resume(throwing: CancellationError())
            startContinuation = nil
        default:
            break
        }
    }

    private func accept(_ connection: NWConnection) {
        guard !finished else { connection.cancel(); return }
        connections.append(connection)
        connection.start(queue: .global(qos: .userInitiated))
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, _, _ in
            Task { await self?.handleRequest(data: data, on: connection) }
        }
    }

    private func handleRequest(data: Data?, on connection: NWConnection) {
        guard !finished else { connection.cancel(); return }
        guard let data, !data.isEmpty,
              let head = String(data: data, encoding: .utf8),
              let requestLine = head.components(separatedBy: "\r\n").first else {
            connection.cancel()
            return
        }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" else { connection.cancel(); return }
        let target = String(parts[1])
        guard target == "/callback" || target.hasPrefix("/callback?"),
              let url = URL(string: "http://127.0.0.1:\(port)\(target)") else {
            respond(connection, status: "404 Not Found", html: Self.page(title: "Not Found", message: "Unknown path."), thenFinish: nil)
            return
        }
        do {
            let code = try OAuth2Service.parseCallbackURL(url, expectedState: expectedState)
            respond(connection, status: "200 OK", html: Self.page(title: "Authorization complete", message: "You can close this window and return to DevToolkit."), thenFinish: .success(code))
        } catch {
            let reason = (error as? OAuth2Error)?.errorDescription ?? error.localizedDescription
            respond(connection, status: "400 Bad Request", html: Self.page(title: "Authorization failed", message: htmlEscape(reason)), thenFinish: .failure(error))
        }
    }

    private func respond(_ connection: NWConnection, status: String, html: String, thenFinish result: Result<String, Error>?) {
        let body = Data(html.utf8)
        let header = "HTTP/1.1 \(status)\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n"
        var response = Data(header.utf8)
        response.append(body)
        connection.send(content: response, completion: .contentProcessed { [weak self] _ in
            connection.cancel()
            if let result {
                Task { await self?.finish(result) }
            }
        })
    }

    private func finish(_ result: Result<String, Error>) {
        guard !finished else { return }
        finished = true
        if let continuation {
            continuation.resume(with: result)
            self.continuation = nil
        } else {
            pendingResult = result
        }
        shutdown()
    }

    private func cancelWait() {
        guard !finished else { return }
        finished = true
        continuation?.resume(throwing: CancellationError())
        continuation = nil
        shutdown()
    }

    private func shutdown() {
        listener?.cancel()
        listener = nil
        for connection in connections { connection.cancel() }
        connections.removeAll()
    }

    private func htmlEscape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }

    private static func page(title: String, message: String) -> String {
        "<!doctype html><html><head><meta charset=\"utf-8\"><title>DevToolkit</title></head><body style=\"font-family:-apple-system,sans-serif;text-align:center;padding-top:80px\"><h2>\(title)</h2><p>\(message)</p></body></html>"
    }
}
