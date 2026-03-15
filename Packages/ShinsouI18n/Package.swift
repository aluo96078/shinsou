// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShinsouI18n",
    defaultLocalization: "en",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "ShinsouI18n", targets: ["ShinsouI18n"]),
    ],
    targets: [
        .target(
            name: "ShinsouI18n",
            path: "Sources/ShinsouI18n",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "ShinsouI18nTests",
            dependencies: ["ShinsouI18n"],
            path: "Tests/ShinsouI18nTests"
        ),
    ]
)
