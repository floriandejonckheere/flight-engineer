// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "FlightEngineerKit",
    platforms: [.macOS(.v14)],
    products: [
        .library(name: "FlightEngineerKit", targets: ["FlightEngineerKit"]),
    ],
    targets: [
        .target(name: "FlightEngineerKit"),
        .testTarget(
            name: "FlightEngineerKitTests",
            dependencies: ["FlightEngineerKit"],
            resources: [.copy("Fixtures")]
        ),
    ]
)
