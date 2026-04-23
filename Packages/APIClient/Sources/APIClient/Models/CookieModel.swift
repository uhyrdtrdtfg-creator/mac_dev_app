import Foundation
import SwiftData

/// Represents a stored HTTP cookie
@Model
public final class CookieModel {
    public var id: UUID = UUID()
    public var domain: String = ""
    public var name: String = ""
    public var value: String = ""
    public var path: String = "/"
    public var expiresAt: Date?
    public var isSecure: Bool = false
    public var isHttpOnly: Bool = false
    public var createdAt: Date = Date()
    public var updatedAt: Date = Date()

    public init(
        domain: String,
        name: String,
        value: String,
        path: String = "/",
        expiresAt: Date? = nil,
        isSecure: Bool = false,
        isHttpOnly: Bool = false
    ) {
        self.id = UUID()
        self.domain = domain
        self.name = name
        self.value = value
        self.path = path
        self.expiresAt = expiresAt
        self.isSecure = isSecure
        self.isHttpOnly = isHttpOnly
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    /// Check if the cookie is expired
    public var isExpired: Bool {
        guard let expiresAt = expiresAt else { return false }
        return expiresAt < Date()
    }

    /// Convert to HTTPCookie for use with URLSession
    public var httpCookie: HTTPCookie? {
        var properties: [HTTPCookiePropertyKey: Any] = [
            .domain: domain,
            .name: name,
            .value: value,
            .path: path
        ]
        if let expiresAt = expiresAt {
            properties[.expires] = expiresAt
        }
        if isSecure {
            properties[.secure] = "TRUE"
        }
        return HTTPCookie(properties: properties)
    }

    /// Parse a Set-Cookie header value into a CookieModel
    public static func parse(setCookieHeader: String, forDomain domain: String) -> CookieModel? {
        let parts = setCookieHeader.split(separator: ";").map { $0.trimmingCharacters(in: .whitespaces) }
        guard let firstPart = parts.first else { return nil }

        // Parse name=value
        let nameValue = firstPart.split(separator: "=", maxSplits: 1)
        guard nameValue.count >= 1 else { return nil }
        let name = String(nameValue[0])
        let value = nameValue.count > 1 ? String(nameValue[1]) : ""

        var cookieDomain = domain
        var path = "/"
        var expiresAt: Date?
        var isSecure = false
        var isHttpOnly = false

        // Parse attributes
        for part in parts.dropFirst() {
            let attr = part.lowercased()
            if attr.hasPrefix("domain=") {
                cookieDomain = String(part.dropFirst(7))
            } else if attr.hasPrefix("path=") {
                path = String(part.dropFirst(5))
            } else if attr.hasPrefix("expires=") {
                let dateStr = String(part.dropFirst(8))
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
                expiresAt = formatter.date(from: dateStr)
            } else if attr.hasPrefix("max-age=") {
                if let seconds = Int(String(part.dropFirst(8))) {
                    expiresAt = Date().addingTimeInterval(TimeInterval(seconds))
                }
            } else if attr == "secure" {
                isSecure = true
            } else if attr == "httponly" {
                isHttpOnly = true
            }
        }

        return CookieModel(
            domain: cookieDomain,
            name: name,
            value: value,
            path: path,
            expiresAt: expiresAt,
            isSecure: isSecure,
            isHttpOnly: isHttpOnly
        )
    }
}
