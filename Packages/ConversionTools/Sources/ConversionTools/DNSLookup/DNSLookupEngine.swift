import Foundation
import Network

public enum DNSRecordType: UInt16, CaseIterable, Identifiable, Sendable {
    case a = 1
    case ns = 2
    case cname = 5
    case soa = 6
    case ptr = 12
    case mx = 15
    case txt = 16
    case aaaa = 28
    case caa = 257

    public var id: UInt16 { rawValue }

    public var name: String {
        switch self {
        case .a: "A"
        case .ns: "NS"
        case .cname: "CNAME"
        case .soa: "SOA"
        case .ptr: "PTR"
        case .mx: "MX"
        case .txt: "TXT"
        case .aaaa: "AAAA"
        case .caa: "CAA"
        }
    }
}

public enum DNSError: Error, LocalizedError {
    case invalidName(String)
    case truncatedMessage
    case badCompressionPointer
    case idMismatch
    case timeout
    case connectionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .invalidName(let n): "Invalid hostname: \(n)"
        case .truncatedMessage: "Malformed DNS message (unexpected end of data)"
        case .badCompressionPointer: "Malformed DNS message (bad compression pointer)"
        case .idMismatch: "Response ID does not match the query"
        case .timeout: "DNS query timed out"
        case .connectionFailed(let reason): "Connection failed: \(reason)"
        }
    }
}

public struct DNSRecord: Identifiable, Sendable {
    public let id = UUID()
    public let name: String
    public let type: String
    public let ttl: UInt32
    public let value: String
}

public struct DNSMessage: Sendable {
    public let id: UInt16
    public let isResponse: Bool
    public let isAuthoritative: Bool
    public let isTruncated: Bool
    public let recursionAvailable: Bool
    public let rcode: Int
    public let answers: [DNSRecord]
    public let authority: [DNSRecord]

    public var rcodeName: String { DNSLookupEngine.rcodeName(rcode) }
}

public struct DNSServerPreset: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let host: String?

    public static let presets: [DNSServerPreset] = [
        DNSServerPreset(id: "google", name: "Google (8.8.8.8)", host: "8.8.8.8"),
        DNSServerPreset(id: "cloudflare", name: "Cloudflare (1.1.1.1)", host: "1.1.1.1"),
        DNSServerPreset(id: "alidns", name: "AliDNS (223.5.5.5)", host: "223.5.5.5"),
        DNSServerPreset(id: "114dns", name: "114DNS (114.114.114.114)", host: "114.114.114.114"),
        DNSServerPreset(id: "system", name: "System", host: nil)
    ]

    public func resolvedHost() -> String { host ?? DNSLookupEngine.systemNameserver() }
}

public struct DNSLookupResult: Sendable {
    public let message: DNSMessage
    public let queriedName: String
    public let serverHost: String
    public let elapsedMilliseconds: Double
    public let usedTCP: Bool
}

public enum DNSLookupEngine {

    // MARK: - Encoding

    public static func encodeQuery(name: String, type: DNSRecordType, id: UInt16) throws -> Data {
        var data = Data()
        appendU16(&data, id)
        appendU16(&data, 0x0100)
        appendU16(&data, 1)
        appendU16(&data, 0)
        appendU16(&data, 0)
        appendU16(&data, 0)
        data.append(try encodeName(name))
        appendU16(&data, type.rawValue)
        appendU16(&data, 1)
        return data
    }

    public static func encodeName(_ name: String) throws -> Data {
        let trimmed = name.hasSuffix(".") ? String(name.dropLast()) : name
        guard !trimmed.isEmpty else { throw DNSError.invalidName(name) }
        var data = Data()
        for label in trimmed.split(separator: ".", omittingEmptySubsequences: false) {
            let bytes = Data(label.utf8)
            guard !bytes.isEmpty, bytes.count <= 63 else { throw DNSError.invalidName(name) }
            data.append(UInt8(bytes.count))
            data.append(bytes)
        }
        guard data.count <= 254 else { throw DNSError.invalidName(name) }
        data.append(0)
        return data
    }

