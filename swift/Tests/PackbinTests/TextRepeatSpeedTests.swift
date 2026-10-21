import Foundation
import Packbin
import Testing

/// AZ-3134 (AC-D1, AC-D2): one text of 65 535 characters in 200 rounds of `times` packs and unpacks within the
/// bound of 1 second. An extension of `TextSpeedTests`, so the release-build speed step of `run-suite.sh`
/// (`--filter '\.TextSpeedTests/'`) runs it; a debug build prints the time and asserts nothing.
extension TextSpeedTests {
    @Test(.enabled(if: !threadSanitized, "the thread sanitizer runs one thread about ten times slower"))
    func packAndUnpack_textOf65535CharactersIn200TimesRounds_roundTripsWithinASecond() throws {
        // Arrange
        let scheme = try Scheme(1, .u8(0, "n"), .times(1, count: 0, .utf8(1, "s")))
        let rounds = 200
        let text = String(repeating: "q", count: 65_535)
        let row: [String: Any] = ["n": rounds, "s": text]
        let limit = bound(1)

        // Act
        let (packet, packSeconds) = try timed { try pack(scheme, row) }
        let (back, unpackSeconds) = try timed { try unpackMap(packet, scheme) }

        // Assert
        print("AZ-3134 pack \(packSeconds) s, unpack \(unpackSeconds) s (\(repeatBuildKind))")
        let got = try #require(back["s"] as? [Any])
        #expect(got.count == rounds)
        #expect(got.allSatisfy { utf8Of($0) == Array(text.utf8) })
        #if !DEBUG
        expectWithin(packSeconds + unpackSeconds, limit)
        #endif
    }
}

#if DEBUG
private let repeatBuildKind = "debug build: not asserted"
#else
private let repeatBuildKind = "release build"
#endif
