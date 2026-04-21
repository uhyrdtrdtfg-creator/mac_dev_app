import Foundation
import JavaScriptCore
import CryptoKit
import CCommonCryptoAPI

/// Thread-safe environment variable store for pm.environment
public final class EnvironmentStore: @unchecked Sendable {
    private var store: [String: String] = [:]
    private let lock = NSLock()

    public init(_ initial: [String: String] = [:]) {
        self.store = initial
    }

    public func get(_ key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }
        return store[key]
    }

    public func set(_ key: String, _ value: String) {
        lock.lock()
        defer { lock.unlock() }
        store[key] = value
    }

    public func remove(_ key: String) {
        lock.lock()
        defer { lock.unlock() }
        store.removeValue(forKey: key)
    }

    public func all() -> [String: String] {
        lock.lock()
        defer { lock.unlock() }
        return store
    }
}

public enum PostmanCompat {

    // MARK: - Public Entry Point

    public static func setup(_ jsContext: JSContext, context: ScriptContext, envStore: EnvironmentStore) {
        setupPolyfills(jsContext)
        setupNativeCrypto(jsContext)
        setupCryptoJS(jsContext)
        setupPm(jsContext, context: context, envStore: envStore)
    }

    // MARK: - Browser Polyfills

    private static func setupPolyfills(_ ctx: JSContext) {
        // atob / btoa
        let atobBlock: @convention(block) (String) -> String = { base64 in
            guard let data = Data(base64Encoded: base64) else { return "" }
            return String(data: data, encoding: .isoLatin1) ?? ""
        }
        let btoaBlock: @convention(block) (String) -> String = { str in
            guard let data = str.data(using: .isoLatin1) else { return "" }
            return data.base64EncodedString()
        }
        ctx.setObject(atobBlock, forKeyedSubscript: "atob" as NSString)
        ctx.setObject(btoaBlock, forKeyedSubscript: "btoa" as NSString)

        // TextEncoder / TextDecoder
        ctx.evaluateScript("""
        class TextEncoder {
            encode(str) {
                var bytes = [];
                for (var i = 0; i < str.length; i++) {
                    var code = str.charCodeAt(i);
                    if (code < 0x80) {
                        bytes.push(code);
                    } else if (code < 0x800) {
                        bytes.push(0xC0 | (code >> 6), 0x80 | (code & 0x3F));
                    } else if (code < 0x10000) {
                        bytes.push(0xE0 | (code >> 12), 0x80 | ((code >> 6) & 0x3F), 0x80 | (code & 0x3F));
                    }
                }
                return new Uint8Array(bytes);
            }
        }
        class TextDecoder {
            decode(bytes) {
                var result = '';
                var arr = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
                for (var i = 0; i < arr.length; i++) {
                    if (arr[i] < 0x80) {
                        result += String.fromCharCode(arr[i]);
                    } else if (arr[i] < 0xE0) {
                        result += String.fromCharCode(((arr[i] & 0x1F) << 6) | (arr[i+1] & 0x3F));
                        i++;
                    } else {
                        result += String.fromCharCode(((arr[i] & 0x0F) << 12) | ((arr[i+1] & 0x3F) << 6) | (arr[i+2] & 0x3F));
                        i += 2;
                    }
                }
                return result;
            }
        }
        """)

        // crypto.getRandomValues
        let getRandomValues: @convention(block) (JSValue) -> JSValue = { typedArray in
            let length = typedArray.objectForKeyedSubscript("length")?.toInt32() ?? 0
            var bytes = [UInt8](repeating: 0, count: Int(length))
            _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
            for i in 0..<Int(length) {
                typedArray.setObject(bytes[i], atIndexedSubscript: i)
            }
            return typedArray
        }
        let cryptoObj = JSValue(newObjectIn: ctx)!
        cryptoObj.setObject(getRandomValues, forKeyedSubscript: "getRandomValues" as NSString)
        ctx.setObject(cryptoObj, forKeyedSubscript: "crypto" as NSString)
    }

