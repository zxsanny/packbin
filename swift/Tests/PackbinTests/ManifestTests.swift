import Foundation
import Testing

/// AC-8 (SW-10 part, SW-11 part): the root manifest, the license and the target layout. Warnings 0
/// is the release build with warnings as errors (`swift build -c release -Xswiftc -warnings-as-errors`).
@Suite struct ManifestTests {
    @Test func manifest_declaresToolsPlatformsAndOneLibrary() throws {
        // Arrange
        let manifest = try repositoryFile("Package.swift")

        // Act
        let firstLine = manifest.split(separator: "\n").first.map(String.init)

        // Assert
        #expect(firstLine == "// swift-tools-version: 6.0")
        #expect(!manifest.contains("swiftLanguage"), "Swift 6 language mode, the default of tools 6.0")
        #expect(manifest.contains(".iOS(.v15)") && manifest.contains(".macOS(.v12)"))
        #expect(manifest.components(separatedBy: ".library(").count - 1 == 1)
        #expect(manifest.contains(#".library(name: "Packbin", targets: ["Packbin"])"#))
        #expect(manifest.contains(".target(\n            name: \"Packbin\","))
        #expect(manifest.contains(#"path: "swift/Sources/Packbin")"#))
    }

    @Test func manifest_hasNoUnsafeFlagOrCTarget() throws {
        // Arrange
        let manifest = try repositoryFile("Package.swift")
        let sources = repositoryRoot.appendingPathComponent("swift/Sources")

        // Act
        let files = FileManager.default.enumerator(atPath: sources.path)?.compactMap { $0 as? String } ?? []
        let cFiles = files.filter { file in [".c", ".h", ".m", ".cpp", ".cc", ".mm"].contains { file.hasSuffix($0) } }

        // Assert
        #expect(!manifest.contains("unsafeFlags"))
        #expect(!manifest.contains("cSettings") && !manifest.contains("cxxSettings") && !manifest.contains("systemLibrary"))
        #expect(!files.isEmpty && cFiles.isEmpty, "C targets 0")
    }

    @Test func license_atTheRepositoryRootIsMIT() throws {
        // Arrange
        let license = try repositoryFile("LICENSE")

        // Act
        let firstLine = license.split(separator: "\n").first.map(String.init)

        // Assert
        #expect(firstLine == "MIT License")
        #expect(!FileManager.default.fileExists(atPath: repositoryRoot.appendingPathComponent("swift/LICENSE").path))
    }
}
