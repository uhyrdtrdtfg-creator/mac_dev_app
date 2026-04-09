import Testing
import Foundation
@testable import APIClient

@Test func preScriptConsoleLog() {
    let ctx = ScriptContext(requestMethod: "GET", requestURL: "https://example.com", requestHeaders: [:])
    let result = ScriptEngine.runPreScript("console.log('hello from pre-script')", context: ctx)
    #expect(result.logs.count == 1)
    #expect(result.logs[0].message == "hello from pre-script")
    #expect(result.logs[0].isError == false)
}

@Test func preScriptModifyURL() {
    let ctx = ScriptContext(requestMethod: "GET", requestURL: "https://example.com", requestHeaders: [:])
    let result = ScriptEngine.runPreScript("request.url = 'https://modified.com'", context: ctx)
    #expect(result.context.requestURL == "https://modified.com")
}

@Test func preScriptModifyHeader() {
    let ctx = ScriptContext(requestMethod: "GET", requestURL: "https://example.com", requestHeaders: ["Accept": "text/html"])
    let script = "request.headers['Authorization'] = 'Bearer token123'"
    let result = ScriptEngine.runPreScript(script, context: ctx)
    #expect(result.context.requestHeaders["Authorization"] == "Bearer token123")
}

@Test func postScriptAssertPass() {
    var ctx = ScriptContext(requestMethod: "GET", requestURL: "https://example.com", requestHeaders: [:])
    ctx.responseStatus = 200
    ctx.responseBody = #"{"ok":true}"#
    let logs = ScriptEngine.runPostScript("assert(response.status === 200, 'Status is 200')", context: ctx)
    #expect(logs.count == 1)
    #expect(logs[0].message.contains("PASS"))
}

@Test func postScriptAssertFail() {
    var ctx = ScriptContext(requestMethod: "GET", requestURL: "https://example.com", requestHeaders: [:])
    ctx.responseStatus = 404
    let logs = ScriptEngine.runPostScript("assert(response.status === 200, 'Status should be 200')", context: ctx)
    #expect(logs.count == 1)
    #expect(logs[0].message.contains("FAIL"))
    #expect(logs[0].isError == true)
}

@Test func emptyScriptNoLogs() {
    let ctx = ScriptContext(requestMethod: "GET", requestURL: "https://example.com", requestHeaders: [:])
    let result = ScriptEngine.runPreScript("", context: ctx)
    #expect(result.logs.isEmpty)
}

@Test func scriptSyntaxError() {
    let ctx = ScriptContext(requestMethod: "GET", requestURL: "https://example.com", requestHeaders: [:])
    let result = ScriptEngine.runPreScript("this is not valid javascript!!!", context: ctx)
    #expect(result.logs.contains { $0.isError })
}