    // MARK: - Native Crypto (Swift-backed)

    private static func setupNativeCrypto(_ ctx: JSContext) {
        let native = JSValue(newObjectIn: ctx)!

        // SHA-256: takes hex string, returns hex string
        let sha256Block: @convention(block) (String) -> String = { hexInput in
            guard let data = Data(pmHex: hexInput) else { return "" }
            let hash = SHA256.hash(data: data)
            return hash.map { String(format: "%02x", $0) }.joined()
        }
        native.setObject(sha256Block, forKeyedSubscript: "sha256" as NSString)

        // SHA-1
        let sha1Block: @convention(block) (String) -> String = { hexInput in
            guard let data = Data(pmHex: hexInput) else { return "" }
            let hash = Insecure.SHA1.hash(data: data)
            return hash.map { String(format: "%02x", $0) }.joined()
        }
        native.setObject(sha1Block, forKeyedSubscript: "sha1" as NSString)

        // HMAC-SHA256: takes hex message and hex key, returns hex
        let hmacSha256Block: @convention(block) (String, String) -> String = { hexMessage, hexKey in
            guard let msgData = Data(pmHex: hexMessage),
                  let keyData = Data(pmHex: hexKey) else { return "" }
            let key = SymmetricKey(data: keyData)
            let auth = CryptoKit.HMAC<SHA256>.authenticationCode(for: msgData, using: key)
            return Data(auth).map { String(format: "%02x", $0) }.joined()
        }
        native.setObject(hmacSha256Block, forKeyedSubscript: "hmacSha256" as NSString)

        // AES-ECB encrypt: hex plaintext + hex key -> hex ciphertext
        let aesEcbBlock: @convention(block) (String, String) -> String = { hexPlain, hexKey in
            guard let plainData = Data(pmHex: hexPlain),
                  let keyData = Data(pmHex: hexKey) else { return "" }

            let bufferSize = plainData.count + kCCBlockSizeAES128
            var buffer = [UInt8](repeating: 0, count: bufferSize)
            var bytesEncrypted = 0

            let status = plainData.withUnsafeBytes { dataPtr in
                keyData.withUnsafeBytes { keyPtr in
                    CCCrypt(
                        CCOperation(kCCEncrypt),
                        CCAlgorithm(kCCAlgorithmAES),
                        CCOptions(kCCOptionECBMode),
                        keyPtr.baseAddress, keyData.count,
                        nil,
                        dataPtr.baseAddress, plainData.count,
                        &buffer, bufferSize,
                        &bytesEncrypted
                    )
                }
            }

            guard status == kCCSuccess else { return "" }
            return buffer[..<bytesEncrypted].map { String(format: "%02x", $0) }.joined()
        }
        native.setObject(aesEcbBlock, forKeyedSubscript: "aesEcbEncrypt" as NSString)

        ctx.setObject(native, forKeyedSubscript: "__native" as NSString)
    }

    // MARK: - CryptoJS Compatibility Layer

