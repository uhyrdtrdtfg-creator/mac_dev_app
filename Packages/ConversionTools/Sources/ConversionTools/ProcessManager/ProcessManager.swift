import Foundation
import Darwin

public struct ListeningPort: Identifiable, Hashable, Sendable {
    public let port: Int
    public let protocolName: String
    public let address: String
    public let pid: Int32
    public let processName: String
    public var id: String { "\(pid):\(port)" }

    public init(port: Int, protocolName: String, address: String, pid: Int32, processName: String) {
        self.port = port
        self.protocolName = protocolName
        self.address = address
        self.pid = pid
        self.processName = processName
    }
}

public struct RunningProcess: Identifiable, Hashable, Sendable {
    public let pid: Int32
    public let cpuPercent: Double
    public let memPercent: Double
    public let rssBytes: Int64
    public let command: String
    public var displayName: String { (command as NSString).lastPathComponent }
    public var id: Int32 { pid }

    public init(pid: Int32, cpuPercent: Double, memPercent: Double, rssBytes: Int64, command: String) {
        self.pid = pid
        self.cpuPercent = cpuPercent
        self.memPercent = memPercent
        self.rssBytes = rssBytes
        self.command = command
    }
}

public enum TerminateOutcome: Sendable, Equatable {
    case success
    case failure(String)
}

public enum ProcessManagerError: LocalizedError {
    case commandFailed(String)
    public var errorDescription: String? {
        switch self { case .commandFailed(let message): message }
    }
}

public enum ProcessManager {
    public static func listListeningPorts() async throws -> [ListeningPort] {
        let output = try await runCommand("/usr/sbin/lsof", ["-nP", "-iTCP", "-sTCP:LISTEN"])
        return parseLsofOutput(output)
    }

    public static func listProcesses() async throws -> [RunningProcess] {
        let output = try await runCommand("/bin/ps", ["axo", "pid=,pcpu=,pmem=,rss=,comm="])
        return parsePsOutput(output)
    }

    /// Parses standard columnar `lsof -nP -iTCP -sTCP:LISTEN` output.
    /// Fields are resolved from the right (the last 9 columns never contain spaces),
    /// so process names containing spaces are reassembled from the leading tokens.
    public static func parseLsofOutput(_ text: String) -> [ListeningPort] {
        var seen = Set<String>()
        var ports: [ListeningPort] = []
        for line in text.split(separator: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasSuffix("(LISTEN)") else { continue }  // also skips the header line
            let tokens = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
            guard tokens.count >= 10, let pid = Int32(tokens[tokens.count - 9]) else { continue }
            let name = tokens[tokens.count - 2]
            let node = tokens[tokens.count - 3]
            let processName = tokens[0..<(tokens.count - 9)].joined(separator: " ")
            guard let colon = name.lastIndex(of: ":"), let port = Int(name[name.index(after: colon)...]) else { continue }
            var address = String(name[..<colon])
            if address.hasPrefix("["), address.hasSuffix("]") { address = String(address.dropFirst().dropLast()) }
            guard seen.insert("\(pid):\(port)").inserted else { continue }
            ports.append(ListeningPort(port: port, protocolName: node, address: address, pid: pid, processName: processName))
        }
        return ports.sorted { $0.port < $1.port }
    }

    /// Parses `ps axo pid=,pcpu=,pmem=,rss=,comm=` output. The command is the
    /// remainder of the line, so paths containing spaces are preserved verbatim.
    public static func parsePsOutput(_ text: String) -> [RunningProcess] {
        var processes: [RunningProcess] = []
        for line in text.split(separator: "\n") {
            guard let match = line.wholeMatch(of: /\s*(\d+)\s+([\d.,]+)\s+([\d.,]+)\s+(\d+)\s+(.+?)\s*/),
                  let pid = Int32(match.1),
                  let cpu = Double(match.2.replacingOccurrences(of: ",", with: ".")),
                  let mem = Double(match.3.replacingOccurrences(of: ",", with: ".")),
                  let rssKB = Int64(match.4) else { continue }
            processes.append(RunningProcess(pid: pid, cpuPercent: cpu, memPercent: mem, rssBytes: rssKB * 1024, command: String(match.5)))
        }
        return processes
    }

    public static func terminate(pid: Int32, force: Bool) -> TerminateOutcome {
        guard pid > 0 else { return .failure("Invalid PID \(pid)") }
        guard kill(pid, force ? SIGKILL : SIGTERM) != 0 else { return .success }
        switch errno {
        case EPERM: return .failure("Permission denied — process owned by another user")
        case ESRCH: return .failure("No such process")
        default: return .failure(String(cString: strerror(errno)))
        }
    }

    private static func runCommand(_ path: String, _ arguments: [String]) async throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let stdout = Pipe()
        process.standardOutput = stdout
        process.standardError = Pipe()
        do { try process.run() } catch {
            throw ProcessManagerError.commandFailed("Failed to run \(path): \(error.localizedDescription)")
        }
        let data = (try? stdout.fileHandleForReading.readToEnd()) ?? Data()
        process.waitUntilExit()
        // Lossy decode: lsof/ps output can contain non-UTF8 bytes (e.g. process
        // names with raw escape bytes). Strict decoding would return nil and
        // silently discard the entire output; lossy decoding replaces invalid
        // sequences with U+FFFD and keeps every row parseable.
        return String(decoding: data, as: UTF8.self)
    }
}
