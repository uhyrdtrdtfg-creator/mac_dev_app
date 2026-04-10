import Foundation
import SwiftData

@MainActor
public final class ChainRunnerService {

    public static func run(
        chain: ChainModel,
        savedRequests: [SavedRequestModel],
        result: ChainRunResult
    ) async {
        result.reset()
        result.startedAt = Date()

        // Clear environment for a clean chain execution
        ScriptEngine.setEnvironment([:])

        let sortedSteps = chain.sortedSteps

        for (index, step) in sortedSteps.enumerated() {
            result.status = .running(currentStep: index)

            // Find the saved request
            guard let savedRequest = savedRequests.first(where: { $0.id == step.savedRequestId }) else {
                let stepResult = StepResult(
                    stepOrder: index,
                    requestName: "(deleted)",
                    requestMethod: "?",
                    requestURL: "?",
                    responseStatus: nil,
                    duration: nil,
                    error: "Saved request not found (may have been deleted)",
                    httpResponse: nil,
                    consoleLogs: ""
                )
                result.stepResults.append(stepResult)
                result.status = .failed(atStep: index)
                result.finishedAt = Date()
                return
            }

            // Inject per-step variables into environment
            let stepVars = step.variables.filter { $0.isEnabled && !$0.key.isEmpty }
            let envStore = ScriptEngine.getEnvironmentStore()
            for pair in stepVars {
                envStore.set(pair.key, pair.value)
            }

            // Restore request parameters from SavedRequest
            let method = HTTPMethod(rawValue: savedRequest.method) ?? .get
            let headers = savedRequest.headers.isEmpty ? [KeyValuePair()] : savedRequest.headers
            let body = savedRequest.body
            let preScript = savedRequest.preScript
            let postScript = savedRequest.postScript
            let rewriteScript = savedRequest.rewriteScript

            // Execute the request
            let execResult = await RequestExecutor.execute(
                method: method,
                url: savedRequest.url,
                headers: headers,
                queryParams: [],
                body: body,
                auth: nil,
                preScript: preScript,
                postScript: postScript,
                rewriteScript: rewriteScript
            )

            let logsText = execResult.consoleLogs.map(\.message).joined(separator: "\n")

            let stepResult = StepResult(
                stepOrder: index,
                requestName: savedRequest.name,
                requestMethod: method.rawValue,
                requestURL: savedRequest.url,
                responseStatus: execResult.response?.statusCode,
                duration: execResult.response?.duration,
                error: execResult.error ?? (execResult.assertionFailed ? "Assertion failed" : nil),
                httpResponse: execResult.response,
                consoleLogs: logsText
            )
            result.stepResults.append(stepResult)

            // Stop on failure
            if execResult.error != nil || execResult.assertionFailed {
                result.status = .failed(atStep: index)
                result.finishedAt = Date()
                return
            }
        }

        result.status = .completed
        result.finishedAt = Date()
    }
}
