// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "KeyboardClean",
    platforms: [
        .macOS(.v13)
    ],
    targets: [
        .executableTarget(
            name: "KeyboardClean",
            path: "Sources/KeyboardClean"
        )
    ]
)
