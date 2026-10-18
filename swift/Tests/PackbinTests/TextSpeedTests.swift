import Foundation
import Packbin
import Testing

/// AC-8 (CS-11) and the long texts: the compact text codec is fast. A debug build reports its time for the
/// round trips and asserts nothing, as `SpeedTests` does; a release build asserts the bound of 1 second.
@Suite(.serialized) struct TextSpeedTests {
    @Test(.enabled(if: !threadSanitized, "the thread sanitizer runs one thread about ten times slower"))
    func roundTrips_hundredThousandTwentyCharacterUkrainianStrings_takeAtMostOneSecond() throws {
        // Arrange
        let scheme = try loneString()
        let row: [String: Any] = ["s": "Привіт, Світе! Як ти?"]
        let rounds = 100_000
        var fastest = Double.infinity

        // Act
        #if DEBUG
        let passes = 1
        #else
        let passes = 3
        #endif
        for _ in 0..<passes where fastest > 1 {
            let start = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<rounds {
                let raw = try pack(scheme, row)
                _ = try unpack(raw, scheme)
            }
            fastest = min(fastest, Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9)
        }

        // Assert
        print("AC-8: fastest pass of \(rounds) round trips of a 20-character Ukrainian string: \(fastest) s (\(buildKind))")
        #if !DEBUG
        #expect(fastest <= 1, "fastest pass \(fastest) s, above 1 s")
        #endif
    }

    @Test(arguments: ["a", "Привіт ", "Aб", "语"])
    func packAndUnpack_textOf65535Bytes_roundTripsWithinASecond(_ unit: String) throws {
        // Arrange: a text of exactly 65 535 UTF-8 bytes made of the unit (and a filler of 'a')
        let scheme = try loneString()
        var text = ""
        while text.utf8.count + unit.utf8.count <= 65_535 { text += unit }
        text += String(repeating: "a", count: 65_535 - text.utf8.count)
        #expect(text.utf8.count == 65_535)

        // Act
        let (back, seconds) = try timed { () throws -> [String: Any] in
            try unpackMap(try pack(scheme, ["s": text]), scheme)
        }

        // Assert
        print("65535 bytes of \(unit.debugDescription): pack and unpack in \(seconds) s (\(buildKind))")
        #expect(utf8Of(back["s"]) == Array(text.utf8))
        #expect(withinOneSecond(seconds), "took \(seconds) s")
    }
}

#if DEBUG
private let buildKind = "debug build: not asserted"
#else
private let buildKind = "release build"
#endif
