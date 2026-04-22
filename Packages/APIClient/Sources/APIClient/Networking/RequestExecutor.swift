import Foundation

public struct ExecutionResult: Sendable {
    public let response: HTTPResponse?
    public let error: String?
    public let consoleLogs: [ScriptConsoleOutput]
    public let assertionFailed: Bool
}

public enum RequestExecutor {

    /// Resolve {{variable}} templates with values from pm.environment
    private static func resolveTemplates(_ text: String, env: EnvironmentStore) -> String {
        var result = text
        let pattern = /\{\{([^}]+)\}\}/
        for match in text.matches(of: pattern) {
            let key = String(match.1).trimmingCharacters(in: .whitespaces)
            if let value = env.get(key) {
                result = result.replacingOccurrences(of: String(match.0), with: value)
            }
        }
        return result
    }

    public static func execute(
        method: HTTPMethod,
        url: String,
        headers: [KeyValuePair],
        queryParams: [KeyValuePair],
        body: RequestBody?,
        auth: AuthType?,
        preScript: String?,
        postScript: String?,
        rewriteScript: String?
    ) async -> ExecutionResult {
        var consoleLogs: [ScriptConsoleOutput] = []
        var assertionFailed = false

        do {
            var request = try HTTPClientService.buildURLRequest(
                method: method, url: url, headers: headers,
                queryParams: queryParams, body: body, auth: auth
            )

            // Run pre-request script
            if let preScript, !preScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // Build full URL with query params for script context
                let fullURL: String = {
                    let enabledParams = queryParams.filter { $0.isEnabled && !$0.key.isEmpty }
                    guard !enabledParams.isEmpty, var comps = URLComponents(string: url) else { return url }
                    let existingItems = comps.queryItems ?? []
                    let newItems = enabledParams.map { URLQueryItem(name: $0.key, value: $0.value) }
                    comps.queryItems = existingItems + newItems
                    return comps.string ?? url
                }()

                var scriptCtx = ScriptContext(
                    requestMethod: method.rawValue,
                    requestURL: fullURL,
                    requestHeaders: Dictionary(uniqueKeysWithValues: headers.filter(\.isEnabled).map { ($0.key, $0.value) })
                )
                if case .json(let json) = body { scriptCtx.requestBody = json }

                let preResult = ScriptEngine.runPreScriptCompat(preScript, context: scriptCtx)
                consoleLogs.append(contentsOf: preResult.logs)

                let updatedCtx = preResult.context
                let updatedMethod = HTTPMethod(rawValue: updatedCtx.requestMethod) ?? method
                let updatedHeaders = updatedCtx.requestHeaders.map { KeyValuePair(key: $0.key, value: $0.value) }
                let updatedBody: RequestBody? = updatedCtx.requestBody.map { .json($0) } ?? body
                request = try HTTPClientService.buildURLRequest(
                    method: updatedMethod, url: updatedCtx.requestURL,
                    headers: updatedHeaders, queryParams: [],
                    body: updatedBody, auth: nil
                )
            }

            // Resolve {{variable}} templates AFTER pre-script
            let envStore = ScriptEngine.getEnvironmentStore()
            if let finalHeaders = request.allHTTPHeaderFields {
                for (key, value) in finalHeaders {
                    let resolved = resolveTemplates(value, env: envStore)
                    if resolved != value {
                        request.setValue(resolved, forHTTPHeaderField: key)
                    }
                }
            }
            if let finalURL = request.url?.absoluteString {
                let resolvedURL = resolveTemplates(finalURL, env: envStore)
                if resolvedURL != finalURL, let newURL = URL(string: resolvedURL) {
                    request.url = newURL
                }
            }
            if let bodyData = request.httpBody, let bodyStr = String(data: bodyData, encoding: .utf8) {
                let resolvedBody = resolveTemplates(bodyStr, env: envStore)
                if resolvedBody != bodyStr {
                    request.httpBody = Data(resolvedBody.utf8)
                }
            }

            // Send
            let httpResponse = try await HTTPClientService.send(request)

            // Run post-request script
            if let postScript, !postScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let postCtx = ScriptContext(
                    requestMethod: method.rawValue,
                    requestURL: url,
                    requestHeaders: [:],
                    responseStatus: httpResponse.statusCode,
                    responseBody: String(data: httpResponse.body, encoding: .utf8),
                    responseHeaders: httpResponse.headers,
                    responseDuration: httpResponse.duration
                )
                let postLogs = ScriptEngine.runPostScript(postScript, context: postCtx)
                consoleLogs.append(contentsOf: postLogs)

                // Check for assertion failures
                if postLogs.contains(where: { $0.message.hasPrefix("FAIL:") }) {
                    assertionFailed = true
                }
            }

            // Run rewrite script
            var finalResponse = httpResponse
            if let rewriteScript, !rewriteScript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let bodyString = String(data: httpResponse.body, encoding: .utf8) ?? ""
                let rwCtx = ScriptContext(
                    requestMethod: method.rawValue,
                    requestURL: url,
                    requestHeaders: [:],
                    responseStatus: httpResponse.statusCode,
                    responseBody: bodyString,
                    responseHeaders: httpResponse.headers,
                    responseDuration: httpResponse.duration
                )
                let rwResult = ScriptEngine.runRewriteScript(rewriteScript, context: rwCtx)
                consoleLogs.append(contentsOf: rwResult.logs)

                let newStatus = rwResult.context.responseStatus ?? httpResponse.statusCode
                let newBody = Data((rwResult.context.responseBody ?? bodyString).utf8)
                let newHeaders = rwResult.context.responseHeaders ?? httpResponse.headers
                finalResponse = HTTPResponse(
                    statusCode: newStatus,
                    headers: newHeaders,
                    body: newBody,
                    duration: httpResponse.duration,
                    bodySize: newBody.count,
                    cookies: httpResponse.cookies
                )
            }

            return ExecutionResult(
                response: finalResponse,
                error: nil,
                consoleLogs: consoleLogs,
                assertionFailed: assertionFailed
            )

        } catch {
            return ExecutionResult(
                response: nil,
                error: error.localizedDescription,
                consoleLogs: consoleLogs,
                assertionFailed: false
            )
        }
    }
}