    private static func setupCryptoJS(_ ctx: JSContext) {
        ctx.evaluateScript("""
        var CryptoJS = (function() {
            function WordArray(words, sigBytes) {
                this.words = words || [];
                this.sigBytes = sigBytes !== undefined ? sigBytes : this.words.length * 4;
            }

            WordArray.prototype.toString = function(encoder) {
                if (!encoder || encoder === Hex) return Hex.stringify(this);
                return encoder.stringify(this);
            };

            WordArray.prototype.clone = function() {
                return new WordArray(this.words.slice(0), this.sigBytes);
            };

            WordArray.create = function(arg) {
                if (arg instanceof ArrayBuffer) arg = new Uint8Array(arg);
                if (arg instanceof Uint8Array || Array.isArray(arg)) {
                    var words = [];
                    for (var i = 0; i < arg.length; i++) {
                        words[i >>> 2] |= (arg[i] & 0xff) << (24 - (i % 4) * 8);
                    }
                    return new WordArray(words, arg.length);
                }
                return new WordArray(arg);
            };

            var Hex = {
                stringify: function(wordArray) {
                    var hex = '';
                    for (var i = 0; i < wordArray.sigBytes; i++) {
                        var bite = (wordArray.words[i >>> 2] >>> (24 - (i % 4) * 8)) & 0xff;
                        hex += (bite < 16 ? '0' : '') + bite.toString(16);
                    }
                    return hex;
                },
                parse: function(hexStr) {
                    var words = [];
                    for (var i = 0; i < hexStr.length; i += 2) {
                        words[i >>> 3] |= parseInt(hexStr.substr(i, 2), 16) << (24 - (i % 8) * 4);
                    }
                    return new WordArray(words, hexStr.length / 2);
                }
            };

            var Base64 = {
                stringify: function(wordArray) {
                    var hex = Hex.stringify(wordArray);
                    var bytes = [];
                    for (var i = 0; i < hex.length; i += 2) {
                        bytes.push(parseInt(hex.substr(i, 2), 16));
                    }
                    var binary = '';
                    for (var j = 0; j < bytes.length; j++) {
                        binary += String.fromCharCode(bytes[j]);
                    }
                    return btoa(binary);
                },
                parse: function(base64Str) {
                    var binary = atob(base64Str);
                    var bytes = [];
                    for (var i = 0; i < binary.length; i++) {
                        bytes.push(binary.charCodeAt(i));
                    }
                    return WordArray.create(bytes);
                }
            };

            var Utf8 = {
                parse: function(str) {
                    var encoder = new TextEncoder();
                    var bytes = encoder.encode(str);
                    return WordArray.create(bytes);
                },
                stringify: function(wordArray) {
                    var hex = Hex.stringify(wordArray);
                    var bytes = [];
                    for (var i = 0; i < hex.length; i += 2) {
                        bytes.push(parseInt(hex.substr(i, 2), 16));
                    }
                    var decoder = new TextDecoder();
                    return decoder.decode(new Uint8Array(bytes));
                }
            };

            function hashWith(nativeFn) {
                return function(message) {
                    var hex;
                    if (typeof message === 'string') {
                        hex = Hex.stringify(Utf8.parse(message));
                    } else if (message && message.words !== undefined) {
                        hex = Hex.stringify(message);
                    } else {
                        hex = String(message);
                    }
                    var resultHex = nativeFn(hex);
                    return Hex.parse(resultHex);
                };
            }

            var SHA256 = hashWith(function(hex) { return __native.sha256(hex); });
            var SHA1 = hashWith(function(hex) { return __native.sha1(hex); });

            function HmacSHA256(message, key) {
                var msgHex, keyHex;
                if (typeof message === 'string') {
                    msgHex = Hex.stringify(Utf8.parse(message));
                } else {
                    msgHex = Hex.stringify(message);
                }
                if (typeof key === 'string') {
                    keyHex = Hex.stringify(Utf8.parse(key));
                } else {
                    keyHex = Hex.stringify(key);
                }
                var resultHex = __native.hmacSha256(msgHex, keyHex);
                return Hex.parse(resultHex);
            }

            var AES = {
                encrypt: function(message, key, cfg) {
                    var plainHex, keyHex;
                    if (message && message.words !== undefined) {
                        plainHex = Hex.stringify(message);
                    } else {
                        plainHex = Hex.stringify(Utf8.parse(String(message)));
                    }
                    if (key && key.words !== undefined) {
                        keyHex = Hex.stringify(key);
                    } else {
                        keyHex = Hex.stringify(Utf8.parse(String(key)));
                    }
                    var resultHex = __native.aesEcbEncrypt(plainHex, keyHex);
                    var ciphertext = Hex.parse(resultHex);
                    return {
                        ciphertext: ciphertext,
                        toString: function() { return Base64.stringify(ciphertext); }
                    };
                }
            };

            var mode = { ECB: { name: 'ECB' }, CBC: { name: 'CBC' } };
            var pad = { NoPadding: { name: 'NoPadding' }, Pkcs7: { name: 'Pkcs7' } };

            return {
                lib: { WordArray: { create: WordArray.create } },
                enc: { Hex: Hex, Base64: Base64, Utf8: Utf8 },
                SHA256: SHA256,
                SHA1: SHA1,
                HmacSHA256: HmacSHA256,
                AES: AES,
                mode: mode,
                pad: pad
            };
        })();
        """)
    }

