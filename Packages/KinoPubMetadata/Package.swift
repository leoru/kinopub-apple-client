// swift-tools-version: 5.9

import PackageDescription

let package = Package(
  name: "KinoPubMetadata",
  platforms: [.macOS(.v13), .iOS(.v16), .tvOS(.v17)],
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
  ]
)
