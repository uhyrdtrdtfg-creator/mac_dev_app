import Foundation
import JavaScriptCore

public struct ScriptConsoleOutput: Identifiable, Sendable {
    public let id = UUID()
    public let message: String
    public let isError: Bool
    public let timestamp: Date

    public init(message: String, isError: Bool = false) {
        self.message = message
        self.isError = isError
        self.timestamp = Date()
    }
}

public struct ScriptContext: Sendable {
    public var requestMethod: String
    public var requestURL: String
    public var requestHeaders: [String: String]
    public var requestBody: String?
    public var responseStatus: Int?
    public var responseBody: String?
    public var responseHeaders: [String: String]?
    public var responseDuration: Double?

    public init(
        requestMethod: String,
        requestURL: String,
        requestHeaders: [String: String],
        requestBody: String? = nil,
        responseStatus: Int? = nil,
        responseBody: String? = nil,
        responseHeaders: [String: String]? = nil,
        responseDuration: Double? = nil
    ) {
        self.requestMethod = requestMethod
        self.requestURL = requestURL
        self.requestHeaders = requestHeaders
        self.requestBody = requestBody
        self.responseStatus = responseStatus
        self.responseBody = responseBody
        self.responseHeaders = responseHeaders
        self.responseDuration = responseDuration
    }
}

public enum ScriptEngine {
    /// Shared environment store for pm.environment across script executions
    nonisolated(unsafe) private static var sharedEnvStore = EnvironmentStore()

    public static func setEnvironment(_ env: [String: String]) {
        sharedEnvStore = EnvironmentStore(env)
    }

    public static func getEnvironmentStore() -> EnvironmentStore {
        return sharedEnvStore
    }

    /// Run a pre-script with Postman compatibility (pm, CryptoJS, polyfills)
    public static func runPreScriptCompat(
        _ script: String,
        context: ScriptContext
    ) -> (context: ScriptContext, logs: [ScriptConsoleOutput]) {
        guard !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (context, [])
        }

        let jsContext = JSContext()!
        var logs: [ScriptConsoleOutput] = []
        var updatedContext = context

        // Set up console.log / console.error
        let consoleLog: @convention(block) (String) -> Void = { message in
            logs.append(ScriptConsoleOutput(message: message))
        }
        let consoleError: @convention(block) (String) -> Void = { message in
            logs.append(ScriptConsoleOutput(message: message, isError: true))
        }

        let console = JSValue(newObjectIn: jsContext)!
        console.setObject(consoleLog, forKeyedSubscript: "log" as NSString)
        console.setObject(consoleError, forKeyedSubscript: "error" as NSString)
        jsContext.setObject(console, forKeyedSubscript: "console" as NSString)

        // Exception handler
        jsContext.exceptionHandler = { _, exception in
            if let msg = exception?.toString() {
                logs.append(ScriptConsoleOutput(message: "Error: \(msg)", isError: true))
            }
        }

        // Inject Postman compat: pm object, CryptoJS, atob/btoa, TextEncoder, crypto
        PostmanCompat.setup(jsContext, context: context, envStore: sharedEnvStore)

        // Also set up the legacy request/response objects for backward compat
        let req = JSValue(newObjectIn: jsContext)!
        req.setObject(context.requestMethod, forKeyedSubscript: "method" as NSString)
        req.setObject(context.requestURL, forKeyedSubscript: "url" as NSString)
        req.setObject(context.requestHeaders, forKeyedSubscript: "headers" as NSString)
        req.setObject(context.requestBody as Any, forKeyedSubscript: "body" as NSString)
        jsContext.setObject(req, forKeyedSubscript: "request" as NSString)

        // Execute
        jsContext.evaluateScript(script)

        // Read back from pm.request if pm was used
        let pmState = PostmanCompat.readBackState(jsContext)
        if let pmBody = pmState.body, pmBody != "undefined" {
            updatedContext.requestBody = pmBody
        }
        if !pmState.headers.isEmpty {
            updatedContext.requestHeaders.merge(pmState.headers) { _, new in new }
        }

        // Also read back from legacy request object (only apply if script actually modified it)
        if let reqObj = jsContext.objectForKeyedSubscript("request") {
            if let method = reqObj.objectForKeyedSubscript("method")?.toString(),
               method != "undefined", method != context.requestMethod {
                updatedContext.requestMethod = method
            }
            if let url = reqObj.objectForKeyedSubscript("url")?.toString(),
               url != "undefined", url != context.requestURL {
                updatedContext.requestURL = url
            }
            if let headers = reqObj.objectForKeyedSubscript("headers")?.toDictionary() as? [String: String],
               headers != context.requestHeaders {
                updatedContext.requestHeaders.merge(headers) { _, new in new }
            }
            if let body = reqObj.objectForKeyedSubscript("body")?.toString(),
               body != "undefined", body != (context.requestBody ?? "") {
                updatedContext.requestBody = body
            }
        }

