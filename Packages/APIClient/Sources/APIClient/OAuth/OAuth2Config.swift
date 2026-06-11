import Foundation

public enum OAuth2GrantType: String, Codable, Sendable, CaseIterable, Identifiable {
    case clientCredentials
    case authorizationCodePKCE
    case refreshTokenOnly

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .clientCredentials: "Client Credentials"
        case .authorizationCodePKCE: "Authorization Code (PKCE)"
        case .refreshTokenOnly: "Refresh Token"
        }
    }
}

public struct OAuth2Tokens: Codable, Sendable, Equatable {
    public var accessToken: String
    public var refreshToken: String?
    public var tokenType: String
    public var expiresAt: Date?

    public init(accessToken: String, refreshToken: String? = nil, tokenType: String = "Bearer", expiresAt: Date? = nil) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenType = tokenType
        self.expiresAt = expiresAt
    }
}

public struct OAuth2Config: Codable, Sendable, Equatable {
    public var grantType: OAuth2GrantType
    public var tokenURL: String
    public var authorizationURL: String
    public var clientID: String
    public var clientSecret: String
    public var scopes: String
    public var redirectPort: Int
    public var clientAuthInBody: Bool
    public var tokens: OAuth2Tokens?

    public init(
        grantType: OAuth2GrantType = .clientCredentials,
        tokenURL: String = "",
        authorizationURL: String = "",
        clientID: String = "",
        clientSecret: String = "",
        scopes: String = "",
        redirectPort: Int = 53682,
        clientAuthInBody: Bool = false,
        tokens: OAuth2Tokens? = nil
    ) {
        self.grantType = grantType
        self.tokenURL = tokenURL
        self.authorizationURL = authorizationURL
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.scopes = scopes
        self.redirectPort = redirectPort
        self.clientAuthInBody = clientAuthInBody
        self.tokens = tokens
    }
}
