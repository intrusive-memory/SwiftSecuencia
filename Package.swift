// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import Foundation
import PackageDescription

// In CI we always pin to released remotes. Locally, prefer a sibling checkout
// at ../<name> if present so in-flight changes can be exercised end-to-end
// without publishing a release. Falls back to the remote pin if the sibling
// directory is missing, so fresh clones still build.
//
// When this manifest is evaluated as a transitive dependency inside Xcode's
// `SourcePackages/checkouts/` or SwiftPM's `.build/checkouts/`, every other
// dependency lives as a sibling in the same directory. Treating those as
// in-development local paths produces conflicting package identities, so we
// must skip the sibling shortcut in that context.
let manifestDir = (#filePath as NSString).deletingLastPathComponent
let isSPMCheckout =
  manifestDir.contains("/SourcePackages/checkouts/")
  || manifestDir.contains("/.build/checkouts/")
let isCI = ProcessInfo.processInfo.environment["CI"] == "true"
let useLocalSiblings = !isCI && !isSPMCheckout

func sibling(_ name: String, remote: String, from version: Version) -> Package.Dependency {
  let localPath = "../\(name)"
  if useLocalSiblings && FileManager.default.fileExists(atPath: localPath) {
    return .package(path: localPath)
  }
  return .package(url: remote, .upToNextMajor(from: version))
}

/// Same sibling-priority pattern as ``sibling(_:remote:from:)`` but pins to a
/// remote branch when no local sibling exists. Use only when a temporary
/// pre-release dependency on a feature branch is required; switch back to the
/// version-pinned ``sibling(_:remote:from:)`` once the upstream tags a release.
func sibling(_ name: String, remote: String, branch: String) -> Package.Dependency {
  let localPath = "../\(name)"
  if useLocalSiblings && FileManager.default.fileExists(atPath: localPath) {
    return .package(path: localPath)
  }
  return .package(url: remote, branch: branch)
}

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
    sibling(
      "SwiftCompartido",
      remote: "https://github.com/intrusive-memory/SwiftCompartido.git",
      from: "7.0.2"),
    sibling(
      "SwiftFijos",
      remote: "https://github.com/intrusive-memory/SwiftFijos.git",
      from: "1.4.1"),
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
