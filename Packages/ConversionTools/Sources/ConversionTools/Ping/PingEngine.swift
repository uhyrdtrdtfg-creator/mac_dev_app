import Foundation

// MARK: - Model

/// A single ICMP echo reply parsed from `ping` output.
public struct PingReply: Identifiable, Sendable {
    public let id = UUID()
    public let sequence: Int
    public let bytes: Int
    /// The responding host/IP (numeric, because we ask `ping` for `-n`).
    public let host: String
    /// IP TTL (IPv4) or hop limit (IPv6); absent when `ping` omits it.
    public let ttl: Int?
    public let timeMilliseconds: Double

    public init(sequence: Int, bytes: Int, host: String, ttl: Int?, timeMilliseconds: Double) {
        self.sequence = sequence
        self.bytes = bytes
        self.host = host
        self.ttl = ttl
        self.timeMilliseconds = timeMilliseconds
    }
}

/// Round-trip latency aggregates from the trailing `ping` summary block.
public struct PingRoundTrip: Sendable, Equatable {
    public let min: Double
    public let avg: Double
    public let max: Double
    public let stddev: Double

    public init(min: Double, avg: Double, max: Double, stddev: Double) {
        self.min = min
        self.avg = avg
        self.max = max
        self.stddev = stddev
    }
}

/// The `--- host ping statistics ---` summary at the end of a run.
public struct PingStatistics: Sendable, Equatable {
    public let transmitted: Int
    public let received: Int
    public let packetLossPercent: Double
    public let roundTrip: PingRoundTrip?

    public init(transmitted: Int, received: Int, packetLossPercent: Double, roundTrip: PingRoundTrip?) {
        self.transmitted = transmitted
        self.received = received
        self.packetLossPercent = packetLossPercent
        self.roundTrip = roundTrip
    }
}

/// An event streamed from a live ping run, in arrival order.
public enum PingEvent: Sendable {
    /// The opening `PING host (ip): N data bytes` banner line.
    case start(String)
    case reply(PingReply)
    case timeout(sequence: Int)
    /// Final statistics, emitted once the process exits (or is stopped).
    case summary(PingStatistics)
    /// A hard error line (e.g. `ping: cannot resolve host: Unknown host`).
    case failure(String)
}

// MARK: - Engine

/// Drives the system `ping`/`ping6` binary and parses its output.
///
/// The parsing half is intentionally a set of pure, side-effect-free functions
/// so the brittle text handling can be unit-tested without touching the network
/// — mirroring how `DNSLookupEngine` keeps its codec testable. The transport
/// half shells out (the app is not sandboxed, like `ProcessManager`) and streams
/// results as they arrive via an `AsyncStream`.
public enum PingEngine {

    // MARK: Parsing (pure)

    /// Parses an echo-reply line, e.g.
    /// `64 bytes from 93.184.216.34: icmp_seq=0 ttl=56 time=11.632 ms`
    /// and the IPv6 form `16 bytes from 2606:…:1946, icmp_seq=0 hlim=56 time=11.4 ms`.
    public static func parseReplyLine(_ line: String) -> PingReply? {
        let pattern = #/(\d+) bytes from (.+?)[:,] icmp_seq=(\d+) (?:ttl|hlim)=(\d+) time=([\d.]+) ?ms/#
        guard let m = line.firstMatch(of: pattern),
              let bytes = Int(m.1),
              let seq = Int(m.3),
              let ttl = Int(m.4),
              let time = Double(m.5) else { return nil }
        return PingReply(
            sequence: seq,
            bytes: bytes,
            host: String(m.2),
            ttl: ttl,
            timeMilliseconds: time
        )
    }

