// swift-tools-version: 6.2

import PackageDescription

let package = Package(
  name: "KinoPubLogging",
  platforms: [.macOS(.v26), .iOS(.v26), .tvOS(.v26)],
  products: [
    .library(
      name: "KinoPubLogging",
      targets: ["KinoPubLogging"])
  ],
  targets: [
    .target(
      name: "KinoPubLogging"),
    .testTarget(
      name: "KinoPubLoggingTests",
      dependencies: ["KinoPubLogging"])
  ],
  swiftLanguageModes: [.v5]
)
