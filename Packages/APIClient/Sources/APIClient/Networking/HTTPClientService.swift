import Foundation

public enum HTTPClientError: Error, LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case noResponse
    case invalidGraphQLVariables(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL"
        case .requestFailed(let e): "Request failed: \(e.localizedDescription)"
        case .noResponse: "No response received"
        case .invalidGraphQLVariables(let detail): "Invalid GraphQL variables: \(detail)"
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
    public let timing: TimingBreakdown?

    public init(statusCode: Int, headers: [String: String], body: Data, duration: TimeInterval, bodySize: Int, cookies: [String], timing: TimingBreakdown? = nil) {
        self.statusCode = statusCode; self.headers = headers; self.body = body
        self.duration = duration; self.bodySize = bodySize; self.cookies = cookies
        self.timing = timing
    }
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
            case .multipart(let parts): try MultipartEncoder.apply(parts: parts, to: &request)
            case .graphql(let query, let variables):
                do { request.httpBody = try GraphQLEnvelope.build(query: query, variables: variables) }
                catch { throw HTTPClientError.invalidGraphQLVariables(error.localizedDescription) }
                if request.value(forHTTPHeaderField: "Content-Type") == nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
            }
        }

        if let auth {
            switch auth {
            case .bearerToken(let token):
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            case .basicAuth(let username, let password):
                let credentials = Data("\(username):\(password)".utf8).base64EncodedString()
                request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
            case .digestAuth:
                break // negotiated via the authentication challenge in TaskDelegate
            case .apiKey(let key, let value, let addTo):
                switch addTo {
                case .header: request.setValue(value, forHTTPHeaderField: key)
                case .queryParam:
                    if var comps = URLComponents(url: finalURL, resolvingAgainstBaseURL: false) {
                        var items = comps.queryItems ?? []; items.append(URLQueryItem(name: key, value: value)); comps.queryItems = items
                        if let newURL = comps.url { request.url = newURL }
                    }
                }
            case .oauth2(let config):
                if let tokens = config.tokens, !tokens.accessToken.isEmpty {
                    request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
                }
            }
        }

        return request
    }

    private static func log(_ message: String, _ args: CVarArg...) {
        guard debugEnabled else { return }
        withVaList(args) { NSLogv("[HTTPClient] " + message, $0) }
    }

    public static func send(_ request: URLRequest, settings: RequestSettings = RequestSettings(), digestCredentials: (username: String, password: String)? = nil) async throws -> HTTPResponse {
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
        mutableRequest.timeoutInterval = settings.timeoutSeconds

        let start = Date()
        let delegate = TaskDelegate(settings: settings, digestCredentials: digestCredentials)
        let (data, response) = try await session.data(for: mutableRequest, delegate: delegate)
        let duration = Date().timeIntervalSince(start)

        guard let httpResponse = response as? HTTPURLResponse else { throw HTTPClientError.noResponse }
        if debugEnabled { NSLog("[HTTPClient] Response status: %d", httpResponse.statusCode) }

        let headers: [String: String] = Dictionary(uniqueKeysWithValues: httpResponse.allHeaderFields.compactMap { key, value -> (String, String)? in
            guard let k = key as? String, let v = value as? String else { return nil }; return (k, v)
        })
        let cookies = (headers["Set-Cookie"] ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }

        return HTTPResponse(
            statusCode: httpResponse.statusCode, headers: headers, body: data,
            duration: duration, bodySize: data.count, cookies: cookies,
            timing: delegate.collectedTiming()
        )
    }

    /// Task-level delegate handling redirect policy, TLS relaxation (per request,
    /// server-trust challenges only), and timing metrics.
    /// @unchecked Sendable: URLSession serializes all delegate callbacks on its
    /// delegate queue, and `collectedTiming()` is only called after the task
    /// completes, so the mutable state is never accessed concurrently.
    private final class TaskDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        private let settings: RequestSettings
        private let digestCredentials: (username: String, password: String)?
        private var redirectCount = 0
        private var timing: TimingBreakdown?

        init(settings: RequestSettings, digestCredentials: (username: String, password: String)? = nil) {
            self.settings = settings
            self.digestCredentials = digestCredentials
        }

        func collectedTiming() -> TimingBreakdown? { timing }

        func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest: URLRequest) async -> URLRequest? {
            redirectCount += 1
            return RequestSettings.shouldFollowRedirect(count: redirectCount, settings: settings) ? newRequest : nil
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
            if settings.insecureSSL,
               challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
               let trust = challenge.protectionSpace.serverTrust {
                return (.useCredential, URLCredential(trust: trust))
            }
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodHTTPDigest,
               let credentials = digestCredentials {
                // One attempt only — a second challenge means the credentials are wrong.
                guard challenge.previousFailureCount == 0 else { return (.performDefaultHandling, nil) }
                return (.useCredential, URLCredential(user: credentials.username, password: credentials.password, persistence: .forSession))
            }
            return (.performDefaultHandling, nil)
        }

        func urlSession(_ session: URLSession, task: URLSessionTask, didFinishCollecting metrics: URLSessionTaskMetrics) {
            timing = TimingBreakdown.from(metrics: metrics)
        }
    }
}
