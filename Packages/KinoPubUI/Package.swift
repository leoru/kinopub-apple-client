// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "KinoPubUI",
  platforms: [.macOS(.v13), .iOS(.v16), .tvOS(.v17)],
  products: [
    .library(
      name: "KinoPubUI",
      targets: ["KinoPubUI"])
  ],
  dependencies: [
    .package(name: "KinoPubBackend", path: "../KinoPubBackend"),
    // Pinned to a release: `master` moved to a new API and silently broke this package.
    .package(url: "https://github.com/CSolanaM/SkeletonUI.git", from: "2.0.2")
  ],
  targets: [
    .target(
      name: "KinoPubUI",
      dependencies: [
        .product(name: "KinoPubBackend", package: "KinoPubBackend"),
        .product(name: "SkeletonUI", package: "SkeletonUI")
      ],
      // Declared explicitly: relying on SwiftPM to infer the asset catalogue meant
      // `Bundle.module` was not generated on every toolchain, and every
      // `Image(..., bundle: .module)` failed to compile.
      resources: [.process("Media.xcassets")]),
    .testTarget(
      name: "KinoPubUITests",
      dependencies: ["KinoPubUI"])
  ]
)
