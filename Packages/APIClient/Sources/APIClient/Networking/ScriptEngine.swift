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

    // MARK: - Console Setup (multi-argument support)

    /// Sets up console.log/error/warn/info with proper multi-argument support
    /// like browser/Node.js: console.log("label:", value, "more:", value2)
    private static func setupConsole(_ jsContext: JSContext, logs: UnsafeMutablePointer<[ScriptConsoleOutput]>) {
        let nativeLog: @convention(block) (String) -> Void = { message in
            logs.pointee.append(ScriptConsoleOutput(message: message))
        }
        let nativeError: @convention(block) (String) -> Void = { message in
            logs.pointee.append(ScriptConsoleOutput(message: message, isError: true))
        }
        jsContext.setObject(nativeLog, forKeyedSubscript: "__nativeLog" as NSString)
        jsContext.setObject(nativeError, forKeyedSubscript: "__nativeError" as NSString)

        jsContext.evaluateScript("""
        var console = {
            log: function() {
                var parts = [];
                for (var i = 0; i < arguments.length; i++) {
                    var arg = arguments[i];
                    if (arg === null) parts.push('null');
                    else if (arg === undefined) parts.push('undefined');
                    else if (typeof arg === 'object') {
                        try { parts.push(JSON.stringify(arg)); } catch(e) { parts.push(String(arg)); }
                    } else parts.push(String(arg));
                }
                __nativeLog(parts.join(' '));
            },
            error: function() {
                var parts = [];
                for (var i = 0; i < arguments.length; i++) {
                    var arg = arguments[i];
                    if (arg === null) parts.push('null');
                    else if (arg === undefined) parts.push('undefined');
                    else if (typeof arg === 'object') {
                        try { parts.push(JSON.stringify(arg)); } catch(e) { parts.push(String(arg)); }
                    } else parts.push(String(arg));
                }
                __nativeError(parts.join(' '));
            },
            warn: function() { console.log.apply(null, arguments); },
            info: function() { console.log.apply(null, arguments); }
        };
        """)
    }

    private static func setupExceptionHandler(_ jsContext: JSContext, logs: UnsafeMutablePointer<[ScriptConsoleOutput]>) {
        jsContext.exceptionHandler = { _, exception in
            if let msg = exception?.toString() {
                logs.pointee.append(ScriptConsoleOutput(message: "Error: \(msg)", isError: true))
            }
        }
    }

    // MARK: - Pre-Script (with Postman compatibility)

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

        setupConsole(jsContext, logs: &logs)
        setupExceptionHandler(jsContext, logs: &logs)

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

    // MARK: - Pre-Script (legacy, no Postman compat)

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

        setupConsole(jsContext, logs: &logs)
        setupExceptionHandler(jsContext, logs: &logs)

        let req = JSValue(newObjectIn: jsContext)!
        req.setObject(context.requestMethod, forKeyedSubscript: "method" as NSString)
        req.setObject(context.requestURL, forKeyedSubscript: "url" as NSString)
        req.setObject(context.requestHeaders, forKeyedSubscript: "headers" as NSString)
        req.setObject(context.requestBody as Any, forKeyedSubscript: "body" as NSString)
        jsContext.setObject(req, forKeyedSubscript: "request" as NSString)

        jsContext.evaluateScript(script)

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

    // MARK: - Post-Script

    public static func runPostScript(
        _ script: String,
        context: ScriptContext
    ) -> [ScriptConsoleOutput] {
        guard !script.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let jsContext = JSContext()!
        var logs: [ScriptConsoleOutput] = []

        setupConsole(jsContext, logs: &logs)
        setupExceptionHandler(jsContext, logs: &logs)

        let req = JSValue(newObjectIn: jsContext)!
        req.setObject(context.requestMethod, forKeyedSubscript: "method" as NSString)
        req.setObject(context.requestURL, forKeyedSubscript: "url" as NSString)
        jsContext.setObject(req, forKeyedSubscript: "request" as NSString)

        let res = JSValue(newObjectIn: jsContext)!
        res.setObject(context.responseStatus as Any, forKeyedSubscript: "status" as NSString)
        res.setObject(context.responseBody as Any, forKeyedSubscript: "body" as NSString)
        res.setObject(context.responseHeaders as Any, forKeyedSubscript: "headers" as NSString)
        res.setObject(context.responseDuration as Any, forKeyedSubscript: "duration" as NSString)
        jsContext.setObject(res, forKeyedSubscript: "response" as NSString)

        let assertBlock: @convention(block) (Bool, String) -> Void = { condition, name in
            if condition {
                logs.append(ScriptConsoleOutput(message: "PASS: \(name)"))
            } else {
                logs.append(ScriptConsoleOutput(message: "FAIL: \(name)", isError: true))
            }
        }
        jsContext.setObject(assertBlock, forKeyedSubscript: "assert" as NSString)

        jsContext.evaluateScript(script)
        return logs
    }

    // MARK: - Rewrite Script

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

        setupConsole(jsContext, logs: &logs)
        setupExceptionHandler(jsContext, logs: &logs)

        // Load full Postman compat: CryptoJS, atob/btoa, TextEncoder, pm.environment
        PostmanCompat.setup(jsContext, context: context, envStore: sharedEnvStore)

        // Set up response object (mutable)
        let res = JSValue(newObjectIn: jsContext)!
        res.setObject(context.responseStatus as Any, forKeyedSubscript: "status" as NSString)
        res.setObject(context.responseHeaders as Any, forKeyedSubscript: "headers" as NSString)

        // Body as string (for encrypted Base64 responses)
        res.setObject(context.responseBody as Any, forKeyedSubscript: "body" as NSString)

        jsContext.setObject(res, forKeyedSubscript: "response" as NSString)

        jsContext.evaluateScript("""
        response.json = function() {
            return typeof response.body === 'string' ? JSON.parse(response.body) : response.body;
        };
        response.text = function() {
            return typeof response.body === 'string' ? response.body : JSON.stringify(response.body);
        };
        """)

        jsContext.evaluateScript(script)

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
