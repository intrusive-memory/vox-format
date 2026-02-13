// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "vox-cli",
    platforms: [
        .macOS(.v13)
    ],
    dependencies: [
        // Local dependency on VoxFormat library
        .package(path: "../../implementations/swift"),
        // Swift Argument Parser for CLI
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.2.0")
    ],
    targets: [
        .executableTarget(
            name: "vox-cli",
            dependencies: [
                .product(name: "VoxFormat", package: "swift"),
                .product(name: "ArgumentParser", package: "swift-argument-parser")
            ]
        )
    ]
)
