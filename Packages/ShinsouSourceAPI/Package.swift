// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShinsouSourceAPI",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "ShinsouSourceAPI", targets: ["ShinsouSourceAPI"]),
    ],
    dependencies: [
        .package(path: "../ShinsouCore"),
    ],
    targets: [
        .target(
            name: "ShinsouSourceAPI",
            dependencies: ["ShinsouCore"],
            path: "Sources/ShinsouSourceAPI"
        ),
        .testTarget(
            name: "ShinsouSourceAPITests",
            dependencies: ["ShinsouSourceAPI"],
            path: "Tests/ShinsouSourceAPITests"
        ),
    ]
)
