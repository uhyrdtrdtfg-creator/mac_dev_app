import Foundation
import AppKit

public enum OAuth2Error: Error, LocalizedError, Equatable, Sendable {
    case invalidURL
    case invalidResponse
    case http(Int)
    case server(code: String, description: String?)
    case missingAccessToken
    case missingRefreshToken
    case stateMismatch
    case missingCode
    case timeout
    case callbackServerFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid OAuth URL"
        case .invalidResponse: "The token endpoint returned an unreadable response"
        case .http(let code): "Token endpoint returned HTTP \(code)"
        case .server(let code, let description): description.map { "\(code): \($0)" } ?? code
        case .missingAccessToken: "No access_token in token response"
        case .missingRefreshToken: "No refresh token available"
        case .stateMismatch: "State parameter mismatch (possible CSRF)"
        case .missingCode: "No authorization code in callback"
        case .timeout: "Timed out waiting for authorization"
        case .callbackServerFailed(let reason): "Callback server failed: \(reason)"
        }
    }
}

public enum OAuth2Service {
    // MARK: - Pure request-formation helpers (unit-testable, no network)

    private static let formUnreserved = CharacterSet(charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")

    static func formEscape(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: formUnreserved) ?? value
    }

    public static func formURLEncode(_ params: [(String, String)]) -> String {
        params.map { "\(formEscape($0.0))=\(formEscape($0.1))" }.joined(separator: "&")
    }

    public static func clientCredentialsParams(config: OAuth2Config) -> [(String, String)] {
        var params = [("grant_type", "client_credentials")]
        if !config.scopes.isEmpty { params.append(("scope", config.scopes)) }
        return params
    }

    public static func refreshParams(refreshToken: String) -> [(String, String)] {
        [("grant_type", "refresh_token"), ("refresh_token", refreshToken)]
    }

    public static func codeExchangeParams(config: OAuth2Config, code: String, codeVerifier: String) -> [(String, String)] {
        [
            ("grant_type", "authorization_code"),
            ("code", code),
            ("redirect_uri", redirectURI(port: config.redirectPort)),
            ("code_verifier", codeVerifier),
        ]
    }

    public static func redirectURI(port: Int) -> String {
        "http://127.0.0.1:\(port)/callback"
    }

    /// Builds the token-endpoint POST. Client auth goes in a Basic header when a secret
    /// is present and `clientAuthInBody` is false; otherwise client_id (+ secret) ride in the body.
    public static func tokenRequest(config: OAuth2Config, params: [(String, String)]) throws -> URLRequest {
        guard let url = URL(string: config.tokenURL), url.scheme != nil else { throw OAuth2Error.invalidURL }
        let useBasic = !config.clientSecret.isEmpty && !config.clientAuthInBody
        var allParams = params
        if !useBasic {
            allParams.append(("client_id", config.clientID))
            if !config.clientSecret.isEmpty { allParams.append(("client_secret", config.clientSecret)) }
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if useBasic {
            let credentials = Data("\(formEscape(config.clientID)):\(formEscape(config.clientSecret))".utf8).base64EncodedString()
            request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = Data(formURLEncode(allParams).utf8)
        return request
    }

    public static func buildAuthorizationURL(config: OAuth2Config, codeChallenge: String, state: String) -> URL? {
        guard !config.authorizationURL.isEmpty, var components = URLComponents(string: config.authorizationURL) else { return nil }
        var items = components.queryItems ?? []
        items.append(contentsOf: [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: config.clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI(port: config.redirectPort)),
            URLQueryItem(name: "code_challenge", value: codeChallenge),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "state", value: state),
        ])
        if !config.scopes.isEmpty { items.append(URLQueryItem(name: "scope", value: config.scopes)) }
        components.queryItems = items
        return components.url
    }

