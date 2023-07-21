// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "KinoPubKit",
    platforms: [.macOS(.v13), .iOS(.v16)],
    products: [
        .library(
            name: "KinoPubKit",
            targets: ["KinoPubKit"]),
    ],
    targets: [
        .target(
            name: "KinoPubKit"),
        .testTarget(
            name: "KinoPubKitTests",
            dependencies: ["KinoPubKit"]),
    ]
)
