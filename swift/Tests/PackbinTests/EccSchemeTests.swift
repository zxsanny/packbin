import Packbin
import Testing

/// AZ-2686 AC-1, AC-2, AC-5 and AC-6 (EC-1 to EC-4, EC-8, EC-10, EC-11, EC-16): the scheme setting, the protected
/// bytes of the position fixture, the size limit, the session, a compact text and the dispatch rule.
@Suite struct EccSchemeTests {
    @Test func parity_defaultsToZeroAndWithLimitsKeepsTheCountItWasGiven() throws {
        // Arrange
        let plain = try positionMapScheme()

        // Act
        let guarded = try plain.withLimits(parity: 4)
        let kept = try guarded.withLimits(maxBytes: 100)
        let cleared = try guarded.withLimits(parity: 0)

        // Assert
        #expect(plain.parity == 0 && guarded.parity == 4 && kept.parity == 4 && cleared.parity == 0)
    }

    @Test func pack_withoutParity_isTheGoldenClearMessage() throws {
        // Act
        let packed = try pack(try positionScheme(parity: 0), goldenMap())

        // Assert
        #expect(hex(packed) == expectedHex)
        #expect(mismatchedBytes(packed, bytes(expectedHex)) == 0)
    }

    @Test(arguments: [(1, "ab"), (2, "16bd"), (4, "ca856682"), (8, "6d4f38479f3f2472"),
                      (16, "4ace66ecd5e4a28ffa28098279f5f19d")], ["map", "typed"])
    func pack_positionFixture_givesTheReportBytes(_ rowCase: (n: Int, parity: String), form: String) throws {
        // Act
        let packed = form == "map"
            ? try pack(try positionScheme(parity: rowCase.n), goldenMap())
            : try pack(try positionTypedScheme(parity: rowCase.n), goldenRow())

        // Assert
        #expect(hex(packed) == expectedHex + rowCase.parity)
    }

    @Test(arguments: [33, -1, 64])
    func withLimits_parityOutOfRange_isNotBuiltNamingTheCountAnd32(_ n: Int) throws {
        // Act
        let error = packbinError { try positionMapScheme().withLimits(parity: n) }

        // Assert
        #expect(error?.kind == .schemeError && error?.name == "parity")
        #expect(error?.reason.contains(String(n)) == true && error?.reason.contains("32") == true)
    }

    @Test func unpackRepair_row7_oneWrongByteWithTwoParityBytesIsRepaired() throws {
        // Act
        let got = try readPosition(bytes("4001000065cc1d00a3e111010016bd"), parity: 2, limit: 1)

        // Assert
        #expect(got.isGolden(repaired: 1))
    }

    @Test func unpackRepair_row8_twoWrongBytesWithFourParityBytesAreRepaired() throws {
        // Act
        let got = try readPosition(bytes("40015a0065cd1d00a322110100ca856682"), parity: 4, limit: 2)

        // Assert
        #expect(got.isGolden(repaired: 2))
    }

    @Test(arguments: [1, 0])
    func unpackRepair_rows9And10_twoWrongBytesBeyondTheLimitAreRefusedWithNoRow(limit: Int) throws {
        // Act
        let got = try readPosition(bytes("40015a0065cd1d00a322110100ca856682"), parity: 4, limit: limit)

        // Assert
        #expect(got.error?.kind == .uncorrectable && got.error?.field == nil && got.error?.name == "")
        #expect(got.rowCount == 0)
    }

    @Test func unpackRepair_row11_anIntactMessageReportsZeroRepaired() throws {
        // Act
        let got = try readPosition(bytes("4001000065cd1d00a3e1110100ca856682"), parity: 4, limit: 2)

        // Assert
        #expect(got.isGolden(repaired: 0))
    }

    @Test func unpack_aSchemeWithoutParity_keepsItsErrorsAndItsRows() throws {
        // Arrange
        let scheme = try positionScheme(parity: 0)

        // Act
        let row = try unpackMap(bytes(expectedHex), scheme)
        let repaired = try unpackMapRepair(bytes(expectedHex), limit: 0, scheme)
        let short = packbinError { try unpackMap(bytes("4001"), scheme) }
        let limit = packbinError { try unpackMapRepair(bytes(expectedHex), limit: 1, scheme) }

        // Assert
        #expect(goldenFieldMismatches(row) == 0 && repaired.repaired == 0)
        #expect(short?.kind == .short && limit?.kind == .schemeError)
    }

    @Test func pack_nThirtyTwo_222ClearBytesArePackedAnd223AreRefusedNamingBothNumbers() throws {
        // Arrange: the type byte and a run of bytes make the clear message
        let fits = try rawScheme(for: [UInt8](repeating: 7, count: 222), parity: 32)
        let over = try rawScheme(for: [UInt8](repeating: 7, count: 223), parity: 32)

        // Act
        let packed = try pack(fits, rawRow([UInt8](repeating: 7, count: 222)))
        let error = packbinError { try pack(over, rawRow([UInt8](repeating: 7, count: 223))) }

        // Assert
        #expect(packed.count == 254)
        #expect(error?.kind == .packError)
        #expect(error?.reason.contains("223") == true && error?.reason.contains("222") == true, "\(String(describing: error?.reason))")
    }

