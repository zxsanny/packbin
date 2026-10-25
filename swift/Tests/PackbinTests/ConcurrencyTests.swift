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
        requireSendable(FrameSession.self)
        requireSendable(MacKey.self)
        requireSendable(ReplayWindow.self)
        requireSendable(MessageContext.self)
        requireSendable(FrameConfig.self)
        requireSendable(FrameOpened.self)

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

    /// AZ-3234 AC-11 (S9): one frame session, 8 tasks x 1,000 distinct message ids; each body opens and equals the
    /// single-thread seal of the same inputs.
    @Test func seal_eightTasksOnOneFrameSession_giveTheSingleThreadBodies() async throws {
        // Arrange
        let session = try FrameSession.load(key: repeatedKey(0x42), epoch: 3, config: FrameConfig(tagLength: 8))
        let tasks = 8
        let rounds = 1_000
        let reference = try (0..<(tasks * rounds)).map { try frameSeal(session, $0) }

        // Act
        let mismatches = await withTaskGroup(of: Int.self) { group in
            for task in 0..<tasks {
                group.addTask {
                    var bad = 0
                    for i in 0..<rounds {
                        let n = task * rounds + i
                        guard let body = try? frameSeal(session, n), body == reference[n] else {
                            bad += 1
                            continue
                        }
                        var out = [UInt8](repeating: 0, count: 255)
                        let opened = try? session.open(direction: .down, context: frameContext(n), ad: [UInt8(truncatingIfNeeded: n)],
                                                       body: body, clearLength: 2, into: &out)
                        if opened?.plainLength != n % 40 || Array(out[0..<(n % 40)]) != framePlain(n) { bad += 1 }
                    }
                    return bad
                }
            }
            return await group.reduce(0, +)
        }

        // Assert
        #expect(mismatches == 0)
        #expect(Set(reference).count == tasks * rounds, "8,000 distinct message ids give 8,000 distinct bodies")
    }
}

private func frameContext(_ n: Int) -> MessageContext {
    MessageContext(msgID: messageID(UInt64(n)), kind: UInt8(n % 16))
}

private func framePlain(_ n: Int) -> [UInt8] {
    (0..<(n % 40)).map { UInt8(truncatingIfNeeded: n &* 31 &+ $0) }
}

/// The body of message `n`: a 2-byte clear part, `n % 40` plaintext bytes and 1 byte of associated data.
private func frameSeal(_ session: FrameSession, _ n: Int) throws -> [UInt8] {
    try sealBody(session, .down, frameContext(n), ad: [UInt8(truncatingIfNeeded: n)], clear: [1, UInt8(truncatingIfNeeded: n)],
                 plain: framePlain(n))
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
