// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "KinoPubUI",
  platforms: [.macOS(.v26), .iOS(.v26), .tvOS(.v26)],
  products: [
    .library(
      name: "KinoPubUI",
      targets: ["KinoPubUI"])
  ],
  dependencies: [
    .package(name: "KinoPubBackend", path: "../KinoPubBackend")
  ],
  targets: [
    .target(
      name: "KinoPubUI",
      dependencies: [
        .product(name: "KinoPubBackend", package: "KinoPubBackend")
      ],
      // Declared explicitly: relying on SwiftPM to infer the asset catalogue meant
      // `Bundle.module` was not generated on every toolchain, and every
      // `Image(..., bundle: .module)` failed to compile.
      resources: [.process("Media.xcassets")]),
    .testTarget(
      name: "KinoPubUITests",
      dependencies: ["KinoPubUI"])
  ],
  // Tools 6.2 is required for `.v26` platforms; stay on language mode 5 until
  // ObservableObject view models move to @Observable (see research/en/04 §4.4).
  swiftLanguageModes: [.v5]
)
