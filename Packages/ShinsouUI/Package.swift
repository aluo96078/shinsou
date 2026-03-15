// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShinsouUI",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "ShinsouUI", targets: ["ShinsouUI"]),
    ],
    dependencies: [
        .package(path: "../ShinsouDomain"),
        .package(path: "../ShinsouCore"),
        .package(path: "../ShinsouI18n"),
        .package(url: "https://github.com/kean/Nuke.git", from: "12.8.0"),
    ],
    targets: [
        .target(
            name: "ShinsouUI",
            dependencies: [
                "ShinsouDomain",
                "ShinsouCore",
                "ShinsouI18n",
                .product(name: "NukeUI", package: "Nuke"),
            ],
            path: "Sources/ShinsouUI"
        ),
        .testTarget(
            name: "ShinsouUITests",
            dependencies: ["ShinsouUI"],
            path: "Tests/ShinsouUITests"
        ),
    ]
)
