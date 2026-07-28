// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "KinoPubKit",
  platforms: [.macOS(.v26), .iOS(.v26), .tvOS(.v26)],
  products: [
    .library(
      name: "KinoPubKit",
      targets: ["KinoPubKit"])
  ],
  dependencies: [
    .package(name: "KinoPubLogging", path: "../KinoPubLogging")
  ],
  targets: [
    .target(
      name: "KinoPubKit",
      dependencies: [
        .product(name: "KinoPubLogging", package: "KinoPubLogging")
      ]),
    .testTarget(
      name: "KinoPubKitTests",
      dependencies: ["KinoPubKit"])
  ],
  swiftLanguageModes: [.v5]
)
