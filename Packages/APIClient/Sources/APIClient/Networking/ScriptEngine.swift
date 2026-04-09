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
}
