import Testing
import Foundation
@testable import ConversionTools

private let cannedLsof = """
COMMAND     PID   USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
rapportd   1633 xiaobo   13u  IPv4  0x3eae79468063332      0t0  TCP *:49152 (LISTEN)
ControlCe  1705 xiaobo   11u  IPv6 0x790b23a4e571440a      0t0  TCP [::1]:7000 (LISTEN)
node      12345 xiaobo   23u  IPv4  0x2efc2860835f2ab      0t0  TCP 127.0.0.1:3000 (LISTEN)
Google Ch   999 xiaobo   30u  IPv4  0x2efc2860835f111      0t0  TCP 127.0.0.1:9222 (LISTEN)
"""

@Test func lsofParseBasic() {
    let ports = ProcessManager.parseLsofOutput(cannedLsof)
    #expect(ports.count == 4)
    #expect(ports.map(\.port) == [3000, 7000, 9222, 49152])

    let node = ports.first { $0.port == 3000 }
    #expect(node?.pid == 12345)
    #expect(node?.processName == "node")
    #expect(node?.address == "127.0.0.1")
    #expect(node?.protocolName == "TCP")
}

@Test func lsofParseWildcardAddress() {
    let ports = ProcessManager.parseLsofOutput(cannedLsof)
    let rapportd = ports.first { $0.port == 49152 }
    #expect(rapportd?.address == "*")
    #expect(rapportd?.processName == "rapportd")
}

@Test func lsofParseIPv6Address() {
    let ports = ProcessManager.parseLsofOutput(cannedLsof)
    let control = ports.first { $0.port == 7000 }
    #expect(control?.address == "::1")
    #expect(control?.pid == 1705)
}

@Test func lsofParseNameWithSpace() {
    let ports = ProcessManager.parseLsofOutput(cannedLsof)
    let chrome = ports.first { $0.port == 9222 }
    #expect(chrome?.processName == "Google Ch")
    #expect(chrome?.pid == 999)
}

@Test func lsofParseSkipsHeader() {
    let ports = ProcessManager.parseLsofOutput("COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME\n")
    #expect(ports.isEmpty)
}

@Test func lsofParseDedupesPidPort() {
    let text = """
    COMMAND     PID   USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME
    ControlCe  1705 xiaobo   10u  IPv4 0x525735ffb7139bd9      0t0  TCP *:7000 (LISTEN)
    ControlCe  1705 xiaobo   11u  IPv6 0x790b23a4e571440a      0t0  TCP *:7000 (LISTEN)
    """
    let ports = ProcessManager.parseLsofOutput(text)
    #expect(ports.count == 1)
    #expect(ports[0].pid == 1705)
    #expect(ports[0].port == 7000)
}

@Test func lsofParseSurvivesNonUTF8Bytes() {
    // Real lsof output can contain raw non-UTF8 bytes in command names
    // (observed live: a process whose name lsof renders with raw \x91 bytes).
    // runCommand must decode lossily — strict UTF-8 decoding returns nil and
    // would silently drop every row.
    var data = Data("COMMAND     PID   USER   FD   TYPE             DEVICE SIZE/OFF NODE NAME\nweird".utf8)
    data.append(contentsOf: [0x91, 0x91])  // invalid UTF-8 continuation bytes
    data.append(Data("app  1664 xiaobo    5u  IPv4  0x2efc2860835f111      0t0  TCP 127.0.0.1:1864 (LISTEN)\nnode      12345 xiaobo   23u  IPv4  0x2efc2860835f2ab      0t0  TCP 127.0.0.1:3000 (LISTEN)\n".utf8))
    #expect(String(data: data, encoding: .utf8) == nil)  // strict decode fails on this input

    let ports = ProcessManager.parseLsofOutput(String(decoding: data, as: UTF8.self))
    #expect(ports.count == 2)
    #expect(ports.map(\.port) == [1864, 3000])
    let weird = ports.first { $0.port == 1864 }
    #expect(weird?.pid == 1664)
    #expect(weird?.address == "127.0.0.1")
    #expect(weird?.processName == "weird\u{FFFD}\u{FFFD}app")
}

@Test func psParseBasic() {
    let text = """
        1   0.0  0.1  20960 /sbin/launchd
      500 123.4  2.5 204800 /Applications/Google Chrome.app/Contents/MacOS/Google Chrome
      777   1.6  0.0   7008 fseventsd
    """
    let processes = ProcessManager.parsePsOutput(text)
    #expect(processes.count == 3)

    let launchd = processes[0]
    #expect(launchd.pid == 1)
    #expect(launchd.cpuPercent == 0.0)
    #expect(launchd.memPercent == 0.1)
    #expect(launchd.rssBytes == 20960 * 1024)
    #expect(launchd.displayName == "launchd")

    let chrome = processes[1]
    #expect(chrome.pid == 500)
    #expect(chrome.cpuPercent == 123.4)
    #expect(chrome.command == "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome")
    #expect(chrome.displayName == "Google Chrome")

    let fsevents = processes[2]
    #expect(fsevents.displayName == "fseventsd")
    #expect(fsevents.rssBytes == 7008 * 1024)
}

@Test func terminateRejectsNonPositivePid() {
    #expect(ProcessManager.terminate(pid: 0, force: false) == .failure("Invalid PID 0"))
    #expect(ProcessManager.terminate(pid: -1, force: true) == .failure("Invalid PID -1"))
}

@Test func terminateNoSuchProcess() throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/true")
    try process.run()
    process.waitUntilExit()  // child is reaped, pid no longer exists
    let outcome = ProcessManager.terminate(pid: process.processIdentifier, force: false)
    #expect(outcome == .failure("No such process"))
}

@Test func terminateRunningProcess() async throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sleep")
    process.arguments = ["100"]
    try process.run()
    let outcome = ProcessManager.terminate(pid: process.processIdentifier, force: false)
    #expect(outcome == .success)
    var exited = false
    for _ in 0..<100 {
        if !process.isRunning { exited = true; break }
        try await Task.sleep(for: .milliseconds(50))
    }
    #expect(exited)
}

@Test func listListeningPortsRuns() async throws {
    // smoke test against the live system; only asserts parse invariants
    let ports = try await ProcessManager.listListeningPorts()
    #expect(ports.allSatisfy { $0.pid > 0 && $0.port > 0 })
}

@Test func listProcessesRuns() async throws {
    let processes = try await ProcessManager.listProcesses()
    #expect(!processes.isEmpty)
    #expect(processes.contains { $0.pid == 1 })
}
