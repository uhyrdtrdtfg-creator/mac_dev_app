import Foundation

public enum HARCodecError: Error, LocalizedError {
    case invalidJSON(String)

    public var errorDescription: String? {
        switch self {
        case .invalidJSON(let detail): "Invalid HAR file: \(detail)"
        }
    }
}

public struct HARImport: Sendable {
    public var entries: [HAREntry]
    public init(entries: [HAREntry]) { self.entries = entries }
}

public struct HAREntry: Sendable {
    public var method: String
    public var url: String
    public var httpVersion: String
    public var headers: [(name: String, value: String)]
    public var queryString: [(name: String, value: String)]
    public var postData: HARPostData?
    public var response: HARResponseSummary?
    public var startedDateTime: Date?
    public var time: Double?

    public init(method: String, url: String, httpVersion: String = "HTTP/1.1",
                headers: [(name: String, value: String)] = [], queryString: [(name: String, value: String)] = [],
                postData: HARPostData? = nil, response: HARResponseSummary? = nil,
                startedDateTime: Date? = nil, time: Double? = nil) {
        self.method = method; self.url = url; self.httpVersion = httpVersion
        self.headers = headers; self.queryString = queryString
        self.postData = postData; self.response = response
        self.startedDateTime = startedDateTime; self.time = time
    }
}

public struct HARParam: Sendable {
    public var name: String
    public var value: String
    public var fileName: String?
    public var contentType: String?

    public init(name: String, value: String = "", fileName: String? = nil, contentType: String? = nil) {
        self.name = name; self.value = value; self.fileName = fileName; self.contentType = contentType
    }
}

public struct HARPostData: Sendable {
    public var mimeType: String
    public var text: String?
    public var params: [HARParam]

    public init(mimeType: String, text: String? = nil, params: [HARParam] = []) {
        self.mimeType = mimeType; self.text = text; self.params = params
    }
}

public struct HARResponseSummary: Sendable {
    public var status: Int
    public var statusText: String
    public var headers: [(name: String, value: String)]
    public var contentMimeType: String?
    public var contentText: String?

    public init(status: Int, statusText: String = "", headers: [(name: String, value: String)] = [],
                contentMimeType: String? = nil, contentText: String? = nil) {
        self.status = status; self.statusText = statusText; self.headers = headers
        self.contentMimeType = contentMimeType; self.contentText = contentText
    }
}

public struct HARMappedRequest: Sendable {
    public var name: String
    public var method: HTTPMethod
    public var url: String
    public var headers: [KeyValuePair]
    public var body: RequestBody?

    public init(name: String, method: HTTPMethod, url: String, headers: [KeyValuePair], body: RequestBody?) {
        self.name = name; self.method = method; self.url = url; self.headers = headers; self.body = body
    }
}

public enum HARCodec {
    public static let creatorName = "DevToolkit"
    public static let creatorVersion = "1.0"

    // MARK: - Decode

    public static func decode(_ data: Data) throws -> HARImport {
        let raw: RawHAR
        do {
            raw = try JSONDecoder().decode(RawHAR.self, from: data)
        } catch {
            throw HARCodecError.invalidJSON(String(describing: error))
        }
        let entries: [HAREntry] = (raw.log?.entries ?? []).compactMap { entry in
            guard let request = entry.request, let url = request.url, !url.isEmpty else { return nil }
            let scheme = URLComponents(string: url)?.scheme?.lowercased()
                ?? url.prefix(while: { $0 != ":" }).lowercased()
            guard scheme == "http" || scheme == "https" else { return nil }

            let postData: HARPostData? = request.postData.flatMap { pd in
                let params = (pd.params ?? []).compactMap { p -> HARParam? in
                    guard let name = p.name else { return nil }
                    return HARParam(name: name, value: p.value ?? "", fileName: p.fileName, contentType: p.contentType)
                }
                guard pd.text != nil || !params.isEmpty else { return nil }
                return HARPostData(mimeType: pd.mimeType ?? "", text: pd.text, params: params)
            }

            let response: HARResponseSummary? = entry.response.map { resp in
                HARResponseSummary(
                    status: resp.status ?? 0,
                    statusText: resp.statusText ?? "",
                    headers: pairs(from: resp.headers),
                    contentMimeType: resp.content?.mimeType,
                    contentText: resp.content?.text
                )
            }

            return HAREntry(
                method: (request.method ?? "GET").uppercased(),
                url: url,
                httpVersion: request.httpVersion ?? "HTTP/1.1",
                headers: pairs(from: request.headers),
                queryString: pairs(from: request.queryString),
                postData: postData,
                response: response,
                startedDateTime: entry.startedDateTime.flatMap { parseISODate($0) },
                time: entry.time
            )
        }
        return HARImport(entries: entries)
    }

