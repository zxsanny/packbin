@_spi(Vectors) import Packbin
import Testing

/// AZ-3234 AC-8 (S6; AC-G2.5): each refusal of the contract returns its kind with nothing written, and 1,000 hostile
/// bodies, lengths and clear lengths from a fixed seed cause no crash and the kind the contract's order gives.
@Suite struct FrameRefusalTests {
    private let context = MessageContext(msgID: messageID(1), kind: 1)

    private func session(tag: Int = 4, directions: FrameDirections = .all) throws -> FrameSession {
        try FrameSession.load(key: repeatedKey(0x33), epoch: 5, config: FrameConfig(tagLength: tag, directions: directions))
    }

    private func sealError(_ session: FrameSession, direction: FrameDirection = .up, context: MessageContext? = nil,
                           ad: Int = 0, clear: Int = 0, plain: Int = 1, out: Int = 255) -> (PackbinError.Kind?, Bool) {
        var buffer = [UInt8](repeating: frameSentinel, count: out)
        let error = packbinError {
            try session.seal(direction: direction, context: context ?? self.context,
                             ad: [UInt8](repeating: 1, count: ad), clear: [UInt8](repeating: 2, count: clear),
                             plain: [UInt8](repeating: 3, count: plain), into: &buffer)
        }
        return (error?.kind, buffer.allSatisfy { $0 == frameSentinel })
    }

    @Test func load_aBadKeyEpochOrTagLength_createsNoSession() throws {
        // Arrange
        let good = repeatedKey(1)
        func load(_ key: [UInt8], _ epoch: UInt32, _ tag: Int) -> PackbinError.Kind? {
            packbinError { try FrameSession.load(key: key, epoch: epoch, config: FrameConfig(tagLength: tag)) }?.kind
        }

        // Act
        let kinds = [load(Array(good.dropLast()), 1, 4), load(good + [0], 1, 4), load(good, 0x0100_0000, 4),
                     load(good, 1, 0), load(good, 1, 5), load(good, 1, 32), load(good, 1, -4)]
        let edges = [load(good, 0xFF_FFFF, 4), load(good, 0, 8), load(good, 1, 16)]

        // Assert
        #expect(kinds.allSatisfy { $0 == .badValue }, "\(kinds)")
        #expect(edges.allSatisfy { $0 == nil }, "epoch 0xFFFFFF and tags 8 and 16 load")
    }

