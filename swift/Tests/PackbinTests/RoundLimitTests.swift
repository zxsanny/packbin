import Packbin
import Testing

/// AC-1 (SW-5, S6): unpack refuses a round past `maxRounds`, or one that would take the slots of the
/// call past `maxSlots`, when the round would start, before its bytes are read: kind `.tooMany`
/// (hostile `too_many`), `needed` 0, `left` the bytes left there (TypeScript `round-limits`, whose
/// interim shape is a short packet with `needed` 0; Go `TooMany`). A huge count that never reaches the
/// limit keeps its short read.
@Suite struct RoundLimitTests {
    @Test func unpack_repeatOfMaxRoundsOneByteRounds_isReadAtTheDefaultLimit() throws {
        // Act
        let row = try unpackMap(roundsPacket(Scheme.defaultMaxRounds), try repeatK())

        // Assert
        #expect((row["k"] as? [Any?])?.count == 65_535)
    }

    @Test func unpack_repeatOfMaxRoundsPlusOneRounds_isRefusedAtTheDefaultLimit() throws {
        // Act
        let error = unpackError(roundsPacket(Scheme.defaultMaxRounds + 1), try repeatK())

        // Assert
        #expect(isRefusedRound(error, "k", left: 1))
        #expect(error?.field == 0 && error?.reason == "round 65536 is above the limit of 65535 rounds")
    }

    @Test func unpack_repeatUnderALoweredLimit_readsExactlyMaxRoundsAndRefusesOneMore() throws {
        // Arrange
        let layout = try repeatK().withLimits(maxRounds: 3)

        // Act
        let row = try unpackMap(bytes("01aabbcc"), layout)
        let error = unpackError(bytes("01aabbccdd"), layout)

        // Assert
        #expect(canon(row["k"]) == "[UInt8(170),UInt8(187),UInt8(204)]")
        #expect(isRefusedRound(error, "k", left: 1))
    }

    @Test(arguments: [("0104090909" + "09", 1), ("0104090909", 0)])
    func unpack_timesRoundPastALoweredLimit_isRefusedBeforeItsBytes(packet: String, left: Int) throws {
        // Arrange
        let layout = try timesK().withLimits(maxRounds: 3)

        // Act
        let error = unpackError(bytes(packet), layout)

        // Assert
        #expect(isRefusedRound(error, "k", left: left))
    }

    @Test func unpack_timesCountEqualToALoweredLimit_isRead() throws {
        // Act
        let row = try unpackMap(bytes("0103090909"), try timesK().withLimits(maxRounds: 3))

        // Assert
        #expect(canon(row["n"]) == "UInt8(3)" && canon(row["k"]) == "[UInt8(9),UInt8(9),UInt8(9)]")
    }

    @Test(arguments: ["01ff09", "01030909"])
    func unpack_timesCountThatNeverReachesTheLimit_keepsItsShortRead(packet: String) throws {
        // Act
        let error = unpackError(bytes(packet), try timesK().withLimits(maxRounds: 3))

        // Assert
        #expect(error?.kind == .short && error?.name == "k" && error?.needed == 1 && error?.left == 0)
    }

    @Test func unpack_timesCountOfMaxRounds_isReadAtTheDefaultLimit() throws {
        // Act
        let row = try unpackMap(countedPacket(65_535, 65_535), try timesK32())

        // Assert
        #expect((row["k"] as? [Any?])?.count == 65_535)
    }

    @Test(arguments: [(UInt32(65_536), 65_536, 1), (UInt32.max, 65_536, 1), (UInt32.max, 65_535, 0)])
    func unpack_timesPastTheDefaultLimit_isRefusedWhenRound65536Starts(count: UInt32, present: Int, left: Int) throws {
        // Act
        let error = unpackError(countedPacket(count, present), try timesK32())

        // Assert
        #expect(isRefusedRound(error, "k", left: left))
    }

