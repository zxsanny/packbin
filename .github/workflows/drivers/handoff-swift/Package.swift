// swift-tools-version: 5.9
import PackageDescription

// The Swift member of the cross-language ring (.github/workflows/language-pair.sh): the handoff driver
// and the position program, on the repository's root package by path (ADR-001: Packbin only).
// ring-swift.sh builds both, release, into a scratch path outside the repository.
let package = Package(
    name: "handoff-swift",
    platforms: [.macOS(.v12)],
    dependencies: [
        .package(path: "../../../.."),
    ],
    targets: [
        .executableTarget(
            name: "handoff-swift",
            dependencies: [.product(name: "Packbin", package: "packbin")],
            path: "Sources/handoff-swift"),
        .executableTarget(
            name: "position",
            dependencies: [.product(name: "Packbin", package: "packbin")],
            path: "Sources/position"),
    ]
)