    public static func reverseName(forIP ip: String) -> String? {
        var v4 = in_addr()
        if inet_pton(AF_INET, ip, &v4) == 1 {
            let b = withUnsafeBytes(of: v4.s_addr) { Array($0) }
            return "\(b[3]).\(b[2]).\(b[1]).\(b[0]).in-addr.arpa"
        }
        var v6 = in6_addr()
        if inet_pton(AF_INET6, ip, &v6) == 1 {
            let bytes = withUnsafeBytes(of: v6) { Array($0) }
            let nibbles = bytes.reversed().flatMap {
                [String($0 & 0x0F, radix: 16), String($0 >> 4, radix: 16)]
            }
            return nibbles.joined(separator: ".") + ".ip6.arpa"
        }
        return nil
    }

    // MARK: - Decoding

    public static func decode(_ data: Data) throws -> DNSMessage {
        let bytes = [UInt8](data)
        guard bytes.count >= 12 else { throw DNSError.truncatedMessage }
        let id = u16(bytes, 0)
        let flags = u16(bytes, 2)
        let qdCount = Int(u16(bytes, 4))
        let anCount = Int(u16(bytes, 6))
        let nsCount = Int(u16(bytes, 8))

        var offset = 12
        for _ in 0..<qdCount {
            _ = try parseName(bytes, &offset)
            guard offset + 4 <= bytes.count else { throw DNSError.truncatedMessage }
            offset += 4
        }
        var answers: [DNSRecord] = []
        for _ in 0..<anCount { answers.append(try parseRecord(bytes, &offset)) }
        var authority: [DNSRecord] = []
        for _ in 0..<nsCount { authority.append(try parseRecord(bytes, &offset)) }

        return DNSMessage(
            id: id,
            isResponse: flags & 0x8000 != 0,
            isAuthoritative: flags & 0x0400 != 0,
            isTruncated: flags & 0x0200 != 0,
            recursionAvailable: flags & 0x0080 != 0,
            rcode: Int(flags & 0x000F),
            answers: answers,
            authority: authority
        )
    }

    public static func rcodeName(_ rcode: Int) -> String {
        switch rcode {
        case 0: "NOERROR"
        case 1: "FORMERR"
        case 2: "SERVFAIL"
        case 3: "NXDOMAIN"
        case 4: "NOTIMP"
        case 5: "REFUSED"
        default: "RCODE\(rcode)"
        }
    }

    static func parseName(_ bytes: [UInt8], _ offset: inout Int) throws -> String {
        var labels: [String] = []
        var pos = offset
        var jumped = false
        var jumps = 0
        while true {
            guard pos < bytes.count else { throw DNSError.truncatedMessage }
            let len = Int(bytes[pos])
            if len == 0 {
                if !jumped { offset = pos + 1 }
                break
            }
            if len & 0xC0 == 0xC0 {
                guard pos + 1 < bytes.count else { throw DNSError.truncatedMessage }
                let target = ((len & 0x3F) << 8) | Int(bytes[pos + 1])
                if !jumped { offset = pos + 2 }
                jumped = true
                jumps += 1
                guard jumps <= 16, target < bytes.count, target != pos else { throw DNSError.badCompressionPointer }
                pos = target
                continue
            }
            guard len & 0xC0 == 0 else { throw DNSError.badCompressionPointer }
            guard pos + 1 + len <= bytes.count else { throw DNSError.truncatedMessage }
            labels.append(String(decoding: bytes[(pos + 1)...(pos + len)], as: UTF8.self))
            pos += 1 + len
        }
        return labels.isEmpty ? "." : labels.joined(separator: ".")
    }

    static func parseRecord(_ bytes: [UInt8], _ offset: inout Int) throws -> DNSRecord {
        let name = try parseName(bytes, &offset)
        guard offset + 10 <= bytes.count else { throw DNSError.truncatedMessage }
        let type = u16(bytes, offset)
        let ttl = u32(bytes, offset + 4)
        let rdLength = Int(u16(bytes, offset + 8))
        offset += 10
        guard offset + rdLength <= bytes.count else { throw DNSError.truncatedMessage }
        let value = try renderRDATA(type: type, bytes: bytes, start: offset, length: rdLength)
        offset += rdLength
        return DNSRecord(name: name, type: typeName(type), ttl: ttl, value: value)
    }

    static func typeName(_ type: UInt16) -> String {
        DNSRecordType(rawValue: type)?.name ?? "TYPE\(type)"
    }

