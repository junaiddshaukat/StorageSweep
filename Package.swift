// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "StorageSweep",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "StorageSweep", targets: ["StorageSweep"])
    ],
    targets: [
        .executableTarget(
            name: "StorageSweep",
            swiftSettings: [
                .unsafeFlags(["-Xfrontend", "-warn-long-function-bodies=300"])
            ]
        )
    ]
)
