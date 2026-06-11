import Testing
import Foundation
@testable import APIClient

private let chromeHAR = #"""
{
  "log": {
    "version": "1.2",
    "creator": { "name": "WebInspector", "version": "537.36" },
    "pages": [
      { "startedDateTime": "2026-01-15T10:00:00.000Z", "id": "page_1", "title": "Example", "pageTimings": {} }
    ],
    "entries": [
      {
        "startedDateTime": "2026-01-15T10:00:01.234Z",
        "time": 123.45,
        "request": {
          "method": "GET",
          "url": "https://api.example.com/v1/users?page=2&limit=10",
          "httpVersion": "http/2.0",
          "headers": [
            { "name": ":authority", "value": "api.example.com" },
            { "name": ":method", "value": "GET" },
            { "name": "accept", "value": "application/json" },
            { "name": "cookie", "value": "session=abc123; theme=dark" },
            { "name": "content-length", "value": "0" }
          ],
          "queryString": [
            { "name": "page", "value": "2" },
            { "name": "limit", "value": "10" }
          ],
          "cookies": [{ "name": "session", "value": "abc123" }],
          "headersSize": -1,
          "bodySize": 0
        },
        "response": {
          "status": 200,
          "statusText": "OK",
          "httpVersion": "http/2.0",
          "headers": [{ "name": "content-type", "value": "application/json; charset=utf-8" }],
          "cookies": [],
          "content": { "size": 12, "mimeType": "application/json", "text": "{\"users\":[]}" },
          "redirectURL": "",
          "headersSize": -1,
          "bodySize": 12
        },
        "cache": {},
        "timings": { "blocked": 1, "dns": 0, "connect": 0, "send": 0.1, "wait": 100, "receive": 3 }
      },
      {
        "startedDateTime": "2026-01-15T10:00:02.000Z",
        "time": 88,
        "request": {
          "method": "POST",
          "url": "https://api.example.com/v1/messages",
          "httpVersion": "http/2.0",
          "headers": [
            { "name": "content-type", "value": "application/json" }
          ],
          "queryString": [],
          "postData": {
            "mimeType": "application/json",
            "text": "{\"text\":\"héllo 你好 🚀\"}"
          },
          "headersSize": -1,
          "bodySize": 30
        },
        "response": {
          "status": 201,
          "statusText": "Created",
          "headers": [],
          "content": { "size": 0, "mimeType": "" },
          "redirectURL": "",
          "headersSize": -1,
          "bodySize": 0
        },
        "cache": {},
        "timings": { "send": 0, "wait": 88, "receive": 0 }
      },
      {
        "startedDateTime": null,
        "time": null,
        "request": {
          "method": null,
          "url": "http://example.com/min",
          "httpVersion": null,
          "headers": null,
          "queryString": null,
          "postData": null
        },
        "response": null
      },
      {
        "request": { "method": "GET", "url": "data:text/plain;base64,aGVsbG8=" },
        "response": { "status": 200 }
      },
      {
        "request": { "method": "GET", "url": "ws://example.com/socket" }
      }
    ]
  }
}
"""#

@Test func harDecodeChromeFixture() throws {
    let har = try HARCodec.decode(Data(chromeHAR.utf8))
    #expect(har.entries.count == 3)

    let get = har.entries[0]
    #expect(get.method == "GET")
    #expect(get.url == "https://api.example.com/v1/users?page=2&limit=10")
    #expect(get.httpVersion == "http/2.0")
    #expect(get.headers.contains { $0.name == "cookie" && $0.value.contains("session=abc123") })
    #expect(get.queryString.count == 2)
    #expect(get.response?.status == 200)
    #expect(get.response?.statusText == "OK")
    #expect(get.response?.contentText == #"{"users":[]}"#)
    #expect(get.response?.contentMimeType == "application/json")
    #expect(get.time == 123.45)
    #expect(get.startedDateTime != nil)

    let post = har.entries[1]
    #expect(post.method == "POST")
    #expect(post.postData?.mimeType == "application/json")
    #expect(post.postData?.text == "{\"text\":\"héllo 你好 🚀\"}")

    let minimal = har.entries[2]
    #expect(minimal.method == "GET")
    #expect(minimal.httpVersion == "HTTP/1.1")
    #expect(minimal.headers.isEmpty)
    #expect(minimal.queryString.isEmpty)
    #expect(minimal.postData == nil)
    #expect(minimal.response == nil)
    #expect(minimal.startedDateTime == nil)
}

@Test func harMapNoDoubleQueryParams() throws {
    let har = try HARCodec.decode(Data(chromeHAR.utf8))
    let mapped = HARCodec.mapToRequests(har)
    #expect(mapped[0].url == "https://api.example.com/v1/users?page=2&limit=10")
    let items = URLComponents(string: mapped[0].url)?.queryItems ?? []
    #expect(items.count == 2)
}

@Test func harMapDropsPseudoHeadersKeepsCookies() throws {
    let har = try HARCodec.decode(Data(chromeHAR.utf8))
    let mapped = HARCodec.mapToRequests(har)
    let keys = mapped[0].headers.map { $0.key.lowercased() }
    #expect(!keys.contains(":authority"))
    #expect(!keys.contains(":method"))
    #expect(!keys.contains("content-length"))
    #expect(keys.contains("cookie"))
    #expect(keys.contains("accept"))
}

@Test func harMapJSONBodyAndName() throws {
    let har = try HARCodec.decode(Data(chromeHAR.utf8))
    let mapped = HARCodec.mapToRequests(har)
    #expect(mapped[1].name == "POST /v1/messages")
    #expect(mapped[1].method == .post)
    if case .json(let text)? = mapped[1].body {
        #expect(text == "{\"text\":\"héllo 你好 🚀\"}")
    } else {
        Issue.record("Expected .json body")
    }
    #expect(mapped[2].body == nil)
}

@Test func harMapAppendsMissingQueryOnce() throws {
    let json = #"""
    {"log":{"entries":[{"request":{"method":"GET","url":"https://example.com/search","queryString":[{"name":"q","value":"swift"},{"name":"page","value":"1"}]}}]}}
    """#
    let mapped = HARCodec.mapToRequests(try HARCodec.decode(Data(json.utf8)))
    #expect(mapped[0].url == "https://example.com/search?q=swift&page=1")
}

@Test func harMapFormURLEncodedParams() throws {
    let json = #"""
    {"log":{"entries":[{"request":{"method":"POST","url":"https://example.com/login","postData":{"mimeType":"application/x-www-form-urlencoded","text":"user=bob&pass=x","params":[{"name":"user","value":"bob"},{"name":"pass","value":"x"}]}}}]}}
    """#
    let mapped = HARCodec.mapToRequests(try HARCodec.decode(Data(json.utf8)))
    if case .formData(let pairs)? = mapped[0].body {
        #expect(pairs.map(\.key) == ["user", "pass"])
        #expect(pairs.map(\.value) == ["bob", "x"])
    } else {
        Issue.record("Expected .formData body")
    }
}

@Test func harMapFormURLEncodedWithoutParamsFallsBackToRaw() throws {
    let json = #"""
    {"log":{"entries":[{"request":{"method":"POST","url":"https://example.com/login","postData":{"mimeType":"application/x-www-form-urlencoded","text":"user=bob&pass=x"}}}]}}
    """#
    let mapped = HARCodec.mapToRequests(try HARCodec.decode(Data(json.utf8)))
    if case .raw(let text)? = mapped[0].body {
        #expect(text == "user=bob&pass=x")
    } else {
        Issue.record("Expected .raw body")
    }
}

@Test func harExportHistoryRoundtrip() throws {
    let item = HTTPHistoryModel(requestMethod: "POST", requestURL: "https://api.example.com/v1/items", responseStatus: 201, duration: 0.345, responseSize: 19)
    item.requestHeadersJSON = try JSONEncoder().encode([
        KeyValuePair(key: "Content-Type", value: "application/json"),
        KeyValuePair(key: "X-Token", value: "abc")
    ])
    item.queryParamsJSON = try JSONEncoder().encode([KeyValuePair(key: "verbose", value: "1")])
    item.bodyType = "JSON"
    item.requestBodyJSON = Data(#"{"name":"héllo"}"#.utf8)
    item.responseBody = Data(#"{"id":42,"ok":true}"#.utf8)
    item.responseHeadersJSON = try JSONEncoder().encode([KeyValuePair(key: "Content-Type", value: "application/json; charset=utf-8")])

    let data = HARCodec.encode(requests: [], historyEntries: [item])
    let decoded = try HARCodec.decode(data)
    #expect(decoded.entries.count == 1)
    let entry = decoded.entries[0]
    #expect(entry.method == "POST")
    #expect(entry.url == "https://api.example.com/v1/items?verbose=1")
    #expect(entry.httpVersion == "HTTP/1.1")
    #expect(entry.queryString.contains { $0.name == "verbose" && $0.value == "1" })
    #expect(entry.headers.contains { $0.name == "X-Token" && $0.value == "abc" })
    #expect(entry.postData?.mimeType == "application/json")
    #expect(entry.postData?.text == #"{"name":"héllo"}"#)
    #expect(entry.response?.status == 201)
    #expect(entry.response?.statusText == "Created")
    #expect(entry.response?.contentMimeType == "application/json; charset=utf-8")
    #expect(entry.response?.contentText == #"{"id":42,"ok":true}"#)
    let time = try #require(entry.time)
    #expect(abs(time - 345) < 0.01)
    let started = try #require(entry.startedDateTime)
    #expect(abs(started.timeIntervalSince(item.executedAt)) < 0.01)

    let obj = try JSONSerialization.jsonObject(with: data) as? [String: Any]
    let log = obj?["log"] as? [String: Any]
    #expect(log?["version"] as? String == "1.2")
    #expect((log?["creator"] as? [String: Any])?["name"] as? String == "DevToolkit")
}

@Test func harExportFormDataHistoryMapsBack() throws {
    let item = HTTPHistoryModel(requestMethod: "POST", requestURL: "https://example.com/login", responseStatus: 200, duration: 0.1, responseSize: 2)
    item.bodyType = "Form Data"
    item.formDataJSON = try JSONEncoder().encode([
        KeyValuePair(key: "user", value: "bob"),
        KeyValuePair(key: "pass", value: "s3cret")
    ])
    let decoded = try HARCodec.decode(HARCodec.encode(requests: [], historyEntries: [item]))
    let mapped = HARCodec.mapToRequests(decoded)
    #expect(mapped.count == 1)
    if case .formData(let pairs)? = mapped[0].body {
        #expect(pairs.map(\.key) == ["user", "pass"])
        #expect(pairs.map(\.value) == ["bob", "s3cret"])
    } else {
        Issue.record("Expected .formData body")
    }
}

@Test func harExportSavedRequestMinimalResponse() throws {
    let saved = SavedRequestModel(name: "Create user", method: "POST", url: "https://api.example.com/users?source=app")
    saved.headers = [KeyValuePair(key: "Content-Type", value: "application/json")]
    saved.body = .json(#"{"a":1}"#)
    saved.bodyType = "json"

    let decoded = try HARCodec.decode(HARCodec.encode(requests: [saved], historyEntries: []))
    #expect(decoded.entries.count == 1)
    let entry = decoded.entries[0]
    #expect(entry.method == "POST")
    #expect(entry.url == "https://api.example.com/users?source=app")
    #expect(entry.queryString.contains { $0.name == "source" && $0.value == "app" })
    #expect(entry.postData?.text == #"{"a":1}"#)
    #expect(entry.response?.status == 0)
}

@Test func harMalformedJSONThrowsClearError() {
    #expect(throws: HARCodecError.self) {
        _ = try HARCodec.decode(Data("not a har {".utf8))
    }
    do {
        _ = try HARCodec.decode(Data("[1,2,3]".utf8))
        Issue.record("Expected decode to throw")
    } catch {
        #expect(error.localizedDescription.contains("Invalid HAR file"))
    }
}

@Test func harEmptyEntriesOK() throws {
    let json = #"{"log":{"version":"1.2","creator":{"name":"x","version":"1"},"entries":[]}}"#
    let har = try HARCodec.decode(Data(json.utf8))
    #expect(har.entries.isEmpty)
    #expect(HARCodec.mapToRequests(har).isEmpty)

    let noEntries = try HARCodec.decode(Data(#"{"log":{"version":"1.2"}}"#.utf8))
    #expect(noEntries.entries.isEmpty)
}

@Test func harLargeBodyRoundtrip() throws {
    let big = String(repeating: "a", count: 1_000_000)
    let item = HTTPHistoryModel(requestMethod: "GET", requestURL: "https://example.com/big", responseStatus: 200, duration: 1.0, responseSize: big.utf8.count)
    item.responseBody = Data(big.utf8)
    let decoded = try HARCodec.decode(HARCodec.encode(requests: [], historyEntries: [item]))
    #expect(decoded.entries[0].response?.contentText?.count == 1_000_000)
}
