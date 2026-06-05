// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "AirPostureCore",
    platforms: [
        .iOS(.v14),
        .macOS(.v14)
    ],
    products: [
        .library(
            name: "AirPostureCore",
            targets: ["AirPostureCore"]
        )
    ],
    dependencies: [],
    targets: [
        .target(
            name: "AirPostureCore",
            dependencies: []
        ),
        .testTarget(
            name: "AirPostureCoreTests",
            dependencies: ["AirPostureCore"]
        )
    ]
)
