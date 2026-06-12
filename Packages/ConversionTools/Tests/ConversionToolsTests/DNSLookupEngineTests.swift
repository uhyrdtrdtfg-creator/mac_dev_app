import Testing
import Foundation
@testable import ConversionTools

private func u16(_ value: UInt16) -> [UInt8] { [UInt8(value >> 8), UInt8(value & 0xFF)] }
private func u32(_ value: UInt32) -> [UInt8] {
    [UInt8(value >> 24), UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
}
private func wireName(_ name: String) -> [UInt8] {
    var bytes: [UInt8] = []
    for label in name.split(separator: ".") {
        bytes.append(UInt8(label.utf8.count))
        bytes.append(contentsOf: Array(label.utf8))
    }
    bytes.append(0)
    return bytes
}
private func dnsHeader(id: UInt16, flags: UInt16, qd: UInt16, an: UInt16, ns: UInt16 = 0) -> [UInt8] {
    u16(id) + u16(flags) + u16(qd) + u16(an) + u16(ns) + u16(0)
}

@Test func dnsEncodeQueryWireFormat() throws {
    let query = try DNSLookupEngine.encodeQuery(name: "example.com", type: .a, id: 0xABCD)
    let expected: [UInt8] = u16(0xABCD) + u16(0x0100) + u16(1) + u16(0) + u16(0) + u16(0)
        + wireName("example.com") + u16(1) + u16(1)
    #expect([UInt8](query) == expected)
}

@Test func dnsEncodeNameTrailingDotAndInvalid() throws {
    #expect(try DNSLookupEngine.encodeName("example.com.") == DNSLookupEngine.encodeName("example.com"))
    #expect(throws: DNSError.self) { try DNSLookupEngine.encodeName("") }
    #expect(throws: DNSError.self) { try DNSLookupEngine.encodeName("a..b") }
    #expect(throws: DNSError.self) { try DNSLookupEngine.encodeName(String(repeating: "a", count: 64) + ".com") }
}

@Test func dnsDecodeMultiAnswerWithCompression() throws {
    var bytes = dnsHeader(id: 0x1234, flags: 0x8180, qd: 1, an: 2)
    bytes += wireName("example.com") + u16(1) + u16(1)
    bytes += u16(0xC00C) + u16(1) + u16(1) + u32(300) + u16(4) + [93, 184, 216, 34]
    bytes += u16(0xC00C) + u16(1) + u16(1) + u32(60) + u16(4) + [93, 184, 216, 35]

    let message = try DNSLookupEngine.decode(Data(bytes))
    #expect(message.id == 0x1234)
    #expect(message.isResponse)
    #expect(message.recursionAvailable)
    #expect(!message.isTruncated)
    #expect(message.rcode == 0)
    #expect(message.rcodeName == "NOERROR")
    #expect(message.answers.count == 2)
    #expect(message.answers[0].name == "example.com")
    #expect(message.answers[0].type == "A")
    #expect(message.answers[0].ttl == 300)
    #expect(message.answers[0].value == "93.184.216.34")
    #expect(message.answers[1].ttl == 60)
    #expect(message.answers[1].value == "93.184.216.35")
}

@Test func dnsDecodeCNAMEWithPointerInsideRDATA() throws {
    var bytes = dnsHeader(id: 1, flags: 0x8180, qd: 1, an: 1)
    bytes += wireName("www.example.com") + u16(5) + u16(1)
    let rdata: [UInt8] = [3] + Array("cdn".utf8) + u16(0xC010)
    bytes += u16(0xC00C) + u16(5) + u16(1) + u32(120) + u16(UInt16(rdata.count)) + rdata

    let message = try DNSLookupEngine.decode(Data(bytes))
    #expect(message.answers.count == 1)
    #expect(message.answers[0].name == "www.example.com")
    #expect(message.answers[0].type == "CNAME")
    #expect(message.answers[0].value == "cdn.example.com")
}

@Test func dnsDecodeMXWithCompressedHost() throws {
    var bytes = dnsHeader(id: 2, flags: 0x8180, qd: 1, an: 1)
    bytes += wireName("example.com") + u16(15) + u16(1)
    let rdata: [UInt8] = u16(10) + [4] + Array("mail".utf8) + u16(0xC00C)
    bytes += u16(0xC00C) + u16(15) + u16(1) + u32(3600) + u16(UInt16(rdata.count)) + rdata

    let message = try DNSLookupEngine.decode(Data(bytes))
    #expect(message.answers[0].type == "MX")
    #expect(message.answers[0].value == "10 mail.example.com")
}

@Test func dnsDecodeTXTConcatenatesStrings() throws {
    var bytes = dnsHeader(id: 3, flags: 0x8180, qd: 1, an: 1)
    bytes += wireName("example.com") + u16(16) + u16(1)
    let rdata: [UInt8] = [7] + Array("v=spf1 ".utf8) + [4] + Array("-all".utf8)
    bytes += u16(0xC00C) + u16(16) + u16(1) + u32(60) + u16(UInt16(rdata.count)) + rdata

    let message = try DNSLookupEngine.decode(Data(bytes))
    #expect(message.answers[0].type == "TXT")
    #expect(message.answers[0].value == "v=spf1 -all")
}

@Test func dnsDecodeSOAInAuthority() throws {
    var bytes = dnsHeader(id: 4, flags: 0x8183, qd: 1, an: 0, ns: 1)
    bytes += wireName("nope.example.com") + u16(1) + u16(1)
    let rdata: [UInt8] = wireName("ns1.example.com") + wireName("admin.example.com")
        + u32(2024061101) + u32(7200) + u32(3600) + u32(1209600) + u32(300)
    bytes += u16(0xC011) + u16(6) + u16(1) + u32(900) + u16(UInt16(rdata.count)) + rdata

    let message = try DNSLookupEngine.decode(Data(bytes))
    #expect(message.rcode == 3)
    #expect(message.rcodeName == "NXDOMAIN")
    #expect(message.answers.isEmpty)
    #expect(message.authority.count == 1)
    #expect(message.authority[0].name == "example.com")
    #expect(message.authority[0].type == "SOA")
    #expect(message.authority[0].value == "ns1.example.com admin.example.com 2024061101 7200 3600 1209600 300")
}

@Test func dnsDecodeAAAA() throws {
    var bytes = dnsHeader(id: 5, flags: 0x8180, qd: 1, an: 1)
    bytes += wireName("example.com") + u16(28) + u16(1)
    let rdata: [UInt8] = [0x20, 0x01, 0x0d, 0xb8, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1]
    bytes += u16(0xC00C) + u16(28) + u16(1) + u32(60) + u16(16) + rdata

    let message = try DNSLookupEngine.decode(Data(bytes))
    #expect(message.answers[0].type == "AAAA")
    #expect(message.answers[0].value == "2001:db8::1")
}

@Test func dnsDecodeTruncatedFlag() throws {
    let bytes = dnsHeader(id: 6, flags: 0x8380, qd: 0, an: 0)
    let message = try DNSLookupEngine.decode(Data(bytes))
    #expect(message.isTruncated)
}

@Test func dnsDecodeRejectsPointerLoop() {
    var bytes = dnsHeader(id: 7, flags: 0x8180, qd: 1, an: 0)
    bytes += u16(0xC00C) + u16(1) + u16(1)
    #expect(throws: DNSError.self) { try DNSLookupEngine.decode(Data(bytes)) }
}

@Test func dnsDecodeRejectsTruncatedRecord() {
    var bytes = dnsHeader(id: 8, flags: 0x8180, qd: 1, an: 1)
    bytes += wireName("example.com") + u16(1) + u16(1)
    bytes += u16(0xC00C) + u16(1) + u16(1) + u32(60) + u16(4) + [93, 184]
    #expect(throws: DNSError.self) { try DNSLookupEngine.decode(Data(bytes)) }
}

@Test func dnsReverseNameIPv4() {
    #expect(DNSLookupEngine.reverseName(forIP: "8.8.4.4") == "4.4.8.8.in-addr.arpa")
    #expect(DNSLookupEngine.reverseName(forIP: "192.168.1.10") == "10.1.168.192.in-addr.arpa")
    #expect(DNSLookupEngine.reverseName(forIP: "example.com") == nil)
}

@Test func dnsReverseNameIPv6() {
    let expected = "1.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.8.b.d.0.1.0.0.2.ip6.arpa"
    #expect(DNSLookupEngine.reverseName(forIP: "2001:db8::1") == expected)
}

@Test func dnsDecodeNSAndPTRNames() throws {
    var bytes = dnsHeader(id: 9, flags: 0x8180, qd: 1, an: 2)
    bytes += wireName("example.com") + u16(2) + u16(1)
    let ns1: [UInt8] = wireName("ns1.example.org")
    bytes += u16(0xC00C) + u16(2) + u16(1) + u32(60) + u16(UInt16(ns1.count)) + ns1
    let ptr: [UInt8] = wireName("host.example.net")
    bytes += u16(0xC00C) + u16(12) + u16(1) + u32(60) + u16(UInt16(ptr.count)) + ptr

    let message = try DNSLookupEngine.decode(Data(bytes))
    #expect(message.answers[0].type == "NS")
    #expect(message.answers[0].value == "ns1.example.org")
    #expect(message.answers[1].type == "PTR")
    #expect(message.answers[1].value == "host.example.net")
}

@Test func dnsDecodeCAA() throws {
    var bytes = dnsHeader(id: 10, flags: 0x8180, qd: 1, an: 1)
    bytes += wireName("example.com") + u16(257) + u16(1)
    let rdata: [UInt8] = [0, 5] + Array("issue".utf8) + Array("letsencrypt.org".utf8)
    bytes += u16(0xC00C) + u16(257) + u16(1) + u32(60) + u16(UInt16(rdata.count)) + rdata

    let message = try DNSLookupEngine.decode(Data(bytes))
    #expect(message.answers[0].type == "CAA")
    #expect(message.answers[0].value == "0 issue \"letsencrypt.org\"")
}
