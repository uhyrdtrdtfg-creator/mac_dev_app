import Testing
@testable import ConversionTools

@Test func diffIdentical() {
    let result = DiffEngine.diff(old: "hello\nworld", new: "hello\nworld")
    #expect(result.allSatisfy { $0.type == .equal })
    #expect(result.count == 2)
}

@Test func diffAddedLine() {
    let result = DiffEngine.diff(old: "hello", new: "hello\nworld")
    let added = result.filter { $0.type == .added }
    #expect(added.count == 1)
    #expect(added.first?.text == "world")
}

@Test func diffRemovedLine() {
    let result = DiffEngine.diff(old: "hello\nworld", new: "hello")
    let removed = result.filter { $0.type == .removed }
    #expect(removed.count == 1)
    #expect(removed.first?.text == "world")
}

@Test func diffModifiedLine() {
    let result = DiffEngine.diff(old: "hello\nworld", new: "hello\nearth")
    let removed = result.filter { $0.type == .removed }
    let added = result.filter { $0.type == .added }
    #expect(removed.count == 1)
    #expect(added.count == 1)
    #expect(removed.first?.text == "world")
    #expect(added.first?.text == "earth")
}

@Test func diffEmpty() {
    let result = DiffEngine.diff(old: "", new: "")
    #expect(result.count == 1) // one empty line
}

@Test func diffStats() {
    let result = DiffEngine.diff(old: "a\nb\nc", new: "a\nx\nc")
    let stats = DiffEngine.stats(from: result)
    #expect(stats.additions == 1)
    #expect(stats.deletions == 1)
    #expect(stats.unchanged == 2)
}

@Test func diffLineNumbers() {
    let result = DiffEngine.diff(old: "a\nb", new: "a\nc")
    let equal = result.first { $0.type == .equal }
    #expect(equal?.leftLineNumber == 1)
    #expect(equal?.rightLineNumber == 1)
}
