import Foundation
import Packbin
import Testing

/// AC-7 (SW-8, project AC-10): 100 000 pack-then-unpack round trips of the AC-1 row on one core take
/// at most 1 second in a release build (`swift test -c release`). The fastest of up to three passes
/// counts, as in TypeScript and Go: a shared runner can stall one pass, while a real slowdown makes
/// every pass slow. A debug build reports its time and asserts nothing.
@Suite(.serialized) struct SpeedTests {
    @Test(arguments: ["typed", "map"])
    func roundTrips_hundredThousandGoldenRows_takeAtMostOneSecond(form: String) throws {
        // Arrange
        let typed = form == "typed"
        let scheme = typed ? try positionTypedScheme() : try positionMapScheme()
        let row = goldenRow()
        let map = goldenMap()
        let rounds = 100_000
        var fastest = Double.infinity

        // Act
        for _ in 0..<3 where fastest > 1 {
            let start = DispatchTime.now().uptimeNanoseconds
            for _ in 0..<rounds {
                let raw = typed ? try pack(scheme, row) : try pack(scheme, map)
                _ = try unpack(raw, scheme)
            }
            let seconds = Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9
            fastest = min(fastest, seconds)
        }

        // Assert
        print("AC-7 \(form): fastest pass of \(rounds) round trips: \(fastest) s (\(buildKind))")
        #if !DEBUG
        #expect(fastest <= 1, "fastest pass \(fastest) s, above 1 s")
        #endif
    }
}

#if DEBUG
private let buildKind = "debug build: not asserted"
#else
private let buildKind = "release build"
#endif
