// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "packbin",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "Packbin", targets: ["Packbin"]),
    ],
    targets: [
        .target(name: "Packbin", path: "swift/Sources/Packbin"),
        .testTarget(name: "PackbinTests", dependencies: ["Packbin"], path: "swift/Tests/PackbinTests"),
    ]
)
