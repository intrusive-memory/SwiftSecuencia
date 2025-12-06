// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftSecuencia",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1)
    ],
    products: [
        .library(
            name: "SwiftSecuencia",
            targets: ["SwiftSecuencia"]
        ),
    ],
    dependencies: [
        // No external dependencies - uses Foundation XML
    ],
    targets: [
        .target(
            name: "SwiftSecuencia",
            dependencies: [],
            path: "Sources/SwiftSecuencia"
        ),
        .testTarget(
            name: "SwiftSecuenciaTests",
            dependencies: ["SwiftSecuencia"],
            path: "Tests/SwiftSecuenciaTests"
        ),
    ],
    swiftLanguageModes: [.v6]
)
