// swift-tools-version: 5.9
import PackageDescription

// swift-crypto gives HKDF-SHA256 where CryptoKit is missing; on Apple platforms its product is not
// linked and Packbin uses CryptoKit (owner decision S-2).
let package = Package(
    name: "packbin",
    platforms: [.iOS(.v15), .macOS(.v12)],
    products: [
        .library(name: "Packbin", targets: ["Packbin"]),
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-crypto.git", exact: "3.12.5"),
    ],
    targets: [
        .target(
            name: "Packbin",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto",
                         condition: .when(platforms: [.linux, .android, .windows, .wasi])),
            ],
            path: "swift/Sources/Packbin"),
        .testTarget(name: "PackbinTests", dependencies: ["Packbin"], path: "swift/Tests/PackbinTests"),
    ]
)
