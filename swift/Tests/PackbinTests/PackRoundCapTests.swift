import Packbin
import Testing

/// AC-1 (SW-5): pack refuses a repeat list or a times count above `maxRounds` before any round, as
/// unpack refuses the round (TypeScript `pack-repeat-round-cap`, `pack-round-count-cap`,
/// `reference_loop20_budget.md` AZ-2355 rows).
@Suite struct PackRoundCapTests {
    @Test func pack_repeatOfMaxRoundsPlusOneEntries_isRefusedNamingTheMember() throws {
        // Act
        let error = packError(try repeatK(), ["k": rounds(65_536, 7)])

        // Assert
        #expect(isPackRefusal(error, "k", "k: the repeat count is 65536, above the limit of 65535 rounds"))
        #expect(error?.field == 0)
    }

    @Test func pack_repeatCap_namesTheMemberWhoseListPassesTheLimit() throws {
        // Arrange
        let layout = try Scheme(1, .repeat(0, .u8(0, "a"), .u8(1, "b"))).withLimits(maxRounds: 3)

        // Act
        let error = packError(layout, ["a": 1, "b": [1, 2, 3, 4]])

        // Assert
        #expect(isPackRefusal(error, "b", "b: the repeat count is 4, above the limit of 3 rounds"))
        #expect(error?.field == 1)
    }

    @Test(arguments: [
        LimitRow("flags", { try Scheme(1, .flags(0, .repeat(0, .u8(0, "k")))) }, { ["k": [1, 2, 3, 4]] }),
        LimitRow("split bit", {
            let fb = FlagByte("m")
            return try Scheme(1, .flagByte(fb), fb.bit(.repeat(0, .u8(0, "k"))))
        }, { ["k": [1, 2, 3, 4]] }),
        LimitRow("when", { try Scheme(1, .u8(0, "m"), .when(1, .eq(0, 1), .repeat(1, .u8(1, "k")))) },
                { ["m": 1, "k": [1, 2, 3, 4]] }),
        LimitRow("list element", { try Scheme(1, .list("items", .group("item", .repeat(0, .u8(0, "k"))))) },
                { ["items": [["k": [1, 2, 3, 4]]]] }),
    ])
    func pack_repeatCap_holdsInFlagsASplitBitAWhenAndAListElement(row: LimitRow) throws {
        // Arrange
        let layout = try row.scheme().withLimits(maxRounds: 3)

        // Act
        let error = packError(layout, row.row())

        // Assert
        #expect(isPackRefusal(error, "k", "k: the repeat count is 4, above the limit of 3 rounds"))
    }

    @Test func pack_repeatOfMaxRoundsEntries_packsAndRoundTrips() throws {
        // Arrange
        let layout = try repeatK()

        // Act
        let wire = try pack(layout, ["k": rounds(65_535, 7)])
        let again = try pack(layout, try unpackMap(wire, layout))

        // Assert
        #expect(wire.count == 65_536 && again == wire)
    }

    @Test func pack_repeatWithMaxRoundsRaised_packsMoreEntries() throws {
        // Act
        let wire = try pack(try repeatK().withLimits(maxRounds: 70_000), ["k": rounds(70_000, 7)])

        // Assert
        #expect(wire.count == 70_001)
    }

    @Test func pack_repeatUnderALoweredLimit_refusesOneMoreAndKeepsTheBytesAtTheLimit() throws {
        // Arrange
        let layout = try repeatK().withLimits(maxRounds: 3)

        // Act
        let error = packError(layout, ["k": [1, 2, 3, 4]])
        let wire = try packHex(layout, ["k": [1, 2, 3]])

        // Assert
        #expect(isPackRefusal(error, "k", "k: the repeat count is 4, above the limit of 3 rounds"))
        #expect(wire == "01010203")
    }

    @Test func pack_typedRepeatWithMoreElementsThanMaxRounds_isRefused() throws {
        // Arrange
        let layout = try samplesScheme().withLimits(maxRounds: 1)
        let row = Samples(rounds: [Sample(k: 1), Sample(k: 2)])

        // Act
        let error = packbinError { try pack(layout, row) }

        // Assert
        #expect(isPackRefusal(error, "k", "k: the repeat count is 2, above the limit of 1 rounds"))
    }

