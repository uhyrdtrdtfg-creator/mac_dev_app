import Foundation
import SwiftData

@Model
public final class HTTPHistoryModel {
    public var id: UUID
    public var requestMethod: String
    public var requestURL: String
    public var requestHeadersJSON: Data?
    public var requestBodyJSON: Data?
    public var responseStatus: Int
    public var responseBody: Data?
    public var responseHeadersJSON: Data?
    public var duration: TimeInterval
    public var responseSize: Int
    public var executedAt: Date

    public init(requestMethod: String, requestURL: String, responseStatus: Int, duration: TimeInterval, responseSize: Int) {
        self.id = UUID(); self.requestMethod = requestMethod; self.requestURL = requestURL
        self.responseStatus = responseStatus; self.duration = duration; self.responseSize = responseSize; self.executedAt = Date()
    }
}
