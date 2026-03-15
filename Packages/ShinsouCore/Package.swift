// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShinsouCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "ShinsouCore", targets: ["ShinsouCore"]),
    ],
    targets: [
        .target(
            name: "ShinsouCore",
            path: "Sources/ShinsouCore"
        ),
        .testTarget(
            name: "ShinsouCoreTests",
            dependencies: ["ShinsouCore"],
            path: "Tests/ShinsouCoreTests"
        ),
    ]
)
