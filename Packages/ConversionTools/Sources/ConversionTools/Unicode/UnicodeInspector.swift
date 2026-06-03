import Foundation

public struct UnicodeScalarInfo: Identifiable, Sendable {
    public let id = UUID()
    public let character: String
    public let codePoint: String   // U+XXXX
    public let name: String
    public let category: String
    public let utf8: String        // space-separated hex bytes
    public let utf16: String
    public let isInvisible: Bool
}

public enum UnicodeInspector {
    public static func inspect(_ text: String) -> [UnicodeScalarInfo] {
        text.unicodeScalars.map { scalar in
            let code = String(format: "U+%04X", scalar.value)
            let name = scalar.properties.name ?? "<unnamed>"
            let category = categoryName(scalar.properties.generalCategory)
            let utf8 = Array(String(scalar).utf8).map { String(format: "%02X", $0) }.joined(separator: " ")
            let utf16 = String(scalar).utf16.map { String(format: "%04X", $0) }.joined(separator: " ")
            return UnicodeScalarInfo(
                character: String(scalar),
                codePoint: code,
                name: name,
                category: category,
                utf8: utf8,
                utf16: utf16,
                isInvisible: isInvisibleScalar(scalar)
            )
        }
    }

    /// True if the string contains zero-width or other invisible/control characters worth flagging.
    public static func hasInvisibleCharacters(_ text: String) -> Bool {
        text.unicodeScalars.contains { isInvisibleScalar($0) }
    }

    private static func isInvisibleScalar(_ s: Unicode.Scalar) -> Bool {
        let invisible: Set<UInt32> = [
            0x00A0, // no-break space
            0x200B, 0x200C, 0x200D, // zero-width space/non-joiner/joiner
            0x200E, 0x200F, // LRM/RLM
            0xFEFF, // BOM / zero-width no-break space
            0x2028, 0x2029, // line/paragraph separator
            0x00AD  // soft hyphen
        ]
        if invisible.contains(s.value) { return true }
        switch s.properties.generalCategory {
        case .control, .format, .surrogate, .privateUse, .lineSeparator, .paragraphSeparator:
            return s != "\n" && s != "\t" && s != "\r"
        default:
            return false
        }
    }

    private static func categoryName(_ c: Unicode.GeneralCategory) -> String {
        switch c {
        case .uppercaseLetter: "Uppercase Letter"
        case .lowercaseLetter: "Lowercase Letter"
        case .titlecaseLetter: "Titlecase Letter"
        case .modifierLetter: "Modifier Letter"
        case .otherLetter: "Other Letter"
        case .decimalNumber: "Decimal Number"
        case .letterNumber: "Letter Number"
        case .otherNumber: "Other Number"
        case .spaceSeparator: "Space Separator"
        case .lineSeparator: "Line Separator"
        case .paragraphSeparator: "Paragraph Separator"
        case .control: "Control"
        case .format: "Format"
        case .surrogate: "Surrogate"
        case .privateUse: "Private Use"
        case .dashPunctuation: "Dash Punctuation"
        case .openPunctuation: "Open Punctuation"
        case .closePunctuation: "Close Punctuation"
        case .connectorPunctuation: "Connector Punctuation"
        case .otherPunctuation: "Other Punctuation"
        case .mathSymbol: "Math Symbol"
        case .currencySymbol: "Currency Symbol"
        case .modifierSymbol: "Modifier Symbol"
        case .otherSymbol: "Other Symbol"
        case .nonspacingMark: "Nonspacing Mark"
        case .spacingMark: "Spacing Mark"
        case .enclosingMark: "Enclosing Mark"
        case .initialPunctuation: "Initial Punctuation"
        case .finalPunctuation: "Final Punctuation"
        @unknown default: "Other"
        }
    }
}
