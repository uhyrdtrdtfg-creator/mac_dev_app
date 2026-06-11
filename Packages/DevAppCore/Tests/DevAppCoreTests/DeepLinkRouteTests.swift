import Foundation
import Testing
@testable import DevAppCore

@Test func deepLinkToolRouteWithInput() {
    let url = URL(string: "devtoolkit://tool/json-formatter?input=hello%20world")!
    #expect(DeepLinkRoute.parse(url) == .tool(id: "json-formatter", input: "hello world"))
}

@Test func deepLinkToolRouteWithoutInput() {
    let url = URL(string: "devtoolkit://tool/base64-codec")!
    #expect(DeepLinkRoute.parse(url) == .tool(id: "base64-codec", input: nil))
}

@Test func deepLinkToolRoutePercentDecodesInput() {
    let url = URL(string: "devtoolkit://tool/json-formatter?input=%7B%22a%22%3A%201%7D")!
    #expect(DeepLinkRoute.parse(url) == .tool(id: "json-formatter", input: "{\"a\": 1}"))
}

@Test func deepLinkPaletteRoute() {
    #expect(DeepLinkRoute.parse(URL(string: "devtoolkit://palette")!) == .palette)
    #expect(DeepLinkRoute.parse(URL(string: "DEVTOOLKIT://PALETTE")!) == .palette)
}

@Test func deepLinkRejectsUnknownHostAndMissingToolID() {
    #expect(DeepLinkRoute.parse(URL(string: "devtoolkit://nonsense")!) == nil)
    #expect(DeepLinkRoute.parse(URL(string: "devtoolkit://")!) == nil)
    #expect(DeepLinkRoute.parse(URL(string: "devtoolkit://tool")!) == nil)
    #expect(DeepLinkRoute.parse(URL(string: "devtoolkit://tool/")!) == nil)
}

@Test func deepLinkRejectsWrongScheme() {
    #expect(DeepLinkRoute.parse(URL(string: "https://tool/json-formatter")!) == nil)
    #expect(DeepLinkRoute.parse(URL(string: "file:///tmp/whatever")!) == nil)
}