    @Test func pack_row13_251ClearBytesWithFourParityBytesAreRefusedNaming251AndTheLimit250() throws {
        // Arrange
        let clear = [UInt8](repeating: 1, count: 251)
        let scheme = try rawScheme(for: clear, parity: 4)

        // Act
        let error = packbinError { try pack(scheme, rawRow(clear)) }

        // Assert
        #expect(error?.kind == .packError)
        #expect(error?.reason.contains("251") == true && error?.reason.contains("250") == true)
    }
}

/// EC-11: a compact text field in a protected message is read after the repair.
@Suite struct EccTextTests {
    func noteScheme() throws -> Scheme {
        try Scheme(0x21, .u8(0, "id"), .utf8(1, "text"), .u16(2, "tail")).withLimits(parity: 4)
    }

    @Test(arguments: ["packbin ecc 0123456789", "Привіт, Світе! Як ти?"])
    func unpackRepair_anyTwoWrongBytes_returnTheOriginalRowAndTheOriginalString(_ text: String) throws {
        // Arrange
        let scheme = try noteScheme()
        let message = try pack(scheme, ["id": 7, "text": text, "tail": 4660])
        var random = SeededRandom(state: 11)
        var cases = 0
        var wrong = 0

        // Act
        for a in 0..<message.count {
            for b in (a + 1)..<message.count {
                for _ in 0..<2 {
                    let values = [UInt8.random(in: 1...255, using: &random), UInt8.random(in: 1...255, using: &random)]
                    let got = try unpackMapRepair(corrupt(message, [a, b], values), limit: 2, scheme)
                    cases += 1
                    let same = got.repaired == 2 && got.row["id"] as? UInt8 == 7 && got.row["tail"] as? UInt16 == 4660
                        && utf8Of(got.row["text"]) == Array(text.utf8)
                    if !same { wrong += 1 }
                }
            }
        }

        // Assert
        #expect(cases > 500)
        #expect(wrong == 0)
    }

    @Test func unpack_detectOnly_aWrongByteInTheStringPayloadIsRefusedWithNoRow() throws {
        // Arrange
        let scheme = try noteScheme()
        let message = try pack(scheme, ["id": 7, "text": "packbin ecc 0123456789", "tail": 4660])

        // Act
        let error = packbinError { try unpackMap(corrupt(message, [4], [0x10]), scheme) }

        // Assert
        #expect(error?.kind == .uncorrectable)
    }
}

/// EC-16: the schemes of one dispatch share a parity count; the message is repaired first, then dispatched.
@Suite struct EccDispatchTests {
    func schemes() throws -> [Scheme] {
        [try Scheme(0x11, .u16(0, "a"), .u8(1, "x")).withLimits(parity: 4),
         try Scheme(0x12, .u16(0, "b"), .u8(1, "x")).withLimits(parity: 4),
         try Scheme(0x13, .u16(0, "c"), .u8(1, "x")).withLimits(parity: 4)]
    }

    @Test func unpackRepair_thousandSeededCasesWithTheTypeByteAmongOneOrTwoWrongBytes_reachTheRightScheme() throws {
        // Arrange
        var random = SeededRandom(state: 16)
        let all = try schemes()
        let names = ["a", "b", "c"]
        var missed = 0

        // Act
        for i in 0..<1_000 {
            let which = i % 3
            let message = try pack(all[which], [names[which]: i, "x": which])
            let extra = pickWrong(&random, size: message.count - 1, count: i % 2).positions.map { $0 + 1 }
            let positions = [0] + extra
            let values = positions.map { _ in UInt8.random(in: 1...255, using: &random) }
            let got = try unpackMapRepair(corrupt(message, positions, values), limit: 2, all)
            let keys = got.row.keys.sorted()
            if got.repaired != positions.count || keys != ["x", names[which]].sorted()
                || got.row[names[which]] as? UInt16 != UInt16(i) || got.row["x"] as? UInt8 != UInt8(which) {
                missed += 1
            }
        }

        // Assert
        #expect(missed == 0)
    }

    @Test(arguments: [2, 0])
    func unpackRepair_schemesWithDifferentParity_areRefusedNamingBothCountsBeforeAnyByteIsRead(other: Int) throws {
        // Arrange
        let mixed = try schemes()[0..<1] + [try Scheme(0x21, .u8(0, "a")).withLimits(parity: other)]

        // Act
        let error = packbinError { try unpackMapRepair([], limit: 0, Array(mixed)) }
        let detect = packbinError { try unpackMap([], Array(mixed)) }

        // Assert
        #expect(error?.kind == .schemeError && detect?.kind == .schemeError)
        #expect(error?.reason.contains("4") == true && error?.reason.contains(String(other)) == true)
    }

