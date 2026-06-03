import Foundation

public struct RGBColor: Sendable, Equatable {
    public var r: Int   // 0-255
    public var g: Int
    public var b: Int
    public var a: Double // 0-1

    public init(r: Int, g: Int, b: Int, a: Double = 1) {
        self.r = r; self.g = g; self.b = b; self.a = a
    }
}

public enum ColorConverter {
    /// Parse `#RGB`, `#RRGGBB`, `#RRGGBBAA`, `rgb(r,g,b)`, or `rgba(r,g,b,a)`.
    public static func parse(_ input: String) -> RGBColor? {
        var s = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if s.hasPrefix("#") {
            s.removeFirst()
            return parseHex(s)
        }
        if s.hasPrefix("rgb") {
            return parseRGBFunction(s)
        }
        return parseHex(s)
    }

    private static func parseHex(_ hex: String) -> RGBColor? {
        let chars = Array(hex)
        func val(_ str: String) -> Int? { Int(str, radix: 16) }
        switch chars.count {
        case 3:
            guard let r = val(String(repeating: chars[0], count: 2)),
                  let g = val(String(repeating: chars[1], count: 2)),
                  let b = val(String(repeating: chars[2], count: 2)) else { return nil }
            return RGBColor(r: r, g: g, b: b)
        case 6:
            guard let r = val(String(chars[0...1])), let g = val(String(chars[2...3])), let b = val(String(chars[4...5])) else { return nil }
            return RGBColor(r: r, g: g, b: b)
        case 8:
            guard let r = val(String(chars[0...1])), let g = val(String(chars[2...3])),
                  let b = val(String(chars[4...5])), let a = val(String(chars[6...7])) else { return nil }
            return RGBColor(r: r, g: g, b: b, a: Double(a) / 255)
        default:
            return nil
        }
    }

    private static func parseRGBFunction(_ s: String) -> RGBColor? {
        guard let open = s.firstIndex(of: "("), let close = s.firstIndex(of: ")") else { return nil }
        let inner = s[s.index(after: open)..<close]
        let parts = inner.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count >= 3, let r = Int(parts[0]), let g = Int(parts[1]), let b = Int(parts[2]) else { return nil }
        let a = parts.count >= 4 ? (Double(parts[3]) ?? 1) : 1
        return RGBColor(r: clamp(r), g: clamp(g), b: clamp(b), a: a)
    }

    // MARK: - Formats

    public static func toHex(_ c: RGBColor, includeAlpha: Bool = false) -> String {
        let base = String(format: "#%02X%02X%02X", clamp(c.r), clamp(c.g), clamp(c.b))
        if includeAlpha { return base + String(format: "%02X", Int((c.a * 255).rounded())) }
        return base
    }

    public static func toRGBString(_ c: RGBColor) -> String {
        c.a < 1 ? "rgba(\(c.r), \(c.g), \(c.b), \(trimDouble(c.a)))" : "rgb(\(c.r), \(c.g), \(c.b))"
    }

    public static func toHSL(_ c: RGBColor) -> (h: Int, s: Int, l: Int) {
        let r = Double(c.r) / 255, g = Double(c.g) / 255, b = Double(c.b) / 255
        let maxV = max(r, g, b), minV = min(r, g, b)
        let l = (maxV + minV) / 2
        var h = 0.0, s = 0.0
        let d = maxV - minV
        if d != 0 {
            s = l > 0.5 ? d / (2 - maxV - minV) : d / (maxV + minV)
            h = hue(r, g, b, maxV, d)
        }
        return (Int((h * 360).rounded()), Int((s * 100).rounded()), Int((l * 100).rounded()))
    }

    public static func toHSB(_ c: RGBColor) -> (h: Int, s: Int, b: Int) {
        let r = Double(c.r) / 255, g = Double(c.g) / 255, bl = Double(c.b) / 255
        let maxV = max(r, g, bl), minV = min(r, g, bl)
        let d = maxV - minV
        let s = maxV == 0 ? 0 : d / maxV
        let h = d == 0 ? 0 : hue(r, g, bl, maxV, d)
        return (Int((h * 360).rounded()), Int((s * 100).rounded()), Int((maxV * 100).rounded()))
    }

    private static func hue(_ r: Double, _ g: Double, _ b: Double, _ maxV: Double, _ d: Double) -> Double {
        var h: Double
        if maxV == r { h = (g - b) / d + (g < b ? 6 : 0) }
        else if maxV == g { h = (b - r) / d + 2 }
        else { h = (r - g) / d + 4 }
        return h / 6
    }

    // MARK: - WCAG contrast

    public static func relativeLuminance(_ c: RGBColor) -> Double {
        func lin(_ v: Int) -> Double {
            let s = Double(v) / 255
            return s <= 0.03928 ? s / 12.92 : pow((s + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(c.r) + 0.7152 * lin(c.g) + 0.0722 * lin(c.b)
    }

    public static func contrastRatio(_ a: RGBColor, _ b: RGBColor) -> Double {
        let l1 = relativeLuminance(a), l2 = relativeLuminance(b)
        let hi = max(l1, l2), lo = min(l1, l2)
        return (hi + 0.05) / (lo + 0.05)
    }

    private static func clamp(_ v: Int) -> Int { Swift.max(0, Swift.min(255, v)) }
    private static func trimDouble(_ d: Double) -> String {
        d == d.rounded() ? String(Int(d)) : String(format: "%.2f", d)
    }
}