    static func renderRDATA(type: UInt16, bytes: [UInt8], start: Int, length: Int) throws -> String {
        switch DNSRecordType(rawValue: type) {
        case .a:
            guard length == 4 else { throw DNSError.truncatedMessage }
            return bytes[start..<(start + 4)].map(String.init).joined(separator: ".")
        case .aaaa:
            guard length == 16 else { throw DNSError.truncatedMessage }
            return formatIPv6(Array(bytes[start..<(start + 16)]))
        case .ns, .cname, .ptr:
            var pos = start
            return try parseName(bytes, &pos)
        case .mx:
            guard length >= 3 else { throw DNSError.truncatedMessage }
            let preference = u16(bytes, start)
            var pos = start + 2
            let host = try parseName(bytes, &pos)
            return "\(preference) \(host)"
        case .txt:
            var strings: [String] = []
            var pos = start
            let end = start + length
            while pos < end {
                let strLen = Int(bytes[pos])
                guard pos + 1 + strLen <= end else { throw DNSError.truncatedMessage }
                strings.append(String(decoding: bytes[(pos + 1)..<(pos + 1 + strLen)], as: UTF8.self))
                pos += 1 + strLen
            }
            return strings.joined()
        case .soa:
            var pos = start
            let mname = try parseName(bytes, &pos)
            let rname = try parseName(bytes, &pos)
            guard pos + 20 <= start + length else { throw DNSError.truncatedMessage }
            let serial = u32(bytes, pos)
            let refresh = u32(bytes, pos + 4)
            let retry = u32(bytes, pos + 8)
            let expire = u32(bytes, pos + 12)
            let minimum = u32(bytes, pos + 16)
            return "\(mname) \(rname) \(serial) \(refresh) \(retry) \(expire) \(minimum)"
        case .caa:
            guard length >= 2 else { throw DNSError.truncatedMessage }
            let flags = bytes[start]
            let tagLen = Int(bytes[start + 1])
            guard start + 2 + tagLen <= start + length else { throw DNSError.truncatedMessage }
            let tag = String(decoding: bytes[(start + 2)..<(start + 2 + tagLen)], as: UTF8.self)
            let value = String(decoding: bytes[(start + 2 + tagLen)..<(start + length)], as: UTF8.self)
            return "\(flags) \(tag) \"\(value)\""
        default:
            return bytes[start..<(start + length)].map { String(format: "%02x", $0) }.joined()
        }
    }

    static func formatIPv6(_ bytes: [UInt8]) -> String {
        var addr = in6_addr()
        withUnsafeMutableBytes(of: &addr) { $0.copyBytes(from: bytes) }
        var buffer = [CChar](repeating: 0, count: Int(INET6_ADDRSTRLEN))
        inet_ntop(AF_INET6, &addr, &buffer, socklen_t(INET6_ADDRSTRLEN))
        return String(cString: buffer)
    }

    // MARK: - Transport

    /// "System" resolves the first `nameserver` from /etc/resolv.conf and falls back
    /// to 8.8.8.8 when it cannot be read, avoiding a libresolv link dependency.
    public static func systemNameserver() -> String {
        if let content = try? String(contentsOfFile: "/etc/resolv.conf", encoding: .utf8) {
            for line in content.split(separator: "\n") {
                let parts = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
                if parts.count >= 2, parts[0] == "nameserver" {
                    return String(parts[1])
                }
            }
        }
        return "8.8.8.8"
    }

    public static func lookup(
        name: String,
        type: DNSRecordType,
        serverHost: String,
        timeout: Double = 5
    ) async throws -> DNSLookupResult {
        let queryName: String
        if type == .ptr, let reversed = reverseName(forIP: name) {
            queryName = reversed
        } else {
            queryName = name
        }
        let id = UInt16.random(in: 0...UInt16.max)
        let query = try encodeQuery(name: queryName, type: type, id: id)

        let start = DispatchTime.now()
        var raw = try await exchange(query, host: serverHost, tcp: false, timeout: timeout)
        var message = try decode(raw)
        guard message.id == id else { throw DNSError.idMismatch }
        var usedTCP = false
        if message.isTruncated {
            raw = try await exchange(query, host: serverHost, tcp: true, timeout: timeout)
            message = try decode(raw)
            guard message.id == id else { throw DNSError.idMismatch }
            usedTCP = true
        }
        let elapsed = Double(DispatchTime.now().uptimeNanoseconds - start.uptimeNanoseconds) / 1_000_000

        return DNSLookupResult(
            message: message,
            queriedName: queryName,
            serverHost: serverHost,
            elapsedMilliseconds: elapsed,
            usedTCP: usedTCP
        )
    }

