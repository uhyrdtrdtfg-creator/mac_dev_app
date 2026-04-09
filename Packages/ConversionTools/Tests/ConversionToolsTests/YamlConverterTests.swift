import Testing
import Foundation
@testable import ConversionTools

@Test func jsonToYamlSimple() {
    let json = #"{"name": "Alice", "age": 30}"#
    let result = YamlConverter.jsonToYaml(json)
    if case .success(let yaml) = result {
        #expect(yaml.contains("name: Alice"))
        #expect(yaml.contains("age: 30"))
    } else {
        Issue.record("Expected success")
    }
}

@Test func jsonToYamlNested() {
    let json = #"{"server": {"host": "localhost", "port": 8080}}"#
    let result = YamlConverter.jsonToYaml(json)
    if case .success(let yaml) = result {
        #expect(yaml.contains("server:"))
        #expect(yaml.contains("host: localhost"))
        #expect(yaml.contains("port: 8080"))
    } else {
        Issue.record("Expected success")
    }
}

@Test func jsonToYamlArray() {
    let json = #"{"items": ["a", "b", "c"]}"#
    let result = YamlConverter.jsonToYaml(json)
    if case .success(let yaml) = result {
        #expect(yaml.contains("items:"))
        #expect(yaml.contains("- a"))
        #expect(yaml.contains("- b"))
    } else {
        Issue.record("Expected success")
    }
}

@Test func yamlToJsonSimple() {
    let yaml = "name: Alice\nage: 30"
    let result = YamlConverter.yamlToJson(yaml)
    if case .success(let json) = result {
        #expect(json.contains("\"name\""))
        #expect(json.contains("\"Alice\""))
        #expect(json.contains("30"))
    } else {
        Issue.record("Expected success")
    }
}

@Test func yamlToJsonNested() {
    let yaml = "server:\n  host: localhost\n  port: 8080"
    let result = YamlConverter.yamlToJson(yaml)
    if case .success(let json) = result {
        #expect(json.contains("\"server\""))
        #expect(json.contains("\"host\""))
        #expect(json.contains("\"localhost\""))
    } else {
        Issue.record("Expected success")
    }
}

@Test func yamlToJsonArray() {
    let yaml = "items:\n  - a\n  - b\n  - c"
    let result = YamlConverter.yamlToJson(yaml)
    if case .success(let json) = result {
        #expect(json.contains("["))
        #expect(json.contains("\"a\""))
    } else {
        Issue.record("Expected success")
    }
}

@Test func roundTripJsonToYamlToJson() {
    let originalJson = #"{"database":{"host":"db.example.com","port":5432,"ssl":true},"name":"myapp","version":"1.0"}"#
    guard case .success(let yaml) = YamlConverter.jsonToYaml(originalJson) else { Issue.record("jsonToYaml failed"); return }
    guard case .success(let json) = YamlConverter.yamlToJson(yaml, prettyPrint: false) else { Issue.record("yamlToJson failed"); return }
    // Parse both to compare structure (not string equality due to formatting)
    let orig = try! JSONSerialization.jsonObject(with: originalJson.data(using: .utf8)!) as! [String: Any]
    let roundTripped = try! JSONSerialization.jsonObject(with: json.data(using: .utf8)!) as! [String: Any]
    #expect(orig["name"] as? String == roundTripped["name"] as? String)
    #expect((orig["database"] as? [String: Any])?["host"] as? String == (roundTripped["database"] as? [String: Any])?["host"] as? String)
}

@Test func invalidJsonError() {
    let result = YamlConverter.jsonToYaml("not json")
    if case .failure = result { /* expected */ } else { Issue.record("Expected failure") }
}

@Test func yamlBooleans() {
    let yaml = "enabled: true\ndisabled: false"
    let result = YamlConverter.yamlToJson(yaml)
    if case .success(let json) = result {
        #expect(json.contains("true"))
        #expect(json.contains("false"))
    } else {
        Issue.record("Expected success")
    }
}

@Test func yamlNull() {
    let yaml = "value: null\nother: ~"
    let result = YamlConverter.yamlToJson(yaml)
    if case .success(let json) = result {
        #expect(json.contains("null"))
    } else {
        Issue.record("Expected success")
    }
}
