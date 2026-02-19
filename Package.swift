// swift-tools-version: 6.2

import PackageDescription

let package = Package(
    name: "VoxFormat",
    platforms: [
        .macOS(.v13),
        .iOS(.v16)
    ],
    products: [
        .library(
            name: "VoxFormat",
            targets: ["VoxFormat"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/weichsel/ZIPFoundation.git", from: "0.9.0"),
    ],
    targets: [
        .target(
            name: "VoxFormat",
            dependencies: ["ZIPFoundation"],
            path: "implementations/swift/Sources/VoxFormat"
        ),
        .testTarget(
            name: "VoxFormatTests",
            dependencies: ["VoxFormat"],
            path: "implementations/swift/Tests/VoxFormatTests"
        ),
    ]
)
