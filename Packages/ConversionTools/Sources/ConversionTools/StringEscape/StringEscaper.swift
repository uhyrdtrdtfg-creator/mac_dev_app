import Foundation

public enum StringEscaper {
    public static func escape(_ input: String) -> String {
        var result = ""
        for char in input {
            switch char {
            case "\"": result += "\\\""
            case "\\": result += "\\\\"
            case "\n": result += "\\n"
            case "\r": result += "\\r"
            case "\t": result += "\\t"
            default: result.append(char)
            }
        }
        return result
    }

    public static func unescape(_ input: String) -> String {
        var result = ""
        var i = input.startIndex
        while i < input.endIndex {
            if input[i] == "\\" {
                let next = input.index(after: i)
                if next < input.endIndex {
                    switch input[next] {
                    case "\"": result += "\""; i = input.index(after: next)
                    case "\\": result += "\\"; i = input.index(after: next)
                    case "n": result += "\n"; i = input.index(after: next)
                    case "r": result += "\r"; i = input.index(after: next)
                    case "t": result += "\t"; i = input.index(after: next)
                    default: result.append(input[i]); i = next
                    }
                } else {
                    result.append(input[i]); i = next
                }
            } else {
                result.append(input[i]); i = input.index(after: i)
            }
        }
        return result
    }
}
