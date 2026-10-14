import Packbin
import Testing

/// One repeat body whose round holds `width` names, with a row of `n` rounds; `atLimit` is the packet
/// of two rounds (packed at `maxSlots` 2 x width), `oneMore` of three (packed at 3 x width).
struct WidthShape: CustomTestStringConvertible, Sendable {
    let name: String
    let width: Int
    let body: @Sendable () -> [Field]
    let row: @Sendable (Int) -> [String: Any]
    let first: String
    let atLimit: String
    let oneMore: String
    let unpackLeft: Int
    var testDescription: String { name }
}

private let fb = FlagByte("m")

/// The ten shapes of TypeScript `round-slot-width` (`reference_loop21_slots.md` rows 1 to 10), with
/// Swift's map form of a group (a `[String: Any]` a round, Go-4 A); the unanchored TypeScript group is
/// Swift's nested row.
private let widthShapes: [WidthShape] = [
    WidthShape(name: "empty group under flags: a, g", width: 2,
               body: { [.u8(0, "a"), .flags(1, .group(1, "g"))] },
               row: { n in ["a": perRound(n) { $0 + 1 }, "g": perRound(n) { $0 % 2 == 0 ? true : nil }] },
               first: "a", atLimit: "0101010200", oneMore: "01010102000301", unpackLeft: 2),
    WidthShape(name: "duplicate leaf names in two when branches: m, k", width: 2,
               body: { [.u8(0, "m"), .when(1, .eq(0, 1), .u8(1, "k")), .when(2, .eq(0, 2), .u8(2, "k"))] },
               row: { n in ["m": perRound(n) { $0 % 2 + 1 }, "k": perRound(n) { 7 + $0 }] },
               first: "m", atLimit: "0101070208", oneMore: "01010702080109", unpackLeft: 2),
    WidthShape(name: "combined flags: on, v", width: 2,
               body: { [.flags(0, .bool(0, "on"), .u8(1, "v"))] },
               row: { n in ["on": rounds(n, true), "v": perRound(n) { 5 + $0 }] },
               first: "on", atLimit: "0103050306", oneMore: "01030503060307", unpackLeft: 2),
    WidthShape(name: "split bits with flag byte m: a, b", width: 2,
               body: { [.flagByte(fb), fb.bit(.u8(0, "a")), fb.bit(.u8(1, "b"))] },
               row: { n in ["a": perRound(n) { 1 + $0 }, "b": perRound(n) { 4 + $0 }] },
               first: "a", atLimit: "01030104030205", oneMore: "01030104030205030306", unpackLeft: 3),
    WidthShape(name: "when that is clear in every round: m, k", width: 2,
               body: { [.u8(0, "m"), .when(1, .eq(0, 1), .u8(1, "k"))] },
               row: { n in ["m": rounds(n, 0)] },
               first: "m", atLimit: "010000", oneMore: "01000000", unpackLeft: 1),
    WidthShape(name: "nested anchored groups: a, b, c", width: 3,
               body: { [.u8(0, "a"), .group(1, "g", .u8(1, "b"), .group(2, "h", .u8(2, "c")))] },
               row: { n in ["a": perRound(n) { 1 + $0 }, "g": perRound(n) { ["b": 4 + $0, "h": ["c": 7 + $0]] }] },
               first: "a", atLimit: "01010407020508", oneMore: "01010407020508030609", unpackLeft: 3),
    WidthShape(name: "anchored group: a, b", width: 2,
               body: { [.u8(0, "a"), .group(1, "g", .u8(1, "b"))] },
               row: { n in ["a": perRound(n) { 1 + $0 }, "g": perRound(n) { ["b": 4 + $0] }] },
               first: "a", atLimit: "0101040205", oneMore: "01010402050306", unpackLeft: 2),
    WidthShape(name: "nested row: a, b", width: 2,
               body: { [.u8(0, "a"), .group("g", .u8(0, "b"))] },
               row: { n in ["a": perRound(n) { 1 + $0 }, "g": perRound(n) { ["b": 4 + $0] }] },
               first: "a", atLimit: "0101040205", oneMore: "01010402050306", unpackLeft: 2),
    WidthShape(name: "u2 with three slots: a, p, q, r", width: 4,
               body: { [.u8(0, "a"), .u2(.slot(1, "p"), .slot(2, "q"), .slot(3, "r"))] },
               row: { n in ["a": perRound(n) { 1 + $0 }, "p": rounds(n, 1), "q": rounds(n, 2), "r": rounds(n, 3)] },
               first: "a", atLimit: "0101390239", oneMore: "01013902390339", unpackLeft: 2),
    WidthShape(name: "list and dict names: n, l, d", width: 3,
               body: { [.u8(0, "n"), .list("l", .u8(0, "e")), .dict("d", .u8(0, "e"))] },
               row: { n in
                   ["n": perRound(n) { 1 + $0 }, "l": perRound(n) { [$0, $0 + 1] }, "d": perRound(n) { ["k": $0] }]
               },
               first: "n", atLimit: "010102000001010001006b000202000102010001006b01",
               oneMore: "010102000001010001006b000202000102010001006b010302000203010001006b02", unpackLeft: 11),
    WidthShape(name: "bytes and sized names: n, b, s", width: 3,
               body: { [.u8(0, "n"), .bytes(1, "b", size: 2), .sized(2, "s", count: 0)] },
               row: { n in
                   ["n": rounds(n, 1), "b": perRound(n) { [UInt8](repeating: UInt8(truncatingIfNeeded: $0), count: 2) }, "s": rounds(n, [UInt8(9)])]
               },
               first: "n", atLimit: "010100000901010109", oneMore: "01010000090101010901020209", unpackLeft: 4),
]

