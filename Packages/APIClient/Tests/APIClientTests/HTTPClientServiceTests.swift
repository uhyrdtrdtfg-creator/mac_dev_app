import Testing
import Foundation
@testable import APIClient

@Test func buildURLRequestGET() throws {
    let request = try HTTPClientService.buildURLRequest(method: .get, url: "https://example.com/api?page=1", headers: [KeyValuePair(key: "Accept", value: "application/json")], queryParams: [], body: nil, auth: nil)
    #expect(request.httpMethod == "GET")
    #expect(request.url?.absoluteString == "https://example.com/api?page=1")
    #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
}

@Test func buildURLRequestPOSTJSON() throws {
    let body = RequestBody.json(#"{"name":"test"}"#)
    let request = try HTTPClientService.buildURLRequest(method: .post, url: "https://example.com/api", headers: [], queryParams: [], body: body, auth: nil)
    #expect(request.httpMethod == "POST")
    #expect(request.httpBody == Data(#"{"name":"test"}"#.utf8))
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
}

@Test func buildURLRequestWithBearerAuth() throws {
    let auth = AuthType.bearerToken("my-token-123")
    let request = try HTTPClientService.buildURLRequest(method: .get, url: "https://example.com/api", headers: [], queryParams: [], body: nil, auth: auth)
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer my-token-123")
}

@Test func buildURLRequestWithBasicAuth() throws {
    let auth = AuthType.basicAuth(username: "user", password: "pass")
    let request = try HTTPClientService.buildURLRequest(method: .get, url: "https://example.com/api", headers: [], queryParams: [], body: nil, auth: auth)
    let expected = "Basic " + Data("user:pass".utf8).base64EncodedString()
    #expect(request.value(forHTTPHeaderField: "Authorization") == expected)
}

@Test func buildURLRequestWithQueryParams() throws {
    let params = [KeyValuePair(key: "page", value: "1"), KeyValuePair(key: "limit", value: "20")]
    let request = try HTTPClientService.buildURLRequest(method: .get, url: "https://example.com/api", headers: [], queryParams: params, body: nil, auth: nil)
    let url = request.url!.absoluteString
    #expect(url.contains("page=1"))
    #expect(url.contains("limit=20"))
}

@Test func buildURLRequestDisabledHeader() throws {
    let headers = [KeyValuePair(key: "Accept", value: "application/json", isEnabled: true), KeyValuePair(key: "X-Debug", value: "true", isEnabled: false)]
    let request = try HTTPClientService.buildURLRequest(method: .get, url: "https://example.com/api", headers: headers, queryParams: [], body: nil, auth: nil)
    #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    #expect(request.value(forHTTPHeaderField: "X-Debug") == nil)
}

@Test func invalidURLThrows() {
    #expect(throws: HTTPClientError.self) {
        try HTTPClientService.buildURLRequest(method: .get, url: "", headers: [], queryParams: [], body: nil, auth: nil)
    }
}