    // MARK: - Map to app requests

    public static func mapToRequests(_ har: HARImport) -> [HARMappedRequest] {
        har.entries.map { entry in
            let url = mergeQuery(into: entry.url, pairs: entry.queryString.map { ($0.name, $0.value) })
            let headers = entry.headers
                .filter { !$0.name.hasPrefix(":") && $0.name.lowercased() != "content-length" }
                .map { KeyValuePair(key: $0.name, value: $0.value) }
            return HARMappedRequest(
                name: requestName(method: entry.method, url: url),
                method: HTTPMethod(rawValue: entry.method) ?? .get,
                url: url,
                headers: headers,
                body: mapBody(entry.postData)
            )
        }
    }

    private static func mapBody(_ postData: HARPostData?) -> RequestBody? {
        guard let postData else { return nil }
        let mime = postData.mimeType.lowercased()
        if mime.contains("application/json") {
            return .json(postData.text ?? "")
        }
        if mime.contains("multipart/form-data"), !postData.params.isEmpty {
            // HAR carries no file contents — file params come back as path-less file parts.
            return .multipart(postData.params.map { p in
                if let fileName = p.fileName {
                    return MultipartPart(name: p.name, kind: .file(path: "", filename: fileName, mimeType: p.contentType ?? ""))
                }
                return MultipartPart(name: p.name, kind: .text(p.value))
            })
        }
        if mime.contains("application/x-www-form-urlencoded"), !postData.params.isEmpty {
            return .formData(postData.params.map { KeyValuePair(key: $0.name, value: $0.value) })
        }
        if let text = postData.text { return .raw(text) }
        if !postData.params.isEmpty {
            return .formData(postData.params.map { KeyValuePair(key: $0.name, value: $0.value) })
        }
        return nil
    }

    // MARK: - Encode

