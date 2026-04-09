import Testing
@testable import ConversionTools

@Test func markdownHeading() {
    let html = MarkdownToHTML.convert("# Hello World")
    #expect(html.contains("<h1>Hello World</h1>"))
}

@Test func markdownBold() {
    let html = MarkdownToHTML.convert("This is **bold** text")
    #expect(html.contains("<strong>bold</strong>"))
}

@Test func markdownItalic() {
    let html = MarkdownToHTML.convert("This is *italic* text")
    #expect(html.contains("<em>italic</em>"))
}

@Test func markdownCode() {
    let html = MarkdownToHTML.convert("Use `code` here")
    #expect(html.contains("<code>code</code>"))
}

@Test func markdownCodeBlock() {
    let html = MarkdownToHTML.convert("```swift\nlet x = 1\n```")
    #expect(html.contains("<pre><code"))
    #expect(html.contains("let x = 1"))
}

@Test func markdownLink() {
    let html = MarkdownToHTML.convert("[Google](https://google.com)")
    #expect(html.contains("<a href=\"https://google.com\">Google</a>"))
}

@Test func markdownList() {
    let html = MarkdownToHTML.convert("- item 1\n- item 2")
    #expect(html.contains("<ul>"))
    #expect(html.contains("<li>"))
}

@Test func markdownTable() {
    let md = "| Name | Age |\n| --- | --- |\n| Alice | 30 |"
    let html = MarkdownToHTML.convert(md)
    #expect(html.contains("<table>"))
    #expect(html.contains("<th>"))
}

@Test func markdownBlockquote() {
    let html = MarkdownToHTML.convert("> This is a quote")
    #expect(html.contains("<blockquote>"))
}
