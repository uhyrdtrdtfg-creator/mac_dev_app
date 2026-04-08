import Foundation

public struct RandomStringOptions: Sendable {
    public var length: Int; public var uppercase: Bool; public var lowercase: Bool; public var digits: Bool; public var special: Bool
    public init(length: Int = 16, uppercase: Bool = true, lowercase: Bool = true, digits: Bool = true, special: Bool = false) {
        self.length = length; self.uppercase = uppercase; self.lowercase = lowercase; self.digits = digits; self.special = special
    }
    var charset: String {
        var cs = ""
        if uppercase { cs += "ABCDEFGHIJKLMNOPQRSTUVWXYZ" }; if lowercase { cs += "abcdefghijklmnopqrstuvwxyz" }
        if digits { cs += "0123456789" }; if special { cs += "!@#$%^&*()-_=+[]{}|;:,.<>?" }
        return cs.isEmpty ? "abcdefghijklmnopqrstuvwxyz" : cs
    }
}

public enum RandomStringGenerator {
    public static func generate(_ options: RandomStringOptions) -> String {
        let charset = Array(options.charset); return (0..<options.length).map { _ in String(charset[Int.random(in: 0..<charset.count)]) }.joined()
    }
    public static func generateBatch(_ count: Int, options: RandomStringOptions) -> [String] { (0..<count).map { _ in generate(options) } }
}
