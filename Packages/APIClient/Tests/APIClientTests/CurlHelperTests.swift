import Testing
import Foundation
@testable import APIClient

@Test func curlExportGET() throws {
    let request = try HTTPClientService.buildURLRequest(method: .get, url: "https://api.example.com/users", headers: [], queryParams: [], body: nil, auth: nil)
    let curl = CurlHelper.export(request)
    #expect(curl.contains("https://api.example.com/users"))
    #expect(!curl.contains("-X")) // GET is default, no -X needed
}

@Test func curlExportPOST() throws {
    let body = RequestBody.json(#"{"name":"test"}"#)
    let request = try HTTPClientService.buildURLRequest(method: .post, url: "https://api.example.com/users", headers: [KeyValuePair(key: "Accept", value: "application/json")], queryParams: [], body: body, auth: nil)
    let curl = CurlHelper.export(request)
    #expect(curl.contains("-X POST"))
    #expect(curl.contains("-d"))
    #expect(curl.contains("name"))
}

@Test func curlParseSimple() {
    let result = CurlHelper.parse("curl 'https://api.example.com/users'")
    #expect(result?.url == "https://api.example.com/users")
    #expect(result?.method == "GET")
}

@Test func curlParsePOST() {
    let result = CurlHelper.parse("curl -X POST -H 'Content-Type: application/json' -d '{\"name\":\"test\"}' 'https://api.example.com/users'")
    #expect(result?.method == "POST")
    #expect(result?.url == "https://api.example.com/users")
    #expect(result?.headers.count == 1)
    #expect(result?.body?.contains("name") == true)
}

@Test func curlParseMultiline() {
    let curl = """
    curl -X PUT \
      -H 'Authorization: Bearer token123' \
      -H 'Content-Type: application/json' \
      -d '{"key":"value"}' \
      'https://api.example.com/resource'
    """
    let result = CurlHelper.parse(curl)
    #expect(result?.method == "PUT")
    #expect(result?.headers.count == 2)
}

@Test func curlParseInvalid() {
    #expect(CurlHelper.parse("not a curl command") == nil)
}
