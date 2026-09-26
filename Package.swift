// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "QdrantBar",
    platforms: [
        .macOS(.v14)
    ],
    products: [
        .executable(name: "QdrantBar", targets: ["QdrantBar"]),
        .library(name: "QdrantBarCore", targets: ["QdrantBarCore"])
    ],
    dependencies: [],
    targets: [
        .target(
            name: "QdrantBarCore",
            dependencies: []
        ),
        .executableTarget(
            name: "QdrantBar",
            dependencies: ["QdrantBarCore"]
        ),
        .testTarget(
            name: "QdrantBarCoreTests",
            dependencies: ["QdrantBarCore"],
            resources: [
                .process("Fixtures")
            ],
            swiftSettings: [
                .unsafeFlags(["-plugin-path", "/Library/Developer/CommandLineTools/usr/lib/swift/host/plugins/testing"])
            ]
        )
    ]
)
