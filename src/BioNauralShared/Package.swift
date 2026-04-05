// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "BioNauralShared",
    platforms: [
        .iOS(.v17),
        .watchOS(.v10)
    ],
    products: [
        .library(
            name: "BioNauralShared",
            targets: ["BioNauralShared"]
        )
    ],
    targets: [
        .target(
            name: "BioNauralShared",
            path: "Sources/BioNauralShared"
        ),
        .testTarget(
            name: "BioNauralSharedTests",
            dependencies: ["BioNauralShared"],
            path: "Tests/BioNauralSharedTests"
        )
    ]
)