    @Test func unpack_timesCountOfUInt32MaxWithOneRound_keepsItsShortRead() throws {
        // Act
        let error = unpackError(bytes("01ffffffff00"), try timesK32())

        // Assert
        #expect(error?.kind == .short && error?.name == "k" && error?.needed == 1 && error?.left == 0)
    }

    private func slotLayout() throws -> Scheme {
        try Scheme(1, .repeat(0, .u8(0, "k"), .when(1, .eq(0, 1), .u8(1, "a"), .u8(2, "b")))).withLimits(maxSlots: 6)
    }

    @Test func unpack_roundsWhoseSlotsEqualMaxSlots_areRead() throws {
        // Act
        let row = try unpackMap(bytes("010000"), try slotLayout())

        // Assert
        #expect(canon(row) == "{a=[nil,nil],b=[nil,nil],k=[UInt8(0),UInt8(0)]}")
    }

    @Test(arguments: [("01000000", 1), ("0100000000", 2)])
    func unpack_theRoundThatWouldPassMaxSlots_isRefusedWithEveryByteStillUnread(packet: String, left: Int) throws {
        // Act
        let error = unpackError(bytes(packet), try slotLayout())

        // Assert
        #expect(isRefusedRound(error, "k", left: left))
        #expect(error?.reason == "the rounds would hold 9 slots, above the limit of 6 slots")
    }

    @Test func unpack_everyRoundFieldOfOneCall_sharesOneSlotCounter() throws {
        // Arrange
        let base = try Scheme(1, .u8(0, "n"), .times(1, count: 0, .u8(1, "k")), .times(2, count: 0, .u8(2, "v")))
        let packet = bytes("0102aabbccdd")

        // Act
        let fits = try unpackMap(packet, try base.withLimits(maxRounds: 3, maxSlots: 4))
        let over = unpackError(packet, try base.withLimits(maxRounds: 3, maxSlots: 3))

        // Assert
        #expect(canon(fits["k"]) == "[UInt8(170),UInt8(187)]" && canon(fits["v"]) == "[UInt8(204),UInt8(221)]")
        #expect(isRefusedRound(over, "v", left: 1))
    }

    /// A round of 37 names (k and 36 behind a when) at one byte a round: round 28 340 would hold
    /// 1 048 580 slots.
    @Test(.enabled(if: !threadSanitized, "one thread, no shared state: the thread sanitizer adds nothing and runs it about ten times slower"))
    func unpack_mebibyteOfOneByteRoundsWith37Names_isRefusedAtTheSlotLimitWithinASecond() throws {
        // Arrange
        let members = (0..<36).map { i in i % 2 == 0 ? Field.u8(1 + i, "f\(i)") : Field.u16(1 + i, "f\(i)") }
        let layout = try Scheme(1, .repeat(0, .u8(0, "k"), .when(1, .eq(0, 1), members)))
        var packet = [UInt8](repeating: 0, count: 1 + 1_048_576)
        packet[0] = 1

        // Act
        let limit = bound(1)
        let (error, seconds) = timed { unpackError(packet, layout) }

        // Assert
        #expect(isRefusedRound(error, "k", left: 1_020_237))
        expectWithin(seconds, limit)
    }

    /// The hostile `limit` cases (fixtures/hostile/cases.txt): `maxRounds` 3, `too_many` with `needed`
    /// 0 and `left` 1; AZ-2519 runs them from the file.
    @Test(arguments: [("repeat_rounds_over_limit", "0111223344"), ("times_rounds_over_limit", "010411223344")])
    func unpack_hostileLimitCases_areRefusedAsTooManyWithNeeded0(id: String, packet: String) throws {
        // Arrange
        let scheme = id.hasPrefix("repeat") ? try Scheme(1, .repeat(0, .u8(0, "v")))
            : try Scheme(1, .u8(0, "n"), .times(1, count: 0, .u8(1, "v")))

        // Act
        let error = unpackError(bytes(packet), try scheme.withLimits(maxRounds: 3))

        // Assert
        #expect(error?.kind.rawValue == "too_many" && error?.needed == 0 && error?.left == 1)
    }
}
