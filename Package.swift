// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "ChibisafeUploader",
    platforms: [
        .macOS(.v10_15)
    ],
    dependencies: [
    ],
    targets: [
        .executableTarget(
            name: "ChibisafeUploader",
            dependencies: [],
            path: "Sources"
        )
    ]
)
