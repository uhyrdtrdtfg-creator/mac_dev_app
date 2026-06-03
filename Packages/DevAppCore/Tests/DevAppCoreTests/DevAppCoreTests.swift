import Testing
@testable import DevAppCore

@Test func toolCategoryHasAllCases() {
    #expect(ToolCategory.allCases.count == 5)
    #expect(ToolCategory.allCases.contains(.developer))
    #expect(ToolCategory.allCases.contains(.generators))
}
