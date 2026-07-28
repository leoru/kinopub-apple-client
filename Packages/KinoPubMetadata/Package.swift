// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "KinoPubMetadata",
  platforms: [.macOS(.v26), .iOS(.v26), .tvOS(.v26)],
  products: [
    .library(
      name: "KinoPubMetadata",
      targets: ["KinoPubMetadata"])
  ],
  dependencies: [
    .package(name: "KinoPubLogging", path: "../KinoPubLogging")
  ],
  targets: [
    .target(
      name: "KinoPubMetadata",
      dependencies: [
        .product(name: "KinoPubLogging", package: "KinoPubLogging")
      ]),
    .testTarget(
      name: "KinoPubMetadataTests",
      dependencies: ["KinoPubMetadata"],
      resources: [
        .copy("Fixtures")
      ])
  ],
  swiftLanguageModes: [.v5]
)
