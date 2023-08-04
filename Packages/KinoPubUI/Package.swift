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
    .package(url: "https://github.com/CSolanaM/SkeletonUI.git", .branch("master"))
  ],
  targets: [
    .target(
      name: "KinoPubUI",
      dependencies: [
        .product(name: "KinoPubBackend", package: "KinoPubBackend"),
        .product(name: "SkeletonUI", package: "SkeletonUI"),
      ]),
    .testTarget(
      name: "KinoPubUITests",
      dependencies: ["KinoPubUI"]),
  ]
)
