// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KinoPubLogging",
    platforms: [.macOS(.v13), .iOS(.v16)],
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
    ]
)
