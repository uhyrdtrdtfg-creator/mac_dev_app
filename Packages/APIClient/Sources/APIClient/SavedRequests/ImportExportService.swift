import Foundation

public enum ImportExportService {
    // MARK: - Export as DevToolkit JSON

    public static func exportAsJSON(_ requests: [SavedRequestModel]) -> String {
        let items = requests.map { req -> [String: Any] in
            var item: [String: Any] = [
                "name": req.name,
                "method": req.method,
                "url": req.url,
                "tags": req.tagList,
                "createdAt": ISO8601DateFormatter().string(from: req.createdAt),
            ]
            if let headers = req.headersJSON,
               let arr = try? JSONDecoder().decode([KeyValuePair].self, from: headers) {
                item["headers"] = arr.filter { !$0.key.isEmpty }.map {
                    ["key": $0.key, "value": $0.value, "enabled": $0.isEnabled] as [String: Any]
                }
            }
            if let bodyType = req.bodyType { item["bodyType"] = bodyType }
            if let bodyData = req.bodyJSON, let bodyStr = String(data: bodyData, encoding: .utf8) {
                item["body"] = bodyStr
            }
            if let s = req.preScript, !s.isEmpty { item["preScript"] = s }
            if let s = req.postScript, !s.isEmpty { item["postScript"] = s }
            if let s = req.rewriteScript, !s.isEmpty { item["rewriteScript"] = s }
            return item
        }

        let export: [String: Any] = [
            "info": [
                "name": "DevToolkit API Collection",
                "version": "1.0",
                "exportedAt": ISO8601DateFormatter().string(from: Date())
            ],
            "requests": items
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: export, options: [.prettyPrinted, .sortedKeys]),
              let json = String(data: data, encoding: .utf8) else { return "{}" }
        return json
    }

    // MARK: - Import DevToolkit JSON

    public static func importDevToolkitJSON(_ json: String) -> [SavedRequestModel] {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let items = obj["requests"] as? [[String: Any]] else { return [] }
        return items.compactMap { parseItem($0) }
    }

    // MARK: - Import Postman Collection v2.1

    public static func importPostmanCollection(_ json: String) -> [SavedRequestModel] {
        guard let data = json.data(using: .utf8),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            // Try as DevToolkit format
            return importDevToolkitJSON(json)
        }

        // Check if it's Postman Collection v2.1
        if let items = obj["item"] as? [[String: Any]] {
            let collectionName = (obj["info"] as? [String: Any])?["name"] as? String
            return parsePostmanItems(items, parentTag: collectionName)
        }

        // Try DevToolkit format
        if obj["requests"] != nil {
            return importDevToolkitJSON(json)
        }

        return []
    }

    private static func parsePostmanItems(_ items: [[String: Any]], parentTag: String?) -> [SavedRequestModel] {
        var results: [SavedRequestModel] = []
        for item in items {
            // Nested folder
            if let subItems = item["item"] as? [[String: Any]] {
                let folderName = item["name"] as? String
                let tag = [parentTag, folderName].compactMap { $0 }.joined(separator: "/")
                results.append(contentsOf: parsePostmanItems(subItems, parentTag: tag))
                continue
            }

            // Request item
            guard let request = item["request"] as? [String: Any] else { continue }
            let name = item["name"] as? String ?? "Untitled"
            let method = (request["method"] as? String ?? "GET").uppercased()

            // Parse URL
            var urlString = ""
            if let urlObj = request["url"] as? [String: Any] {
                urlString = urlObj["raw"] as? String ?? ""
            } else if let u = request["url"] as? String {
                urlString = u
            }

            let saved = SavedRequestModel(name: name, method: method, url: urlString)
            if let tag = parentTag, !tag.isEmpty {
                saved.tagList = [tag]
            }

            // Parse headers
            if let headerArr = request["header"] as? [[String: Any]] {
                saved.headers = headerArr.map {
                    KeyValuePair(
                        key: $0["key"] as? String ?? "",
                        value: $0["value"] as? String ?? "",
                        isEnabled: !($0["disabled"] as? Bool ?? false)
                    )
                }
            }

            // Parse body
            if let bodyObj = request["body"] as? [String: Any] {
                let mode = bodyObj["mode"] as? String ?? "raw"
                if mode == "raw", let raw = bodyObj["raw"] as? String {
                    saved.body = .json(raw)
                    saved.bodyType = "json"
                } else if mode == "formdata", let params = bodyObj["formdata"] as? [[String: Any]] {
                    saved.body = .formData(params.map {
                        KeyValuePair(key: $0["key"] as? String ?? "", value: $0["value"] as? String ?? "")
                    })
                    saved.bodyType = "formData"
                }
            }

            // Parse pre-request script
            if let events = item["event"] as? [[String: Any]] {
                for event in events {
                    let listen = event["listen"] as? String
                    if let scriptObj = event["script"] as? [String: Any],
                       let exec = scriptObj["exec"] as? [String] {
                        let code = exec.joined(separator: "\n")
                        if listen == "prerequest" { saved.preScript = code }
                        else if listen == "test" { saved.postScript = code }
                    }
                }
            }

            results.append(saved)
        }
        return results
    }

    // MARK: - Import cURL Commands

    public static func importCurlCommands(_ text: String) -> [SavedRequestModel] {
        // Split by lines that start with "curl"
        let lines = text.components(separatedBy: "\n")
        var commands: [String] = []
        var current = ""
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("curl") && !current.isEmpty {
                commands.append(current)
                current = trimmed
            } else if trimmed.lowercased().hasPrefix("curl") {
                current = trimmed
            } else if !current.isEmpty {
                current += " " + trimmed
            }
        }
        if !current.isEmpty { commands.append(current) }

        return commands.compactMap { cmd in
            guard let parsed = CurlHelper.parse(cmd) else { return nil }
            let saved = SavedRequestModel(
                name: shortName(from: parsed.url),
                method: parsed.method,
                url: parsed.url
            )
            saved.headers = parsed.headers.map { KeyValuePair(key: $0.0, value: $0.1) }
            if let body = parsed.body {
                saved.body = .json(body)
                saved.bodyType = "json"
            }
            saved.tagList = ["cURL Import"]
            return saved
        }
    }

    // MARK: - Helpers

    private static func parseItem(_ dict: [String: Any]) -> SavedRequestModel? {
        guard let name = dict["name"] as? String,
              let method = dict["method"] as? String,
              let url = dict["url"] as? String else { return nil }
        let saved = SavedRequestModel(name: name, method: method, url: url)
        if let tags = dict["tags"] as? [String] { saved.tagList = tags }
        if let bodyType = dict["bodyType"] as? String { saved.bodyType = bodyType }
        if let bodyStr = dict["body"] as? String { saved.bodyJSON = bodyStr.data(using: .utf8) }
        if let headers = dict["headers"] as? [[String: Any]] {
            saved.headers = headers.map {
                KeyValuePair(
                    key: $0["key"] as? String ?? "",
                    value: $0["value"] as? String ?? "",
                    isEnabled: $0["enabled"] as? Bool ?? true
                )
            }
        }
        if let s = dict["preScript"] as? String { saved.preScript = s }
        if let s = dict["postScript"] as? String { saved.postScript = s }
        if let s = dict["rewriteScript"] as? String { saved.rewriteScript = s }
        return saved
    }

    private static func shortName(from url: String) -> String {
        guard let comps = URLComponents(string: url) else { return url }
        let path = comps.path
        if path.isEmpty || path == "/" { return comps.host ?? url }
        let parts = path.split(separator: "/")
        return String(parts.last ?? Substring(comps.host ?? "request"))
    }
}
