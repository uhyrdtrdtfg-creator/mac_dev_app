import Testing
import Foundation
@testable import APIClient

@Test func keyValuePairCodable() throws {
    let pair = KeyValuePair(key: "Content-Type", value: "application/json", isEnabled: true)
    let data = try JSONEncoder().encode(pair)
    let decoded = try JSONDecoder().decode(KeyValuePair.self, from: data)
    #expect(decoded.key == "Content-Type")
    #expect(decoded.value == "application/json")
    #expect(decoded.isEnabled == true)
}

@Test func requestBodyJSONCodable() throws {
    let body = RequestBody.json(#"{"key": "value"}"#)
    let data = try JSONEncoder().encode(body)
    let decoded = try JSONDecoder().decode(RequestBody.self, from: data)
    if case .json(let str) = decoded { #expect(str == #"{"key": "value"}"#) }
    else { Issue.record("Expected .json case") }
}

@Test func authTypeBearerCodable() throws {
    let auth = AuthType.bearerToken("my-token")
    let data = try JSONEncoder().encode(auth)
    let decoded = try JSONDecoder().decode(AuthType.self, from: data)
    if case .bearerToken(let token) = decoded { #expect(token == "my-token") }
    else { Issue.record("Expected .bearerToken case") }
}

@Test func authTypeBasicCodable() throws {
    let auth = AuthType.basicAuth(username: "user", password: "pass")
    let data = try JSONEncoder().encode(auth)
    let decoded = try JSONDecoder().decode(AuthType.self, from: data)
    if case .basicAuth(let u, let p) = decoded { #expect(u == "user"); #expect(p == "pass") }
    else { Issue.record("Expected .basicAuth case") }
}

@Test func httpMethodAllCases() {
    #expect(HTTPMethod.allCases.count == 7)
}
