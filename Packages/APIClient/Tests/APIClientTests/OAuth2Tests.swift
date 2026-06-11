import Testing
import Foundation
@testable import APIClient

// MARK: - PKCE

@Test func pkceVerifierLengthAndCharset() {
    let allowed = Set("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-._~")
    var seen = Set<String>()
    for _ in 0..<200 {
        let verifier = PKCE.generateCodeVerifier()
        #expect(verifier.count >= 43 && verifier.count <= 128)
        #expect(verifier.allSatisfy { allowed.contains($0) })
        seen.insert(verifier)
    }
    #expect(seen.count == 200)
}

@Test func pkceVerifierLengthClamped() {
    #expect(PKCE.generateCodeVerifier(length: 10).count == 43)
    #expect(PKCE.generateCodeVerifier(length: 500).count == 128)
    #expect(PKCE.generateCodeVerifier(length: 100).count == 100)
}

@Test func pkceChallengeMatchesRFC7636AppendixB() {
    let challenge = PKCE.codeChallenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")
    #expect(challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
}

// MARK: - Token request formation

@Test func formURLEncodePercentEncodesReservedCharacters() {
    let body = OAuth2Service.formURLEncode([("scope", "read write"), ("redirect_uri", "http://127.0.0.1:53682/callback"), ("x", "a&b=c+d")])
    #expect(body == "scope=read%20write&redirect_uri=http%3A%2F%2F127.0.0.1%3A53682%2Fcallback&x=a%26b%3Dc%2Bd")
}

@Test func tokenRequestClientCredentialsUsesBasicAuthByDefault() throws {
    let config = OAuth2Config(tokenURL: "https://auth.example.com/token", clientID: "my-client", clientSecret: "s3cret", scopes: "read write")
    let request = try OAuth2Service.tokenRequest(config: config, params: OAuth2Service.clientCredentialsParams(config: config))
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Content-Type")?.hasPrefix("application/x-www-form-urlencoded") == true)
    let expected = "Basic " + Data("my-client:s3cret".utf8).base64EncodedString()
    #expect(request.value(forHTTPHeaderField: "Authorization") == expected)
    let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
    #expect(body.contains("grant_type=client_credentials"))
    #expect(body.contains("scope=read%20write"))
    #expect(!body.contains("client_secret"))
    #expect(!body.contains("client_id"))
}

@Test func tokenRequestClientAuthInBody() throws {
    let config = OAuth2Config(tokenURL: "https://auth.example.com/token", clientID: "my-client", clientSecret: "s3cret", clientAuthInBody: true)
    let request = try OAuth2Service.tokenRequest(config: config, params: OAuth2Service.clientCredentialsParams(config: config))
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
    #expect(body.contains("client_id=my-client"))
    #expect(body.contains("client_secret=s3cret"))
}

@Test func tokenRequestPublicClientPutsClientIDInBody() throws {
    let config = OAuth2Config(tokenURL: "https://auth.example.com/token", clientID: "public-client")
    let request = try OAuth2Service.tokenRequest(config: config, params: OAuth2Service.codeExchangeParams(config: config, code: "abc", codeVerifier: "ver"))
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    let body = String(data: request.httpBody ?? Data(), encoding: .utf8) ?? ""
    #expect(body.contains("grant_type=authorization_code"))
    #expect(body.contains("code=abc"))
    #expect(body.contains("code_verifier=ver"))
    #expect(body.contains("redirect_uri=http%3A%2F%2F127.0.0.1%3A53682%2Fcallback"))
    #expect(body.contains("client_id=public-client"))
    #expect(!body.contains("client_secret"))
}

@Test func tokenRequestInvalidURLThrows() {
    let config = OAuth2Config(tokenURL: "")
    #expect(throws: OAuth2Error.invalidURL) {
        try OAuth2Service.tokenRequest(config: config, params: [])
    }
}

// MARK: - Authorization URL

