import Packbin
import Testing

let sessionCipherHex = "b55d0a29c56c203712b241232e"
let sessionNonceHex = "01000000000000000000000000000000"

func sessionSeed() -> [UInt8] {
    (1...32).map { UInt8($0) }
}

func sessionNonce() -> [UInt8] {
    bytes(sessionNonceHex)
}

/// An opener and a waiter on the same seed and value.
func sessionPair(_ nonce: [UInt8] = sessionNonce()) throws -> (opener: PackSession, waiter: PackSession) {
    let opener = try PackSession.load(sessionSeed())
    let waiter = try PackSession.load(sessionSeed())
    _ = try opener.start(nonce)
    try waiter.join(nonce)
    return (opener, waiter)
}

/// The fields of a map row that differ from the AC-1 row (sid 1, lat 500000000, lon 300000000,
/// profile 1, no motion field).
func goldenFieldMismatches(_ row: [String: Any]) -> Int {
    var bad = 0
    if row["sid"] as? UInt16 != 1 { bad += 1 }
    if row["lat"] as? Int32 != 500_000_000 { bad += 1 }
    if row["lon"] as? Int32 != 300_000_000 { bad += 1 }
    if row["profile"] as? UInt8 != 1 { bad += 1 }
    return bad + ["heading", "speed", "altitude"].filter { row[$0] != nil }.count
}

/// AZ-2518 AC-1 and AC-2 (SW-6, S12): session AC-1 to AC-7 of
/// `_docs/02_task_plans/pack-session/acceptance_criteria.md`. The ciphertexts other than C#'s are
/// TypeScript's for the same seed, value and row.
@Suite struct SessionTests {
    @Test(arguments: ["map", "typed"])
    func pack_openerWithTheCSharpSeedAndValue_givesTheCSharpCiphertext(form: String) throws {
        // Arrange
        let opener = try PackSession.load(sessionSeed())
        _ = try opener.start(sessionNonce())

        // Act
        let payload = form == "map"
            ? try opener.pack(try positionMapScheme(), goldenMap())
            : try opener.pack(try positionTypedScheme(), goldenRow())

        // Assert
        #expect(payload.count == 13)
        #expect(hex(payload) == sessionCipherHex)
        #expect(mismatchedBytes(payload, bytes(sessionCipherHex)) == 0)
    }

    @Test(arguments: [("seed 1..32", sessionSeed(), "d9bc"), ("zero seed", [UInt8](repeating: 0, count: 32), "5781")])
    func pack_oneU8UnderTheValueOfOnes_givesTypeScriptsKeyedFirstPacket(name: String, seed: [UInt8], want: String) throws {
        // Arrange: the TypeScript rows of AZ-2243.
        let one = try Scheme(1, .u8(0, "a"))
        let opener = try PackSession.load(seed)
        _ = try opener.start([UInt8](repeating: 1, count: 16))

        // Act
        let payload = try opener.pack(one, ["a": 0])

        // Assert
        #expect(hex(payload) == want, "\(name)")
    }

    @Test func unpack_waiterOfTheOpenersPayload_recoversTheFiveFields() throws {
        // Arrange
        let (opener, waiter) = try sessionPair()
        let scheme = try positionMapScheme()

        // Act
        let payload = try opener.pack(scheme, goldenMap())
        let row = try waiter.unpackMap(payload, scheme)

        // Assert
        #expect(payload.count == bytes(expectedHex).count, "added bytes 0")
        #expect(goldenFieldMismatches(row) == 0, "\(describeMap(row))")
    }

    @Test func unpack_typedRow_roundTrips() throws {
        // Arrange
        let (opener, waiter) = try sessionPair()
        let scheme = try positionTypedScheme()

        // Act
        let payload = try opener.pack(scheme, goldenRow())
        let row = try waiter.unpack(payload, scheme)

        // Assert
        #expect(row as? Position == goldenRow())
    }

    @Test func pack_waiter_sendsWithTheOtherKeyAndTheOpenerReads() throws {
        // Arrange
        let (opener, waiter) = try sessionPair()
        let scheme = try positionMapScheme()

        // Act
        let first = try waiter.pack(scheme, goldenMap())
        let second = try waiter.pack(scheme, goldenMap())
        let rows = try [first, second].map { try opener.unpackMap($0, scheme) }

        // Assert
        #expect(hex(first) == "f5114f9ae867fab4d63d4aaf8d" && hex(second) == "e93cf62d3737db666320249ea8")
        #expect(rows.map(goldenFieldMismatches) == [0, 0])
    }