    // MARK: - Postman pm Object

    private static func setupPm(_ ctx: JSContext, context: ScriptContext, envStore: EnvironmentStore) {
        // pm.environment
        let envGet: @convention(block) (String) -> String = { key in
            envStore.get(key) ?? ""
        }
        let envSet: @convention(block) (String, String) -> Void = { key, value in
            envStore.set(key, value)
        }
        let envUnset: @convention(block) (String) -> Void = { key in
            envStore.remove(key)
        }
        let envHas: @convention(block) (String) -> Bool = { key in
            envStore.get(key) != nil
        }

        let pmEnv = JSValue(newObjectIn: ctx)!
        pmEnv.setObject(envGet, forKeyedSubscript: "get" as NSString)
        pmEnv.setObject(envSet, forKeyedSubscript: "set" as NSString)
        pmEnv.setObject(envUnset, forKeyedSubscript: "unset" as NSString)
        pmEnv.setObject(envHas, forKeyedSubscript: "has" as NSString)

        // pm.request.body
        let pmBody = JSValue(newObjectIn: ctx)!
        pmBody.setObject(context.requestBody ?? "{}", forKeyedSubscript: "raw" as NSString)

        let bodyUpdate: @convention(block) (JSValue) -> Void = { opts in
            if let raw = opts.objectForKeyedSubscript("raw")?.toString() {
                pmBody.setObject(raw, forKeyedSubscript: "raw" as NSString)
            }
        }
        pmBody.setObject(bodyUpdate, forKeyedSubscript: "update" as NSString)

        // pm.request.headers
        let headerStore = JSValue(newObjectIn: ctx)!

        // Pre-populate from context
        for (key, value) in context.requestHeaders {
            headerStore.setObject(value, forKeyedSubscript: key as NSString)
        }

        let headerUpsert: @convention(block) (JSValue) -> Void = { opts in
            let key = opts.objectForKeyedSubscript("key")?.toString() ?? ""
            let value = opts.objectForKeyedSubscript("value")?.toString() ?? ""
            if !key.isEmpty {
                headerStore.setObject(value, forKeyedSubscript: key as NSString)
            }
        }

        let pmHeaders = JSValue(newObjectIn: ctx)!
        pmHeaders.setObject(headerUpsert, forKeyedSubscript: "upsert" as NSString)

        // pm.request.url.query — parse real query params from URL
        let queryItems: [(String, String)] = {
            guard let comps = URLComponents(string: context.requestURL),
                  let items = comps.queryItems else { return [] }
            return items.compactMap { item in
                guard let value = item.value, !item.name.isEmpty else { return nil }
                return (item.name, value)
            }
        }()

        let queryObj = JSValue(newObjectIn: ctx)!
        let queryCount: @convention(block) () -> Int = { queryItems.count }
        let queryEach: @convention(block) (JSValue) -> Void = { callback in
            for (key, value) in queryItems {
                let param = JSValue(newObjectIn: ctx)!
                param.setObject(key, forKeyedSubscript: "key" as NSString)
                param.setObject(value, forKeyedSubscript: "value" as NSString)
                callback.call(withArguments: [param as Any])
            }
        }
        queryObj.setObject(queryCount, forKeyedSubscript: "count" as NSString)
        queryObj.setObject(queryEach, forKeyedSubscript: "each" as NSString)

        let pmUrl = JSValue(newObjectIn: ctx)!
        pmUrl.setObject(queryObj, forKeyedSubscript: "query" as NSString)

        // pm.request
        let pmRequest = JSValue(newObjectIn: ctx)!
        pmRequest.setObject(pmBody, forKeyedSubscript: "body" as NSString)
        pmRequest.setObject(pmHeaders, forKeyedSubscript: "headers" as NSString)
        pmRequest.setObject(pmUrl, forKeyedSubscript: "url" as NSString)

        // pm.variables — mirrors pm.environment but adds replaceIn()
        let pmVariables = JSValue(newObjectIn: ctx)!
        pmVariables.setObject(envGet, forKeyedSubscript: "get" as NSString)
        pmVariables.setObject(envSet, forKeyedSubscript: "set" as NSString)
        pmVariables.setObject(envUnset, forKeyedSubscript: "unset" as NSString)
        pmVariables.setObject(envHas, forKeyedSubscript: "has" as NSString)

        // pm.variables.replaceIn — replaces {{variableName}} with values from envStore
        let replaceIn: @convention(block) (String) -> String = { template in
            var result = template
            let pattern = "\\{\\{([^}]+)\\}\\}"
            guard let regex = try? NSRegularExpression(pattern: pattern) else { return template }
            let range = NSRange(template.startIndex..., in: template)
            let matches = regex.matches(in: template, range: range)
            // Process in reverse to preserve indices
            for match in matches.reversed() {
                guard let fullRange = Range(match.range, in: result),
                      let keyRange = Range(match.range(at: 1), in: result) else { continue }
                let key = String(result[keyRange])
                let value = envStore.get(key) ?? ""
                result.replaceSubrange(fullRange, with: value)
            }
            return result
        }
        pmVariables.setObject(replaceIn, forKeyedSubscript: "replaceIn" as NSString)

        // pm
        let pm = JSValue(newObjectIn: ctx)!
        pm.setObject(pmEnv, forKeyedSubscript: "environment" as NSString)
        pm.setObject(pmVariables, forKeyedSubscript: "variables" as NSString)
        pm.setObject(pmRequest, forKeyedSubscript: "request" as NSString)

        // pm.response (for post-scripts)
        if let status = context.responseStatus {
            let pmResponse = JSValue(newObjectIn: ctx)!
            pmResponse.setObject(status, forKeyedSubscript: "code" as NSString)
            pmResponse.setObject(context.responseBody ?? "", forKeyedSubscript: "text" as NSString)

            let responseBody = context.responseBody
            let jsonFn: @convention(block) () -> Any = {
                guard let body = responseBody,
                      let data = body.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) else {
                    return [:] as [String: Any]
                }
                return json
            }
            pmResponse.setObject(jsonFn, forKeyedSubscript: "json" as NSString)
            pm.setObject(pmResponse, forKeyedSubscript: "response" as NSString)
        }

        ctx.setObject(pm, forKeyedSubscript: "pm" as NSString)

        // Store references for reading back after script execution
        ctx.setObject(pmBody, forKeyedSubscript: "__pmBody" as NSString)
        ctx.setObject(headerStore, forKeyedSubscript: "__pmHeaders" as NSString)
    }

    /// Read back modified request state after pre-script execution
    public static func readBackState(_ ctx: JSContext) -> (body: String?, headers: [String: String]) {
        let body = ctx.objectForKeyedSubscript("__pmBody")?.objectForKeyedSubscript("raw")?.toString()
        var headers: [String: String] = [:]
        if let headerStore = ctx.objectForKeyedSubscript("__pmHeaders"),
           let dict = headerStore.toDictionary() as? [String: String] {
            headers = dict
        }
        return (body: body, headers: headers)
    }
}

// Helper for hex string to Data conversion
private extension Data {
    init?(pmHex hex: String) {
        let h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard h.count.isMultiple(of: 2) else { return nil }
        var data = Data(capacity: h.count / 2)
        var index = h.startIndex
        while index < h.endIndex {
            let nextIndex = h.index(index, offsetBy: 2)
            guard let byte = UInt8(h[index..<nextIndex], radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }
        self = data
    }
}
