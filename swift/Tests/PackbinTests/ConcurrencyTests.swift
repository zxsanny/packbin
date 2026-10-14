import Packbin
import Testing

/// The public types a caller shares between tasks; this compiles only while each is `Sendable`.
private func requireSendable<T: Sendable>(_: T.Type) {}

/// AC-6 (SW-14, S3): one built scheme, 8 tasks x 10 000 pack-then-unpack round trips. Run under
/// `swift test --sanitize=thread` for the data-race count.
@Suite struct ConcurrencyTests {
    @Test func publicTypes_areSendable() {
        // Arrange, Act
        requireSendable(Scheme.self)
        requireSendable(Field.self)
        requireSendable(FlagByte.self)
        requireSendable(Condition.self)
        requireSendable(PackbinError.self)

        // Assert
        #expect(Bool(true), "checked by the compiler")
    }

    @Test func packAndUnpack_eightTasksOnOneScheme_giveNoMismatch() async throws {
        // Arrange
        let typed = try positionTypedScheme()
        let asMap = try positionMapScheme()
        let other = try Scheme(1, .u8(0, "x"))
        let golden = bytes(try goldenHex())
        let tasks = 8
        let rounds = 10_000

        // Act
        let mismatches = await withTaskGroup(of: Int.self) { group in
            for task in 0..<tasks {
                group.addTask {
                    roundTrips(task: task, rounds: rounds, typed: typed, asMap: asMap, other: other, golden: golden)
                }
            }
            return await group.reduce(0, +)
        }

        // Assert
        #expect(mismatches == 0)
    }
}

/// The mismatches and failures of one task's round trips.
private func roundTrips(task: Int, rounds: Int, typed: Scheme, asMap: Scheme, other: Scheme,
                        golden: [UInt8]) -> Int {
    var bad = 0
    for i in 0..<rounds {
        var row = goldenRow()
        if task % 2 == 1 { row.speed = UInt8(truncatingIfNeeded: i) }
        do {
            let raw = try pack(typed, row)
            guard let back = try unpack(raw, typed, other) as? Position, back == row else {
                bad += 1
                continue
            }
            if task % 2 == 0 {
                let map = try unpackMap(raw, asMap)
                if try pack(asMap, map) != golden { bad += 1 }
            }
        } catch {
            bad += 1
        }
    }
    return bad
}