        return (updatedContext, logs)
    }

    public static func runPreScript(
        _ script: String,
        context: ScriptContext
    ) -> (context: ScriptContext, logs: [ScriptConsoleOutput]) {
        guard !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (context, [])
        }

        let jsContext = JSContext()!
        var logs: [ScriptConsoleOutput] = []
        var updatedContext = context

        // Set up console.log / console.error
        let consoleLog: @convention(block) (String) -> Void = { message in
            logs.append(ScriptConsoleOutput(message: message))
        }
        let consoleError: @convention(block) (String) -> Void = { message in
            logs.append(ScriptConsoleOutput(message: message, isError: true))
        }

        let console = JSValue(newObjectIn: jsContext)!
        console.setObject(consoleLog, forKeyedSubscript: "log" as NSString)
        console.setObject(consoleError, forKeyedSubscript: "error" as NSString)
        jsContext.setObject(console, forKeyedSubscript: "console" as NSString)

        // Set up request object
        let req = JSValue(newObjectIn: jsContext)!
        req.setObject(context.requestMethod, forKeyedSubscript: "method" as NSString)
        req.setObject(context.requestURL, forKeyedSubscript: "url" as NSString)
        req.setObject(context.requestHeaders, forKeyedSubscript: "headers" as NSString)
        req.setObject(context.requestBody as Any, forKeyedSubscript: "body" as NSString)
        jsContext.setObject(req, forKeyedSubscript: "request" as NSString)

        // Exception handler
        jsContext.exceptionHandler = { _, exception in
            if let msg = exception?.toString() {
                logs.append(ScriptConsoleOutput(message: "Error: \(msg)", isError: true))
            }
        }

        // Execute
        jsContext.evaluateScript(script)

        // Read back modified request
        if let reqObj = jsContext.objectForKeyedSubscript("request") {
            if let method = reqObj.objectForKeyedSubscript("method")?.toString(), method != "undefined" {
                updatedContext.requestMethod = method
            }
            if let url = reqObj.objectForKeyedSubscript("url")?.toString(), url != "undefined" {
                updatedContext.requestURL = url
            }
            if let headers = reqObj.objectForKeyedSubscript("headers")?.toDictionary() as? [String: String] {
                updatedContext.requestHeaders = headers
            }
            if let body = reqObj.objectForKeyedSubscript("body")?.toString(), body != "undefined" {
                updatedContext.requestBody = body
            }
        }

        return (updatedContext, logs)
    }

    public static func runPostScript(
        _ script: String,
        context: ScriptContext
    ) -> [ScriptConsoleOutput] {
        guard !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let jsContext = JSContext()!
        var logs: [ScriptConsoleOutput] = []

        // Console
        let consoleLog: @convention(block) (String) -> Void = { message in
            logs.append(ScriptConsoleOutput(message: message))
        }
        let consoleError: @convention(block) (String) -> Void = { message in
            logs.append(ScriptConsoleOutput(message: message, isError: true))
        }

        let console = JSValue(newObjectIn: jsContext)!
        console.setObject(consoleLog, forKeyedSubscript: "log" as NSString)
        console.setObject(consoleError, forKeyedSubscript: "error" as NSString)
        jsContext.setObject(console, forKeyedSubscript: "console" as NSString)

        // Request object (read-only context)
        let req = JSValue(newObjectIn: jsContext)!
        req.setObject(context.requestMethod, forKeyedSubscript: "method" as NSString)
        req.setObject(context.requestURL, forKeyedSubscript: "url" as NSString)
        jsContext.setObject(req, forKeyedSubscript: "request" as NSString)

        // Response object
        let res = JSValue(newObjectIn: jsContext)!
        res.setObject(context.responseStatus as Any, forKeyedSubscript: "status" as NSString)
        res.setObject(context.responseBody as Any, forKeyedSubscript: "body" as NSString)
        res.setObject(context.responseHeaders as Any, forKeyedSubscript: "headers" as NSString)
        res.setObject(context.responseDuration as Any, forKeyedSubscript: "duration" as NSString)
        jsContext.setObject(res, forKeyedSubscript: "response" as NSString)

        // Simple test/assert helpers
        let testPass: @convention(block) (String) -> Void = { name in
            logs.append(ScriptConsoleOutput(message: "PASS: \(name)"))
        }
        let testFail: @convention(block) (String) -> Void = { name in
            logs.append(ScriptConsoleOutput(message: "FAIL: \(name)", isError: true))
        }
        jsContext.setObject(testPass, forKeyedSubscript: "pass" as NSString)
        jsContext.setObject(testFail, forKeyedSubscript: "fail" as NSString)

        // assert(condition, name) helper
        let assertBlock: @convention(block) (Bool, String) -> Void = { condition, name in
            if condition {
                logs.append(ScriptConsoleOutput(message: "PASS: \(name)"))
            } else {
                logs.append(ScriptConsoleOutput(message: "FAIL: \(name)", isError: true))
            }
        }
        jsContext.setObject(assertBlock, forKeyedSubscript: "assert" as NSString)

        // Exception handler
        jsContext.exceptionHandler = { _, exception in
            if let msg = exception?.toString() {
                logs.append(ScriptConsoleOutput(message: "Error: \(msg)", isError: true))
            }
        }

        jsContext.evaluateScript(script)
        return logs
    }

    /// Run a rewrite script that can modify the response body, status, and headers.
    /// Returns the modified context and logs.
    public static func runRewriteScript(
        _ script: String,
        context: ScriptContext
    ) -> (context: ScriptContext, logs: [ScriptConsoleOutput]) {
        guard !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return (context, [])
        }

        let jsContext = JSContext()!
        var logs: [ScriptConsoleOutput] = []
        var updatedContext = context

        // Console
        let consoleLog: @convention(block) (String) -> Void = { message in
            logs.append(ScriptConsoleOutput(message: message))
        }
        let consoleError: @convention(block) (String) -> Void = { message in
            logs.append(ScriptConsoleOutput(message: message, isError: true))
        }
        let console = JSValue(newObjectIn: jsContext)!
        console.setObject(consoleLog, forKeyedSubscript: "log" as NSString)
        console.setObject(consoleError, forKeyedSubscript: "error" as NSString)
        jsContext.setObject(console, forKeyedSubscript: "console" as NSString)

        // Response object (mutable)
        let res = JSValue(newObjectIn: jsContext)!
        res.setObject(context.responseStatus as Any, forKeyedSubscript: "status" as NSString)
        res.setObject(context.responseHeaders as Any, forKeyedSubscript: "headers" as NSString)

        // Parse body as JSON if possible, otherwise set as string
        if let bodyString = context.responseBody,
           let bodyData = bodyString.data(using: .utf8),
           let jsonObj = try? JSONSerialization.jsonObject(with: bodyData) {
            res.setObject(jsonObj, forKeyedSubscript: "body" as NSString)
        } else {
            res.setObject(context.responseBody as Any, forKeyedSubscript: "body" as NSString)
        }

        jsContext.setObject(res, forKeyedSubscript: "response" as NSString)

        // Helper: JSON.stringify available by default in JSC
        // Helper: response.json() to get parsed body
        jsContext.evaluateScript("""
        response.json = function() {
            return typeof response.body === 'string' ? JSON.parse(response.body) : response.body;
        };
        """)

        // Exception handler
        jsContext.exceptionHandler = { _, exception in
            if let msg = exception?.toString() {
                logs.append(ScriptConsoleOutput(message: "Error: \(msg)", isError: true))
            }
        }

        // Execute user script
        jsContext.evaluateScript(script)

        // Read back modified response
        if let resObj = jsContext.objectForKeyedSubscript("response") {
            if let status = resObj.objectForKeyedSubscript("status"), !status.isUndefined, !status.isNull {
                updatedContext.responseStatus = Int(status.toInt32())
            }
            if let headers = resObj.objectForKeyedSubscript("headers")?.toDictionary() as? [String: String] {
                updatedContext.responseHeaders = headers
            }
            if let bodyVal = resObj.objectForKeyedSubscript("body") {
                if bodyVal.isString {
                    updatedContext.responseBody = bodyVal.toString()
                } else if !bodyVal.isUndefined && !bodyVal.isNull {
                    // Object/Array — serialize back to JSON string
                    if let jsonData = try? JSONSerialization.data(
                        withJSONObject: bodyVal.toObject() as Any,
                        options: [.prettyPrinted, .sortedKeys]
                    ), let jsonStr = String(data: jsonData, encoding: .utf8) {
                        updatedContext.responseBody = jsonStr
                    }
                }
            }
        }

        return (updatedContext, logs)
    }
}
