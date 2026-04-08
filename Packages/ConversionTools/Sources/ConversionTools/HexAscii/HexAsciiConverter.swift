import Foundation

public enum HexAsciiConverter {
    public static func asciiToHex(_ input: String, separator: String = " ") -> String {
        input.unicodeScalars.map { String(format: "%02X", $0.value) }.joined(separator: separator)
    }

    public static func hexToAscii(_ input: String) -> String? {
        let cleaned = input.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "0x", with: "").replacingOccurrences(of: ",", with: "")
        guard cleaned.count.isMultiple(of: 2) else { return nil }
        var result = ""
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let nextIndex = cleaned.index(index, offsetBy: 2)
            guard let byte = UInt8(cleaned[index..<nextIndex], radix: 16) else { return nil }
            result.append(Character(UnicodeScalar(byte)))
            index = nextIndex
        }
        return result
    }
}
