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
    ],
    targets: [
        .target(
            name: "KinoPubUI",
            dependencies: []),
        .testTarget(
            name: "KinoPubUITests",
            dependencies: ["KinoPubUI"]),
    ]
)