    public static func parseTokenResponse(_ data: Data, statusCode: Int? = nil, now: Date = Date()) throws -> OAuth2Tokens {
        guard let obj = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            if let code = statusCode, !(200..<300).contains(code) { throw OAuth2Error.http(code) }
            throw OAuth2Error.invalidResponse
        }
        if let error = obj["error"] as? String {
            throw OAuth2Error.server(code: error, description: obj["error_description"] as? String)
        }
        guard let accessToken = obj["access_token"] as? String, !accessToken.isEmpty else {
            throw OAuth2Error.missingAccessToken
        }
        let expiresAt: Date? = {
            if let seconds = obj["expires_in"] as? Double { return now.addingTimeInterval(seconds) }
            if let str = obj["expires_in"] as? String, let seconds = Double(str) { return now.addingTimeInterval(seconds) }
            return nil
        }()
        return OAuth2Tokens(
            accessToken: accessToken,
            refreshToken: obj["refresh_token"] as? String,
            tokenType: (obj["token_type"] as? String) ?? "Bearer",
            expiresAt: expiresAt
        )
    }

    public static func parseCallbackURL(_ url: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { throw OAuth2Error.invalidResponse }
        let items = components.queryItems ?? []
        func value(_ name: String) -> String? { items.first(where: { $0.name == name })?.value }
        if let error = value("error") {
            throw OAuth2Error.server(code: error, description: value("error_description"))
        }
        guard value("state") == expectedState else { throw OAuth2Error.stateMismatch }
        guard let code = value("code"), !code.isEmpty else { throw OAuth2Error.missingCode }
        return code
    }

    // MARK: - Token flows (network)

    public static func fetchTokenClientCredentials(_ config: OAuth2Config) async throws -> OAuth2Tokens {
        try await performTokenRequest(tokenRequest(config: config, params: clientCredentialsParams(config: config)))
    }

    public static func refreshToken(_ config: OAuth2Config) async throws -> OAuth2Tokens {
        guard let refresh = config.tokens?.refreshToken, !refresh.isEmpty else { throw OAuth2Error.missingRefreshToken }
        var tokens = try await performTokenRequest(tokenRequest(config: config, params: refreshParams(refreshToken: refresh)))
        if tokens.refreshToken == nil { tokens.refreshToken = refresh }
        return tokens
    }

    /// Full RFC 7636 authorization-code flow: opens the browser, awaits the loopback
    /// callback (180s timeout), then exchanges the code + verifier at the token endpoint.
    public static func authorizationCodePKCE(_ config: OAuth2Config, openURL: (@Sendable (URL) async -> Void)? = nil) async throws -> OAuth2Tokens {
        let verifier = PKCE.generateCodeVerifier()
        let challenge = PKCE.codeChallenge(for: verifier)
        let state = PKCE.generateState()
        guard let authURL = buildAuthorizationURL(config: config, codeChallenge: challenge, state: state),
              let port = UInt16(exactly: config.redirectPort), port > 0 else { throw OAuth2Error.invalidURL }

        let server = OAuthCallbackServer(port: port, expectedState: state)
        try await server.start()
        do {
            if let openURL {
                await openURL(authURL)
            } else {
                await MainActor.run { _ = NSWorkspace.shared.open(authURL) }
            }
            let code = try await withTimeout(seconds: 180) { try await server.waitForCode() }
            await server.stop()
            let request = try tokenRequest(config: config, params: codeExchangeParams(config: config, code: code, codeVerifier: verifier))
            return try await performTokenRequest(request)
        } catch {
            await server.stop()
            throw error
        }
    }

    private static func performTokenRequest(_ request: URLRequest) async throws -> OAuth2Tokens {
        let (data, response) = try await URLSession.shared.data(for: request)
        return try parseTokenResponse(data, statusCode: (response as? HTTPURLResponse)?.statusCode)
    }

    private static func withTimeout<T: Sendable>(seconds: Double, _ operation: @escaping @Sendable () async throws -> T) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw OAuth2Error.timeout
            }
            let result = try await group.next()!
            group.cancelAll()
            return result
        }
    }
}
