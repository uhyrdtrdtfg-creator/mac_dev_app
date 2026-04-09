import Foundation

public enum HTTPClientError: Error, LocalizedError {
    case invalidURL
    case requestFailed(Error)
    case noResponse

    public var errorDescription: String? {
        switch self {
        case .invalidURL: "Invalid URL"
        case .requestFailed(let e): "Request failed: \(e.localizedDescription)"
        case .noResponse: "No response received"
        }
    }
}

public struct HTTPResponse: Sendable, Equatable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data
    public let duration: TimeInterval
    public let bodySize: Int
    public let cookies: [String]
}

public enum HTTPClientService {
    public static func buildURLRequest(method: HTTPMethod, url: String, headers: [KeyValuePair], queryParams: [KeyValuePair], body: RequestBody?, auth: AuthType?) throws -> URLRequest {
        guard var components = URLComponents(string: url), !url.isEmpty else { throw HTTPClientError.invalidURL }

        let enabledParams = queryParams.filter(\.isEnabled)
        if !enabledParams.isEmpty {
            var items = components.queryItems ?? []
            items.append(contentsOf: enabledParams.map { URLQueryItem(name: $0.key, value: $0.value) })
            components.queryItems = items
        }

        guard let finalURL = components.url else { throw HTTPClientError.invalidURL }
        var request = URLRequest(url: finalURL)
        request.httpMethod = method.rawValue

        for header in headers where header.isEnabled && !header.key.isEmpty {
            request.setValue(header.value, forHTTPHeaderField: header.key)
        }

        if let body {
            switch body {
            case .json(let json):
                request.httpBody = Data(json.utf8)
                if request.value(forHTTPHeaderField: "Content-Type") == nil { request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
            case .formData(let pairs):
                let encoded = pairs.filter(\.isEnabled).map { "\($0.key)=\($0.value)" }.joined(separator: "&")
                request.httpBody = Data(encoded.utf8)
                if request.value(forHTTPHeaderField: "Content-Type") == nil { request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type") }
            case .raw(let text): request.httpBody = Data(text.utf8)
            case .binary(let data): request.httpBody = data
            }
        }

        if let auth {
            switch auth {
            case .bearerToken(let token):
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            case .basicAuth(let username, let password):
                let credentials = Data("\(username):\(password)".utf8).base64EncodedString()
                request.setValue("Basic \(credentials)", forHTTPHeaderField: "Authorization")
            case .apiKey(let key, let value, let addTo):
                switch addTo {
                case .header: request.setValue(value, forHTTPHeaderField: key)
                case .queryParam:
                    if var comps = URLComponents(url: finalURL, resolvingAgainstBaseURL: false) {
                        var items = comps.queryItems ?? []; items.append(URLQueryItem(name: key, value: value)); comps.queryItems = items
                        if let newURL = comps.url { request.url = newURL }
                    }
                }
            }
        }

        return request
    }

    public static func send(_ request: URLRequest) async throws -> HTTPResponse {
        let start = Date()
        let (data, response) = try await URLSession.shared.data(for: request)
        let duration = Date().timeIntervalSince(start)
        guard let httpResponse = response as? HTTPURLResponse else { throw HTTPClientError.noResponse }
        let headers: [String: String] = Dictionary(uniqueKeysWithValues: httpResponse.allHeaderFields.compactMap { key, value -> (String, String)? in
            guard let k = key as? String, let v = value as? String else { return nil }; return (k, v)
        })
        let cookies = (headers["Set-Cookie"] ?? "").split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        return HTTPResponse(statusCode: httpResponse.statusCode, headers: headers, body: data, duration: duration, bodySize: data.count, cookies: cookies)
    }
}