/// AC-1 (SW-5): a round is charged the distinct names it can hold, on pack and unpack, before its bytes
/// (TypeScript `round-slot-width`; `reference_loop21_slots.md` section 1). The limit is two rounds'
/// worth, so two rounds pack exactly at `maxSlots` and a third would hold `maxSlots` + width.
@Suite struct SlotWidthTests {
    private func at(_ shape: WidthShape, _ maxSlots: Int) throws -> Scheme {
        try Scheme(1, .repeat(0, shape.body())).withLimits(maxSlots: maxSlots)
    }

    @Test(arguments: widthShapes)
    func packAndUnpack_roundsAtAndOnePastMaxSlots_areChargedTheNamesTheRoundHolds(shape: WidthShape) throws {
        // Arrange
        let limit = 2 * shape.width

        // Act
        let atLimit = try packHex(try at(shape, limit), shape.row(2))
        let refused = packError(try at(shape, limit), shape.row(3))
        let oneMore = try packHex(try at(shape, limit + shape.width), shape.row(3))
        let back = try unpackMap(bytes(atLimit), try at(shape, limit))
        let refusedUnpack = unpackError(bytes(oneMore), try at(shape, limit))

        // Assert
        #expect(atLimit == shape.atLimit && oneMore == shape.oneMore)
        #expect(isPackRefusal(refused, shape.first, slotsText(shape.first, limit + shape.width, limit)))
        #expect(try packHex(try at(shape, limit), back) == shape.atLimit)
        #expect(isRefusedRound(refusedUnpack, shape.first, left: shape.unpackLeft))
    }

    @Test func pack_timesChargesTheSameWidthAsRepeat() throws {
        // Arrange
        let layout = try Scheme(1, .u8(0, "n"),
                                .times(1, count: 0, .u8(1, "m"), .when(2, .eq(1, 1), .u8(2, "k")), .when(3, .eq(1, 2), .u8(3, "k"))))
            .withLimits(maxSlots: 4)

        // Act
        let two = try packHex(layout, ["n": 2, "m": [1, 2], "k": [7, 8]])
        let error = packError(layout, ["n": 3, "m": [1, 2, 1], "k": [7, 8, 9]])

        // Assert
        #expect(two == "010201070208")
        #expect(isPackRefusal(error, "m", slotsText("m", 6, 4)))
    }

    @Test func pack_twoRoundFieldsInOneCall_shareOneCounter() throws {
        // Arrange
        let shared = try Scheme(1, .u8(0, "n"), .times(1, count: 0, .u8(1, "a")), .repeat(2, .u8(2, "b")))
            .withLimits(maxSlots: 3)

        // Act
        let packs = try packHex(shared, ["n": 1, "a": [1], "b": [2, 3]])
        let error = packError(shared, ["n": 1, "a": [1], "b": [2, 3, 4]])

        // Assert
        #expect(packs == "0101010203")
        #expect(isPackRefusal(error, "b", slotsText("b", 4, 3)))
    }

    /// D3 (assessment 24, kept): a nested row in a round is a scope of its own and charges the width of
    /// its own members, apart from the names around it, even where it repeats one (as Go).
    @Test func packAndUnpack_nestedRowInARound_chargesItsOwnMembers() throws {
        // Arrange
        let nested = try Scheme(1, .repeat(0, .u8(0, "a"), .group("g", .u8(0, "a"), .u8(1, "y")))).withLimits(maxSlots: 6)
        let row = { (n: Int) -> [String: Any] in ["a": perRound(n) { $0 }, "g": perRound(n) { ["a": $0, "y": $0] }] }

        // Act
        let two = try pack(nested, row(2))
        let back = try unpackMap(two, nested)
        let error = packError(nested, row(3))
        let refusedUnpack = unpackError(bytes("01000000010101020202"), nested)

        // Assert
        #expect(canon(back["a"]) == "[UInt8(0),UInt8(1)]")
        #expect(isPackRefusal(error, "a", slotsText("a", 9, 6)))
        #expect(isRefusedRound(refusedUnpack, "a", left: 3))
    }

    /// A zero-width bytes names a slot a round, so `maxSlots` bounds the rounds of a body that writes
    /// nothing (`reference_loop21_slots.md` row 21).
    @Test func pack_zeroWidthBytesRound_isBoundedByMaxSlots() throws {
        // Arrange
        let layout = try Scheme(1, .u8(0, "n"), .times(1, count: 0, .bytes(1, "v", size: 0))).withLimits(maxSlots: 5)

        // Act
        let error = packError(layout, ["n": 10, "v": rounds(10, [UInt8]())])

        // Assert
        #expect(isPackRefusal(error, "v", slotsText("v", 6, 5)))
    }
}
