import Testing
import Foundation
@testable import ConversionTools

// MARK: - Reply parsing

@Test func parseIPv4Reply() {
    let reply = PingEngine.parseReplyLine("64 bytes from 93.184.216.34: icmp_seq=0 ttl=56 time=11.632 ms")
    #expect(reply?.bytes == 64)
    #expect(reply?.host == "93.184.216.34")
    #expect(reply?.sequence == 0)
    #expect(reply?.ttl == 56)
    #expect(reply?.timeMilliseconds == 11.632)
}

@Test func parseReplyToleratesTrailingDuplicateMarker() {
    // ping appends "(DUP!)" for duplicate replies — the prefix must still parse.
    let reply = PingEngine.parseReplyLine("64 bytes from 127.0.0.1: icmp_seq=2 ttl=64 time=0.087 ms (DUP!)")
    #expect(reply?.sequence == 2)
    #expect(reply?.timeMilliseconds == 0.087)
    #expect(reply?.ttl == 64)
}

@Test func parseIPv6Reply() {
    // ping6 uses a comma before icmp_seq and `hlim` instead of `ttl`.
    let reply = PingEngine.parseReplyLine("16 bytes from 2606:2800:220:1:248:1893:25c8:1946, icmp_seq=3 hlim=55 time=11.4 ms")
    #expect(reply?.host == "2606:2800:220:1:248:1893:25c8:1946")
    #expect(reply?.sequence == 3)
    #expect(reply?.ttl == 55)
    #expect(reply?.timeMilliseconds == 11.4)
}

@Test func parseReplyRejectsNonReplyLines() {
    #expect(PingEngine.parseReplyLine("PING 8.8.8.8 (8.8.8.8): 56 data bytes") == nil)
    #expect(PingEngine.parseReplyLine("Request timeout for icmp_seq 4") == nil)
    #expect(PingEngine.parseReplyLine("") == nil)
}

// MARK: - Timeout parsing

@Test func parseTimeoutLine() {
    #expect(PingEngine.parseTimeout("Request timeout for icmp_seq 7") == 7)
    #expect(PingEngine.parseTimeout("64 bytes from 1.1.1.1: icmp_seq=0 ttl=59 time=9 ms") == nil)
}

// MARK: - Statistics parsing

@Test func parseStatisticsBasic() {
    let text = """
    --- example.com ping statistics ---
    5 packets transmitted, 5 packets received, 0.0% packet loss
    round-trip min/avg/max/stddev = 11.632/12.345/13.456/0.789 ms
    """
    let stats = PingEngine.parseStatistics(text)
    #expect(stats?.transmitted == 5)
    #expect(stats?.received == 5)
    #expect(stats?.packetLossPercent == 0.0)
    #expect(stats?.roundTrip == PingRoundTrip(min: 11.632, avg: 12.345, max: 13.456, stddev: 0.789))
}

@Test func parseStatisticsWithLossAndNoRoundTrip() {
    let text = """
    --- 10.255.255.1 ping statistics ---
    3 packets transmitted, 0 packets received, 100.0% packet loss
    """
    let stats = PingEngine.parseStatistics(text)
    #expect(stats?.transmitted == 3)
    #expect(stats?.received == 0)
    #expect(stats?.packetLossPercent == 100.0)
    #expect(stats?.roundTrip == nil)
}

@Test func parseStatisticsWithDuplicates() {
    let text = """
    --- 127.0.0.1 ping statistics ---
    5 packets transmitted, 6 packets received, +1 duplicates, 0.0% packet loss
    round-trip min/avg/max/stddev = 0.045/0.067/0.123/0.028 ms
    """
    let stats = PingEngine.parseStatistics(text)
    #expect(stats?.transmitted == 5)
    #expect(stats?.received == 6)
    #expect(stats?.packetLossPercent == 0.0)
    #expect(stats?.roundTrip?.max == 0.123)
}

@Test func parseStatisticsReturnsNilForNonSummary() {
    #expect(PingEngine.parseStatistics("64 bytes from 1.1.1.1: icmp_seq=0 ttl=59 time=9 ms") == nil)
}

// MARK: - Line classification

@Test func classifyRoutesLines() {
    if case .start(let banner)? = PingEngine.classify("PING 8.8.8.8 (8.8.8.8): 56 data bytes") {
        #expect(banner.hasPrefix("PING"))
    } else {
        Issue.record("expected .start")
    }

    if case .reply(let reply)? = PingEngine.classify("64 bytes from 8.8.8.8: icmp_seq=1 ttl=117 time=14.2 ms") {
        #expect(reply.sequence == 1)
    } else {
        Issue.record("expected .reply")
    }

    if case .timeout(let seq)? = PingEngine.classify("Request timeout for icmp_seq 9") {
        #expect(seq == 9)
    } else {
        Issue.record("expected .timeout")
    }

    #expect(PingEngine.classify("--- 8.8.8.8 ping statistics ---") == nil)
}

// MARK: - Live smoke test

@Test func pingLocalhostStreamsEvents() async {
    // Drives the whole subprocess → parse → AsyncStream pipeline end to end
    // against loopback (no external network needed). Tolerant of restricted
    // environments: it asserts the plumbing always reaches a terminal state and
    // that any replies are well-formed, rather than requiring ICMP to succeed.
    var events: [PingEvent] = []
    for await event in PingEngine.ping(host: "127.0.0.1", count: 2) {
        events.append(event)
    }

    #expect(!events.isEmpty)

    let replies = events.compactMap { event -> PingReply? in
        if case .reply(let reply) = event { return reply }
        return nil
    }
    for reply in replies { #expect(reply.timeMilliseconds >= 0) }

    let hasSummary = events.contains { if case .summary = $0 { return true }; return false }
    let hasFailure = events.contains { if case .failure = $0 { return true }; return false }
    // Either ping succeeded (reply + summary) or the environment refused it
    // (failure) — but the stream must always terminate, never hang.
    #expect(hasSummary || hasFailure)
}
