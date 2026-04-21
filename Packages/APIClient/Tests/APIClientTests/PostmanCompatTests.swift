import Testing
import Foundation
@testable import APIClient

@Test func pmEnvironmentGetSet() {
    let ctx = ScriptContext(requestMethod: "GET", requestURL: "https://example.com", requestHeaders: [:])
    let script = """
    pm.environment.set("testKey", "testValue");
    var val = pm.environment.get("testKey");
    console.log("env: " + val);
    """
    let result = ScriptEngine.runPreScriptCompat(script, context: ctx)
    #expect(result.logs.contains { $0.message == "env: testValue" })
}

@Test func pmRequestBodyRead() {
    var ctx = ScriptContext(requestMethod: "POST", requestURL: "https://example.com", requestHeaders: [:])
    ctx.requestBody = "{\"name\":\"test\"}"
    let script = """
    var body = pm.request.body.raw;
    console.log("body: " + body);
    """
    let result = ScriptEngine.runPreScriptCompat(script, context: ctx)
    #expect(result.logs.contains { $0.message.contains("test") })
}

@Test func pmRequestBodyUpdate() {
    var ctx = ScriptContext(requestMethod: "POST", requestURL: "https://example.com", requestHeaders: [:])
    ctx.requestBody = "{}"
    let script = """
    pm.request.body.update({ mode: 'raw', raw: '{"modified":true}' });
    """
    let result = ScriptEngine.runPreScriptCompat(script, context: ctx)
    #expect(result.context.requestBody?.contains("modified") == true)
}

@Test func pmHeadersUpsert() {
    let ctx = ScriptContext(requestMethod: "GET", requestURL: "https://example.com", requestHeaders: [:])
    let script = """
    pm.request.headers.upsert({ key: "X-Custom", value: "hello" });
    pm.request.headers.upsert({ key: "Authorization", value: "Bearer token123" });
    """
    let result = ScriptEngine.runPreScriptCompat(script, context: ctx)
    #expect(result.context.requestHeaders["X-Custom"] == "hello")
    #expect(result.context.requestHeaders["Authorization"] == "Bearer token123")
}

@Test func cryptoJsSHA256() {
    let ctx = ScriptContext(requestMethod: "GET", requestURL: "https://example.com", requestHeaders: [:])
    let script = """
    var hash = CryptoJS.SHA256("hello");
    console.log("hash: " + hash.toString(CryptoJS.enc.Hex));
    """
    let result = ScriptEngine.runPreScriptCompat(script, context: ctx)
    #expect(result.logs.contains { $0.message.contains("2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824") })
}

@Test func cryptoJsHmacSHA256() {
    let ctx = ScriptContext(requestMethod: "GET", requestURL: "https://example.com", requestHeaders: [:])
    let script = """
    var hmac = CryptoJS.HmacSHA256("The quick brown fox jumps over the lazy dog", "key");
    console.log("hmac: " + hmac.toString(CryptoJS.enc.Hex));
    """
    let result = ScriptEngine.runPreScriptCompat(script, context: ctx)
    #expect(result.logs.contains { $0.message.contains("f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8") })
}

@Test func cryptoJsBase64() {
    let ctx = ScriptContext(requestMethod: "GET", requestURL: "https://example.com", requestHeaders: [:])
    let script = """
    var hmac = CryptoJS.HmacSHA256("test", "key");
    var b64 = CryptoJS.enc.Base64.stringify(hmac);
    console.log("b64: " + b64);
    """
    let result = ScriptEngine.runPreScriptCompat(script, context: ctx)
    #expect(result.logs.contains { $0.message.hasPrefix("b64: ") })
}

@Test func atobBtoa() {
    let ctx = ScriptContext(requestMethod: "GET", requestURL: "https://example.com", requestHeaders: [:])
    let script = """
    var encoded = btoa("Hello, World!");
    var decoded = atob(encoded);
    console.log("encoded: " + encoded);
    console.log("decoded: " + decoded);
    """
    let result = ScriptEngine.runPreScriptCompat(script, context: ctx)
    #expect(result.logs.contains { $0.message == "encoded: SGVsbG8sIFdvcmxkIQ==" })
    #expect(result.logs.contains { $0.message == "decoded: Hello, World!" })
}

@Test func pmVariablesReplaceIn() {
    let ctx = ScriptContext(requestMethod: "GET", requestURL: "https://example.com", requestHeaders: [:])
    let script = """
    pm.variables.set("host", "api.example.com");
    pm.variables.set("token", "abc123");
    var url = pm.variables.replaceIn("https://{{host}}/users?token={{token}}");
    console.log("url: " + url);
    var hasHost = pm.variables.has("host");
    console.log("hasHost: " + hasHost);
    var hostVal = pm.variables.get("host");
    console.log("hostVal: " + hostVal);
    """
    let result = ScriptEngine.runPreScriptCompat(script, context: ctx)
    #expect(result.logs.contains { $0.message == "url: https://api.example.com/users?token=abc123" })
    #expect(result.logs.contains { $0.message == "hasHost: true" })
    #expect(result.logs.contains { $0.message == "hostVal: api.example.com" })
}

@Test func pmRequestMethodAndUrl() {
    let ctx = ScriptContext(
        requestMethod: "POST",
        requestURL: "https://api.example.com/v1/users/123?name=test&age=25",
        requestHeaders: ["Content-Type": "application/json"]
    )
    let script = """
    console.log("method: " + pm.request.method);
    console.log("url: " + pm.request.url.toString());
    console.log("protocol: " + pm.request.url.protocol);
    console.log("host: " + pm.request.url.host);
    console.log("pathLength: " + pm.request.url.path.length);
    console.log("path0: " + pm.request.url.path[0]);
    console.log("path1: " + pm.request.url.path[1]);
    console.log("path2: " + pm.request.url.path[2]);
    """
    let result = ScriptEngine.runPreScriptCompat(script, context: ctx)
    #expect(result.logs.contains { $0.message == "method: POST" })
    #expect(result.logs.contains { $0.message == "url: https://api.example.com/v1/users/123?name=test&age=25" })
    #expect(result.logs.contains { $0.message == "protocol: https" })
    #expect(result.logs.contains { $0.message == "host: api.example.com" })
    #expect(result.logs.contains { $0.message == "pathLength: 3" })
    #expect(result.logs.contains { $0.message == "path0: v1" })
    #expect(result.logs.contains { $0.message == "path1: users" })
    #expect(result.logs.contains { $0.message == "path2: 123" })
}