@Test func buildAuthorizationURLContainsAllParams() throws {
    let config = OAuth2Config(grantType: .authorizationCodePKCE, authorizationURL: "https://auth.example.com/authorize?audience=api", clientID: "cid", scopes: "openid profile", redirectPort: 4444)
    let url = try #require(OAuth2Service.buildAuthorizationURL(config: config, codeChallenge: "the-challenge", state: "the-state"))
    let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
    func value(_ name: String) -> String? { items.first(where: { $0.name == name })?.value }
    #expect(value("audience") == "api")
    #expect(value("response_type") == "code")
    #expect(value("client_id") == "cid")
    #expect(value("redirect_uri") == "http://127.0.0.1:4444/callback")
    #expect(value("code_challenge") == "the-challenge")
    #expect(value("code_challenge_method") == "S256")
    #expect(value("state") == "the-state")
    #expect(value("scope") == "openid profile")
}

@Test func buildAuthorizationURLEmptyReturnsNil() {
    let config = OAuth2Config(authorizationURL: "")
    #expect(OAuth2Service.buildAuthorizationURL(config: config, codeChallenge: "c", state: "s") == nil)
}

// MARK: - Token response parsing

@Test func parseTokenResponseFull() throws {
    let now = Date(timeIntervalSince1970: 1_000_000)
    let json = #"{"access_token":"abc123","token_type":"Bearer","expires_in":3600,"refresh_token":"refr"}"#
    let tokens = try OAuth2Service.parseTokenResponse(Data(json.utf8), now: now)
    #expect(tokens.accessToken == "abc123")
    #expect(tokens.tokenType == "Bearer")
    #expect(tokens.refreshToken == "refr")
    #expect(tokens.expiresAt == now.addingTimeInterval(3600))
}

@Test func parseTokenResponseMissingExpiresIn() throws {
    let json = #"{"access_token":"abc123","token_type":"bearer"}"#
    let tokens = try OAuth2Service.parseTokenResponse(Data(json.utf8))
    #expect(tokens.expiresAt == nil)
    #expect(tokens.refreshToken == nil)
    #expect(tokens.tokenType == "bearer")
}

@Test func parseTokenResponseStringExpiresIn() throws {
    let now = Date(timeIntervalSince1970: 0)
    let json = #"{"access_token":"abc","expires_in":"120"}"#
    let tokens = try OAuth2Service.parseTokenResponse(Data(json.utf8), now: now)
    #expect(tokens.expiresAt == now.addingTimeInterval(120))
    #expect(tokens.tokenType == "Bearer")
}

@Test func parseTokenResponseErrorSurfaced() {
    let json = #"{"error":"invalid_client","error_description":"Client authentication failed"}"#
    #expect(throws: OAuth2Error.server(code: "invalid_client", description: "Client authentication failed")) {
        try OAuth2Service.parseTokenResponse(Data(json.utf8))
    }
}

@Test func parseTokenResponseMissingAccessToken() {
    #expect(throws: OAuth2Error.missingAccessToken) {
        try OAuth2Service.parseTokenResponse(Data(#"{"token_type":"Bearer"}"#.utf8))
    }
}

@Test func parseTokenResponseNonJSONWithErrorStatus() {
    #expect(throws: OAuth2Error.http(502)) {
        try OAuth2Service.parseTokenResponse(Data("Bad Gateway".utf8), statusCode: 502)
    }
}

// MARK: - Callback URL parsing

@Test func parseCallbackURLExtractsCode() throws {
    let url = URL(string: "http://127.0.0.1:53682/callback?code=auth-code-1&state=xyz")!
    #expect(try OAuth2Service.parseCallbackURL(url, expectedState: "xyz") == "auth-code-1")
}

@Test func parseCallbackURLStateMismatchThrows() {
    let url = URL(string: "http://127.0.0.1:53682/callback?code=auth-code-1&state=wrong")!
    #expect(throws: OAuth2Error.stateMismatch) {
        try OAuth2Service.parseCallbackURL(url, expectedState: "xyz")
    }
}

@Test func parseCallbackURLErrorParamSurfaced() {
    let url = URL(string: "http://127.0.0.1:53682/callback?error=access_denied&error_description=User%20cancelled&state=xyz")!
    #expect(throws: OAuth2Error.server(code: "access_denied", description: "User cancelled")) {
        try OAuth2Service.parseCallbackURL(url, expectedState: "xyz")
    }
}

