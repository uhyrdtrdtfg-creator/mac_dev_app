import Testing
@testable import DevAppCore

@MainActor
@Test func handoffSendAndConsume() {
    let bus = ToolHandoff()
    var selected: String?
    bus.onSelect = { selected = $0 }

    bus.send("hello", to: "json-formatter")
    #expect(selected == "json-formatter")
    #expect(bus.consume("json-formatter") == "hello")
    // Consuming again clears it.
    #expect(bus.consume("json-formatter") == nil)
}

@MainActor
@Test func handoffDestinationsExcluding() {
    let bus = ToolHandoff()
    bus.destinations = [
        .init(id: "a", name: "A", icon: "a"),
        .init(id: "b", name: "B", icon: "b"),
    ]
    #expect(bus.destinationsExcluding("a").map(\.id) == ["b"])
    #expect(bus.destinationsExcluding(nil).count == 2)
}
