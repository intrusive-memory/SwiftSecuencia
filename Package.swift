// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftSecuencia",
    platforms: [
        .macOS(.v26)
    ],
    products: [
        .library(
            name: "SwiftSecuencia",
            targets: ["SwiftSecuencia"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/intrusive-memory/SwiftCompartido.git", branch: "development"),
    ],
    targets: [
        .target(
            name: "SwiftSecuencia",
            dependencies: [
                .product(name: "SwiftCompartido", package: "SwiftCompartido", condition: .when(platforms: [.macOS])),
            ],
            path: "Sources/SwiftSecuencia",
            swiftSettings: [
                // Treat availability warnings as errors
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .testTarget(
            name: "SwiftSecuenciaTests",
            dependencies: [
                "SwiftSecuencia",
                .product(name: "SwiftCompartido", package: "SwiftCompartido", condition: .when(platforms: [.macOS])),
            ],
            path: "Tests/SwiftSecuenciaTests",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