    public static func encode(requests: [SavedRequestModel], historyEntries: [HTTPHistoryModel]) -> Data {
        var entries = historyEntries.map { historyEntry($0) }
        entries.append(contentsOf: requests.map { savedRequestEntry($0) })
        let doc = OutHAR(log: OutLog(
            version: "1.2",
            creator: OutCreator(name: creatorName, version: creatorVersion),
            entries: entries
        ))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(doc)) ?? Data("{}".utf8)
    }

    private static func historyEntry(_ item: HTTPHistoryModel) -> OutEntry {
        let requestHeaders = decodeKVPairs(item.requestHeadersJSON).filter { $0.isEnabled && !$0.key.isEmpty }
        let queryParams = decodeKVPairs(item.queryParamsJSON).filter { $0.isEnabled && !$0.key.isEmpty }
        let url = mergeQuery(into: item.requestURL, pairs: queryParams.map { ($0.key, $0.value) })
        let contentType = headerValue("Content-Type", in: requestHeaders)
        let postData = historyPostData(item, contentType: contentType)

        let responseHeaders = decodeKVPairs(item.responseHeadersJSON).filter { !$0.key.isEmpty }
        let responseContentType = headerValue("Content-Type", in: responseHeaders) ?? ""
        var contentText: String?
        var contentEncoding: String?
        if let body = item.responseBody, !body.isEmpty {
            if let text = String(data: body, encoding: .utf8) {
                contentText = text
            } else {
                contentText = body.base64EncodedString()
                contentEncoding = "base64"
            }
        }
        let responseBodySize = item.responseBody?.count ?? item.responseSize
        let durationMS = item.duration * 1000

        return OutEntry(
            startedDateTime: isoString(item.executedAt),
            time: durationMS,
            request: OutRequest(
                method: item.requestMethod,
                url: url,
                httpVersion: "HTTP/1.1",
                cookies: [],
                headers: requestHeaders.map { OutNV(name: $0.key, value: $0.value) },
                queryString: queryString(from: url),
                postData: postData,
                headersSize: -1,
                bodySize: postData?.text.map { $0.utf8.count } ?? 0
            ),
            response: OutResponse(
                status: item.responseStatus,
                statusText: statusText(for: item.responseStatus),
                httpVersion: "HTTP/1.1",
                cookies: [],
                headers: responseHeaders.map { OutNV(name: $0.key, value: $0.value) },
                content: OutContent(size: responseBodySize, mimeType: responseContentType, text: contentText, encoding: contentEncoding),
                redirectURL: "",
                headersSize: -1,
                bodySize: responseBodySize
            ),
            cache: OutCache(),
            timings: OutTimings(send: 0, wait: durationMS, receive: 0)
        )
    }

    private static func savedRequestEntry(_ item: SavedRequestModel) -> OutEntry {
        let headers = item.headers.filter { $0.isEnabled && !$0.key.isEmpty }
        let contentType = headerValue("Content-Type", in: headers)
        var postData: OutPostData?
        if let body = item.body {
            if case .json(let text) = body {
                postData = OutPostData(mimeType: "application/json", text: text, params: nil)
            } else if case .formData(let pairs) = body {
                let enabled = pairs.filter { $0.isEnabled && !$0.key.isEmpty }
                postData = OutPostData(
                    mimeType: "application/x-www-form-urlencoded",
                    text: enabled.map { "\($0.key)=\($0.value)" }.joined(separator: "&"),
                    params: enabled.map { OutParam(name: $0.key, value: $0.value) }
                )
            } else if case .raw(let text) = body {
                postData = OutPostData(mimeType: contentType ?? "text/plain", text: text, params: nil)
            } else if case .binary(let data) = body {
                postData = OutPostData(mimeType: contentType ?? "application/octet-stream", text: data.base64EncodedString(), params: nil)
            } else if case .multipart(let parts) = body {
                postData = OutPostData(mimeType: "multipart/form-data", text: nil, params: outParams(parts))
            }
        }
        return OutEntry(
            startedDateTime: isoString(item.createdAt),
            time: 0,
            request: OutRequest(
                method: item.method,
                url: item.url,
                httpVersion: "HTTP/1.1",
                cookies: [],
                headers: headers.map { OutNV(name: $0.key, value: $0.value) },
                queryString: queryString(from: item.url),
                postData: postData,
                headersSize: -1,
                bodySize: postData?.text.map { $0.utf8.count } ?? 0
            ),
            response: OutResponse(
                status: 0, statusText: "", httpVersion: "HTTP/1.1", cookies: [], headers: [],
                content: OutContent(size: 0, mimeType: "", text: nil, encoding: nil),
                redirectURL: "", headersSize: -1, bodySize: 0
            ),
            cache: OutCache(),
            timings: OutTimings(send: 0, wait: 0, receive: 0)
        )
    }

    private static func historyPostData(_ item: HTTPHistoryModel, contentType: String?) -> OutPostData? {
        let normalized = (item.bodyType ?? "").lowercased().replacingOccurrences(of: " ", with: "")
        if normalized == "json" || (normalized.isEmpty && item.requestBodyJSON != nil) {
            guard let data = item.requestBodyJSON, let text = String(data: data, encoding: .utf8) else { return nil }
            return OutPostData(mimeType: contentType ?? "application/json", text: text, params: nil)
        }
        if normalized == "formdata" {
            let pairs = decodeKVPairs(item.formDataJSON).filter { $0.isEnabled && !$0.key.isEmpty }
            guard !pairs.isEmpty else { return nil }
            return OutPostData(
                mimeType: "application/x-www-form-urlencoded",
                text: pairs.map { "\($0.key)=\($0.value)" }.joined(separator: "&"),
                params: pairs.map { OutParam(name: $0.key, value: $0.value) }
            )
        }
        if normalized == "raw", let raw = item.rawBody {
            return OutPostData(mimeType: contentType ?? "text/plain", text: raw, params: nil)
        }
        // History stores multipart parts as encoded [MultipartPart] in requestBodyJSON.
        if normalized == "multipart", let data = item.requestBodyJSON,
           let parts = try? JSONDecoder().decode([MultipartPart].self, from: data) {
            return OutPostData(mimeType: "multipart/form-data", text: nil, params: outParams(parts))
        }
        // History stores binary request bytes in requestBodyJSON.
        if normalized == "binary", let data = item.requestBodyJSON {
            return OutPostData(mimeType: contentType ?? "application/octet-stream", text: data.base64EncodedString(), params: nil)
        }
        return nil
    }

    private static func outParams(_ parts: [MultipartPart]) -> [OutParam] {
        parts.filter { $0.isEnabled && !$0.name.isEmpty }.map { part in
            switch part.kind {
            case .text(let value):
                OutParam(name: part.name, value: value)
            case .file(let path, let filename, let mime):
                // File contents are intentionally not exported — only filename and content type.
                OutParam(
                    name: part.name,
                    value: nil,
                    fileName: filename.isEmpty ? (path as NSString).lastPathComponent : filename,
                    contentType: mime.isEmpty ? nil : mime
                )
            }
        }
    }

    // MARK: - Helpers

    /// Appends query pairs that are not already present in the URL's query.
    /// Chrome HARs repeat the query both inside `url` and in `queryString` — never double-add.
    static func mergeQuery(into url: String, pairs: [(String, String)]) -> String {
        guard !pairs.isEmpty, var components = URLComponents(string: url) else { return url }
        var items = components.queryItems ?? []
        let existing = Set(items.map { "\($0.name)\u{1}\($0.value ?? "")" })
        var added = false
        for (name, value) in pairs where !name.isEmpty {
            if !existing.contains("\(name)\u{1}\(value)") {
                items.append(URLQueryItem(name: name, value: value))
                added = true
            }
        }
        guard added else { return url }
        components.queryItems = items
        return components.url?.absoluteString ?? url
    }

    static func requestName(method: String, url: String) -> String {
        guard let components = URLComponents(string: url) else { return "\(method) \(url)" }
        let path = components.path.isEmpty ? "/" : components.path
        return "\(method) \(path)"
    }

    private static func pairs(from raw: [RawNV]?) -> [(name: String, value: String)] {
        (raw ?? []).compactMap { nv in
            guard let name = nv.name else { return nil }
            return (name: name, value: nv.value ?? "")
        }
    }

    private static func decodeKVPairs(_ data: Data?) -> [KeyValuePair] {
        guard let data else { return [] }
        return (try? JSONDecoder().decode([KeyValuePair].self, from: data)) ?? []
    }

    private static func headerValue(_ name: String, in headers: [KeyValuePair]) -> String? {
        headers.first { $0.key.caseInsensitiveCompare(name) == .orderedSame }?.value
    }

    private static func queryString(from url: String) -> [OutNV] {
        (URLComponents(string: url)?.queryItems ?? []).map { OutNV(name: $0.name, value: $0.value ?? "") }
    }

    private static func isoString(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.string(from: date)
    }

    private static func parseISODate(_ string: String) -> Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: string) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: string)
    }

    private static func statusText(for code: Int) -> String {
        let texts: [Int: String] = [
            200: "OK", 201: "Created", 202: "Accepted", 204: "No Content",
            301: "Moved Permanently", 302: "Found", 304: "Not Modified",
            400: "Bad Request", 401: "Unauthorized", 403: "Forbidden", 404: "Not Found",
            405: "Method Not Allowed", 409: "Conflict", 422: "Unprocessable Entity",
            429: "Too Many Requests", 500: "Internal Server Error", 502: "Bad Gateway",
            503: "Service Unavailable", 504: "Gateway Timeout"
        ]
        return texts[code] ?? ""
    }

    // MARK: - Raw decoding types (defensive: every field optional)

    private struct RawHAR: Decodable { var log: RawLog? }
    private struct RawLog: Decodable { var entries: [RawEntry]? }
    private struct RawEntry: Decodable {
        var startedDateTime: String?
        var time: Double?
        var request: RawRequest?
        var response: RawResponse?
    }
    private struct RawRequest: Decodable {
        var method: String?
        var url: String?
        var httpVersion: String?
        var headers: [RawNV]?
        var queryString: [RawNV]?
        var postData: RawPostData?
    }
    private struct RawNV: Decodable { var name: String?; var value: String? }
    private struct RawParam: Decodable { var name: String?; var value: String?; var fileName: String?; var contentType: String? }
    private struct RawPostData: Decodable {
        var mimeType: String?
        var text: String?
        var params: [RawParam]?
    }
    private struct RawResponse: Decodable {
        var status: Int?
        var statusText: String?
        var headers: [RawNV]?
        var content: RawContent?
    }
    private struct RawContent: Decodable { var mimeType: String?; var text: String? }

    // MARK: - Encoding types

    private struct OutHAR: Encodable { var log: OutLog }
    private struct OutLog: Encodable { var version: String; var creator: OutCreator; var entries: [OutEntry] }
    private struct OutCreator: Encodable { var name: String; var version: String }
    private struct OutEntry: Encodable {
        var startedDateTime: String
        var time: Double
        var request: OutRequest
        var response: OutResponse
        var cache: OutCache
        var timings: OutTimings
    }
    private struct OutRequest: Encodable {
        var method: String; var url: String; var httpVersion: String
        var cookies: [OutNV]; var headers: [OutNV]; var queryString: [OutNV]
        var postData: OutPostData?
        var headersSize: Int; var bodySize: Int
    }
    private struct OutNV: Encodable { var name: String; var value: String }
    private struct OutParam: Encodable { var name: String; var value: String?; var fileName: String? = nil; var contentType: String? = nil }
    private struct OutPostData: Encodable { var mimeType: String; var text: String?; var params: [OutParam]? }
    private struct OutResponse: Encodable {
        var status: Int; var statusText: String; var httpVersion: String
        var cookies: [OutNV]; var headers: [OutNV]
        var content: OutContent
        var redirectURL: String
        var headersSize: Int; var bodySize: Int
    }
    private struct OutContent: Encodable { var size: Int; var mimeType: String; var text: String?; var encoding: String? }
    private struct OutCache: Encodable {}
    private struct OutTimings: Encodable { var send: Double; var wait: Double; var receive: Double }
}
