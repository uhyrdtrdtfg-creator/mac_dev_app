import Foundation
import SwiftData

@Model
public final class HTTPHistoryModel {
    public var id: UUID = UUID()
    public var requestMethod: String = "GET"
    public var requestURL: String = ""
    public var requestHeadersJSON: Data?
    public var requestBodyJSON: Data?
    public var responseStatus: Int = 0
    public var responseBody: Data?
    public var responseHeadersJSON: Data?
    public var duration: TimeInterval = 0
    public var responseSize: Int = 0
    public var executedAt: Date = Date()

    // Scripts
    public var preScript: String?
    public var postScript: String?
    public var rewriteScript: String?

    // Body type info for restoration
    public var bodyType: String?  // "none", "json", "formData", "raw"

    public init(requestMethod: String, requestURL: String, responseStatus: Int, duration: TimeInterval, responseSize: Int) {
        self.id = UUID()
        self.requestMethod = requestMethod
        self.requestURL = requestURL
        self.responseStatus = responseStatus
        self.duration = duration
        self.responseSize = responseSize
        self.executedAt = Date()
    }
}
