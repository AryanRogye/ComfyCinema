// swift-tools-version: 6.4
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MoviesAPIData",
    platforms: [
        .iOS("26.1"),
        .macOS(.v26),
    ],
    products: [
        .library(
            name: "MoviesAPIData",
            targets: ["MoviesAPIData"]
        ),
    ],
    targets: [
        .target(
            name: "MoviesAPIData",
            swiftSettings: [
                .enableUpcomingFeature("ApproachableConcurrency"),
            ],
        ),

    ]
)
