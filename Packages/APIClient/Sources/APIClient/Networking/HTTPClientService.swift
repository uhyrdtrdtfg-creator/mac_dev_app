import Foundation

public enum HTTPClientError: Error, LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case noResponse

    public var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL"
        case .requestFailed(let e): "Request failed: \(e.localizedDescription)"
        case .noResponse: "No response received"
        }
    }
}

public struct HTTPResponse: Sendable, Equatable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data
    public let duration: TimeInterval
    public let bodySize: Int
    public let cookies: [String]
}

public enum HTTPClientService {
    /// Enable debug logging - can be toggled at runtime
    public nonisolated(unsafe) static var debugEnabled: Bool = false

    /// Custom URLSession configured for compatibility with various servers
    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        // Configure for better compatibility
        config.httpAdditionalHeaders = ["Connection": "keep-alive"]
        config.httpShouldUsePipelining = false
        config.httpMaximumConnectionsPerHost = 1
        return URLSession(configuration: config)
    }()

    public static func buildURLRequest(method: HTTPMethod, url: String, headers: [KeyValuePair], queryParams: [KeyValuePair], body: RequestBody?, auth: AuthType?) throws -> URLRequest {
        guard var components = URLComponents(string: url), !url.isEmpty else { throw HTTPClientError.invalidURL }

        let enabledParams = queryParams.filter { $0.isEnabled && !$0.key.isEmpty }
        if !enabledParams.isEmpty {
            var items = components.queryItems ?? []
            items.append(contentsOf: enabledParams.map { URLQueryItem(name: $0.key, value: $0.value) })
            components.queryItems = items
        }

        guard let finalURL = components.url else { throw HTTPClientError.invalidURL }
        var request = URLRequest(url: finalURL)
        request.httpMethod = method.rawValue

        for header in headers where header.isEnabled && !header.key.isEmpty {
            request.setValue(header.value, forHTTPHeaderField: header.key)
        }

        if let body {
            switch body {
            case .json(let json):
                request.httpBody = Data(json.utf8)
                if request.value(forHTTPHeaderField: "Content-Type") == nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
            case .formData(let pairs):
                let encoded = pairs.filter(\.isEnabled).map { "\($0.key)=\($0.value)" }.joined(separator: "&")
                request.httpBody = Data(encoded.utf8)
                if request.value(forHTTPHeaderField: "Content-Type") == nil { request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type") }
            case .raw(let text): request.httpBody = Data(text.utf8)
            case .binary(let data): request.httpBody = data
            }
        }

        if let auth {
            switch auth {
            case .bearerToken(let token):
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            case .basicAuth(let username, let password):
                let credentials = Data("\(username):\(password)".utf8).base64EncodedString()
                request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
            case .apiKey(let key, let value, let addTo):
                switch addTo {
                case .header: request.setValue(value, forHTTPHeaderField: key)
                case .queryParam:
                    if var comps = URLComponents(url: finalURL, resolvingAgainstBaseURL: false) {
                        var items = comps.queryItems ?? []; items.append(URLQueryItem(name: key, value: value)); comps.queryItems = items
                        if let newURL = comps.url { request.url = newURL }
                    }
                }
            }
        }

        return request
    }

    private static func log(_ message: String, _ args: CVarArg...) {
        guard debugEnabled else { return }
        withVaList(args) { NSLogv("[HTTPClient] " + message, $0) }
    }

    public static func send(_ request: URLRequest) async throws -> HTTPResponse {
        // Debug logging (only when enabled)
        log("URL: %@", request.url?.absoluteString ?? "nil")
        log("Method: %@", request.httpMethod ?? "nil")
        log("Headers: %@", String(describing: request.allHTTPHeaderFields ?? [:]))
        if let body = request.httpBody {
            log("Body size: %d bytes", body.count)
            if let bodyStr = String(data: body, encoding: .utf8) {
                log("Body: %@", bodyStr)
            }
        } else {
            log("No body")
        }

        var mutableRequest = request
        mutableRequest.httpShouldUsePipelining = false

        // Use download task to avoid "resource exceeds maximum size" error
        let start = Date()
        let isDebug = debugEnabled
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.downloadTask(with: mutableRequest) { localURL, response, error in
                let duration = Date().timeIntervalSince(start)

                if let error = error {
                    if isDebug { NSLog("[HTTPClient] Download error: %@", String(describing: error)) }
                    continuation.resume(throwing: error)
                    return
                }

                guard let httpResponse = response as? HTTPURLResponse else {
                    continuation.resume(throwing: HTTPClientError.noResponse)
                    return
                }

                if isDebug { NSLog("[HTTPClient] Response status: %d", httpResponse.statusCode) }

                var data = Data()
                if let localURL = localURL {
                    do {
                        data = try Data(contentsOf: localURL)
                    } catch {
                        if isDebug { NSLog("[HTTPClient] Failed to read downloaded file: %@", String(describing: error)) }
                    }
                }

                let headers: [String: String] = Dictionary(uniqueKeysWithValues: httpResponse.allHeaderFields.compactMap { key, value -> (String, String)? in
                    guard let k = key as? String, let v = value as? String else { return nil }; return (k, v)
                })
                let cookies = (headers["Set-Cookie"] ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

                let result = HTTPResponse(statusCode: httpResponse.statusCode, headers: headers, body: data, duration: duration, bodySize: data.count, cookies: cookies)
                continuation.resume(returning: result)
            }
            task.resume()
        }
    }
}