    private final class OneShot: @unchecked Sendable {
        private let lock = NSLock()
        private var continuation: CheckedContinuation<Data, Error>?

        init(_ continuation: CheckedContinuation<Data, Error>) {
            self.continuation = continuation
        }

        func resume(_ result: Result<Data, Error>) {
            lock.lock()
            let pending = continuation
            continuation = nil
            lock.unlock()
            pending?.resume(with: result)
        }
    }

    static func exchange(_ message: Data, host: String, tcp: Bool, timeout: Double) async throws -> Data {
        guard let port = NWEndpoint.Port(rawValue: 53) else { throw DNSError.connectionFailed("bad port") }
        let connection = NWConnection(
            host: NWEndpoint.Host(host),
            port: port,
            using: tcp ? .tcp : .udp
        )
        let payload: Data
        if tcp {
            var framed = Data()
            framed.append(UInt8(message.count >> 8))
            framed.append(UInt8(message.count & 0xFF))
            framed.append(message)
            payload = framed
        } else {
            payload = message
        }
        let queue = DispatchQueue(label: "dns-lookup.transport")

        return try await withCheckedThrowingContinuation { continuation in
            let oneShot = OneShot(continuation)

            queue.asyncAfter(deadline: .now() + timeout) {
                oneShot.resume(.failure(DNSError.timeout))
                connection.cancel()
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: payload, completion: .contentProcessed { error in
                        if let error {
                            oneShot.resume(.failure(DNSError.connectionFailed(error.localizedDescription)))
                            connection.cancel()
                            return
                        }
                        if tcp {
                            receiveTCP(connection, buffer: Data(), oneShot: oneShot)
                        } else {
                            connection.receiveMessage { data, _, _, error in
                                if let data, !data.isEmpty {
                                    oneShot.resume(.success(data))
                                } else {
                                    oneShot.resume(.failure(DNSError.connectionFailed(
                                        error?.localizedDescription ?? "empty response"
                                    )))
                                }
                                connection.cancel()
                            }
                        }
                    })
                case .failed(let error):
                    oneShot.resume(.failure(DNSError.connectionFailed(error.localizedDescription)))
                    connection.cancel()
                case .waiting(let error):
                    oneShot.resume(.failure(DNSError.connectionFailed(error.localizedDescription)))
                    connection.cancel()
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }

    private static func receiveTCP(_ connection: NWConnection, buffer: Data, oneShot: OneShot) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65535) { data, _, isComplete, error in
            var accumulated = buffer
            if let data { accumulated.append(data) }
            if accumulated.count >= 2 {
                let expected = Int(accumulated[0]) << 8 | Int(accumulated[1])
                if accumulated.count >= 2 + expected {
                    oneShot.resume(.success(accumulated.subdata(in: 2..<(2 + expected))))
                    connection.cancel()
                    return
                }
            }
            if let error {
                oneShot.resume(.failure(DNSError.connectionFailed(error.localizedDescription)))
                connection.cancel()
                return
            }
            if isComplete {
                oneShot.resume(.failure(DNSError.truncatedMessage))
                connection.cancel()
                return
            }
            receiveTCP(connection, buffer: accumulated, oneShot: oneShot)
        }
    }

    // MARK: - Byte helpers

    static func appendU16(_ data: inout Data, _ value: UInt16) {
        data.append(UInt8(value >> 8))
        data.append(UInt8(value & 0xFF))
    }

    static func u16(_ bytes: [UInt8], _ offset: Int) -> UInt16 {
        UInt16(bytes[offset]) << 8 | UInt16(bytes[offset + 1])
    }

    static func u32(_ bytes: [UInt8], _ offset: Int) -> UInt32 {
        UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16
            | UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3])
    }
}
