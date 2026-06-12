import Testing
@testable import ConversionTools

private func ip(_ s: String) -> UInt32 { SubnetCalculatorEngine.ipv4Value(s)! }

@Test func subnetSlash24() throws {
    let info = try SubnetCalculatorEngine.parseIPv4("192.168.1.10/24")
    #expect(info.network == ip("192.168.1.0"))
    #expect(info.broadcast == ip("192.168.1.255"))
    #expect(info.firstUsable == ip("192.168.1.1"))
    #expect(info.lastUsable == ip("192.168.1.254"))
    #expect(info.usableHostCount == 254)
    #expect(info.netmask == ip("255.255.255.0"))
    #expect(info.wildcard == ip("0.0.0.255"))
}

@Test func subnetSlash31RFC3021() throws {
    let info = try SubnetCalculatorEngine.parseIPv4("10.0.0.1/31")
    #expect(info.usableHostCount == 2)
    #expect(info.network == ip("10.0.0.0"))
    #expect(info.broadcast == ip("10.0.0.1"))
    #expect(info.firstUsable == ip("10.0.0.0"))
    #expect(info.lastUsable == ip("10.0.0.1"))
}

@Test func subnetSlash32() throws {
    let info = try SubnetCalculatorEngine.parseIPv4("10.0.0.5/32")
    #expect(info.usableHostCount == 1)
    #expect(info.network == ip("10.0.0.5"))
    #expect(info.broadcast == ip("10.0.0.5"))
    #expect(info.firstUsable == ip("10.0.0.5"))
    #expect(info.lastUsable == ip("10.0.0.5"))
}

@Test func subnetSlash0() throws {
    let info = try SubnetCalculatorEngine.parseIPv4("1.2.3.4/0")
    #expect(info.network == 0)
    #expect(info.broadcast == ip("255.255.255.255"))
    #expect(info.usableHostCount == 4_294_967_294)
}

@Test func subnetMaskPrefixRoundTrip() {
    for n in 0...32 {
        let mask = SubnetCalculatorEngine.mask(fromPrefix: n)
        #expect(SubnetCalculatorEngine.prefix(fromMask: mask) == n)
    }
}

@Test func subnetNonContiguousMaskRejected() {
    #expect(SubnetCalculatorEngine.prefix(fromMask: ip("255.0.255.0")) == nil)
    #expect(throws: SubnetError.self) { try SubnetCalculatorEngine.parseIPv4("10.0.0.1 mask 255.0.255.0") }
}

@Test func subnetMaskNotation() throws {
    let info = try SubnetCalculatorEngine.parseIPv4("192.168.1.10 mask 255.255.255.0")
    #expect(info.prefix == 24)
    #expect(info.network == ip("192.168.1.0"))
    let spaced = try SubnetCalculatorEngine.parseIPv4("172.16.5.1 255.240.0.0")
    #expect(spaced.prefix == 12)
}

@Test func subnetSeparateAddressPrefix() throws {
    let info = try SubnetCalculatorEngine.ipv4(address: "10.1.2.3", prefix: 16)
    #expect(info.network == ip("10.1.0.0"))
    #expect(throws: SubnetError.self) { try SubnetCalculatorEngine.ipv4(address: "10.1.2.3", prefix: 33) }
    #expect(throws: SubnetError.self) { try SubnetCalculatorEngine.ipv4(address: "10.1.2.256", prefix: 8) }
}

@Test func subnetBinary() {
    #expect(SubnetCalculatorEngine.binary(ip("192.168.1.1")) == "11000000.10101000.00000001.00000001")
    #expect(SubnetCalculatorEngine.binary(ip("255.255.255.0")) == "11111111.11111111.11111111.00000000")
}

@Test func subnetClassAndKind() throws {
    #expect(try SubnetCalculatorEngine.parseIPv4("10.0.0.1").ipClass == "A")
    #expect(try SubnetCalculatorEngine.parseIPv4("10.0.0.1").kind == .privateUse)
    #expect(try SubnetCalculatorEngine.parseIPv4("172.16.0.1").ipClass == "B")
    #expect(try SubnetCalculatorEngine.parseIPv4("172.16.0.1").kind == .privateUse)
    #expect(try SubnetCalculatorEngine.parseIPv4("172.32.0.1").kind == .publicUse)
    #expect(try SubnetCalculatorEngine.parseIPv4("192.168.1.1").ipClass == "C")
    #expect(try SubnetCalculatorEngine.parseIPv4("192.168.1.1").kind == .privateUse)
    #expect(try SubnetCalculatorEngine.parseIPv4("127.0.0.1").kind == .loopback)
    #expect(try SubnetCalculatorEngine.parseIPv4("169.254.1.1").kind == .linkLocal)
    #expect(try SubnetCalculatorEngine.parseIPv4("100.64.0.1").kind == .cgn)
    #expect(try SubnetCalculatorEngine.parseIPv4("100.128.0.1").kind == .publicUse)
    #expect(try SubnetCalculatorEngine.parseIPv4("224.0.0.1").ipClass == "D")
    #expect(try SubnetCalculatorEngine.parseIPv4("224.0.0.1").kind == .multicast)
    #expect(try SubnetCalculatorEngine.parseIPv4("240.0.0.1").ipClass == "E")
    #expect(try SubnetCalculatorEngine.parseIPv4("240.0.0.1").kind == .reserved)
    #expect(try SubnetCalculatorEngine.parseIPv4("8.8.8.8").kind == .publicUse)
}

