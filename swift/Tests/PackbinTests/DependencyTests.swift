import Foundation
import Testing

/// AZ-2518 AC-5 (SW-11): one package dependency, swift-crypto at an exact version, linked by
/// `Packbin` only where CryptoKit is missing; `Package.resolved` pins it (and swift-asn1, which
/// swift-crypto requires) at versions whose manifests Swift 5.9 reads.
@Suite struct DependencyTests {
    static let cryptoVersion = "3.12.5"
    static let asn1Version = "1.3.2"

    @Test func manifest_hasExactlyOneDependency_swiftCryptoAtAnExactVersion() throws {
        // Arrange
        let manifest = try repositoryFile("Package.swift")

        // Act
        let packages = manifest.components(separatedBy: ".package(").dropFirst().map { $0.prefix { $0 != ")" } }

        // Assert
        #expect(packages.count == 1, "package dependencies \(packages.count)")
        #expect(packages.first.map(String.init) == #"url: "https://github.com/apple/swift-crypto.git", exact: "\#(Self.cryptoVersion)""#)
    }

    @Test func manifest_linksCryptoOnlyOnPlatformsWithoutCryptoKit() throws {
        // Arrange
        let manifest = try repositoryFile("Package.swift")
        let apple = [".macOS", ".macCatalyst", ".iOS", ".tvOS", ".watchOS", ".visionOS", ".driverKit"]

        // Act
        let products = Array(manifest.components(separatedBy: ".product(").dropFirst())
        let parts = (products.first ?? "").components(separatedBy: "condition: .when(platforms: [")
        let condition = parts.count == 2 ? String(parts[1].prefix { $0 != "]" }) : ""
        let platforms = condition.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }

        // Assert
        #expect(products.count == 1)
        #expect(products.first?.hasPrefix(#"name: "Crypto", package: "swift-crypto","#) == true)
        #expect(platforms == [".linux", ".android", ".windows", ".wasi"], "\(platforms)")
        #expect(!platforms.contains { apple.contains($0) }, "Apple platforms link 0 products")
    }

    @Test func resolved_pinsSwiftCryptoAndOnlyItsSwiftASN1() throws {
        // Arrange
        let data = try #require(try repositoryFile("Package.resolved").data(using: .utf8))

        // Act
        let resolved = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let pins = (resolved["pins"] as? [[String: Any]]) ?? []
        let versions = pins.reduce(into: [String: String]()) { out, pin in
            let state = pin["state"] as? [String: Any]
            out[(pin["identity"] as? String) ?? ""] = (state?["version"] as? String) ?? "no version"
        }

        // Assert
        #expect(versions == ["swift-crypto": Self.cryptoVersion, "swift-asn1": Self.asn1Version])
        #expect(pins.allSatisfy { ($0["state"] as? [String: Any])?["revision"] is String })
    }

    @Test func build_linksCryptoOnlyWhereCryptoKitIsMissing() {
        // Arrange, Act
        #if canImport(CryptoKit)
        let cryptoKit = true
        #else
        let cryptoKit = false
        #endif
        #if canImport(Crypto)
        let crypto = true
        #else
        let crypto = false
        #endif

        // Assert: swift-crypto's module is built where it is linked, and only there.
        #expect(crypto != cryptoKit, "CryptoKit \(cryptoKit), swift-crypto \(crypto)")
    }
}
