import Testing
import Foundation
@testable import ConversionTools

private let booksXML = #"<catalog><book id="b1"><title>Swift</title></book><book id="b2"><title>Rust</title></book></catalog>"#

@Test func xpathElementMatch() {
    let result = XPathQuery.query(booksXML, xpath: "//book[1]")
    #expect(result.matchCount == 1)
    #expect(result.output == #"<book id="b1"><title>Swift</title></book>"#)
    #expect(result.error == nil)
}

@Test func xpathAttributeMatch() {
    let result = XPathQuery.query(booksXML, xpath: "//book/@id")
    #expect(result.matchCount == 2)
    #expect(result.output == "b1\nb2")
    #expect(result.error == nil)
}

@Test func xpathTextSelection() {
    let result = XPathQuery.query(booksXML, xpath: "//book[1]/title/text()")
    #expect(result.matchCount == 1)
    #expect(result.output == "Swift")
    #expect(result.error == nil)
}

@Test func xpathMultipleMatchCount() {
    let result = XPathQuery.query(booksXML, xpath: "//title")
    #expect(result.matchCount == 2)
    #expect(result.error == nil)
}

@Test func xpathNoMatchReturnsEmptyNotError() {
    let result = XPathQuery.query(booksXML, xpath: "//magazine")
    #expect(result.matchCount == 0)
    #expect(result.output == "")
    #expect(result.error == nil)
}

@Test func xpathInvalidExpression() {
    let result = XPathQuery.query(booksXML, xpath: "///[[bad")
    #expect(result.output == nil)
    #expect(result.error?.contains("Invalid XPath") == true)
}

@Test func xpathInvalidXML() {
    let result = XPathQuery.query("<a><b></a>", xpath: "//b")
    #expect(result.output == nil)
    #expect(result.error != nil)
}

@Test func xpathNamespacePrefix() {
    let xml = #"<catalog xmlns:bk="http://example.com/book"><bk:book id="1"><bk:title>Swift</bk:title></bk:book></catalog>"#
    let result = XPathQuery.query(xml, xpath: "//bk:book/@id")
    #expect(result.matchCount == 1)
    #expect(result.output == "1")
    #expect(result.error == nil)
}
