import Testing
@testable import ConversionTools

@Test func htmlEncode() { #expect(HTMLEntityCodec.encode("<div class=\"test\">Hello & World</div>") == "&lt;div class=&quot;test&quot;&gt;Hello &amp; World&lt;/div&gt;") }
@Test func htmlDecode() { #expect(HTMLEntityCodec.decode("&lt;div&gt;Hello &amp; World&lt;/div&gt;") == "<div>Hello & World</div>") }
@Test func htmlDecodeNumeric() { #expect(HTMLEntityCodec.decode("&#72;&#101;&#108;&#108;&#111;") == "Hello") }
@Test func htmlDecodeHex() { #expect(HTMLEntityCodec.decode("&#x48;&#x65;&#x6C;&#x6C;&#x6F;") == "Hello") }
@Test func htmlRoundTrip() { let input = "<p>It's \"cool\" & <fun>"; #expect(HTMLEntityCodec.decode(HTMLEntityCodec.encode(input)) == input) }
