// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "KinoPubBackend",
  defaultLocalization: "en",
  platforms: [.macOS(.v26), .iOS(.v26), .tvOS(.v26)],
  products: [
    .library(
      name: "KinoPubBackend",
      targets: ["KinoPubBackend"])
  ],
  dependencies: [
    .package(name: "KinoPubLogging", path: "../KinoPubLogging")
  ],
  targets: [
    .target(
      name: "KinoPubBackend",
      dependencies: [
        .product(name: "KinoPubLogging", package: "KinoPubLogging")
      ],
      resources: [
        .process("Resources")
      ]),
    .testTarget(
      name: "KinoPubBackendTests",
      dependencies: ["KinoPubBackend"],
      resources: [
        .copy("Fixtures")
      ])
  ],
  swiftLanguageModes: [.v5]
)
