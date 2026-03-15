// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShinsouSourceLocal",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "ShinsouSourceLocal", targets: ["ShinsouSourceLocal"]),
    ],
    dependencies: [
        .package(path: "../ShinsouSourceAPI"),
        .package(path: "../ShinsouCore"),
    ],
    targets: [
        .target(
            name: "ShinsouSourceLocal",
            dependencies: ["ShinsouSourceAPI", "ShinsouCore"],
            path: "Sources/ShinsouSourceLocal"
        ),
        .testTarget(
            name: "ShinsouSourceLocalTests",
            dependencies: ["ShinsouSourceLocal"],
            path: "Tests/ShinsouSourceLocalTests"
        ),
    ]
)
