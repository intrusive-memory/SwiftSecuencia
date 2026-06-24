// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "SwiftSecuencia",
  platforms: [
    .macOS(.v26),
    .iOS(.v26),  // Audio export and Timeline/TimelineClip only; FCPXML export requires macOS
  ],
  products: [
    .library(
      name: "SwiftSecuencia",
      targets: ["SwiftSecuencia"]
    ),
    .library(
      name: "SecuenciaCLICore",
      targets: ["SecuenciaCLICore"]
    ),
    .executable(
      name: "secuencia",
      targets: ["SecuenciaCLI"]
    ),
  ],
  dependencies: [
    .package(url: "https://github.com/intrusive-memory/SwiftCompartido.git", .upToNextMajor(from: "7.2.1")),
    .package(url: "https://github.com/intrusive-memory/SwiftFijos.git", .upToNextMajor(from: "1.4.1")),
    .package(url: "https://github.com/orchetect/swift-timecode", from: "3.0.0"),
    .package(url: "https://github.com/mattt/WebVTT.git", from: "1.0.0"),
    .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.3.0"),
    .package(url: "https://github.com/marcprux/universal.git", from: "5.3.0"),
    .package(url: "https://github.com/TheAcharya/pipeline-neo.git", from: "2.0.0"),
  ],
  targets: [
    .target(
      name: "SwiftSecuencia",
      dependencies: [
        .product(
          name: "PipelineNeo", package: "pipeline-neo", condition: .when(platforms: [.macOS])),  // FCPXML only on macOS
        .product(name: "SwiftCompartido", package: "SwiftCompartido"),
        .product(name: "SwiftFijos", package: "SwiftFijos"),  // DTD validation macOS-only
        .product(name: "SwiftTimecode", package: "swift-timecode"),
        .product(name: "WebVTT", package: "WebVTT"),
      ],
      path: "Sources/SwiftSecuencia",
      swiftSettings: [
        // Treat availability warnings as errors
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
    .target(
      name: "SecuenciaCLICore",
      dependencies: [
        "SwiftSecuencia",
        .product(name: "SwiftFijos", package: "SwiftFijos"),
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
        .product(name: "Universal", package: "universal"),
      ],
      path: "Sources/SecuenciaCLICore",
      resources: [
        .process("Resources/")
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
    .executableTarget(
      name: "SecuenciaCLI",
      dependencies: [
        "SecuenciaCLICore",
        .product(name: "ArgumentParser", package: "swift-argument-parser"),
      ],
      path: "Sources/SecuenciaCLI",
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
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
      resources: [
        .copy("Fixtures")
      ],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
    .testTarget(
      name: "SecuenciaCLITests",
      dependencies: [
        "SecuenciaCLICore",
        "SwiftSecuencia",
        .product(name: "SwiftFijos", package: "SwiftFijos"),
      ],
      path: "Tests/SecuenciaCLITests",
      resources: [.copy("Fixtures")],
      swiftSettings: [
        .enableUpcomingFeature("StrictConcurrency")
      ]
    ),
  ],
  swiftLanguageModes: [.v6]
)