    @Test func pack_secondPacket_usesTheNextPositionAndRoundTrips() throws {
        // Arrange
        let (opener, waiter) = try sessionPair()
        let scheme = try positionMapScheme()
        let first = try opener.pack(scheme, goldenMap())
        _ = try waiter.unpackMap(first, scheme)

        // Act
        let second = try opener.pack(scheme, goldenMap())
        let row = try waiter.unpackMap(second, scheme)

        // Assert
        #expect(hex(second) == "c6592af5394f86a5807033c298")
        #expect(goldenFieldMismatches(row) == 0)
    }

    @Test func unpack_aClientWithAnotherValue_doesNotReadTheRow() throws {
        // Arrange: one seed, two different 16-byte values.
        let opener = try PackSession.load(sessionSeed())
        _ = try opener.start(sessionNonce())
        let other = try PackSession.load(sessionSeed())
        try other.join([UInt8](repeating: 2, count: 16))
        let scheme = try positionMapScheme()
        let payload = try opener.pack(scheme, goldenMap())

        // Act
        let error = packbinError { try other.unpackMap(payload, scheme) }

        // Assert: TypeScript reads type number 0 there, as Swift does.
        #expect(error?.kind == .unknownType && error?.actual == 0)
    }

    @Test func loadAndJoin_badLengths_createNoSession() throws {
        // Arrange
        var created = 0
        let loaded = try PackSession.load(sessionSeed())

        // Act
        for n in [0, 31, 33] where (try? PackSession.load([UInt8](repeating: 0, count: n))) != nil {
            created += 1
        }
        for n in [0, 15, 17] {
            if (try? loaded.join([UInt8](repeating: 0, count: n))) != nil { created += 1 }
            if (try? loaded.start([UInt8](repeating: 0, count: n))) != nil { created += 1 }
        }
        let afterRefusals = try loaded.start(sessionNonce())

        // Assert
        #expect(created == 0)
        #expect(afterRefusals == sessionNonce(), "a refused value keeps the seed")
    }

    @Test func pack_beforeStartOrJoin_throwsAndGivesNoPayload() throws {
        // Arrange
        let loaded = try PackSession.load(sessionSeed())
        var payloads = 0

        // Act
        let error = packbinError {
            let out = try loaded.pack(try positionMapScheme(), goldenMap())
            payloads += 1
            return out
        }
        let typed = packbinError { try loaded.pack(try positionTypedScheme(), goldenRow()) }

        // Assert
        #expect(payloads == 0)
        #expect(error?.kind == .packError && error?.field == nil)
        #expect(error?.reason == "the session is not open: call start or join first")
        #expect(typed?.kind == .packError)
    }

    @Test func start_drawsSixteenRandomBytesTheWaiterJoins() throws {
        // Arrange
        let opener = try PackSession.load(sessionSeed())
        let again = try PackSession.load(sessionSeed())
        let waiter = try PackSession.load(sessionSeed())
        let scheme = try positionMapScheme()

        // Act
        let nonce = try opener.start()
        let other = try again.start()
        try waiter.join(nonce)
        let row = try waiter.unpackMap(try opener.pack(scheme, goldenMap()), scheme)

        // Assert
        #expect(nonce.count == 16 && other.count == 16 && nonce != other)
        #expect(goldenFieldMismatches(row) == 0)
    }

    @Test func start_withAValue_returnsThatValue() throws {
        // Arrange
        let opener = try PackSession.load(sessionSeed())
        var nonce = sessionNonce()

        // Act
        let out = try opener.start(nonce)
        nonce[0] = 0xff

        // Assert
        #expect(hex(out) == sessionNonceHex)
    }

    @Test func clearPack_besideASession_isUnchanged() throws {
        // Arrange
        let (opener, _) = try sessionPair()
        _ = try opener.pack(try positionMapScheme(), goldenMap())

        // Act
        let clear = try packHex(try positionMapScheme(), goldenMap())

        // Assert
        #expect(clear == expectedHex)
    }
}
