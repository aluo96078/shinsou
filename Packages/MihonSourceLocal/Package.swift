// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MihonSourceLocal",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "MihonSourceLocal", targets: ["MihonSourceLocal"]),
    ],
    dependencies: [
        .package(path: "../MihonSourceAPI"),
        .package(path: "../MihonCore"),
    ],
    targets: [
        .target(
            name: "MihonSourceLocal",
            dependencies: ["MihonSourceAPI", "MihonCore"],
            path: "Sources/MihonSourceLocal"
        ),
        .testTarget(
            name: "MihonSourceLocalTests",
            dependencies: ["MihonSourceLocal"],
            path: "Tests/MihonSourceLocalTests"
        ),
    ]
)
