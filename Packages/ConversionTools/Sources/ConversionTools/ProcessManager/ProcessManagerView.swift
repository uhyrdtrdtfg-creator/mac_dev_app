import SwiftUI
import DevAppCore

public struct ProcessManagerView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case ports = "Ports"
        case processes = "Processes"
        var id: String { rawValue }
    }

    private struct KillTarget: Identifiable {
        let pid: Int32
        let name: String
        var id: Int32 { pid }
    }

    @State private var tab: Tab = .ports
    @State private var ports: [ListeningPort] = []
    @State private var processes: [RunningProcess] = []
    @State private var searchText = ""
    @State private var portSort = [KeyPathComparator(\ListeningPort.port)]
    @State private var processSort = [KeyPathComparator(\RunningProcess.cpuPercent, order: .reverse)]
    @State private var autoRefresh = false
    @State private var killTarget: KillTarget?
    @State private var showKillDialog = false
    @State private var killError: String?
    @State private var loadError: String?

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Port & Process Manager").font(.title2).fontWeight(.semibold)
                Text("Inspect listening TCP ports and running processes, and terminate them")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Picker("", selection: $tab) { ForEach(Tab.allCases) { t in Text(t.rawValue).tag(t) } }
                    .pickerStyle(.segmented).labelsHidden().frame(width: 220)

                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField(tab == .ports ? "Filter by port or process name" : "Filter by name or PID", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(6).background(.fill.tertiary).clipShape(RoundedRectangle(cornerRadius: 8))

                Button { Task { await refresh() } } label: { Image(systemName: "arrow.clockwise") }
                    .help("Refresh")

                Toggle("Auto-refresh", isOn: $autoRefresh).toggleStyle(.checkbox)
            }

            if let loadError {
                Label(loadError, systemImage: "xmark.circle").font(.caption).foregroundStyle(.red)
            }
            if let killError {
                Label(killError, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.red)
            }

            switch tab {
            case .ports: portsTable
            case .processes: processesTable
            }
        }
        .padding()
        .task(id: tab) {
            killError = nil
            await refresh()
        }
        .task(id: autoRefresh) {
            guard autoRefresh else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(3))
                guard !Task.isCancelled else { break }
                await refresh()
            }
        }
        .confirmationDialog(
            "Kill \(killTarget?.name ?? "") (PID \(killTarget.map { String($0.pid) } ?? ""))?",
            isPresented: $showKillDialog, titleVisibility: .visible, presenting: killTarget
        ) { target in
            Button("Terminate") { performKill(target, force: false) }
            Button("Force Kill", role: .destructive) { performKill(target, force: true) }
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Terminate sends SIGTERM, Force Kill sends SIGKILL.")
        }
    }

    private var filteredPorts: [ListeningPort] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let filtered = query.isEmpty ? ports : ports.filter {
            String($0.port).contains(query) || $0.processName.localizedCaseInsensitiveContains(query)
        }
        return filtered.sorted(using: portSort)
    }

    private var filteredProcesses: [RunningProcess] {
        let query = searchText.trimmingCharacters(in: .whitespaces)
        let filtered = query.isEmpty ? processes : processes.filter {
            String($0.pid).contains(query) || $0.displayName.localizedCaseInsensitiveContains(query)
        }
        return filtered.sorted(using: processSort)
    }

    private var portsTable: some View {
        Table(filteredPorts, sortOrder: $portSort) {
            TableColumn("Port", value: \.port) { Text(String($0.port)).monospacedDigit() }.width(min: 50, ideal: 60)
            TableColumn("Protocol", value: \.protocolName).width(min: 50, ideal: 70)
            TableColumn("Address", value: \.address).width(min: 90, ideal: 140)
            TableColumn("PID", value: \.pid) { Text(String($0.pid)).monospacedDigit() }.width(min: 50, ideal: 60)
            TableColumn("Process", value: \.processName)
            TableColumn("") { port in killButton(pid: port.pid, name: port.processName) }.width(50)
        }
    }

    private var processesTable: some View {
        Table(filteredProcesses, sortOrder: $processSort) {
            TableColumn("PID", value: \.pid) { Text(String($0.pid)).monospacedDigit() }.width(min: 50, ideal: 60)
            TableColumn("Name", value: \.displayName) { p in Text(p.displayName).help(p.command) }
            TableColumn("CPU %", value: \.cpuPercent) { Text(String(format: "%.1f", $0.cpuPercent)).monospacedDigit() }.width(min: 50, ideal: 60)
            TableColumn("Mem %", value: \.memPercent) { Text(String(format: "%.1f", $0.memPercent)).monospacedDigit() }.width(min: 50, ideal: 60)
            TableColumn("RSS", value: \.rssBytes) { Text($0.rssBytes.formatted(.byteCount(style: .memory))).monospacedDigit() }.width(min: 60, ideal: 80)
            TableColumn("") { p in killButton(pid: p.pid, name: p.displayName) }.width(50)
        }
    }

    private func killButton(pid: Int32, name: String) -> some View {
        Button("Kill") {
            killTarget = KillTarget(pid: pid, name: name)
            showKillDialog = true
        }
        .buttonStyle(.borderless).foregroundStyle(.red).font(.caption)
    }

    private func performKill(_ target: KillTarget, force: Bool) {
        switch ProcessManager.terminate(pid: target.pid, force: force) {
        case .success:
            killError = nil
            Task {
                try? await Task.sleep(for: .milliseconds(400))
                await refresh()
            }
        case .failure(let message):
            killError = "Failed to kill \(target.name) (PID \(target.pid)): \(message)"
        }
    }

    private func refresh() async {
        do {
            switch tab {
            case .ports: ports = try await ProcessManager.listListeningPorts()
            case .processes: processes = try await ProcessManager.listProcesses()
            }
            loadError = nil
        } catch {
            loadError = error.localizedDescription
        }
    }
}

extension ProcessManagerView {
    public static let descriptor = ToolDescriptor(id: "process-manager", name: "Port & Process Manager", icon: "cpu", category: .developer, searchKeywords: ["port", "process", "lsof", "kill", "listen", "pid", "tcp", "端口", "进程", "杀进程", "占用"])
}
