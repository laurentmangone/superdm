// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "superdm",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "superdm-cli", targets: ["CLI"]),
        .executable(name: "superdm-gui", targets: ["GUI"]),
        .library(name: "App", targets: ["App"])
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.2.0"),
        .package(url: "https://github.com/stephencelis/SQLite.swift.git", from: "0.14.1")
    ],
    targets: [
        .target(name: "App", dependencies: [
            .product(name: "SQLite", package: "SQLite.swift")
        ]),
        .executableTarget(name: "CLI", dependencies: [
            .product(name: "ArgumentParser", package: "swift-argument-parser"),
            "App"
        ]),
        .executableTarget(name: "GUI", dependencies: ["App"])
    ]
)
