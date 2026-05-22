// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Vell",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "Vell",
            path: "Sources/Vell"
        )
    ]
)
