import Foundation
import Packbin
import Testing

/// What a probe saw when an object was released.
final class Released: @unchecked Sendable {
    private let lock = NSLock()
    private var calls: [[UInt8]] = []

    func record(_ bytes: [UInt8]) {
        lock.lock()
        calls.append(bytes)
        lock.unlock()
    }

    var all: [[UInt8]] {
        lock.lock()
        defer { lock.unlock() }
        return calls
    }

    var probe: FrameProbe { FrameProbe(onRelease: { [self] in record($0) }) }
}

/// AZ-3234 AC-9 and AC-10 (S10; AC-G2.6, AC-G2.7): the tag compare reads every byte, and keys are overwritten when
/// a session or key object is closed or released, after which a call gives `BadValue`.
@Suite struct FrameWipeTests {
    @Test func tagsEqual_equalTagsAndTagsThatDifferInTheFirstOrTheLastByte_giveEqualNotEqualNotEqual() {
        // Arrange
        let tag: [UInt8] = [1, 2, 3, 4, 5, 6, 7, 8]
        var first = tag
        first[0] ^= 0x80
        var last = tag
        last[7] ^= 1

        // Act
        let results = [FramePrimitives.tagsEqual(tag, tag), FramePrimitives.tagsEqual(tag, first),
                       FramePrimitives.tagsEqual(tag, last)]

        // Assert
        #expect(results == [true, false, false])
        #expect(!FramePrimitives.tagsEqual(tag, Array(tag.dropLast())), "a different length is not equal")
        #expect(FramePrimitives.tagsEqual([], []))
    }

    @Test func tagsEqual_everyBitPosition_isDetected() {
        // Arrange
        let tag = (0..<16).map { UInt8($0 &* 7) }

        // Act
        let missed = (0..<(tag.count * 8)).filter { FramePrimitives.tagsEqual(tag, flipped(tag, bit: $0)) }

        // Assert
        #expect(missed.isEmpty)
    }

    @Test func compareHelper_hasNoReturnBreakOrContinueBetweenItsLoopAndItsDecision() throws {
        // Arrange
        let source = try repositoryFile("swift/Sources/Packbin/FrameCrypto.swift")
        let helper = try #require(source.components(separatedBy: "static func equal(_ a: UnsafeRawBufferPointer").dropFirst().first)
        let fold = try #require(helper.components(separatedBy: "for i in 0..<a.count").dropFirst().first)

        // Act
        let loop = try #require(fold.components(separatedBy: "return diff == 0").first)

        // Assert
        #expect(loop.contains("diff |= a[i] ^ b[i]"))
        for word in ["return", "break", "continue", "if ", "guard"] {
            #expect(!loop.contains(word), "the fold loop holds `\(word)`")
        }
    }

    @Test func release_aSessionOverwritesItsKeys_whichWereNotZeroBefore() throws {
        // Arrange
        let released = Released()
        var session: FrameSession? = try FrameSession.load(key: repeatedKey(0x5A), epoch: 9, config: FrameConfig(tagLength: 4),
                                                           probe: released.probe)
        try session?.setPrevious(key: repeatedKey(0x6B), epoch: 8)
        let before = (session?.derivedKeys(for: .up)).map { $0.enc + $0.mac } ?? []
        let beforePrevious = (session?.derivedKeys(for: .group, previous: true)).map { $0.enc + $0.mac } ?? []

        // Act
        session = nil

        // Assert
        let calls = released.all
        #expect(before.count == 64 && before.contains { $0 != 0 })
        #expect(beforePrevious.count == 64 && beforePrevious.contains { $0 != 0 })
        #expect(calls.count == 1 && calls.first?.count == 384, "current and previous slot: 2 x 6 keys x 32 bytes")
        #expect(calls.first?.allSatisfy { $0 == 0 } == true)
    }

    @Test func close_overwritesTheKeysAndEveryLaterCallIsBadValue() throws {
        // Arrange
        let session = try FrameSession.load(key: repeatedKey(0x5A), epoch: 9, config: FrameConfig(tagLength: 4))
        try session.setPrevious(key: repeatedKey(0x6B), epoch: 8)
        let context = MsgContext(msgID: messageID(1), kind: 1)
        let body = try sealBody(session, .up, context, plain: [1, 2])
        let live = session.derivedKeys(for: .down)

        // Act
        session.close()
        session.close()
        var out = [UInt8](repeating: frameSentinel, count: 64)
        var window = ReplayWindow()
        let sealed = packbinError { try session.seal(direction: .up, context: context, ad: [], clear: [], plain: [1], into: &out) }
        let opened = packbinError {
            try session.open(direction: .up, context: context, ad: [], body: body, clearLength: 0, window: &window,
                              counter: 1, into: &out)
        }
        let previous = packbinError { try session.setPrevious(key: repeatedKey(1), epoch: 1); return 0 }

        // Assert
        #expect(live.map { $0.enc.contains { $0 != 0 } && $0.mac.contains { $0 != 0 } } == true)
        for direction in FrameDirection.allCases {
            for slot in [false, true] {
                let keys = session.derivedKeys(for: direction, previous: slot)
                #expect(keys.map { ($0.enc + $0.mac).allSatisfy { $0 == 0 } } == true, "\(direction) previous \(slot)")
            }
        }
        #expect(session.isClosed)
        #expect(sealed?.kind == .badValue && opened?.kind == .badValue && previous?.kind == .badValue)
        #expect(out.allSatisfy { $0 == frameSentinel } && window == ReplayWindow())
    }

    @Test func clearPrevious_overwritesThePreviousSlotAndDropsIt() throws {
        // Arrange
        let session = try FrameSession.load(key: repeatedKey(0x5A), epoch: 9, config: FrameConfig(tagLength: 4))
        try session.setPrevious(key: repeatedKey(0x6B), epoch: 8)
        #expect(session.derivedKeys(for: .up, previous: true) != nil)

        // Act
        session.clearPrevious()

        // Assert
        #expect(session.derivedKeys(for: .up, previous: true) == nil)
        #expect(session.derivedKeys(for: .up)?.enc.contains { $0 != 0 } == true, "the current key is kept")
    }

    @Test func macKey_closeAndRelease_overwriteTheKeyAndACloseKeyGivesBadValue() throws {
        // Arrange
        let released = Released()
        var key: MacKey? = try MacKey.derive(key: repeatedKey(0x22), epoch: 7, label: [1, 2, 3], probe: released.probe)
        let closing = try MacKey.derive(key: repeatedKey(0x22), epoch: 7, label: [1, 2, 3])
        let live = closing.storedKey
        let tag = try closing.tag([[1]], length: 4)

        // Act
        key = nil
        closing.close()
        let error = packbinError { try closing.tag([[1]], length: 4) }

        // Assert
        #expect(live.count == 32 && live.contains { $0 != 0 })
        #expect(released.all.count == 1 && released.all.first?.count == 32 && released.all.first?.allSatisfy { $0 == 0 } == true)
        #expect(closing.storedKey.allSatisfy { $0 == 0 } && closing.isClosed)
        #expect(error?.kind == .badValue)
        #expect(!closing.verify([[1]], tag: tag), "a closed key verifies nothing")
        #expect(key == nil)
    }
}
