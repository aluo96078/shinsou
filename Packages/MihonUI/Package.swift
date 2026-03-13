// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MihonUI",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "MihonUI", targets: ["MihonUI"]),
    ],
    dependencies: [
        .package(path: "../MihonDomain"),
        .package(path: "../MihonCore"),
        .package(path: "../MihonI18n"),
        .package(url: "https://github.com/kean/Nuke.git", from: "12.8.0"),
    ],
    targets: [
        .target(
            name: "MihonUI",
            dependencies: [
                "MihonDomain",
                "MihonCore",
                "MihonI18n",
                .product(name: "NukeUI", package: "Nuke"),
            ],
            path: "Sources/MihonUI"
        ),
        .testTarget(
            name: "MihonUITests",
            dependencies: ["MihonUI"],
            path: "Tests/MihonUITests"
        ),
    ]
)