    @Test func seal_eachRefusal_returnsItsKindAndWritesNothing() throws {
        // Arrange
        let both = try session()
        let upOnly = try session(directions: .up)
        let big = MessageContext(msgID: messageID(1), kind: 16)
        let short = MessageContext(msgID: [1, 2, 3], kind: 1)

        // Act
        let results: [(name: String, kind: PackbinError.Kind?, untouched: Bool)] = [
            ("direction", sealError(upOnly, direction: .down)),
            ("kind 16", sealError(both, context: big)),
            ("msg_id of 3 bytes", sealError(both, context: short)),
            ("ad 256", sealError(both, ad: 256)),
            ("body 256", sealError(both, clear: 100, plain: 152)),
            ("body 256 into a short buffer", sealError(both, clear: 100, plain: 152, out: 10)),
            ("one byte short", sealError(both, clear: 3, plain: 5, out: 11)),
            ("empty buffer", sealError(both, out: 0)),
        ].map { ($0.0, $0.1.0, $0.1.1) }

        // Assert
        #expect(results.map(\.kind) == [.badValue, .badValue, .badValue, .tooLong, .tooLong, .tooLong, .bufferFull, .bufferFull],
                "\(results.map { "\($0.name): \(String(describing: $0.kind))" })")
        #expect(results.allSatisfy { $0.untouched }, "a refused seal left no partial output")
    }

    @Test func seal_theLargestBodyAndTheLargestAssociatedData_seal() throws {
        // Arrange
        let session = try session(tag: 4)
        var out = [UInt8](repeating: frameSentinel, count: 255)

        // Act
        let n = try session.seal(direction: .group, context: context, ad: [UInt8](repeating: 9, count: 255),
                                 clear: [1, 2, 3], plain: [UInt8](repeating: 4, count: 248), into: &out)

        // Assert
        #expect(n == 255)
        #expect(out.prefix(3) == [1, 2, 3])
    }

    @Test func open_eachRefusal_returnsItsKindWritesNothingAndKeepsTheWindow() throws {
        // Arrange
        let session = try session()
        let sealer = try self.session()
        let body = try sealBody(sealer, .up, context, ad: [1], clear: [2, 2], plain: [3, 3, 3])
        var window = ReplayWindow(top: 70, bits: 0b11)
        let kind16 = MessageContext(msgID: messageID(1), kind: 16)

        // Act
        let cases: [(String, OpenOutcome)] = [
            ("kind 16", attemptOpen(session, .up, kind16, ad: [1], body: body, clearLength: 2, window: &window, counter: 80)),
            ("ad 256", attemptOpen(session, .up, context, ad: [UInt8](repeating: 1, count: 256), body: body, clearLength: 2,
                                   window: &window, counter: 80)),
            ("body 256", attemptOpen(session, .up, context, ad: [1], body: [UInt8](repeating: 0, count: 256), clearLength: 2,
                                     window: &window, counter: 80)),
            ("clear 256", attemptOpen(session, .up, context, ad: [1], body: body, clearLength: 256, window: &window, counter: 80)),
            ("negative clear", attemptOpen(session, .up, context, ad: [1], body: body, clearLength: -1, window: &window,
                                           counter: 80)),
            ("short", attemptOpen(session, .up, context, ad: [1], body: body, clearLength: body.count - 3, window: &window,
                                  counter: 80)),
            ("buffer", attemptOpen(session, .up, context, ad: [1], body: body, clearLength: 2, window: &window, counter: 80,
                                   outLength: 2)),
            ("duplicate", attemptOpen(session, .up, context, ad: [1], body: body, clearLength: 2, window: &window, counter: 70)),
            ("too old", attemptOpen(session, .up, context, ad: [1], body: body, clearLength: 2, window: &window, counter: 6)),
            ("tag", attemptOpen(session, .up, context, ad: [2], body: body, clearLength: 2, window: &window, counter: 80)),
            ("empty body", attemptOpen(session, .up, context, ad: [], body: [], clearLength: 0, window: &window, counter: 80)),
        ]

        // Assert
        let kinds = cases.map(\.1.kind)
        #expect(kinds == [.badValue, .tooLong, .tooLong, .tooLong, .badValue, .short, .bufferFull, .duplicate, .tooOld,
                          .tagMismatch, .short], "\(cases.map { "\($0.0): \(String(describing: $0.1.kind))" })")
        #expect(cases.allSatisfy { $0.1.untouched && $0.1.windowKept })
        #expect(window == ReplayWindow(top: 70, bits: 0b11))
    }

    @Test func open_aDirectionNotLoaded_isBadValueAndWritesNothing() throws {
        // Arrange
        let upOnly = try session(directions: .up)
        var window = ReplayWindow()

        // Act
        let outcome = attemptOpen(upOnly, .group, context, ad: [], body: [1, 2, 3, 4, 5], clearLength: 0, window: &window)

        // Assert
        #expect(outcome.kind == .badValue && outcome.untouched)
    }

    @Test func errorDescription_eachFrameKind_namesTheKindAndTheReason() throws {
        // Arrange
        let session = try session(directions: .up)
        let body = try sealBody(session, .up, context, plain: [1])
        var window = ReplayWindow(top: 70, bits: 1)
        var out = [UInt8](repeating: 0, count: 255)

        // Act
        let tag = packbinError { try session.open(direction: .up, context: context, ad: [1], body: body, clearLength: 0, into: &out) }
        let duplicate = packbinError {
            try session.open(direction: .up, context: context, ad: [], body: body, clearLength: 0, window: &window, counter: 70,
                             into: &out)
        }
        let old = packbinError {
            try session.open(direction: .up, context: context, ad: [], body: body, clearLength: 0, window: &window, counter: 1,
                             into: &out)
        }
        var tiny = [UInt8](repeating: 0, count: 1)
        let full = packbinError { try session.seal(direction: .up, context: context, ad: [], clear: [], plain: [1], into: &tiny) }

        // Assert
        #expect(tag?.kind.rawValue == "tag_mismatch" && tag?.description.hasPrefix("packbin: tag mismatch: frame: ") == true)
        #expect(duplicate?.kind.rawValue == "duplicate" && duplicate?.description.contains("counter 70") == true)
        #expect(old?.kind.rawValue == "too_old" && old?.description.hasPrefix("packbin: frame too old: ") == true)
        #expect(full?.kind.rawValue == "buffer_full" && full?.needed == 5 && full?.left == 1)
    }

    @Test func hostileCorpus_1000RandomBodiesLengthsAndClearLengths_giveTheContractsKindAndNoCrash() throws {
        // Arrange
        var random = SeededRandom(state: 0xA23_234)
        let sessions = try [4, 8, 16].map { try session(tag: $0) }
        var unexpected: [String] = []
        var okCount = 0
        var kindCounts: [PackbinError.Kind: Int] = [:]

        // Act
        for i in 0..<1000 {
            let tag = [4, 8, 16][i % 3]
            let direction = FrameDirection.allCases[Int.random(in: 0..<3, using: &random)]
            let kind = UInt8.random(in: 0...20, using: &random)
            let idLength = Int.random(in: 0...1, using: &random) == 0 ? 8 : Int.random(in: 0...10, using: &random)
            let ctx = MessageContext(msgID: (0..<idLength).map { _ in UInt8.random(in: 0...255, using: &random) }, kind: kind)
            let adLength = Int.random(in: 0...300, using: &random)
            let ad = (0..<adLength).map { _ in UInt8.random(in: 0...255, using: &random) }
            let bodyLength = Int.random(in: 0...300, using: &random)
            let body = (0..<bodyLength).map { _ in UInt8.random(in: 0...255, using: &random) }
            let clear = Int.random(in: -3...300, using: &random)
            let outLength = Int.random(in: 0...300, using: &random)
            var window = ReplayWindow()
            let before = window

            let outcome = attemptOpen(sessions[i % 3], direction, ctx, ad: ad, body: body, clearLength: clear, window: &window,
                                      counter: UInt64.random(in: 0...200, using: &random), outLength: outLength)

            // Model of the contract's order (argument checks, then the tag), written apart from the implementation.
            let want: PackbinError.Kind
            if kind > 15 || idLength != 8 || clear < 0 { want = .badValue }
            else if adLength > 255 || bodyLength > 255 || clear > 255 { want = .tooLong }
            else if bodyLength < clear + tag { want = .short }
            else if outLength < bodyLength - clear - tag { want = .bufferFull }
            else { want = .tagMismatch }
            if outcome.kind != want || !outcome.untouched || window != before { unexpected.append("case \(i): \(String(describing: outcome.kind)) not \(want)") }
            if let k = outcome.kind { kindCounts[k, default: 0] += 1 } else { okCount += 1 }
        }

        // Assert
        #expect(unexpected.isEmpty, "\(unexpected.prefix(5))")
        #expect(okCount == 0, "a random body does not carry a valid tag")
        #expect(kindCounts.keys.count >= 5, "the corpus reaches the kinds: \(kindCounts)")
    }

    @Test func roundTrip_500RandomSealedFrames_openToTheirPlaintext() throws {
        // Arrange
        var random = SeededRandom(state: 0x5EA1)
        var wrong: [String] = []

        // Act
        for i in 0..<500 {
            let tag = [4, 8, 16][i % 3]
            let session = try self.session(tag: tag)
            let direction = FrameDirection.allCases[i % 3]
            let clearLength = Int.random(in: 0...20, using: &random)
            let plainLength = Int.random(in: 0...(255 - tag - clearLength), using: &random)
            let ad = (0..<Int.random(in: 0...255, using: &random)).map { _ in UInt8.random(in: 0...255, using: &random) }
            let clear = (0..<clearLength).map { _ in UInt8.random(in: 0...255, using: &random) }
            let plain = (0..<plainLength).map { _ in UInt8.random(in: 0...255, using: &random) }
            let ctx = MessageContext(msgID: messageID(random.next()), kind: UInt8.random(in: 0...15, using: &random))
            let body = try sealBody(session, direction, ctx, ad: ad, clear: clear, plain: plain)
            var window = ReplayWindow()
            let outcome = attemptOpen(session, direction, ctx, ad: ad, body: body, clearLength: clearLength, window: &window,
                                      counter: UInt64(i), outLength: plainLength)
            if outcome.kind != nil || outcome.plain != plain || Array(body.prefix(clearLength)) != clear
                || body.count != clearLength + plainLength + tag || window.check(UInt64(i)) != .duplicate {
                wrong.append("frame \(i)")
            }
        }

        // Assert
        #expect(wrong.isEmpty, "\(wrong.prefix(5))")
    }
}
