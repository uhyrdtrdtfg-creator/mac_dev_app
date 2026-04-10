import Foundation

public enum ChainRunStatus: Equatable {
    case idle
    case running(currentStep: Int)
    case completed
    case failed(atStep: Int)
}

public struct StepResult: Identifiable {
    public let id = UUID()
    public let stepOrder: Int
    public let requestName: String
    public let requestMethod: String
    public let requestURL: String
    public let responseStatus: Int?
    public let duration: TimeInterval?
    public let error: String?
    public let httpResponse: HTTPResponse?
    public let consoleLogs: String
}

@MainActor
@Observable
public final class ChainRunResult {
    public var stepResults: [StepResult] = []
    public var startedAt: Date?
    public var finishedAt: Date?
    public var status: ChainRunStatus = .idle

    public init() {}

    public func reset() {
        stepResults = []
        startedAt = nil
        finishedAt = nil
        status = .idle
    }
}
