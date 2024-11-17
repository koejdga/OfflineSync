// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "OfflineSync",
    platforms: [
        .iOS(.v13),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "OfflineSync",
            targets: ["OfflineSync"]),

    ],
    dependencies: [
        .package(url: "https://github.com/SwiftyBeaver/SwiftyBeaver.git", .upToNextMajor(from: "2.1.1")),
        .package(url: "https://github.com/realm/realm-swift.git", .upToNextMajor(from: "10.0.0")),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "OfflineSync",
            dependencies: [
                .product(name: "SwiftyBeaver", package: "SwiftyBeaver"),
                .product(name: "RealmSwift", package: "realm-swift"),
            ]),
        .testTarget(
            name: "OfflineSyncTests",
            dependencies: ["OfflineSync"]),
    ])
