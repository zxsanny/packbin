import Packbin
import Testing

/// AC-1 (SW-5): pack has one output budget, `maxBytes`, checked before every write and naming the
/// member written, and charges `maxSlots` per round as unpack does, before the round's bytes
/// (TypeScript `pack-output-budget`, `reference_loop20_budget.md` AZ-2354 rows).
@Suite struct PackBudgetTests {
    /// list items of a nested row { u32 n; times(n) { utf8 s } }: 18 bytes a round and one slot, so 16
    /// items of 65 535 rounds (1 048 560 slots) reach the bytes budget first.
    private func elementTimes() throws -> Scheme {
        try Scheme(1, .list("items", .group("item", .u32(0, "n"), .times(1, count: 0, .utf8(1, "s")))))
    }

    private func sixteenItems() -> [String: Any] {
        ["items": [Any](repeating: ["n": 65_535, "s": String(repeating: "q", count: 16)] as [String: Any], count: 16)]
    }

    @Test func pack_loneStringUnderACappedTimes_isRefusedNamingItWithinASecond() throws {
        // Arrange
        let layout = try Scheme(1, .u32(0, "n"), .times(1, count: 0, .utf8(1, "s")))
        let row: [String: Any] = ["n": 65_535, "s": String(repeating: "q", count: 65_535)]

        // Act
        let limit = bound(1)
        let (error, seconds) = timed { packError(layout, row) }

        // Assert
        #expect(isPackRefusal(error, "s", bytesText("s", 16_777_989, 16_777_216)))
        #expect(error?.field == 1)
        expectWithinUnlessSanitized(seconds, limit)
    }

    @Test func pack_elementThatHoldsATimes_isRefusedAtTheDefaultBudgetNamingItsMember() throws {
        // Act
        let error = packError(try elementTimes(), sixteenItems())

        // Assert
        #expect(isPackRefusal(error, "s", bytesText("s", 16_777_233, 16_777_216)))
    }

