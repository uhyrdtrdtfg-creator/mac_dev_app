import SwiftUI
import DevAppCore

public struct SubnetCalculatorView: View {
    @State private var input = "192.168.1.10/24"
    @State private var parsed: ParsedSubnet?
    @State private var errorMessage: String?
    @State private var splitPrefix = 25
    @State private var containerInput = "10.0.0.0/8"
    @State private var candidateInput = "10.1.2.3"

    public init() {}

    public var body: some View {
        // No ScrollView here: ContentView wraps this tool in its own ScrollView.
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("IP Subnet Calculator").font(.title2).fontWeight(.semibold)
                Text("Compute network, broadcast, host range and classification for IPv4/IPv6 CIDR blocks")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            TextField("192.168.1.10/24, 10.0.0.1 mask 255.0.0.0 or 2001:db8::1/64", text: $input)
                .font(.system(.title3, design: .monospaced)).textFieldStyle(.plain)
                .padding(10).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))

            if let errorMessage {
                Label(errorMessage, systemImage: "xmark.circle").font(.callout).foregroundStyle(.red)
            } else if let parsed {
                switch parsed {
                case .v4(let info): ipv4Results(info)
                case .v6(let info): ipv6Results(info)
                }
            }

            containmentSection
        }
        .padding()
        .onAppear { update() }
        .onChange(of: input) { _, _ in update() }
    }

    @ViewBuilder
    private func ipv4Results(_ info: IPv4Info) -> some View {
        let e = SubnetCalculatorEngine.self
        resultGroup {
            row("Network", "\(e.ipv4String(info.network))/\(info.prefix)")
            row("Netmask", e.ipv4String(info.netmask))
            row("Wildcard", e.ipv4String(info.wildcard))
            row("Broadcast", e.ipv4String(info.broadcast))
            row("First Host", e.ipv4String(info.firstUsable))
            row("Last Host", e.ipv4String(info.lastUsable))
            row("Usable Hosts", "\(info.usableHostCount)")
            row("Class", info.ipClass)
            row("Type", info.kind.rawValue)
        }

        VStack(alignment: .leading, spacing: 4) {
            Text("Binary").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
            VStack(alignment: .leading, spacing: 2) {
                binaryRow("Address", info.address, prefix: info.prefix)
                binaryRow("Netmask", info.netmask, prefix: info.prefix)
                HStack(spacing: 8) {
                    Text("").frame(width: 70, alignment: .leading)
                    Text("network bits").font(.caption2).foregroundStyle(Color.accentColor)
                    Text("host bits").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
            .background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
        }

        if info.prefix < 32 {
            splitSection(info)
        }
    }

    @ViewBuilder
    private func ipv6Results(_ info: IPv6Info) -> some View {
        let e = SubnetCalculatorEngine.self
        resultGroup {
            row("Canonical", info.canonical)
            row("Expanded", info.expanded)
            row("Network", "\(e.canonical(info.networkGroups))/\(info.prefix)")
            row("Range Start", e.canonical(info.networkGroups))
            row("Range End", e.canonical(info.lastGroups))
            row("Total Addresses", info.totalAddresses)
            row("Type", info.kind.rawValue)
        }
    }

    @ViewBuilder
    private func splitSection(_ info: IPv4Info) -> some View {
        let target = min(max(splitPrefix, info.prefix + 1), 32)
        let subnets = SubnetCalculatorEngine.split(info, to: target)
        let total = SubnetCalculatorEngine.splitCount(from: info.prefix, to: target)
        VStack(alignment: .leading, spacing: 4) {
            Text("Split Subnets").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
            Stepper(value: $splitPrefix, in: (info.prefix + 1)...32) {
                Text("Target prefix: /\(target)").font(.body)
            }
            Text(total > UInt64(subnets.count)
                 ? "\(total) subnets, showing first \(subnets.count)"
                 : "\(subnets.count) subnets")
                .font(.caption).foregroundStyle(.tertiary)
            LazyVStack(alignment: .leading, spacing: 2) {
                ForEach(subnets, id: \.address) { subnet in
                    HStack {
                        Text("\(SubnetCalculatorEngine.ipv4String(subnet.network))/\(subnet.prefix)")
                            .font(.system(.body, design: .monospaced)).textSelection(.enabled)
                        Spacer()
                        Text("\(SubnetCalculatorEngine.ipv4String(subnet.firstUsable)) – \(SubnetCalculatorEngine.ipv4String(subnet.lastUsable))")
                            .font(.system(.caption, design: .monospaced)).foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .onChange(of: input) { _, _ in
            if splitPrefix <= info.prefix { splitPrefix = info.prefix + 1 }
        }
    }

    private var containmentSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Containment Check").font(.caption).foregroundStyle(.secondary).textCase(.uppercase)
            HStack(spacing: 8) {
                TextField("CIDR, e.g. 10.0.0.0/8", text: $containerInput)
                    .font(.system(.body, design: .monospaced)).textFieldStyle(.plain)
                    .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
                Text("contains").font(.caption).foregroundStyle(.secondary).fixedSize()
                TextField("IP or CIDR", text: $candidateInput)
                    .font(.system(.body, design: .monospaced)).textFieldStyle(.plain)
                    .padding(8).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
            }
            containmentResult
        }
    }

    @ViewBuilder
    private var containmentResult: some View {
        if !containerInput.trimmingCharacters(in: .whitespaces).isEmpty,
           !candidateInput.trimmingCharacters(in: .whitespaces).isEmpty {
            switch Result(catching: { try SubnetCalculatorEngine.contains(containerInput, candidateInput) }) {
            case .success(true):
                Label("Yes — \(candidateInput.trimmingCharacters(in: .whitespaces)) is inside \(containerInput.trimmingCharacters(in: .whitespaces))", systemImage: "checkmark.circle")
                    .font(.callout).foregroundStyle(.green)
            case .success(false):
                Label("No — \(candidateInput.trimmingCharacters(in: .whitespaces)) is outside \(containerInput.trimmingCharacters(in: .whitespaces))", systemImage: "xmark.circle")
                    .font(.callout).foregroundStyle(.orange)
            case .failure(let error):
                Label(error.localizedDescription, systemImage: "xmark.circle")
                    .font(.callout).foregroundStyle(.red)
            }
        }
    }

    private func resultGroup(@ViewBuilder _ content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            content()
        }
        .padding(10).frame(maxWidth: .infinity, alignment: .leading)
        .background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func row(_ label: String, _ value: String) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 110, alignment: .leading)
            Text(value).font(.system(.body, design: .monospaced)).textSelection(.enabled)
                .lineLimit(1).truncationMode(.middle)
            Spacer()
            CopyButton(text: value)
        }
    }

    private func binaryRow(_ label: String, _ value: UInt32, prefix: Int) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.caption).foregroundStyle(.secondary).frame(width: 70, alignment: .leading)
            binaryText(value, prefix: prefix).font(.system(.body, design: .monospaced)).textSelection(.enabled)
        }
    }

    private func binaryText(_ value: UInt32, prefix: Int) -> Text {
        var result = Text(verbatim: "")
        for bit in 0..<32 {
            if bit > 0, bit % 8 == 0 {
                let dot = Text(verbatim: ".").foregroundStyle(.tertiary)
                result = Text("\(result)\(dot)")
            }
            let ch = value >> (31 - bit) & 1 == 1 ? "1" : "0"
            let piece = Text(verbatim: ch)
                .foregroundStyle(bit < prefix ? Color.accentColor : Color.secondary)
            result = Text("\(result)\(piece)")
        }
        return result
    }

    private func update() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            parsed = nil; errorMessage = nil; return
        }
        do {
            let result = try SubnetCalculatorEngine.parse(trimmed)
            parsed = result
            errorMessage = nil
            if case .v4(let info) = result, splitPrefix <= info.prefix || splitPrefix > 32 {
                splitPrefix = min(info.prefix + 1, 32)
            }
        } catch {
            parsed = nil
            errorMessage = error.localizedDescription
        }
    }
}

extension SubnetCalculatorView {
    public static let descriptor = ToolDescriptor(
        id: "subnet-calculator",
        name: "IP Subnet Calculator",
        icon: "point.3.connected.trianglepath.dotted",
        category: .developer,
        searchKeywords: ["subnet", "cidr", "netmask", "ip", "ipv4", "ipv6", "network", "broadcast", "wildcard", "子网", "掩码", "网络地址"]
    )
}
