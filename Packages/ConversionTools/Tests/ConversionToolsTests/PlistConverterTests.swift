import Testing
import Foundation
@testable import ConversionTools

private let xmlFixture = """
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>name</key>
    <string>DevToolkit</string>
    <key>count</key>
    <integer>42</integer>
    <key>ratio</key>
    <real>3.14</real>
    <key>enabled</key>
    <true/>
    <key>created</key>
    <date>2024-01-15T10:30:00Z</date>
    <key>payload</key>
    <data>aGVsbG8=</data>
    <key>tags</key>
    <array>
        <string>a</string>
        <integer>1</integer>
    </array>
    <key>nested</key>
    <dict>
        <key>inner</key>
        <string>value</string>
    </dict>
</dict>
</plist>
"""

@Test func plistXMLToJSON() {
    let result = PlistConverter.plistToJSON(xmlFixture)
    #expect(result.error == nil)
    let json = result.output ?? ""
    #expect(json.contains(#""name" : "DevToolkit""#))
    #expect(json.contains(#""count" : 42"#))
    #expect(json.contains("3.14"))
    #expect(json.contains(#""enabled" : true"#))
    #expect(json.contains(#""created" : "2024-01-15T10:30:00Z""#))
    #expect(json.contains(#""payload" : "aGVsbG8=""#))
    #expect(json.contains(#""inner" : "value""#))
    #expect(json.contains(#""tags""#))
}

@Test func plistJSONToXML() {
    let json = #"{"name":"x","count":3,"ratio":1.5,"flag":false,"items":["a","b"],"created":"2024-01-15T10:30:00Z"}"#
    let result = PlistConverter.jsonToXML(json)
    #expect(result.error == nil)
    let xml = result.output ?? ""
    #expect(xml.contains("<string>x</string>"))
    #expect(xml.contains("<integer>3</integer>"))
    #expect(xml.contains("<real>1.5</real>"))
    #expect(xml.contains("<false/>"))
    #expect(xml.contains("<date>2024-01-15T10:30:00Z</date>"))
    #expect(xml.contains("<array>"))
}

@Test func plistJSONRoundtrip() throws {
    let json = #"{"a":1,"b":"text","c":[true,2.5],"d":{"e":"f"},"when":"2030-06-01T08:00:00Z"}"#
    let xml = try #require(PlistConverter.jsonToXML(json).output)
    let back = try #require(PlistConverter.plistToJSON(xml).output)
    let original = try JSONSerialization.jsonObject(with: Data(json.utf8)) as? NSDictionary
    let roundtripped = try JSONSerialization.jsonObject(with: Data(back.utf8)) as? NSDictionary
    #expect(original == roundtripped)
}

@Test func plistBinaryDataToXML() throws {
    let object: [String: Any] = ["title": "binary", "version": 2, "active": true]
    let binary = try PropertyListSerialization.data(fromPropertyList: object, format: .binary, options: 0)
    let result = PlistConverter.dataToXML(binary)
    #expect(result.error == nil)
    let xml = result.output ?? ""
    #expect(xml.contains("<string>binary</string>"))
    #expect(xml.contains("<integer>2</integer>"))
    #expect(xml.contains("<true/>"))
}

@Test func plistBase64BinaryInput() throws {
    let object: [String: Any] = ["key": "value"]
    let binary = try PropertyListSerialization.data(fromPropertyList: object, format: .binary, options: 0)
    let base64 = binary.base64EncodedString()

    #expect(PlistConverter.detect(base64) == .base64Binary)

    let xml = PlistConverter.base64BinaryToXML(base64)
    #expect(xml.error == nil)
    #expect((xml.output ?? "").contains("<string>value</string>"))

    let json = PlistConverter.plistToJSON(base64)
    #expect(json.error == nil)
    #expect((json.output ?? "").contains(#""key" : "value""#))
}

@Test func plistXMLToBinary() throws {
    let result = PlistConverter.xmlToBinary(xmlFixture)
    #expect(result.error == nil)
    let data = try #require(result.data)
    #expect(data.prefix(6) == Data("bplist".utf8))
    #expect(result.base64 == data.base64EncodedString())

    let back = PlistConverter.plistDataToJSON(data)
    #expect((back.output ?? "").contains(#""name" : "DevToolkit""#))
}

@Test func plistInvalidXMLError() {
    let result = PlistConverter.plistToJSON("<plist version=\"1.0\"><dict><key>oops</key></dict></plist>")
    #expect(result.output == nil)
    #expect(result.error != nil)

    let garbage = PlistConverter.formatXML("not a plist at all")
    #expect(garbage.output == nil)
    #expect(garbage.error != nil)
}

@Test func plistJSONNullRejected() {
    let result = PlistConverter.jsonToXML(#"{"a":{"b":[1,null]}}"#)
    #expect(result.output == nil)
    let error = result.error ?? ""
    #expect(error.contains("null"))
    #expect(error.contains("$.a.b[1]"))
}

@Test func plistFormatValidate() throws {
    let messy = "<plist version=\"1.0\"><dict><key>z</key><string>last</string><key>a</key><integer>1</integer></dict></plist>"
    let result = PlistConverter.formatXML(messy)
    #expect(result.error == nil)
    let xml = try #require(result.output)
    #expect(xml.contains("<?xml version=\"1.0\" encoding=\"UTF-8\"?>"))
    #expect(xml.contains("<key>a</key>"))
    #expect(xml.contains("<string>last</string>"))
}

@Test func plistDetectKinds() {
    #expect(PlistConverter.detect("<?xml version=\"1.0\"?><plist><dict/></plist>") == .xmlPlist)
    #expect(PlistConverter.detect("<plist version=\"1.0\"><array/></plist>") == .xmlPlist)
    #expect(PlistConverter.detect("{\"a\":1}") == .json)
    #expect(PlistConverter.detect("[1,2]") == .json)
    #expect(PlistConverter.detect("plain text") == .unknown)
}

@Test func plistNonDateStringStaysString() throws {
    let xml = try #require(PlistConverter.jsonToXML(#"{"note":"2024-01-15","b64":"aGVsbG8="}"#).output)
    #expect(xml.contains("<string>2024-01-15</string>"))
    #expect(xml.contains("<string>aGVsbG8=</string>"))
    #expect(!xml.contains("<data>"))
    #expect(!xml.contains("<date>"))
}