@Test func parseCallbackURLMissingCodeThrows() {
    let url = URL(string: "http://127.0.0.1:53682/callback?state=xyz")!
    #expect(throws: OAuth2Error.missingCode) {
        try OAuth2Service.parseCallbackURL(url, expectedState: "xyz")
    }
}

// MARK: - Codable

@Test func oauth2ConfigCodableRoundtrip() throws {
    let config = OAuth2Config(
        grantType: .authorizationCodePKCE,
        tokenURL: "https://auth.example.com/token",
        authorizationURL: "https://auth.example.com/authorize",
        clientID: "cid",
        clientSecret: "sec",
        scopes: "read write",
        redirectPort: 4444,
        clientAuthInBody: true,
        tokens: OAuth2Tokens(accessToken: "at", refreshToken: "rt", tokenType: "Bearer", expiresAt: Date(timeIntervalSince1970: 12345))
    )
    let data = try JSONEncoder().encode(config)
    let decoded = try JSONDecoder().decode(OAuth2Config.self, from: data)
    #expect(decoded == config)
}

@Test func authTypeOAuth2Codable() throws {
    let auth = AuthType.oauth2(OAuth2Config(tokenURL: "https://t", clientID: "c"))
    let data = try JSONEncoder().encode(auth)
    let decoded = try JSONDecoder().decode(AuthType.self, from: data)
    if case .oauth2(let config) = decoded { #expect(config.tokenURL == "https://t"); #expect(config.clientID == "c") }
    else { Issue.record("Expected .oauth2 case") }
}

@Test func legacyAuthTypeJSONStillDecodes() throws {
    let json = #"{"bearerToken":{"_0":"legacy-token"}}"#
    let decoded = try JSONDecoder().decode(AuthType.self, from: Data(json.utf8))
    if case .bearerToken(let token) = decoded { #expect(token == "legacy-token") }
    else { Issue.record("Expected .bearerToken case") }
}

// MARK: - buildURLRequest bearer injection

@Test func buildURLRequestOAuth2WithTokens() throws {
    let config = OAuth2Config(tokens: OAuth2Tokens(accessToken: "live-token"))
    let request = try HTTPClientService.buildURLRequest(method: .get, url: "https://example.com/api", headers: [], queryParams: [], body: nil, auth: .oauth2(config))
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer live-token")
}

@Test func buildURLRequestOAuth2WithoutTokensSetsNoHeader() throws {
    let request = try HTTPClientService.buildURLRequest(method: .get, url: "https://example.com/api", headers: [], queryParams: [], body: nil, auth: .oauth2(OAuth2Config()))
    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    let empty = OAuth2Config(tokens: OAuth2Tokens(accessToken: ""))
    let request2 = try HTTPClientService.buildURLRequest(method: .get, url: "https://example.com/api", headers: [], queryParams: [], body: nil, auth: .oauth2(empty))
    #expect(request2.value(forHTTPHeaderField: "Authorization") == nil)
}

// MARK: - Callback server integration (loopback)

@Test func callbackServerDeliversCodeOverRealHTTP() async throws {
    let server = OAuthCallbackServer(port: 53791, expectedState: "state-1")
    try await server.start()
    async let pendingCode = server.waitForCode()
    let url = URL(string: "http://127.0.0.1:53791/callback?code=abc123&state=state-1")!
    let (data, response) = try await URLSession.shared.data(from: url)
    #expect((response as? HTTPURLResponse)?.statusCode == 200)
    #expect(String(data: data, encoding: .utf8)?.contains("Authorization complete") == true)
    let code = try await pendingCode
    #expect(code == "abc123")
    await server.stop()
}

@Test func callbackServerRejectsStateMismatchOverRealHTTP() async throws {
    let server = OAuthCallbackServer(port: 53792, expectedState: "expected")
    try await server.start()
    let url = URL(string: "http://127.0.0.1:53792/callback?code=abc&state=wrong")!
    let (_, response) = try await URLSession.shared.data(from: url)
    #expect((response as? HTTPURLResponse)?.statusCode == 400)
    await #expect(throws: OAuth2Error.stateMismatch) { try await server.waitForCode() }
    await server.stop()
}
