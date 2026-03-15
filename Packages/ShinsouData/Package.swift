// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShinsouData",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "ShinsouData", targets: ["ShinsouData"]),
    ],
    dependencies: [
        .package(path: "../ShinsouDomain"),
        .package(path: "../ShinsouSourceAPI"),
        .package(path: "../ShinsouCore"),
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "6.29.0"),
    ],
    targets: [
        .target(
            name: "ShinsouData",
            dependencies: [
                "ShinsouDomain",
                "ShinsouSourceAPI",
                "ShinsouCore",
                .product(name: "GRDB", package: "GRDB.swift"),
            ],
            path: "Sources/ShinsouData"
        ),
        .testTarget(
            name: "ShinsouDataTests",
            dependencies: ["ShinsouData"],
            path: "Tests/ShinsouDataTests"
        ),
    ]
)
