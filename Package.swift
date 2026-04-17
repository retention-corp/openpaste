// swift-tools-version: 6.0
import PackageDescription

let package = Package(
  name: "OpenPaste",
  platforms: [
    .macOS(.v14),
  ],
  products: [
    .executable(
      name: "OpenPaste",
      targets: ["OpenPaste"]
    ),
  ],
  targets: [
    .executableTarget(
      name: "OpenPaste",
      path: "Sources/OpenPaste"
    ),
    .testTarget(
      name: "OpenPasteTests",
      dependencies: ["OpenPaste"],
      path: "Tests/OpenPasteTests"
    ),
  ]
)