@Test func subnetSplitNextPrefix() throws {
    let info = try SubnetCalculatorEngine.parseIPv4("192.168.1.0/24")
    let halves = SubnetCalculatorEngine.split(info, to: 25)
    #expect(halves.count == 2)
    #expect(halves[0].network == ip("192.168.1.0"))
    #expect(halves[1].network == ip("192.168.1.128"))
    #expect(halves.allSatisfy { $0.prefix == 25 })
}

@Test func subnetSplitCapped() throws {
    let info = try SubnetCalculatorEngine.parseIPv4("10.0.0.0/8")
    let subnets = SubnetCalculatorEngine.split(info, to: 24)
    #expect(SubnetCalculatorEngine.splitCount(from: 8, to: 24) == 65536)
    #expect(subnets.count == 256)
    #expect(subnets[255].network == ip("10.0.255.0"))
}

@Test func subnetSplitInvalidTarget() throws {
    let info = try SubnetCalculatorEngine.parseIPv4("10.0.0.0/24")
    #expect(SubnetCalculatorEngine.split(info, to: 24).isEmpty)
    #expect(SubnetCalculatorEngine.split(info, to: 16).isEmpty)
    #expect(SubnetCalculatorEngine.split(info, to: 33).isEmpty)
}

@Test func subnetContainmentV4() throws {
    #expect(try SubnetCalculatorEngine.contains("10.0.0.0/8", "10.1.2.3"))
    #expect(try SubnetCalculatorEngine.contains("10.0.0.0/8", "10.2.0.0/16"))
    #expect(try !SubnetCalculatorEngine.contains("10.0.0.0/8", "11.0.0.0/8"))
    #expect(try !SubnetCalculatorEngine.contains("10.1.0.0/16", "10.0.0.0/8"))
    #expect(try SubnetCalculatorEngine.contains("0.0.0.0/0", "203.0.113.7"))
    #expect(throws: SubnetError.self) { try SubnetCalculatorEngine.contains("10.0.0.0/8", "2001:db8::1") }
}

@Test func subnetContainmentV6() throws {
    #expect(try SubnetCalculatorEngine.contains("2001:db8::/32", "2001:db8:1::/48"))
    #expect(try SubnetCalculatorEngine.contains("2001:db8::/32", "2001:db8::1"))
    #expect(try !SubnetCalculatorEngine.contains("2001:db8::/32", "2001:db9::1"))
    #expect(try !SubnetCalculatorEngine.contains("2001:db8::/48", "2001:db8::/32"))
}

@Test func ipv6CanonicalAllZeros() {
    #expect(SubnetCalculatorEngine.canonical(SubnetCalculatorEngine.ipv6Groups("0:0:0:0:0:0:0:0")!) == "::")
}

@Test func ipv6CanonicalLoopback() {
    #expect(SubnetCalculatorEngine.canonical(SubnetCalculatorEngine.ipv6Groups("0000:0000:0000:0000:0000:0000:0000:0001")!) == "::1")
}

@Test func ipv6CanonicalLeadingZeros() {
    #expect(SubnetCalculatorEngine.canonical(SubnetCalculatorEngine.ipv6Groups("2001:0db8::0001")!) == "2001:db8::1")
}

@Test func ipv6CanonicalLongestRunLeftmostTie() {
    #expect(SubnetCalculatorEngine.canonical(SubnetCalculatorEngine.ipv6Groups("2001:db8:0:0:1:0:0:1")!) == "2001:db8::1:0:0:1")
}

@Test func ipv6CanonicalLongestRunWins() {
    #expect(SubnetCalculatorEngine.canonical(SubnetCalculatorEngine.ipv6Groups("2001:0:0:1:0:0:0:1")!) == "2001:0:0:1::1")
}

@Test func ipv6CanonicalSingleZeroNotCompressed() {
    #expect(SubnetCalculatorEngine.canonical(SubnetCalculatorEngine.ipv6Groups("2001:db8:0:1:1:1:1:1")!) == "2001:db8:0:1:1:1:1:1")
}

