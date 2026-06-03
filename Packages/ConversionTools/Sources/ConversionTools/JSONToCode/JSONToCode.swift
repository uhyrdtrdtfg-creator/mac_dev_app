import Foundation

public enum CodeLanguage: String, CaseIterable, Identifiable, Sendable {
    case swift = "Swift"
    case typescript = "TypeScript"
    case go = "Go"
    case java = "Java"
    case python = "Python"
    public var id: String { rawValue }
}

public enum JSONToCodeError: Error, LocalizedError {
    case invalidJSON
    public var errorDescription: String? { "Invalid JSON" }
}

public enum JSONToCode {
    indirect enum Inferred {
        case string, int, double, bool, any
        case object(String)
        case array(Inferred)
    }

    public static func generate(json: String, language: CodeLanguage, rootName: String = "Root") -> Result<String, JSONToCodeError> {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return .failure(.invalidJSON)
        }
        var gen = Generator(language: language)
        let rootType = gen.infer(root, name: rootName)
        return .success(gen.render(rootType: rootType, rootName: rootName))
    }

    private struct Generator {
        let language: CodeLanguage
        var structOrder: [String] = []
        var structs: [String: [(key: String, type: Inferred)]] = [:]

        mutating func infer(_ value: Any, name: String) -> Inferred {
            if value is NSNull { return .any }
            if let n = value as? NSNumber {
                if CFGetTypeID(n) == CFBooleanGetTypeID() { return .bool }
                return isInteger(n) ? .int : .double
            }
            if value is String { return .string }
            if let dict = value as? [String: Any] {
                let typeName = uniqueName(pascal(name))
                structOrder.append(typeName)
                structs[typeName] = []
                var fields: [(String, Inferred)] = []
                for key in dict.keys.sorted() {
                    fields.append((key, infer(dict[key]!, name: singular(key))))
                }
                structs[typeName] = fields
                return .object(typeName)
            }
            if let arr = value as? [Any] {
                guard let first = arr.first else { return .array(.any) }
                return .array(infer(first, name: singular(name)))
            }
            return .any
        }

        func render(rootType: Inferred, rootName: String) -> String {
            switch language {
            case .swift: return structOrder.map { renderSwift($0) }.joined(separator: "\n\n")
            case .typescript: return structOrder.map { renderTS($0) }.joined(separator: "\n\n")
            case .go: return structOrder.map { renderGo($0) }.joined(separator: "\n\n")
            case .java:
                return structOrder.enumerated().map { renderJava($0.element, isRoot: $0.offset == 0) }.joined(separator: "\n\n")
            case .python:
                let body = structOrder.reversed().map { renderPython($0) }.joined(separator: "\n\n")
                return "from __future__ import annotations\nfrom dataclasses import dataclass\nfrom typing import Any, List\n\n\n" + body
            }
        }

        // MARK: - Swift

        private func renderSwift(_ name: String) -> String {
            var out = "struct \(name): Codable {\n"
            for field in structs[name] ?? [] {
                out += "    let \(camel(field.key)): \(swiftType(field.type))\n"
            }
            out += "}"
            return out
        }

        private func swiftType(_ type: Inferred) -> String {
            switch type {
            case .string: "String"
            case .int: "Int"
            case .double: "Double"
            case .bool: "Bool"
            case .any: "JSONAny"
            case .object(let n): n
            case .array(let e): "[\(swiftType(e))]"
            }
        }

        // MARK: - TypeScript

        private func renderTS(_ name: String) -> String {
            var out = "interface \(name) {\n"
            for field in structs[name] ?? [] {
                out += "  \(field.key): \(tsType(field.type));\n"
            }
            out += "}"
            return out
        }

        private func tsType(_ type: Inferred) -> String {
            switch type {
            case .string: "string"
            case .int, .double: "number"
            case .bool: "boolean"
            case .any: "any"
            case .object(let n): n
            case .array(let e): "\(tsType(e))[]"
            }
        }

        // MARK: - Go

        private func renderGo(_ name: String) -> String {
            var out = "type \(name) struct {\n"
            for field in structs[name] ?? [] {
                out += "\t\(pascal(field.key)) \(goType(field.type)) `json:\"\(field.key)\"`\n"
            }
            out += "}"
            return out
        }

        private func goType(_ type: Inferred) -> String {
            switch type {
            case .string: "string"
            case .int: "int"
            case .double: "float64"
            case .bool: "bool"
            case .any: "interface{}"
            case .object(let n): n
            case .array(let e): "[]\(goType(e))"
            }
        }

        // MARK: - Java

        private func renderJava(_ name: String, isRoot: Bool) -> String {
            var out = (isRoot ? "public class " : "class ") + "\(name) {\n"
            for field in structs[name] ?? [] {
                out += "    public \(javaType(field.type)) \(camel(field.key));\n"
            }
            out += "}"
            return out
        }

        private func javaType(_ type: Inferred) -> String {
            switch type {
            case .string: "String"
            case .int: "int"
            case .double: "double"
            case .bool: "boolean"
            case .any: "Object"
            case .object(let n): n
            case .array(let e): "List<\(javaBoxedType(e))>"
            }
        }

        private func javaBoxedType(_ type: Inferred) -> String {
            switch type {
            case .int: "Integer"
            case .double: "Double"
            case .bool: "Boolean"
            default: javaType(type)
            }
        }

        // MARK: - Python

        private func renderPython(_ name: String) -> String {
            let fields = structs[name] ?? []
            var out = "@dataclass\nclass \(name):\n"
            if fields.isEmpty {
                out += "    pass"
                return out
            }
            for field in fields {
                out += "    \(field.key): \(pythonType(field.type))\n"
            }
            return String(out.dropLast())
        }

        private func pythonType(_ type: Inferred) -> String {
            switch type {
            case .string: "str"
            case .int: "int"
            case .double: "float"
            case .bool: "bool"
            case .any: "Any"
            case .object(let n): n
            case .array(let e): "List[\(pythonType(e))]"
            }
        }

        // MARK: - Naming

        private mutating func uniqueName(_ base: String) -> String {
            let name = base.isEmpty ? "Object" : base
            if structs[name] == nil && !structOrder.contains(name) { return name }
            var i = 2
            while structs["\(name)\(i)"] != nil || structOrder.contains("\(name)\(i)") { i += 1 }
            return "\(name)\(i)"
        }

        private func isInteger(_ n: NSNumber) -> Bool {
            let type = CFNumberGetType(n)
            switch type {
            case .float32Type, .float64Type, .floatType, .doubleType, .cgFloatType: return false
            default: return n.doubleValue == n.doubleValue.rounded()
            }
        }
    }
}

// MARK: - Naming helpers

private func pascal(_ s: String) -> String {
    words(s).map { $0.prefix(1).uppercased() + $0.dropFirst() }.joined()
}
private func camel(_ s: String) -> String {
    let p = pascal(s)
    return p.prefix(1).lowercased() + p.dropFirst()
}
private func singular(_ s: String) -> String {
    if s.hasSuffix("ies") { return String(s.dropLast(3)) + "y" }
    if s.hasSuffix("ses") { return String(s.dropLast(2)) }
    if s.hasSuffix("s") && !s.hasSuffix("ss") { return String(s.dropLast()) }
    return s
}
private func words(_ s: String) -> [String] {
    s.split(whereSeparator: { $0 == "_" || $0 == "-" || $0 == " " }).flatMap { token -> [String] in
        // Split camelCase boundaries.
        var result: [String] = []
        var current = ""
        for (i, c) in token.enumerated() {
            if c.isUppercase, i > 0, let last = current.last, last.isLowercase {
                result.append(current); current = ""
            }
            current.append(c)
        }
        if !current.isEmpty { result.append(current) }
        return result.map { $0.lowercased() }
    }
}
