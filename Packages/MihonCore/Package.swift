// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MihonCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "MihonCore", targets: ["MihonCore"]),
    ],
    targets: [
        .target(
            name: "MihonCore",
            path: "Sources/MihonCore"
        ),
        .testTarget(
            name: "MihonCoreTests",
            dependencies: ["MihonCore"],
            path: "Tests/MihonCoreTests"
        ),
    ]
)
