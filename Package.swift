// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "ImeCursor",
  platforms: [.macOS(.v14)],
  targets: [
    .target(name: "ImeCursorCore"),
    .executableTarget(
      name: "ImeCursor",
      dependencies: ["ImeCursorCore"],
      linkerSettings: [.linkedFramework("Carbon")]
    ),
    .testTarget(name: "ImeCursorCoreTests", dependencies: ["ImeCursorCore"]),
  ]
)
