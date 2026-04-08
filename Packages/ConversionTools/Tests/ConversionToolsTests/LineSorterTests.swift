import Testing
@testable import ConversionTools

@Test func sortAscending() { #expect(LineSorter.sort("c\na\nb", mode: .ascending) == "a\nb\nc") }
@Test func sortDescending() { #expect(LineSorter.sort("a\nb\nc", mode: .descending) == "c\nb\na") }
@Test func sortReverse() { #expect(LineSorter.sort("1\n2\n3", mode: .reverse) == "3\n2\n1") }
@Test func deduplicate() { #expect(LineSorter.deduplicate("a\nb\na\nc\nb") == "a\nb\nc") }
@Test func stats() { let s = LineSorter.stats("a\nb\na\n"); #expect(s.total == 4); #expect(s.unique == 3); #expect(s.duplicates == 1); #expect(s.empty == 1) }
