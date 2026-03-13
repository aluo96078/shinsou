// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MihonSourceAPI",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "MihonSourceAPI", targets: ["MihonSourceAPI"]),
    ],
    dependencies: [
        .package(path: "../MihonCore"),
    ],
    targets: [
        .target(
            name: "MihonSourceAPI",
            dependencies: ["MihonCore"],
            path: "Sources/MihonSourceAPI"
        ),
        .testTarget(
            name: "MihonSourceAPITests",
            dependencies: ["MihonSourceAPI"],
            path: "Tests/MihonSourceAPITests"
        ),
    ]
)
