// swift-tools-version: 6.0
import PackageDescription
let package = Package(
    name: "swiftprobe",
    platforms: [.macOS(.v15)],
    dependencies: [.package(path: "/Users/zxsanny/dev/zxsanny/packbin")],
    targets: [
        .executableTarget(name: "swiftprobe", dependencies: [.product(name: "Packbin", package: "packbin")]),
    ]
)