@Test func ipv6CanonicalLowercase() {
    #expect(SubnetCalculatorEngine.canonical(SubnetCalculatorEngine.ipv6Groups("2001:DB8::ABCD")!) == "2001:db8::abcd")
}

@Test func ipv6Expanded() throws {
    let info = try SubnetCalculatorEngine.parseIPv6("::1")
    #expect(info.expanded == "0000:0000:0000:0000:0000:0000:0000:0001")
    #expect(try SubnetCalculatorEngine.parseIPv6("2001:db8::1").expanded == "2001:0db8:0000:0000:0000:0000:0000:0001")
}

@Test func ipv6Network() throws {
    let info = try SubnetCalculatorEngine.parseIPv6("2001:db8:abcd:12::1/64")
    #expect(SubnetCalculatorEngine.canonical(info.networkGroups) == "2001:db8:abcd:12::")
    #expect(SubnetCalculatorEngine.canonical(info.lastGroups) == "2001:db8:abcd:12:ffff:ffff:ffff:ffff")
}

@Test func ipv6IPv4Mapped() throws {
    let info = try SubnetCalculatorEngine.parseIPv6("::ffff:192.168.1.1")
    #expect(info.kind == .ipv4Mapped)
    #expect(info.canonical == "::ffff:192.168.1.1")
    #expect(info.expanded == "0000:0000:0000:0000:0000:ffff:c0a8:0101")
}

@Test func ipv6TotalAddresses() throws {
    #expect(try SubnetCalculatorEngine.parseIPv6("2001:db8::/64").totalAddresses == "18446744073709551616")
    #expect(try SubnetCalculatorEngine.parseIPv6("::/0").totalAddresses == "340282366920938463463374607431768211456")
    #expect(try SubnetCalculatorEngine.parseIPv6("::1/128").totalAddresses == "1")
}

@Test func ipv6Kinds() throws {
    #expect(try SubnetCalculatorEngine.parseIPv6("::").kind == .unspecified)
    #expect(try SubnetCalculatorEngine.parseIPv6("::1").kind == .loopback)
    #expect(try SubnetCalculatorEngine.parseIPv6("fe80::1").kind == .linkLocal)
    #expect(try SubnetCalculatorEngine.parseIPv6("fd00::1").kind == .uniqueLocal)
    #expect(try SubnetCalculatorEngine.parseIPv6("ff02::1").kind == .multicast)
    #expect(try SubnetCalculatorEngine.parseIPv6("2001:db8::1").kind == .globalUnicast)
}

@Test func ipv6InvalidInputs() {
    #expect(SubnetCalculatorEngine.ipv6Groups("1::2::3") == nil)
    #expect(SubnetCalculatorEngine.ipv6Groups("1:2:3:4:5:6:7") == nil)
    #expect(SubnetCalculatorEngine.ipv6Groups("1:2:3:4:5:6:7:8:9") == nil)
    #expect(SubnetCalculatorEngine.ipv6Groups("12345::") == nil)
    #expect(SubnetCalculatorEngine.ipv6Groups("g::1") == nil)
    #expect(throws: SubnetError.self) { try SubnetCalculatorEngine.parseIPv6("2001:db8::1/129") }
}

@Test func subnetAutoFamilyDetection() throws {
    if case .v4(let info) = try SubnetCalculatorEngine.parse("192.168.0.1/16") {
        #expect(info.prefix == 16)
    } else {
        Issue.record("expected IPv4")
    }
    if case .v6(let info) = try SubnetCalculatorEngine.parse("fe80::1") {
        #expect(info.prefix == 128)
    } else {
        Issue.record("expected IPv6")
    }
}

@Test func ipv6EmbeddedIPv4MustBeFinalTokenOfAddress() {
    // inet_pton(AF_INET6) rejects these: dotted-quad before "::"
    #expect(SubnetCalculatorEngine.ipv6Groups("1.2.3.4::") == nil)
    #expect(SubnetCalculatorEngine.ipv6Groups("1.2.3.4::5") == nil)
    // Valid placements still parse
    #expect(SubnetCalculatorEngine.ipv6Groups("::ffff:1.2.3.4") == [0, 0, 0, 0, 0, 0xFFFF, 0x0102, 0x0304])
    #expect(SubnetCalculatorEngine.ipv6Groups("64:ff9b::192.0.2.1") != nil)
}

@Test func ipv6RejectsSignedHexGroups() {
    // UInt16(_, radix:) accepts a leading '+'; inet_pton does not.
    #expect(SubnetCalculatorEngine.ipv6Groups("::+1") == nil)
    #expect(SubnetCalculatorEngine.ipv6Groups("+1::") == nil)
    #expect(SubnetCalculatorEngine.ipv6Groups("::1") == [0, 0, 0, 0, 0, 0, 0, 1])
}
