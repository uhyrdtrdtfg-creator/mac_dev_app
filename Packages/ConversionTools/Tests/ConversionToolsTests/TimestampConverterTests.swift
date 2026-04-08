import Testing
import Foundation
@testable import ConversionTools

@Test func timestampToDateUTC() {
    let result = TimestampConverter.toDate(timestamp: 0, timeZone: .gmt)
    #expect(result.iso8601 == "1970-01-01T00:00:00Z")
}

@Test func timestampToDateKnownValue() {
    let result = TimestampConverter.toDate(timestamp: 1704067200, timeZone: .gmt)
    #expect(result.iso8601 == "2024-01-01T00:00:00Z")
}

@Test func dateToTimestamp() {
    let ts = TimestampConverter.toTimestamp(year: 2024, month: 1, day: 1, hour: 0, minute: 0, second: 0, timeZone: .gmt)
    #expect(ts == 1704067200)
}

@Test func autoDetectSeconds() { #expect(TimestampConverter.detectUnit("1704067200") == .seconds) }
@Test func autoDetectMilliseconds() { #expect(TimestampConverter.detectUnit("1704067200000") == .milliseconds) }

@Test func millisecondsToDate() {
    let result = TimestampConverter.toDate(timestamp: 1704067200000, isMilliseconds: true, timeZone: .gmt)
    #expect(result.iso8601 == "2024-01-01T00:00:00Z")
}

@Test func formatCustom() {
    let result = TimestampConverter.toDate(timestamp: 1704067200, timeZone: .gmt)
    #expect(result.custom == "2024-01-01 00:00:00")
}