    @Test func unpack_schemesWithoutParity_areUnchanged() throws {
        // Arrange
        let plain = try Scheme(0x31, .u8(0, "a"))

        // Act
        let row = try unpackMap(try pack(plain, ["a": 5]), plain)
        let repaired = try unpackMapRepair(try pack(plain, ["a": 5]), limit: 0, plain)

        // Assert
        #expect(row["a"] as? UInt8 == 5 && repaired.row["a"] as? UInt8 == 5 && repaired.repaired == 0)
    }
}

/// EC-10: the parity covers the padded bytes of a session payload.
@Suite struct EccSessionTests {
    @Test func pack_payloadIsThePaddedClearMessagePlusTheParityOfThePaddedBytes() throws {
        // Arrange
        let (opener, _) = try sessionPair()

        // Act
        let payload = try opener.pack(try positionScheme(parity: 4), goldenMap())
        // The payload is a protected message of its own whose "clear" bytes are the padded ones.
        let raw = try rawScheme(for: Array(payload.prefix(13)), parity: 4)
        let intact = try unpackMapRepair(payload, limit: 0, raw)

        // Assert
        #expect(payload.count == 17)
        #expect(hex(Array(payload.prefix(13))) == sessionCipherHex)
        #expect(intact.repaired == 0 && (intact.row["b"] as? [UInt8]).map(hex) == String(sessionCipherHex.dropFirst(2)))
    }

    @Test func pack_aSchemeWithZeroParity_keepsThePayloadAsLongAsTheClearMessage() throws {
        // Arrange
        let (opener, waiter) = try sessionPair()
        let scheme = try positionScheme(parity: 0)

        // Act
        let payload = try opener.pack(scheme, goldenMap())
        let got = try waiter.unpackMapRepair(payload, limit: 0, scheme)

        // Assert
        #expect(hex(payload) == sessionCipherHex)
        #expect(got.repaired == 0 && goldenFieldMismatches(got.row) == 0)
    }

    @Test func unpackRepair_twoWrongBytesAreRepairedBeforeThePadIsRemovedAndTheRowIsRecovered() throws {
        // Arrange
        let (opener, waiter) = try sessionPair()
        let scheme = try positionTypedScheme(parity: 4)
        let payload = try opener.pack(scheme, goldenRow())

        // Act
        let got = try waiter.unpackRepair(corrupt(payload, [2, 15], [0x80, 0x21]), limit: 2, scheme)

        // Assert
        #expect(got.row as? Position == goldenRow() && got.repaired == 2)
    }

    @Test func unpackRepair_threeWrongBytesWithLimitTwoAreRefusedThenTheNextPayloadIsRead() throws {
        // Arrange
        let (opener, waiter) = try sessionPair()
        let scheme = try positionScheme(parity: 4)
        let first = try opener.pack(scheme, goldenMap())
        let second = try opener.pack(scheme, goldenMap().merging(["sid": 9]) { $1 })

        // Act
        let refused = packbinError { try waiter.unpackMapRepair(corrupt(first, [1, 5, 11], [1, 2, 3]), limit: 2, scheme) }
        let next = try waiter.unpackMapRepair(second, limit: 2, scheme)

        // Assert
        #expect(refused?.kind == .uncorrectable)
        #expect(next.repaired == 0 && next.row["sid"] as? UInt16 == 9)
    }

    @Test func unpackRepair_aLimitAboveHalfTheParity_throwsBeforeThePositionIsSpent() throws {
        // Arrange
        let (opener, waiter) = try sessionPair()
        let scheme = try positionScheme(parity: 4)
        let payload = try opener.pack(scheme, goldenMap())

        // Act
        let error = packbinError { try waiter.unpackMapRepair(payload, limit: 3, scheme) }
        let after = try waiter.unpackMapRepair(payload, limit: 2, scheme)

        // Assert
        #expect(error?.kind == .schemeError)
        #expect(after.repaired == 0 && goldenFieldMismatches(after.row) == 0)
    }

    @Test func pack_aMessageAboveTheParityLimit_isRefusedAndTheSendPositionDoesNotMove() throws {
        // Arrange
        let (opener, _) = try sessionPair()
        let clear = [UInt8](repeating: 0, count: 223)
        let big = try rawScheme(for: clear, parity: 32)

        // Act
        let error = packbinError { try opener.pack(big, rawRow(clear)) }
        let first = try opener.pack(try positionScheme(parity: 0), goldenMap())

        // Assert
        #expect(error?.kind == .packError)
        #expect(hex(first) == sessionCipherHex)
    }

    @Test func unpack_theProtectedPayloadReadByAnUnprotectedScheme_isRefusedNotTrapped() throws {
        // Arrange
        let (opener, waiter) = try sessionPair()
        let payload = try opener.pack(try positionScheme(parity: 4), goldenMap())

        // Act
        let error = packbinError { try waiter.unpackMap(payload, try positionScheme(parity: 0)) }

        // Assert
        #expect(error?.kind == .trailing)
    }
}
