import Packbin
import Testing

/// AZ-3234 AC-5 and AC-6 (S2, S3, S5; AC-G2.2, AC-G2.3): the replay check runs before any MAC, a failed open never
/// moves the window, and the previous key opens what was sealed just before a key change.
@Suite struct FrameReplayTests {
    private func context(_ n: UInt64) -> MsgContext {
        MsgContext(msgID: messageID(n), kind: 3)
    }

    @Test func open_aSeenCounterAndOneSixtyFourBehind_areRefusedWithNoMacAndTheWindowUnchanged() throws {
        // Arrange
        let count = MacCount()
        let session = try FrameSession.load(key: repeatedKey(7), epoch: 2, config: FrameConfig(tagLength: 4),
                                            probe: count.probe)
        let sealer = try FrameSession.load(key: repeatedKey(7), epoch: 2, config: FrameConfig(tagLength: 4))
        let body = { (n: UInt64) in try sealBody(sealer, .up, self.context(n), ad: [9], plain: [1, 2, 3]) }
        var window = ReplayWindow()
        let first = attemptOpen(session, .up, context(100), ad: [9], body: try body(100), clearLength: 0, window: &window,
                                counter: 100)
        let macsAfterFirst = count.value
        let committed = window

        // Act
        let seen = attemptOpen(session, .up, context(100), ad: [9], body: try body(100), clearLength: 0, window: &window,
                               counter: 100)
        let old = attemptOpen(session, .up, context(36), ad: [9], body: try body(36), clearLength: 0, window: &window,
                              counter: 36)

        // Assert
        #expect(first.kind == nil && macsAfterFirst == 1)
        #expect(committed == ReplayWindow(top: 100, bits: 1))
        #expect(seen.kind == .duplicate && seen.untouched && seen.windowKept)
        #expect(old.kind == .tooOld && old.untouched && old.windowKept)
        #expect(count.value == macsAfterFirst, "a refused counter computed \(count.value - macsAfterFirst) MACs")
    }

    @Test func open_aFreshValidBody_commitsItsCounterAndAFreshTamperedBodyDoesNot() throws {
        // Arrange
        let count = MacCount()
        let session = try FrameSession.load(key: repeatedKey(7), epoch: 2, config: FrameConfig(tagLength: 8),
                                            probe: count.probe)
        let sealer = try FrameSession.load(key: repeatedKey(7), epoch: 2, config: FrameConfig(tagLength: 8))
        var window = ReplayWindow(top: 100, bits: 1)
        let valid = try sealBody(sealer, .down, context(37), plain: [5, 6])
        var tampered = try sealBody(sealer, .down, context(150), plain: [5, 6])
        tampered[0] ^= 1

        // Act
        let edge = attemptOpen(session, .down, context(37), ad: [], body: valid, clearLength: 0, window: &window,
                               counter: 37)
        let committedEdge = window
        let bad = attemptOpen(session, .down, context(150), ad: [], body: tampered, clearLength: 0, window: &window,
                              counter: 150)

        // Assert
        #expect(edge.kind == nil && edge.plain == [5, 6], "counter 37 is 63 behind: still in the window")
        #expect(committedEdge.check(37) == .duplicate && committedEdge.top == 100)
        #expect(bad.kind == .tagMismatch && bad.untouched && bad.windowKept)
        #expect(window == committedEdge)
        #expect(count.value == 2, "one MAC per fresh body")
    }

