// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "KinoPubBackend",
  platforms: [.macOS(.v13), .iOS(.v16)],
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
      ]),
    .testTarget(
      name: "KinoPubBackendTests",
      dependencies: ["KinoPubBackend"])
  ]
)