    /// Parses `Request timeout for icmp_seq 7`, returning the sequence number.
    public static func parseTimeout(_ line: String) -> Int? {
        guard let m = line.firstMatch(of: #/Request timeout for icmp_seq (\d+)/#) else { return nil }
        return Int(m.1)
    }

    /// Parses the trailing statistics block. Returns `nil` if the
    /// `packets transmitted` line is absent (i.e. not a summary).
    public static func parseStatistics(_ text: String) -> PingStatistics? {
        guard let counts = text.firstMatch(of: #/(\d+) packets transmitted, (\d+) packets received/#),
              let tx = Int(counts.1),
              let rx = Int(counts.2) else { return nil }

        let loss: Double
        if let lossMatch = text.firstMatch(of: #/([\d.]+)% packet loss/#), let value = Double(lossMatch.1) {
            loss = value
        } else {
            loss = tx > 0 ? Double(tx - rx) / Double(tx) * 100 : 0
        }

        var roundTrip: PingRoundTrip?
        let rttPattern = #/min/avg/max/(?:stddev|std-dev) = ([\d.]+)/([\d.]+)/([\d.]+)/([\d.]+) ?ms/#
        if let r = text.firstMatch(of: rttPattern),
           let mn = Double(r.1), let av = Double(r.2), let mx = Double(r.3), let sd = Double(r.4) {
            roundTrip = PingRoundTrip(min: mn, avg: av, max: mx, stddev: sd)
        }

        return PingStatistics(transmitted: tx, received: rx, packetLossPercent: loss, roundTrip: roundTrip)
    }

    /// Classifies a single stdout line into a live event, or `nil` for lines
    /// that only matter to the end-of-run summary (handled separately).
    static func classify(_ raw: String) -> PingEvent? {
        let line = raw.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else { return nil }
        if line.hasPrefix("PING ") { return .start(line) }
        if let seq = parseTimeout(line) { return .timeout(sequence: seq) }
        if let reply = parseReplyLine(line) { return .reply(reply) }
        return nil
    }

    // MARK: Transport (subprocess)

    /// Streams ICMP echo results for `host`.
    ///
    /// - Parameters:
    ///   - host: hostname or IP. An IPv6 literal routes to `/sbin/ping6`.
    ///   - count: number of packets, or `nil` for continuous (stops when the
    ///     consumer cancels iteration).
    ///   - perReplyTimeoutMs: how long `ping` waits for each reply (IPv4 only).
    ///   - packetSize: optional ICMP payload size in bytes.
    ///
    /// Cancelling the consuming task interrupts `ping` (SIGINT), which prints its
    /// summary and exits cleanly, so a final `.summary` event is still delivered.
    public static func ping(
        host: String,
        count: Int?,
        perReplyTimeoutMs: Int = 2000,
        packetSize: Int? = nil
    ) -> AsyncStream<PingEvent> {
        let isIPv6 = host.contains(":")
        let executable = isIPv6 ? "/sbin/ping6" : "/sbin/ping"

        var arguments: [String] = []
        if !isIPv6 {
            // -n: numeric output (no reverse DNS, keeps "from <ip>" stable & fast)
            // -W: per-reply wait so timeouts surface promptly. ping6 lacks both.
            arguments += ["-n", "-W", String(perReplyTimeoutMs)]
        }
        if let count, count > 0 { arguments += ["-c", String(count)] }
        if let packetSize { arguments += ["-s", String(packetSize)] }
        arguments.append(host)

        return AsyncStream { continuation in
            let run = PingRun(executable: executable, arguments: arguments, continuation: continuation)
            continuation.onTermination = { _ in run.interrupt() }
            run.start()
        }
    }
}

// MARK: - Process driver

/// Owns the `ping` process and its pipes, feeding parsed events into an
/// `AsyncStream` continuation. Marked `@unchecked Sendable` because access to
/// `fullStdout` is confined to the single reader task and only read after the
/// reader group joins (a happens-before established by the task group).
private final class PingRun: @unchecked Sendable {
    private let process = Process()
    private let stdoutPipe = Pipe()
    private let stderrPipe = Pipe()
    private let continuation: AsyncStream<PingEvent>.Continuation
    private var fullStdout = ""

    init(
        executable: String,
        arguments: [String],
        continuation: AsyncStream<PingEvent>.Continuation
    ) {
        self.continuation = continuation
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
    }

    func start() {
        do {
            try process.run()
        } catch {
            let name = process.executableURL?.lastPathComponent ?? "ping"
            continuation.yield(.failure("Failed to launch \(name): \(error.localizedDescription)"))
            continuation.finish()
            return
        }

        Task.detached { [self] in
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await self.readStdout() }
                group.addTask { await self.readStderr() }
            }
            process.waitUntilExit()
            if let stats = PingEngine.parseStatistics(fullStdout) {
                continuation.yield(.summary(stats))
            }
            continuation.finish()
        }
    }

    private func readStdout() async {
        do {
            for try await line in stdoutPipe.fileHandleForReading.bytes.lines {
                fullStdout += line + "\n"
                if let event = PingEngine.classify(line) { continuation.yield(event) }
            }
        } catch {
            // Read interrupted (e.g. process torn down) — nothing to recover.
        }
    }

    private func readStderr() async {
        do {
            for try await line in stderrPipe.fileHandleForReading.bytes.lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if !trimmed.isEmpty { continuation.yield(.failure(trimmed)) }
            }
        } catch {
            // Same as stdout: best-effort.
        }
    }

    func interrupt() {
        if process.isRunning { process.interrupt() }
    }
}
