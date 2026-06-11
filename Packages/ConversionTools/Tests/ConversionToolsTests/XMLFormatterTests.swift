import Testing
import Foundation
@testable import ConversionTools

@Test func xmlFormat2Spaces() {
    let result = XMLFormatter.format("<a><b>x</b></a>", indent: .spaces2)
    let expected = """
    <a>
      <b>x</b>
    </a>
    """
    #expect(result.output == expected)
    #expect(result.error == nil)
}

@Test func xmlFormat4Spaces() {
    let result = XMLFormatter.format("<a><b>x</b></a>", indent: .spaces4)
    let expected = """
    <a>
        <b>x</b>
    </a>
    """
    #expect(result.output == expected)
    #expect(result.error == nil)
}

@Test func xmlFormatTab() {
    let result = XMLFormatter.format("<a><b>x</b></a>", indent: .tab)
    #expect(result.output == "<a>\n\t<b>x</b>\n</a>")
    #expect(result.error == nil)
}

@Test func xmlMinify() {
    let input = """
    <?xml version="1.0" encoding="UTF-8"?>
    <a>
      <b>x</b>
    </a>
    """
    let result = XMLFormatter.minify(input)
    #expect(result.output == #"<?xml version="1.0" encoding="UTF-8"?><a><b>x</b></a>"#)
    #expect(result.error == nil)
}

@Test func xmlFormatPreservesDeclaration() {
    let result = XMLFormatter.format("<?xml version=\"1.0\" encoding=\"UTF-8\"?><a><b>x</b></a>", indent: .spaces2)
    #expect(result.output?.hasPrefix("<?xml version=\"1.0\" encoding=\"UTF-8\"?>") == true)
}

@Test func xmlFormatInvalid() {
    let result = XMLFormatter.format("<a>\n  <b>x</c>\n</a>", indent: .spaces2)
    #expect(result.output == nil)
    #expect(result.error != nil)
    #expect(result.error?.contains("Line 2") == true)
}

@Test func xmlValidateValid() {
    let result = XMLFormatter.validate("<root><child/></root>")
    #expect(result.isValid == true)
    #expect(result.error == nil)
}

@Test func xmlValidateInvalid() {
    let result = XMLFormatter.validate("not xml at all")
    #expect(result.isValid == false)
    #expect(result.error != nil)
}

@Test func xmlFormatPreservesAttributesAndCDATA() {
    let result = XMLFormatter.format(#"<r><e id="7" name="n"><![CDATA[<x> & raw]]></e></r>"#, indent: .spaces2)
    #expect(result.error == nil)
    #expect(result.output?.contains(#"id="7""#) == true)
    #expect(result.output?.contains(#"name="n""#) == true)
    #expect(result.output?.contains("<![CDATA[<x> & raw]]>") == true)
}

@Test func xmlFormatPreservesComments() {
    let result = XMLFormatter.format("<r><!-- keep me --><e/></r>", indent: .spaces2)
    #expect(result.output?.contains("<!-- keep me -->") == true)
}

@Test func xmlFormatHandlesNamespaces() {
    let input = #"<catalog xmlns:bk="http://example.com/book"><bk:book id="1"><bk:title>Swift</bk:title></bk:book></catalog>"#
    let result = XMLFormatter.format(input, indent: .spaces2)
    #expect(result.error == nil)
    #expect(result.output?.contains(#"xmlns:bk="http://example.com/book""#) == true)
    #expect(result.output?.contains("<bk:title>Swift</bk:title>") == true)
}

@Test func xmlMinifyInvalid() {
    let result = XMLFormatter.minify("<a><b></a>")
    #expect(result.output == nil)
    #expect(result.error != nil)
}