    @Test func pack_elementThatHoldsATimesWithMaxBytesRaised_packsAndUnpacksToIt() throws {
        // Arrange
        let layout = try elementTimes().withLimits(maxBytes: 33_554_432)

        // Act
        let wire = try pack(layout, sixteenItems())
        let back = try unpackMap(wire, layout)

        // Assert
        #expect(wire.count == 18_874_147)
        #expect(hex(Array(wire.prefix(16))) == "011000ffff0000111071717171717171")
        #expect(hex(Array(wire.suffix(16))) == String(repeating: "71", count: 16))
        let items = back["items"] as? [Any] ?? []
        #expect(items.count == 16)
        #expect(items.allSatisfy { item in
            let row = item as? [String: Any]
            let strings = row?["s"] as? [Any?] ?? []
            return row?["n"] as? UInt32 == 65_535 && strings.count == 65_535
                && strings.allSatisfy { $0 as? String == String(repeating: "q", count: 16) }
        })
    }

    @Test func pack_packetOfExactlyMaxBytes_packsAndOneByteMoreIsRefused() throws {
        // Arrange
        let layout = try Scheme(1, .utf8(0, "s")).withLimits(maxBytes: 64)

        // Act
        let exact = try packHex(layout, ["s": String(repeating: "q", count: 61)])
        let error = packError(layout, ["s": String(repeating: "q", count: 62)])

        // Assert
        #expect(exact == "013e10" + String(repeating: "71", count: 61))
        #expect(isPackRefusal(error, "s", bytesText("s", 65, 64)))
    }

    @Test func pack_boundaryHoldsRoundByRound() throws {
        // Arrange
        let layout = try repeatK().withLimits(maxBytes: 64)

        // Act
        let exact = try packHex(layout, ["k": rounds(63, 7)])
        let error = packError(layout, ["k": rounds(64, 7)])

        // Assert
        #expect(exact == "01" + String(repeating: "07", count: 63))
        #expect(isPackRefusal(error, "k", bytesText("k", 65, 64)))
    }

    @Test func pack_bareScheme_writesTheTypeByteAtMaxBytes1() throws {
        // Act
        let wire = try packHex(try Scheme(1, [Field]()).withLimits(maxBytes: 1), [String: Any]())

        // Assert
        #expect(wire == "01")
    }

    /// The type byte counts; a split flag byte is named by its own name, a combined flags byte by the
    /// first name its members declare (through a times too), a list length by the list.
    @Test(arguments: [
        BudgetRow("u8", { try Scheme(1, .u8(0, "a")) }, max: 1, ["a": 1], field: 0, "a", 2),
        BudgetRow("split flag byte", {
            let fb = FlagByte("m")
            return try Scheme(1, .flagByte(fb), fb.bit(.u8(0, "c")))
        }, max: 1, ["c": 1], field: nil, "m", 2),
        BudgetRow("split flag byte with no name", {
            let fb = FlagByte("")
            return try Scheme(1, .flagByte(fb), fb.bit(.u8(0, "c")))
        }, max: 1, ["c": 1], field: nil, "c", 2),
        BudgetRow("combined flags", { try Scheme(1, .flags(0, .u8(0, "c"))) }, max: 1, ["c": 1], field: 0, "c", 2),
        BudgetRow("list length", { try Scheme(1, .list("xs", .u8(0, "v"))) }, max: 2, ["xs": [Any]()],
                  field: nil, "xs", 3),
        BudgetRow("flags byte named through a times", {
            try Scheme(1, .u8(0, "n"), .flags(1, .times(1, count: 0, .u8(1, "k"))))
        }, max: 2, ["n": 1, "k": 3], field: 1, "k", 3),
    ])
    func pack_aWritePastMaxBytes_isRefusedNamingItsMember(row: BudgetRow) throws {
        // Arrange
        let layout = try row.scheme().withLimits(maxBytes: row.max)

        // Act
        let error = packError(layout, row.row())

        // Assert
        #expect(isPackRefusal(error, row.member, bytesText(row.member, row.bytes, row.max)))
        #expect(error?.field == row.field)
    }

    @Test func pack_65MemberRoundCounted65535Times_isRefusedNamingTheMember() throws {
        // Arrange
        let (layout, row) = try wideRound()

        // Act
        let error = packError(layout, row)

        // Assert
        #expect(isPackRefusal(error, "m0", slotsText("m0", 1_048_580, 1_048_576)))
        #expect(error?.field == 1)
    }

    @Test func pack_slotsAreChargedBeforeTheRoundsBytes() throws {
        // Arrange
        let both = try timesK32().withLimits(maxSlots: 3, maxBytes: 8)

        // Act
        let atBoth = try packHex(both, ["n": 3, "k": 7])
        let slots = packError(both, ["n": 10, "k": 7])
        let bytesFirst = packError(try timesK32().withLimits(maxSlots: 3, maxBytes: 7), ["n": 10, "k": 7])

        // Assert
        #expect(atBoth == "0103000000070707")
        #expect(isPackRefusal(slots, "k", slotsText("k", 4, 3)))
        #expect(isPackRefusal(bytesFirst, "k", bytesText("k", 8, 7)))
    }

    @Test func pack_slotsOfTheRoundsInListItems_addUpAcrossTheItems() throws {
        // Arrange
        let layout = try Scheme(1, .list("items", .group("item", .u8(0, "n"), .times(1, count: 0, .u8(1, "k")))))
            .withLimits(maxSlots: 5)

        // Act
        let refused = packError(layout, ["items": [["n": 3, "k": 1], ["n": 3, "k": 2]]])
        let fits = try packHex(layout, ["items": [["n": 3, "k": 1], ["n": 2, "k": 2]]])

        // Assert
        #expect(isPackRefusal(refused, "k", slotsText("k", 6, 5)))
        #expect(fits == "01020003010101020202")
    }

    @Test func pack_nonEmptyGroupsOwnName_isNoSlot() throws {
        // Arrange
        let layout = try Scheme(1, .repeat(0, .u8(0, "a"), .group(1, "g", .u8(1, "b")))).withLimits(maxSlots: 5)

        // Act
        let two = try packHex(layout, ["a": [1, 2], "g": [["b": 3], ["b": 4]]])
        let error = packError(layout, ["a": [1, 2, 3], "g": [["b": 3], ["b": 4], ["b": 5]]])

        // Assert
        #expect(two == "0101030204")
        #expect(isPackRefusal(error, "a", slotsText("a", 6, 5)))
    }

    @Test func pack_roundCapFiresBeforeAnyRoundAndACountFieldBeforeTheRoundCap() throws {
        // Act
        let rounds = packError(try timesK32().withLimits(maxRounds: 5, maxSlots: 3, maxBytes: 8), ["n": 10, "k": 7])
        let count = packError(try timesK32().withLimits(maxRounds: 5, maxSlots: 3, maxBytes: 4), ["n": 10, "k": 7])

        // Assert
        #expect(isPackRefusal(rounds, "k", "k: the times count is 10, above the limit of 5 rounds"))
        #expect(isPackRefusal(count, "n", bytesText("n", 5, 4)))
    }
}

/// One scheme, row and `maxBytes` whose pack is refused naming `member` at `bytes` bytes.
struct BudgetRow: CustomTestStringConvertible, Sendable {
    let name: String
    let scheme: @Sendable () throws -> Scheme
    let max: Int
    let row: @Sendable () -> [String: Any]
    let field: Int?
    let member: String
    let bytes: Int
    var testDescription: String { name }

    init(_ name: String, _ scheme: @escaping @Sendable () throws -> Scheme, max: Int,
         _ row: @autoclosure @escaping @Sendable () -> [String: Any], field: Int?, _ member: String, _ bytes: Int) {
        self.name = name
        self.scheme = scheme
        self.max = max
        self.row = row
        self.field = field
        self.member = member
        self.bytes = bytes
    }
}
