import Testing
@testable import ConversionTools

@Test func escapeQuotes() { #expect(StringEscaper.escape("say \"hello\"") == "say \\\"hello\\\"") }
@Test func escapeNewline() { #expect(StringEscaper.escape("line1\nline2") == "line1\\nline2") }
@Test func escapeTab() { #expect(StringEscaper.escape("col1\tcol2") == "col1\\tcol2") }
@Test func escapeBackslash() { #expect(StringEscaper.escape("path\\to") == "path\\\\to") }
@Test func unescapeQuotes() { #expect(StringEscaper.unescape("say \\\"hello\\\"") == "say \"hello\"") }
@Test func unescapeNewline() { #expect(StringEscaper.unescape("line1\\nline2") == "line1\nline2") }
@Test func roundTrip() { let input = "Hello\n\"World\"\t\\End"; #expect(StringEscaper.unescape(StringEscaper.escape(input)) == input) }
