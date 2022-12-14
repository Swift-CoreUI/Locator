// swift-tools-version:5.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "Locator",
    platforms: [.iOS(.v11), .macOS(.v11)],
    products: [
        .library(name: "Locator", targets: ["Locator"]),
    ],
    dependencies: [],
    targets: [
        .target(
            name: "Locator",
            dependencies: []),
        .testTarget(
            name: "LocatorTests",
            dependencies: ["Locator"]),
    ]
)
