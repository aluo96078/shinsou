// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ShinsouDomain",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "ShinsouDomain", targets: ["ShinsouDomain"]),
    ],
    dependencies: [
        .package(path: "../ShinsouCore"),
    ],
    targets: [
        .target(
            name: "ShinsouDomain",
            dependencies: ["ShinsouCore"],
            path: "Sources/ShinsouDomain"
        ),
        .testTarget(
            name: "ShinsouDomainTests",
            dependencies: ["ShinsouDomain"],
            path: "Tests/ShinsouDomainTests"
        ),
    ]
)
