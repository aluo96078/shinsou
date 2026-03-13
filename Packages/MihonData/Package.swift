// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MihonData",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "MihonData", targets: ["MihonData"]),
    ],
    dependencies: [
        .package(path: "../MihonDomain"),
        .package(path: "../MihonSourceAPI"),
        .package(path: "../MihonCore"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.0"),
    ],
    targets: [
        .target(
            name: "MihonData",
            dependencies: [
                "MihonDomain",
                "MihonSourceAPI",
                "MihonCore",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/MihonData"
        ),
        .testTarget(
            name: "MihonDataTests",
            dependencies: ["MihonData"],
            path: "Tests/MihonDataTests"
        ),
    ]
)
