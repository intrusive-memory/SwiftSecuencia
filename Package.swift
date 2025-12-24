// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "SwiftSecuencia",
    platforms: [
        .macOS(.v26),
        .iOS(.v26)  // Audio export and Timeline/TimelineClip only; FCPXML export requires macOS
    ],
    products: [
        .library(
            name: "SwiftSecuencia",
            targets: ["SwiftSecuencia"]
        ),
        .library(
            name: "Pipeline",
            targets: ["Pipeline"]
        ),
    ],
    dependencies: [
        .package(url: "https://github.com/intrusive-memory/SwiftCompartido.git", branch: "development"),
        .package(url: "https://github.com/intrusive-memory/SwiftFijos.git", branch: "development"),
        .package(url: "https://github.com/orchetect/swift-timecode", from: "3.0.0"),
        .package(url: "https://github.com/mattt/WebVTT.git", from: "1.0.0"),
    ],
    targets: [
        .target(
            name: "Pipeline",
            dependencies: [],
            path: "Sources/Pipeline",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
        .target(
            name: "SwiftSecuencia",
            dependencies: [
                .target(name: "Pipeline", condition: .when(platforms: [.macOS])),  // FCPXML only on macOS
                .product(name: "SwiftCompartido", package: "SwiftCompartido"),
                .product(name: "SwiftFijos", package: "SwiftFijos"),  // DTD validation macOS-only
                .product(name: "SwiftTimecode", package: "swift-timecode"),
                .product(name: "WebVTT", package: "WebVTT"),
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
                .product(name: "SwiftCompartido", package: "SwiftCompartido"),
                .product(name: "SwiftFijos", package: "SwiftFijos"),
            ],
            path: "Tests/SwiftSecuenciaTests",
            swiftSettings: [
                .enableUpcomingFeature("StrictConcurrency"),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)
