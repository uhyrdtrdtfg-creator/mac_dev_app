// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "CryptoTools",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "CryptoTools", targets: ["CryptoTools"])
    ],
    dependencies: [
        .package(path: "../DevAppCore")
    ],
    targets: [
        .target(
            name: "CCommonCrypto",
            cSettings: [.headerSearchPath("include")]
        ),
        .target(
            name: "CryptoTools",
            dependencies: ["DevAppCore", "CCommonCrypto"]
        ),
        .testTarget(name: "CryptoToolsTests", dependencies: ["CryptoTools"])
    ]
)
