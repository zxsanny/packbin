import Packbin
import Testing

/// AZ-3234 AC-4 (S4; AC-G2.1): a changed byte never yields plaintext. Every single bit of the associated data, the
/// clear part, the ciphertext and the tag of E1, E2 and E3 is flipped in turn, and the message id, the kind, the
/// direction, the epoch and the key are each changed; every open is `TagMismatch`, writes nothing and leaves the
/// window as it was.
@Suite struct FrameTamperTests {
    @Test func open_theUntouchedWorkedExamples_giveThePlaintext() throws {
        for example in try workedExamples() {
            // Arrange
            let session = try example.session()
            var window = ReplayWindow()

            // Act
            let outcome = attemptOpen(session, example.direction, example.context, ad: example.ad, body: example.body,
                                      clearLength: example.clear.count, window: &window)

            // Assert
            #expect(outcome.kind == nil, "\(example.name)")
            #expect(outcome.plain == example.plain, "\(example.name)")
            #expect(outcome.opened == FrameOpened(slot: .current, clearLength: example.clear.count, plainLength: example.plain.count))
        }
    }

    @Test func open_everyFlippedBitOfAdClearCiphertextAndTag_isTagMismatchWithNothingWritten() throws {
        var flips = 0
        for example in try workedExamples() {
            // Arrange
            let session = try example.session()
            let before = ReplayWindow(top: 100, bits: 0b1011)
            var window = before
            var failures: [String] = []

            // Act
            for bit in 0..<(example.ad.count * 8) {
                let outcome = attemptOpen(session, example.direction, example.context, ad: flipped(example.ad, bit: bit),
                                          body: example.body, clearLength: example.clear.count, window: &window,
                                          counter: 200)
                if outcome.kind != .tagMismatch || !outcome.untouched || !outcome.windowKept { failures.append("ad bit \(bit)") }
                flips += 1
            }
            for bit in 0..<(example.body.count * 8) {
                let outcome = attemptOpen(session, example.direction, example.context, ad: example.ad,
                                          body: flipped(example.body, bit: bit), clearLength: example.clear.count,
                                          window: &window, counter: 200)
                if outcome.kind != .tagMismatch || !outcome.untouched || !outcome.windowKept { failures.append("body bit \(bit)") }
                flips += 1
            }

            // Assert
            #expect(failures.isEmpty, "\(example.name): \(failures.prefix(5))")
            #expect(window == before, "\(example.name)")
        }
        #expect(flips > 600, "\(flips) flips ran")
    }

    @Test func open_aChangedMessageIdKindDirectionEpochOrKey_isTagMismatchWithNothingWritten() throws {
        for example in try workedExamples() {
            // Arrange
            let other = FrameDirection.allCases.first { $0 != example.direction } ?? .up
            var context = example.context
            context.kind = (context.kind + 1) & 15
            var window = ReplayWindow(top: 7, bits: 1)
            var tries: [(String, FrameSession, FrameDirection, MessageContext)] = [
                ("kind", try example.session(), example.direction, context),
                ("direction", try example.session(), other, example.context),
                ("epoch", try FrameSession.load(key: example.key, epoch: example.epoch + 1,
                                                 config: FrameConfig(tagLength: example.tagLength)),
                 example.direction, example.context),
                ("key", try FrameSession.load(key: flipped(example.key, bit: 0), epoch: example.epoch,
                                               config: FrameConfig(tagLength: example.tagLength)),
                 example.direction, example.context),
            ]
            for bit in 0..<64 {
                tries.append(("msg_id bit \(bit)", try example.session(), example.direction,
                              MessageContext(msgID: flipped(example.context.msgID, bit: bit), kind: example.context.kind)))
            }

            // Act
            let failures = tries.filter { _, session, direction, context in
                let outcome = attemptOpen(session, direction, context, ad: example.ad, body: example.body,
                                          clearLength: example.clear.count, window: &window, counter: 8)
                return outcome.kind != .tagMismatch || !outcome.untouched || !outcome.windowKept
            }

            // Assert
            #expect(failures.isEmpty, "\(example.name): \(failures.map(\.0))")
            #expect(window == ReplayWindow(top: 7, bits: 1))
        }
    }

    @Test func open_aWrongClearLength_isTagMismatchOrShortPacketAndWritesNothing() throws {
        for example in try workedExamples() {
            // Arrange
            let session = try example.session()
            var window = ReplayWindow()

            // Act
            let up = attemptOpen(session, example.direction, example.context, ad: example.ad, body: example.body,
                                 clearLength: example.clear.count + 1, window: &window)
            let down = example.clear.isEmpty ? nil : attemptOpen(
                session, example.direction, example.context, ad: example.ad, body: example.body,
                clearLength: example.clear.count - 1, window: &window)

            // Assert
            #expect(up.kind == .tagMismatch && up.untouched, "\(example.name)")
            #expect(down == nil || (down?.kind == .tagMismatch && down?.untouched == true), "\(example.name)")
        }
    }
}
