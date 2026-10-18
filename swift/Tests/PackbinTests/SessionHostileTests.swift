import Packbin
import Testing

/// AZ-2518 AC-3 (SW-6): hostile session input throws a `PackbinError` and never traps; the positions
/// of both directions move as TypeScript's do (a failed pack spends none, every unpack of an open
/// session spends one). The TypeScript outcomes were run at HEAD.
@Suite struct SessionHostileTests {
    @Test func load_keepsACopy_theCallersSeedIsNotWiped() throws {
        // Arrange
        let seed = sessionSeed()
        let opener = try PackSession.load(seed)
        let waiter = try PackSession.load(seed)

        // Act
        _ = try opener.start(sessionNonce())
        try waiter.join(sessionNonce())

        // Assert
        #expect(seed == sessionSeed())
    }

    @Test(arguments: [0, 1, 31, 33, 64])
    func load_aSeedOfAnotherLength_throwsBadValue(count: Int) {
        // Act
        let error = packbinError { try PackSession.load([UInt8](repeating: 7, count: count)) }

        // Assert
        #expect(error?.kind == .badValue && error?.field == nil)
        #expect(error?.reason == "session: the seed is \(count) bytes, not 32")
    }

    @Test(arguments: [0, 15, 17, 32])
    func startAndJoin_aValueOfAnotherLength_throwBadValue(count: Int) throws {
        // Arrange
        let session = try PackSession.load(sessionSeed())
        let value = [UInt8](repeating: 1, count: count)

        // Act
        let started = packbinError { try session.start(value) }
        let joined = packbinError { try session.join(value) }

        // Assert
        for error in [started, joined] {
            #expect(error?.kind == .badValue && error?.reason == "session: the session value is \(count) bytes, not 16")
        }
        #expect(throws: Never.self) { try session.join(sessionNonce()) }
    }

    @Test func openSession_opensOnceAndNotAgain() throws {
        // Arrange
        let (opener, waiter) = try sessionPair()

        // Act
        let errors = [
            packbinError { try opener.start() },
            packbinError { try opener.start(sessionNonce()) },
            packbinError { try opener.join(sessionNonce()) },
            packbinError { try waiter.join(sessionNonce()) },
            packbinError { try waiter.start() },
        ]

        // Assert
        #expect(errors.map { $0?.kind } == [PackbinError.Kind?](repeating: .badValue, count: 5))
        #expect(errors.allSatisfy { $0?.reason == "session: the session is already open" })
    }

    @Test func unpack_beforeJoin_isTheShortPacketOfAnEmptyBuffer() throws {
        // Arrange
        let loaded = try PackSession.load(sessionSeed())

        // Act
        let error = packbinError { try loaded.unpack(bytes(sessionCipherHex), try positionMapScheme()) }
        let asMap = packbinError { try loaded.unpackMap(bytes(sessionCipherHex), try positionMapScheme()) }

        // Assert
        for e in [error, asMap] {
            #expect(e?.kind == .short && e?.field == nil && e?.name == "" && e?.needed == 1 && e?.left == 0)
        }
    }

    @Test func pack_thatFails_spendsNoPosition() throws {
        // Arrange
        let (opener, _) = try sessionPair()
        let scheme = try positionMapScheme()
        let typed = try positionTypedScheme()

        // Act
        let errors = [
            packbinError { try opener.pack(scheme, ["sid": 1]) },
            packbinError { try opener.pack(scheme, [:]) },
            packbinError { try opener.pack(scheme, ["sid": 70_000, "lat": 0, "lon": 0, "profile": 0]) },
            packbinError { try opener.pack(typed, 42) },
            packbinError { try opener.pack(scheme, "not a row") },
        ]
        let payload = try opener.pack(scheme, goldenMap())

        // Assert
        #expect(errors.allSatisfy { $0?.kind == .packError })
        #expect(hex(payload) == sessionCipherHex, "the packet after the failures is position 0")
    }

    @Test func unpack_thatCannotBeRead_spendsAPositionAndTheNextMessageReads() throws {
        // Arrange: the TypeScript hostile session row (tests/support/hostile-cases.ts runSession): the
        // sender writes 01 00 05; the receiver's type 1 is k then a repeat of zero-width rounds.
        let (opener, waiter) = try sessionPair([UInt8]((1...16).map { UInt8($0) }))
        let sender = try Scheme(1, .u8(0, "k"), .u8(1, "extra"))
        let receiver = try Scheme(1, .u8(0, "k"), .repeat(1, .bytes(1, "v", size: 0)))
        let next = try Scheme(2, .u8(0, "k"))
        let hostile = try opener.pack(sender, ["k": 0, "extra": 5])
        let fine = try opener.pack(next, ["k": 7])
        let clear = packbinError { try unpack(bytes("010005"), receiver) }

        // Act
        let first = packbinError { try waiter.unpack(hostile, receiver) }
        let second = try waiter.unpackMap(fine, next)

        // Assert
        #expect(hex(hostile) == "a4c586" && hex(fine) == "5e7b", "TypeScript's payloads")
        #expect(first?.kind == .trailing && first?.left == 1 && first == clear, "the error clear unpack throws")
        #expect(second["k"] as? UInt8 == 7)
    }

