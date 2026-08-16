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
    .package(name: "KinoPubBackend", path: "../KinoPubBackend"),
    // Artwork pipeline. Everything Nuke-shaped stays behind `Artwork` /
    // `CachedRemoteImage` / `TVUIKitRemoteImage` — no call site imports it.
    .package(url: "https://github.com/kean/Nuke.git", from: "13.2.0")
  ],
  targets: [
    .target(
      name: "KinoPubUI",
      dependencies: [
        .product(name: "KinoPubBackend", package: "KinoPubBackend"),
        .product(name: "Nuke", package: "Nuke"),
        .product(name: "NukeUI", package: "Nuke")
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
