import Foundation
import Packbin
import Testing

/// AZ-2686 AC-7 (EC-13): the repair of a 254-byte message with 16 parity bytes and 8 wrong bytes, 1 000 times, and
/// the packing of it 1 000 times, each take at most 1 second in a release build. In `SpeedTests` so the release speed
/// step of `run-suite.sh` runs it; a debug build reports the times and asserts nothing, as the other speed tests do.
extension SpeedTests {
    @Test(.enabled(if: !threadSanitized, "one thread, no shared state: the thread sanitizer adds nothing and runs it about ten times slower"))
    func eccRepairAndPack_thousandTimesOfA254ByteMessage_takeAtMostOneSecondEach() throws {
        // Arrange: 238 clear bytes (the type byte and a run) and 16 parity bytes make 254
        let clear = (0..<238).map { UInt8(truncatingIfNeeded: $0 &* 37 &+ 11) }
        let scheme = try rawScheme(for: clear, parity: 16)
        let row = rawRow(clear)
        let message = try pack(scheme, row)
        let wrong = corrupt(message, [0, 30, 60, 90, 120, 180, 220, 253], [1, 2, 3, 4, 5, 6, 7, 8])
        var repaired = 0
        var last: [UInt8] = []

        // Act
        let (_, repairSeconds) = timed { () -> Void in
            for _ in 0..<1_000 {
                if let got = try? unpackMapRepair(wrong, limit: 8, scheme), got.repaired == 8 { repaired += 1 }
            }
        }
        let (_, packSeconds) = try timed { () throws -> Void in
            for _ in 0..<1_000 {
                last = try pack(scheme, row)
            }
        }

        // Assert
        print("EC-13: 1000 repairs of 8 wrong bytes in \(repairSeconds) s, 1000 packs in \(packSeconds) s (\(eccBuildKind))")
        #expect(message.count == 254 && repaired == 1_000 && last == message)
        #if !DEBUG
        #expect(repairSeconds <= 1 && packSeconds <= 1, "repair \(repairSeconds) s, pack \(packSeconds) s")
        #endif
    }
}

#if DEBUG
private let eccBuildKind = "debug build: not asserted"
#else
private let eccBuildKind = "release build"
#endif
