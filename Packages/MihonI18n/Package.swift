// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MihonI18n",
    defaultLocalization: "en",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "MihonI18n", targets: ["MihonI18n"]),
    ],
    targets: [
        .target(
            name: "MihonI18n",
            path: "Sources/MihonI18n",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "MihonI18nTests",
            dependencies: ["MihonI18n"],
            path: "Tests/MihonI18nTests"
        ),
    ]
)