    @Test func open_aRefusalBeforeTheReplayCheck_doesNotTouchTheWindow() throws {
        // Arrange
        let session = try FrameSession.load(key: repeatedKey(7), epoch: 2, config: FrameConfig(tagLength: 4))
        var window = ReplayWindow(top: 5, bits: 1)

        // Act
        let short = attemptOpen(session, .up, context(1), ad: [], body: [1, 2], clearLength: 0, window: &window, counter: 5)
        let tooLong = attemptOpen(session, .up, context(1), ad: [], body: [UInt8](repeating: 0, count: 256), clearLength: 0,
                                  window: &window, counter: 5)
        let small = attemptOpen(session, .up, context(1), ad: [], body: [UInt8](repeating: 0, count: 20), clearLength: 0,
                                window: &window, counter: 5, outLength: 3)

        // Assert
        #expect(short.kind == .short && tooLong.kind == .tooLong && small.kind == .bufferFull,
                "the argument checks come before the replay check, so a duplicate counter does not hide them")
        #expect(window == ReplayWindow(top: 5, bits: 1))
    }

    @Test func window_followsTheModelOfSeenCountersOver2000RandomSteps() {
        // Arrange
        var random = SeededRandom(state: 0x3234)
        var window = ReplayWindow()
        var seen = Set<UInt64>()
        var top: UInt64 = 0
        var wrong = 0

        // Act
        for _ in 0..<2000 {
            let n = seen.isEmpty ? 1000 : UInt64(Int64(top) + Int64.random(in: -80...20, using: &random))
            let want: Freshness = seen.isEmpty || n > top ? .fresh : top - n >= 64 ? .tooOld : seen.contains(n) ? .duplicate : .fresh
            let before = window
            if window.check(n) != want || window != before { wrong += 1 }
            if want == .fresh {
                window.commit(n)
                seen.insert(n)
                top = max(top, n)
            }
        }

        // Assert
        #expect(wrong == 0)
    }

    @Test func open_underThePreviousKey_isOkPreviousAndTheCurrentKeyIsOkCurrent() throws {
        // Arrange
        let (a, b) = (repeatedKey(0xA1), repeatedKey(0xB2))
        let config = FrameConfig(tagLength: 4)
        let old = try FrameSession.load(key: a, epoch: 6, config: config)
        let new = try FrameSession.load(key: b, epoch: 7, config: config)
        let session = try FrameSession.load(key: b, epoch: 7, config: config)
        try session.setPrevious(key: a, epoch: 6)
        let underA = try sealBody(old, .group, context(1), ad: [1], clear: [8], plain: [1, 2, 3])
        let underB = try sealBody(new, .group, context(2), ad: [1], clear: [8], plain: [4, 5])
        var window = ReplayWindow()

        // Act
        let first = attemptOpen(session, .group, context(1), ad: [1], body: underA, clearLength: 1, window: &window, counter: 1)
        let second = attemptOpen(session, .group, context(2), ad: [1], body: underB, clearLength: 1, window: &window, counter: 2)
        let sealed = try sealBody(session, .group, context(1), ad: [1], clear: [8], plain: [1, 2, 3])

        // Assert
        #expect(first.opened == FrameOpened(slot: .previous, clearLength: 1, plainLength: 3) && first.plain == [1, 2, 3])
        #expect(second.opened == FrameOpened(slot: .current, clearLength: 1, plainLength: 2) && second.plain == [4, 5])
        #expect(window == ReplayWindow(top: 2, bits: 0b11), "a previous-key frame commits into the same window")
        #expect(sealed != underA, "seal never uses the previous key")
    }

    @Test func open_withNoPreviousSlotOrAfterClearPrevious_aBodyUnderTheOldKeyIsTagMismatch() throws {
        // Arrange
        let config = FrameConfig(tagLength: 4)
        let old = try FrameSession.load(key: repeatedKey(0xA1), epoch: 6, config: config)
        let body = try sealBody(old, .up, context(1), plain: [1, 2, 3])
        let none = try FrameSession.load(key: repeatedKey(0xB2), epoch: 7, config: config)
        let cleared = try FrameSession.load(key: repeatedKey(0xB2), epoch: 7, config: config)
        try cleared.setPrevious(key: repeatedKey(0xA1), epoch: 6)
        var window = ReplayWindow()
        let before = attemptOpen(cleared, .up, context(1), ad: [], body: body, clearLength: 0, window: &window)

        // Act
        cleared.clearPrevious()
        let withoutSlot = attemptOpen(none, .up, context(1), ad: [], body: body, clearLength: 0, window: &window, counter: 1)
        let afterClear = attemptOpen(cleared, .up, context(1), ad: [], body: body, clearLength: 0, window: &window, counter: 1)

        // Assert
        #expect(before.opened?.slot == .previous)
        #expect(withoutSlot.kind == .tagMismatch && withoutSlot.untouched && withoutSlot.windowKept)
        #expect(afterClear.kind == .tagMismatch && afterClear.untouched && afterClear.windowKept)
        #expect(window == ReplayWindow())
    }

    @Test func setPrevious_aKeyOfTheWrongSizeOrAnEpochAbove24Bits_isBadValueAndKeepsTheSlot() throws {
        // Arrange
        let session = try FrameSession.load(key: repeatedKey(1), epoch: 1, config: FrameConfig(tagLength: 4))
        try session.setPrevious(key: repeatedKey(2), epoch: 0)
        let kept = session.derivedKeys(for: .up, previous: true)

        // Act
        let short = packbinError { try session.setPrevious(key: [UInt8](repeating: 3, count: 31), epoch: 0); return 0 }
        let epoch = packbinError { try session.setPrevious(key: repeatedKey(3), epoch: 0x0100_0000); return 0 }

        // Assert
        #expect(short?.kind == .badValue && epoch?.kind == .badValue)
        #expect(session.derivedKeys(for: .up, previous: true)?.enc == kept?.enc && kept != nil)
    }
}
