// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "ConversionTools",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "ConversionTools", targets: ["ConversionTools"])
    ],
    dependencies: [
        .package(path: "../DevAppCore")
    ],
    targets: [
        .target(name: "ConversionTools", dependencies: ["DevAppCore"]),
        .testTarget(name: "ConversionToolsTests", dependencies: ["ConversionTools"])
    ]
)
