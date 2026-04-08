// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "DevAppCore",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "DevAppCore", targets: ["DevAppCore"])
    ],
    targets: [
        .target(name: "DevAppCore"),
        .testTarget(name: "DevAppCoreTests", dependencies: ["DevAppCore"])
    ]
)
