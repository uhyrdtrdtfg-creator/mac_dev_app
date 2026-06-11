import Foundation

/// SwiftData-free mirror of CookieModel so matching logic stays pure and testable.
public struct CookieRecord: Sendable, Equatable {
    public var domain: String   // leading "." marks a Domain= cookie (suffix match)
    public var name: String
    public var value: String
    public var path: String
    public var expiresAt: Date?
    public var isSecure: Bool

    public init(domain: String, name: String, value: String, path: String = "/", expiresAt: Date? = nil, isSecure: Bool = false) {
        self.domain = domain; self.name = name; self.value = value
        self.path = path; self.expiresAt = expiresAt; self.isSecure = isSecure
    }
}

public enum CookieJar {

    /// RFC 6265 §5.1.3 domain matching. A leading dot on the stored domain (or any
    /// stored domain, per the Domain-attribute rule) allows suffix matching, but the
    /// suffix is anchored on a label boundary so `evil.com` can never match
    /// `api.evil.com.attacker.net`.
    public static func domainMatches(host: String, cookieDomain: String) -> Bool {
        let host = host.lowercased()
        let domain = cookieDomain.lowercased().hasPrefix(".") ? String(cookieDomain.lowercased().dropFirst()) : cookieDomain.lowercased()
        guard !domain.isEmpty, !host.isEmpty else { return false }
        if host == domain { return true }
        return host.hasSuffix("." + domain)
    }

    /// RFC 6265 §5.1.4 path matching.
    public static func pathMatches(requestPath: String, cookiePath: String) -> Bool {
        let requestPath = requestPath.isEmpty ? "/" : requestPath
        if requestPath == cookiePath { return true }
        guard requestPath.hasPrefix(cookiePath) else { return false }
        if cookiePath.hasSuffix("/") { return true }
        let next = requestPath.index(requestPath.startIndex, offsetBy: cookiePath.count)
        return requestPath[next] == "/"
    }

    /// Cookies applicable to `url`: domain + path matched, unexpired, and Secure
    /// cookies only over https. Sorted longest-path-first per RFC 6265 §5.4.
    public static func matching(_ records: [CookieRecord], for url: URL, now: Date) -> [CookieRecord] {
        guard let host = url.host else { return [] }
        let isHTTPS = url.scheme?.lowercased() == "https"
        let requestPath = url.path.isEmpty ? "/" : url.path
        return records.filter { cookie in
            if let expires = cookie.expiresAt, expires < now { return false }
            if cookie.isSecure && !isHTTPS { return false }
            guard domainMatches(host: host, cookieDomain: cookie.domain) else { return false }
            return pathMatches(requestPath: requestPath, cookiePath: cookie.path.isEmpty ? "/" : cookie.path)
        }
        .sorted { $0.path.count > $1.path.count }
    }

    /// Builds the Cookie header value: "a=1; b=2".
    public static func headerValue(_ records: [CookieRecord]) -> String {
        records.map { "\($0.name)=\($0.value)" }.joined(separator: "; ")
    }

    /// Parses Set-Cookie response headers into records using Foundation's
    /// HTTPCookie parser (correctly splits the comma-merged header field).
    /// Host-only cookies come back without a leading dot; Domain= cookies keep it.
    public static func capture(responseHeaders: [String: String], requestURL: URL) -> [CookieRecord] {
        let setCookieFields = responseHeaders.filter { $0.key.caseInsensitiveCompare("Set-Cookie") == .orderedSame }
        guard !setCookieFields.isEmpty else { return [] }
        let cookies = HTTPCookie.cookies(withResponseHeaderFields: setCookieFields, for: requestURL)
        return cookies.map { c in
            CookieRecord(domain: c.domain, name: c.name, value: c.value, path: c.path, expiresAt: c.expiresDate, isSecure: c.isSecure)
        }
    }
}
