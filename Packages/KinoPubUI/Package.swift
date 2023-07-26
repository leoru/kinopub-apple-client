// swift-tools-version: 5.8
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
  name: "KinoPubUI",
  platforms: [.macOS(.v13), .iOS(.v16)],
  products: [
    .library(
      name: "KinoPubUI",
      targets: ["KinoPubUI"]),
  ],
  dependencies: [
    .package(name: "KinoPubBackend", path: "../KinoPubBackend"),
  ],
  targets: [
    .target(
      name: "KinoPubUI",
      dependencies: [
        .product(name: "KinoPubBackend", package: "KinoPubBackend"),
      ]),
    .testTarget(
      name: "KinoPubUITests",
      dependencies: ["KinoPubUI"]),
  ]
)
