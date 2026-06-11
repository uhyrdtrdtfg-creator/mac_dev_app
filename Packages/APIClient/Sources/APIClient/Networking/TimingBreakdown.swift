import Foundation

/// Per-phase timing of a request, from URLSessionTaskTransactionMetrics.
public struct TimingBreakdown: Codable, Sendable, Equatable {
    public var dnsMillis: Double?
    public var tcpMillis: Double?
    public var tlsMillis: Double?
    public var ttfbMillis: Double?
    public var downloadMillis: Double?
    public var totalMillis: Double

    public init(dnsMillis: Double? = nil, tcpMillis: Double? = nil, tlsMillis: Double? = nil, ttfbMillis: Double? = nil, downloadMillis: Double? = nil, totalMillis: Double) {
        self.dnsMillis = dnsMillis; self.tcpMillis = tcpMillis; self.tlsMillis = tlsMillis
        self.ttfbMillis = ttfbMillis; self.downloadMillis = downloadMillis; self.totalMillis = totalMillis
    }

    /// Pure phase derivation from transaction timestamps (testable without URLSession).
    /// TCP excludes the TLS handshake when secureConnectionStart falls inside the
    /// connect interval.
    public static func from(
        fetchStart: Date?, domainLookupStart: Date?, domainLookupEnd: Date?,
        connectStart: Date?, secureConnectionStart: Date?, secureConnectionEnd: Date?,
        connectEnd: Date?, requestStart: Date?, responseStart: Date?, responseEnd: Date?
    ) -> TimingBreakdown? {
        guard let responseEnd else { return nil }
        let start = fetchStart ?? domainLookupStart ?? connectStart ?? requestStart
        guard let start else { return nil }

        func millis(_ a: Date?, _ b: Date?) -> Double? {
            guard let a, let b, b >= a else { return nil }
            return b.timeIntervalSince(a) * 1000
        }

        let tcpEnd = secureConnectionStart ?? connectEnd
        return TimingBreakdown(
            dnsMillis: millis(domainLookupStart, domainLookupEnd),
            tcpMillis: millis(connectStart, tcpEnd),
            tlsMillis: millis(secureConnectionStart, secureConnectionEnd),
            ttfbMillis: millis(requestStart, responseStart),
            downloadMillis: millis(responseStart, responseEnd),
            totalMillis: responseEnd.timeIntervalSince(start) * 1000
        )
    }

    static func from(metrics: URLSessionTaskMetrics) -> TimingBreakdown? {
        guard let tx = metrics.transactionMetrics.last(where: { $0.resourceFetchType == .networkLoad }) ?? metrics.transactionMetrics.last else { return nil }
        return from(
            fetchStart: tx.fetchStartDate,
            domainLookupStart: tx.domainLookupStartDate, domainLookupEnd: tx.domainLookupEndDate,
            connectStart: tx.connectStartDate,
            secureConnectionStart: tx.secureConnectionStartDate, secureConnectionEnd: tx.secureConnectionEndDate,
            connectEnd: tx.connectEndDate,
            requestStart: tx.requestStartDate, responseStart: tx.responseStartDate, responseEnd: tx.responseEndDate
        )
    }
}
