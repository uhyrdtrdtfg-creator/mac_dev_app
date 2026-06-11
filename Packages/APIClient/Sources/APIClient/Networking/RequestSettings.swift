import Foundation

/// Per-request execution settings, persisted per tab.
public struct RequestSettings: Codable, Sendable, Equatable {
    public var timeoutSeconds: Double = 60
    public var followRedirects: Bool = true
    public var maxRedirects: Int = 10
    public var insecureSSL: Bool = false
    public var sendCookies: Bool = true
    public var storeCookies: Bool = true

    public init() {}

    // Tolerant decoding: missing keys fall back to defaults so persisted
    // settings survive future field additions.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        timeoutSeconds = try c.decodeIfPresent(Double.self, forKey: .timeoutSeconds) ?? 60
        followRedirects = try c.decodeIfPresent(Bool.self, forKey: .followRedirects) ?? true
        maxRedirects = try c.decodeIfPresent(Int.self, forKey: .maxRedirects) ?? 10
        insecureSSL = try c.decodeIfPresent(Bool.self, forKey: .insecureSSL) ?? false
        sendCookies = try c.decodeIfPresent(Bool.self, forKey: .sendCookies) ?? true
        storeCookies = try c.decodeIfPresent(Bool.self, forKey: .storeCookies) ?? true
    }

    /// Redirect policy decision: should redirect number `count` (1-based) be followed?
    public static func shouldFollowRedirect(count: Int, settings: RequestSettings) -> Bool {
        settings.followRedirects && count <= settings.maxRedirects
    }
}
