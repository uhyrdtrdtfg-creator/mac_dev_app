// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "APIClient",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "APIClient", targets: ["APIClient"])
    ],
    dependencies: [
        .package(path: "../DevAppCore")
    ],
    targets: [
        .target(
            name: "CCommonCrypto",
            cSettings: [.headerSearchPath("include")]
        ),
        .target(name: "APIClient", dependencies: ["DevAppCore", "CCommonCrypto"]),
        .testTarget(name: "APIClientTests", dependencies: ["APIClient"])
    ]
)
