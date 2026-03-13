// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "MihonDomain",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "MihonDomain", targets: ["MihonDomain"]),
    ],
    dependencies: [
        .package(path: "../MihonCore"),
    ],
    targets: [
        .target(
            name: "MihonDomain",
            dependencies: ["MihonCore"],
            path: "Sources/MihonDomain"
        ),
        .testTarget(
            name: "MihonDomainTests",
            dependencies: ["MihonDomain"],
            path: "Tests/MihonDomainTests"
        ),
    ]
)