    @Test(arguments: ["empty", "one byte", "cut after the type", "a tail"])
    func unpack_aRefusedCall_stillSpendsAPositionAsTypeScript(name: String) throws {
        // Arrange
        let (opener, waiter) = try sessionPair()
        let scheme = try positionMapScheme()
        let first = try opener.pack(scheme, goldenMap())
        let second = try opener.pack(scheme, goldenMap())
        let payloads = ["empty": [], "one byte": [0], "cut after the type": Array(first.prefix(3)),
                        "a tail": first + [1, 2, 3]]

        // Act
        let error = packbinError {
            return try waiter.unpackMap(payloads[name] ?? first, scheme)
        }
        let row = try waiter.unpackMap(second, scheme)

        // Assert
        #expect(error != nil)
        #expect(goldenFieldMismatches(row) == 0, "the second payload reads at position 1")
    }

    @Test func unpack_aRepeatedTypeNumber_isRefusedBeforeThePositionAdvances() throws {
        // Arrange
        let (opener, waiter) = try sessionPair()
        let scheme = try positionMapScheme()
        let first = try opener.pack(scheme, goldenMap())
        let second = try opener.pack(scheme, goldenMap())

        // Act
        let refused = [packbinError { try waiter.unpack(first, scheme, scheme) },
                       packbinError { try waiter.unpackMap(first, scheme, scheme) },
                       packbinError { try waiter.unpackRepair(first, limit: 0, scheme, scheme) }]
        let readFirst = try waiter.unpackMap(first, scheme)
        let readSecond = try waiter.unpackMap(second, scheme)

        // Assert
        #expect(refused.allSatisfy { $0?.kind == .schemeError && $0?.reason == "duplicate type number \(scheme.typeNumber)" })
        #expect(goldenFieldMismatches(readFirst) == 0, "the first payload still reads at position 0")
        #expect(goldenFieldMismatches(readSecond) == 0, "the second payload reads at position 1")
    }

    @Test func unpack_shortAndOddPayloads_throwTheErrorOfClearUnpack() throws {
        // Arrange
        let scheme = try positionMapScheme()
        let cipher = bytes(sessionCipherHex)
        let cases: [(String, [UInt8], PackbinError.Kind?)] = [
            ("empty", [], .short),
            ("one byte", [0], nil),
            ("cut after the type", Array(cipher.prefix(3)), .short),
            ("a tail", cipher + [1, 2, 3], .trailing),
        ]

        for (name, payload, kind) in cases {
            let (_, waiter) = try sessionPair()

            // Act
            let error = packbinError { try waiter.unpack(payload, scheme) }

            // Assert
            #expect(error != nil, "\(name)")
            if let kind { #expect(error?.kind == kind, "\(name)") }
        }
    }

    @Test(arguments: [1 << 20])
    func unpack_aLargePayload_throwsWithoutATrap(count: Int) throws {
        // Arrange
        let (_, waiter) = try sessionPair()
        let payload = [UInt8](repeating: 0, count: count)

        // Act: the pad turns the zeros into its key stream.
        let error = packbinError { try waiter.unpackMap(payload, try positionMapScheme()) }

        // Assert
        #expect(error?.kind == .unknownType || error?.kind == .trailing)
    }

    @Test func unpack_randomPayloads_throwOrReadAndNeverTrap() throws {
        // Arrange
        let (_, waiter) = try sessionPair()
        let schemes = [try positionMapScheme(), try Scheme(1, .u8(0, "k"), .repeat(1, .u8(1, "v")))]
        var random = SystemRandomNumberGenerator()
        var outcomes = 0

        // Act
        for length in 0..<300 {
            let payload = (0..<(length % 40)).map { _ in UInt8.random(in: .min ... .max, using: &random) }
            do {
                _ = try waiter.unpackMap(payload, schemes)
                outcomes += 1
            } catch is PackbinError {
                outcomes += 1
            }
        }

        // Assert
        #expect(outcomes == 300)
    }

    @Test func unpack_leavesTheCallersPayloadAlone() throws {
        // Arrange
        let (opener, waiter) = try sessionPair()
        let scheme = try positionMapScheme()
        let payload = try opener.pack(scheme, goldenMap())

        // Act
        _ = try waiter.unpackMap(payload, scheme)

        // Assert
        #expect(hex(payload) == sessionCipherHex)
    }

    @Test func packAndUnpack_typedRows_refuseAWrongRowType() throws {
        // Arrange
        let (opener, waiter) = try sessionPair()
        let typed = try positionTypedScheme()

        // Act
        let refused = packbinError { try opener.pack(typed, 42) }
        let payload = try opener.pack(typed, goldenRow())
        let row = try waiter.unpack(payload, typed)

        // Assert
        #expect(refused?.kind == .packError)
        #expect(hex(payload) == sessionCipherHex && row as? Position == goldenRow())
    }
}