    @Test func pack_timesCountOnePastTheLimitWithALoneScalar_isRefusedNamingTheFirstBodyMember() throws {
        // Act
        let error = packError(try timesK32(), ["n": 65_536, "k": 7])

        // Assert
        #expect(isPackRefusal(error, "k", "k: the times count is 65536, above the limit of 65535 rounds"))
        #expect(error?.field == 1)
    }

    @Test func pack_fourBillionTimesCountWithALoneScalar_isRefusedAtOnce() throws {
        // Arrange
        let layout = try timesK32()

        // Act
        let (error, seconds) = timed { packError(layout, ["n": 4_000_000_000, "k": 7]) }

        // Assert
        #expect(isPackRefusal(error, "k", "k: the times count is 4000000000, above the limit of 65535 rounds"))
        #expect(withinOneSecond(seconds), "took \(seconds) s")
    }

    @Test func pack_timesCountOverTheLimitWithNoValue_isRefusedByTheLimit() throws {
        // Act
        let error = packError(try timesK32(), ["n": 70_000])

        // Assert
        #expect(isPackRefusal(error, "k", "k: the times count is 70000, above the limit of 65535 rounds"))
    }

    @Test func pack_timesUnderALoweredLimit_refusesOneMoreAndKeepsTheBytesAtTheLimit() throws {
        // Arrange
        let layout = try timesK32().withLimits(maxRounds: 3)

        // Act
        let error = packError(layout, ["n": 4, "k": 7])
        let wire = try packHex(layout, ["n": 3, "k": 7])

        // Assert
        #expect(isPackRefusal(error, "k", "k: the times count is 4, above the limit of 3 rounds"))
        #expect(wire == "0103000000070707")
    }

    @Test func pack_timesThatIsAMemberOfFlags_isCappedToo() throws {
        // Arrange
        let layout = try Scheme(1, .u32(0, "n"), .flags(1, .times(1, count: 0, .u8(1, "k")), .u16(2, "h")))

        // Act
        let error = packError(layout, ["n": 65_536, "k": 7, "h": 1])

        // Assert
        #expect(isPackRefusal(error, "k", "k: the times count is 65536, above the limit of 65535 rounds"))
    }

    @Test func pack_timesCountAtTheLimit_packsAndRoundTrips() throws {
        // Arrange
        let layout = try timesK32()

        // Act
        let wire = try pack(layout, ["n": 65_535, "k": 7])
        let back = try unpackMap(wire, layout)

        // Assert
        #expect(wire.count == 5 + 65_535)
        #expect((back["k"] as? [Any?])?.count == 65_535)
        #expect(try pack(layout, back) == wire)
    }

    @Test func pack_timesWithMaxRoundsRaised_packsALargerCountAndTheBaseStillRefusesIt() throws {
        // Arrange
        let base = try timesK32()
        let raised = try base.withLimits(maxRounds: 70_000)

        // Act
        let wire = try pack(raised, ["n": 70_000, "k": 7])
        let copy = try pack(raised, ["n": 66_000, "k": 7])
        let error = packError(base, ["n": 66_000, "k": 7])

        // Assert
        #expect(wire.count == 5 + 70_000 && copy.count == 5 + 66_000)
        #expect((try unpackMap(wire, raised)["k"] as? [Any?])?.count == 70_000)
        #expect(error?.kind == .packError)
    }

    /// A count above `Int.max` is refused by the count rule before the round cap, with TypeScript's
    /// text (its count rule stops at 2^53).
    @Test func pack_timesCountAboveIntMax_isRefusedByTheCountRule() throws {
        // Arrange
        let layout = try Scheme(1, .u64(0, "n"), .times(1, count: 0, .u8(1, "k")))

        // Act
        let error = packError(layout, ["n": UInt64.max, "k": 7])

        // Assert
        #expect(isPackRefusal(error, "k", "times: item count 18446744073709551615"))
    }
}
