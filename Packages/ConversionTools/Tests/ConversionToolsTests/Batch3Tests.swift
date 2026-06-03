import XCTest
@testable import ConversionTools

final class RegexTesterTests: XCTestCase {
    func testSimpleMatches() {
        guard case .success(let m) = RegexTester.matches(pattern: "\\d+", in: "a1 b22 c333") else { return XCTFail() }
        XCTAssertEqual(m.count, 3)
        XCTAssertEqual(m[1].value, "22")
    }

    func testCaptureGroups() {
        guard case .success(let m) = RegexTester.matches(pattern: "(\\w+)@(\\w+)", in: "user@host") else { return XCTFail() }
        XCTAssertEqual(m.first?.groups.count, 2)
        XCTAssertEqual(m.first?.groups[0].value, "user")
    }

    func testReplace() {
        guard case .success(let r) = RegexTester.replace(pattern: "(\\d+)", in: "x5", template: "[$1]") else { return XCTFail() }
        XCTAssertEqual(r, "x[5]")
    }

    func testInvalidPattern() {
        guard case .failure = RegexTester.matches(pattern: "(", in: "x") else { return XCTFail() }
    }
}

final class CronParserTests: XCTestCase {
    private var utc: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }

    func testParseEveryFiveMinutes() throws {
        let cron = try CronParser.parse("*/5 * * * *")
        XCTAssertTrue(cron.minutes.contains(0))
        XCTAssertTrue(cron.minutes.contains(5))
        XCTAssertFalse(cron.minutes.contains(3))
    }

    func testWrongFieldCount() {
        XCTAssertThrowsError(try CronParser.parse("* * *"))
    }

    func testNextDatesDaily() throws {
        // 2026-01-01 00:00 UTC, cron "0 9 * * *" → next is same day 09:00.
        var comps = DateComponents()
        comps.year = 2026; comps.month = 1; comps.day = 1; comps.hour = 0; comps.minute = 0
        let base = utc.date(from: comps)!
        let next = try CronParser.nextDates("0 9 * * *", after: base, count: 1, calendar: utc)
        let nc = utc.dateComponents([.hour, .minute, .day], from: next[0])
        XCTAssertEqual(nc.hour, 9)
        XCTAssertEqual(nc.minute, 0)
        XCTAssertEqual(nc.day, 1)
    }

    func testDescribe() {
        XCTAssertEqual(CronParser.describe("0 9 * * *"), "At 09:00")
    }
}

final class ColorConverterTests: XCTestCase {
    func testParseHex6() {
        let c = ColorConverter.parse("#3B82F6")
        XCTAssertEqual(c, RGBColor(r: 59, g: 130, b: 246))
    }

    func testParseShortHex() {
        XCTAssertEqual(ColorConverter.parse("#fff"), RGBColor(r: 255, g: 255, b: 255))
    }

    func testParseRGB() {
        XCTAssertEqual(ColorConverter.parse("rgb(10, 20, 30)"), RGBColor(r: 10, g: 20, b: 30))
    }

    func testToHSL() {
        let hsl = ColorConverter.toHSL(RGBColor(r: 255, g: 0, b: 0))
        XCTAssertEqual(hsl.h, 0); XCTAssertEqual(hsl.s, 100); XCTAssertEqual(hsl.l, 50)
    }

    func testContrastBlackWhite() {
        let ratio = ColorConverter.contrastRatio(RGBColor(r: 0, g: 0, b: 0), RGBColor(r: 255, g: 255, b: 255))
        XCTAssertEqual(ratio, 21, accuracy: 0.01)
    }
}

final class SQLFormatterTests: XCTestCase {
    func testFormatUppercasesAndBreaks() {
        let out = SQLFormatter.format("select id, name from users where id = 1")
        XCTAssertTrue(out.contains("SELECT"))
        XCTAssertTrue(out.contains("\nFROM"))
        XCTAssertTrue(out.contains("\nWHERE"))
    }

    func testMinify() {
        let out = SQLFormatter.minify("SELECT  *\nFROM   t")
        XCTAssertEqual(out, "SELECT * FROM t")
    }
}

final class UnicodeInspectorTests: XCTestCase {
    func testCodePoints() {
        let info = UnicodeInspector.inspect("A")
        XCTAssertEqual(info.count, 1)
        XCTAssertEqual(info[0].codePoint, "U+0041")
    }

    func testDetectsZeroWidth() {
        XCTAssertTrue(UnicodeInspector.hasInvisibleCharacters("a\u{200B}b"))
        XCTAssertFalse(UnicodeInspector.hasInvisibleCharacters("ab"))
    }
}

final class CompressionToolTests: XCTestCase {
    func testRoundTripAllAlgorithms() throws {
        let text = String(repeating: "The quick brown fox. ", count: 20)
        for algo in CompressionAlgorithm.allCases {
            let compressed = try CompressionTool.compress(text: text, algorithm: algo)
            let restored = try CompressionTool.decompress(base64: compressed.base64, algorithm: algo)
            XCTAssertEqual(restored, text, "Failed for \(algo.rawValue)")
            XCTAssertLessThan(compressed.compressedBytes, compressed.originalBytes, "No compression for \(algo.rawValue)")
        }
    }
}

final class DotenvConverterTests: XCTestCase {
    func testEnvToJSON() {
        guard case .success(let json) = DotenvConverter.toJSON("PORT=8080\nNAME=app") else { return XCTFail() }
        XCTAssertTrue(json.contains("\"PORT\""))
        XCTAssertTrue(json.contains("8080"))
    }

    func testIniSections() {
        let ini = "[db]\nhost=localhost\nport=5432"
        guard case .success(let json) = DotenvConverter.toJSON(ini) else { return XCTFail() }
        XCTAssertTrue(json.contains("\"db\""))
        XCTAssertTrue(json.contains("localhost"))
    }

    func testJSONToEnv() {
        guard case .success(let env) = DotenvConverter.fromJSON("{\"A\":1,\"B\":\"x\"}") else { return XCTFail() }
        XCTAssertTrue(env.contains("A=1"))
        XCTAssertTrue(env.contains("B=x"))
    }
}
