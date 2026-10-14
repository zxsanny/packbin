import Packbin
import Testing

@Sendable func optionalU8() throws -> Scheme { try Scheme(1, .repeat(0, .u8(0, "w"), .flags(1, .u8(1, "v")))) }
@Sendable func timesOne() throws -> Scheme { try Scheme(1, .u8(0, "a"), .times(1, count: 0, .u8(1, "x"))) }
@Sendable func timesTwo() throws -> Scheme {
    try Scheme(1, .u8(0, "a"), .times(1, count: 0, .u8(1, "x"), .u8(2, "y")))
}
@Sendable func timesPlain() throws -> Scheme { try Scheme(1, .u8(0, "n"), .times(1, count: 0, .u8(1, "pt"))) }
@Sendable func timesCombined() throws -> Scheme {
    try Scheme(1, .u8(0, "n"), .flags(1, .times(1, count: 0, .u8(1, "pt")), .u16(2, "heading")))
}

/// AC-2 (SW-3), TypeScript `repeat-short-optional` (U3), `times-longer-list` and
/// `times-count-zero-with-values`: the list rules of rounds. A group is one name of the round, so its
/// short list is named by the group (TypeScript names its member, given flat).
@Suite struct RoundListTests {
    static let shortOptional: [RoundRefusal] = [
        RoundRefusal("U3 row", optionalU8, field: 1, "v", "v: 1 items, repeat count 2; give one entry per round") {
            ["w": [1, 2], "v": [5]]
        },
        RoundRefusal("three rounds two entries", optionalU8, field: 1, "v", "2 items, repeat count 3") {
            ["w": [1, 2, 3], "v": [5, nil] as [Int?]]
        },
        RoundRefusal("bool", { try Scheme(1, .repeat(0, .u8(0, "w"), .flags(1, .bool(1, "on")))) }, field: 1, "on",
                     "1 items, repeat count 2") { ["w": [1, 2], "on": [true]] },
        RoundRefusal("split bit", {
            let fb = FlagByte("m")
            return try Scheme(1, .repeat(0, .u8(0, "w"), .flagByte(fb), fb.bit(.u8(1, "v"))))
        }, field: 1, "v", "1 items, repeat count 2") { ["w": [1, 2], "v": [5]] },
        RoundRefusal("group under flags", { try Scheme(1, .repeat(0, .u8(0, "w"), .flags(1, .group(1, "g", .u8(1, "v"))))) },
                     field: 1, "g", "1 items, repeat count 2") { ["w": [1, 2], "g": [["v": 5]]] },
        RoundRefusal("group member given flat (Go-4)",
                     { try Scheme(1, .repeat(0, .u8(0, "w"), .flags(1, .group(1, "g", .u8(1, "v"))))) },
                     field: 1, "v", "member of group g") { ["w": [1, 2], "v": [5]] },
        RoundRefusal("u2 slot", { try Scheme(1, .repeat(0, .u8(0, "w"), .flags(1, .u2(.slot(1, "p"), .slot(2, "q"))))) },
                     field: 1, "p", "1 items, repeat count 2") { ["w": [1, 2], "p": [1], "q": [2, 3]] },
        RoundRefusal("when under flags", { try Scheme(1, .repeat(0, .u8(0, "w"), .flags(1, .when(1, .eq(0, 1), .u8(1, "v"))))) },
                     field: 1, "v", "1 items, repeat count 2") { ["w": [1, 1], "v": [5]] },
        RoundRefusal("combined flags names the short member",
                     { try Scheme(1, .repeat(0, .flags(0, .u8(0, "a"), .u8(1, "b")))) }, field: 0, "a",
                     "1 items, repeat count 2") { ["a": [1], "b": [5, 6]] },
        RoundRefusal("a group that holds flags is optional too",
                     { try Scheme(1, .repeat(0, .u8(0, "w"), .group(1, "g", .flags(1, .u8(1, "v"))))) },
                     field: 1, "g", "1 items, repeat count 2") { ["w": [1, 2], "g": [["v": 5]]] },
        RoundRefusal("required member keeps its own error", { try Scheme(1, .repeat(0, .u8(0, "a"), .u8(1, "b"))) },
                     field: 1, "b", "missing b") { ["a": [1, 2], "b": [3]] },
        RoundRefusal("short required beside optional is missing", optionalU8, field: 0, "w", "missing w") {
            ["w": [1], "v": [5, 6]]
        },
    ]

    @Test(arguments: shortOptional)
    func pack_repeatShortOptionalList_isRefusedNamingTheMember(_ c: RoundRefusal) throws {
        try expectRefused(c)
    }

    static let shortOptionalPacks: [PackRow] = [
        PackRow("full list with nil", optionalU8, "010101050200") { ["w": [1, 2], "v": [5, nil] as [Int?]] },
        PackRow("full list with a boxed nil", optionalU8, "010101050200") {
            ["w": [1, 2], "v": [5, Int?.none as Any] as [Any]]
        },
        PackRow("both entries", optionalU8, "01010105020106") { ["w": [1, 2], "v": [5, 6]] },
        PackRow("no entry", optionalU8, "0101000200") { ["w": [1, 2]] },
        PackRow("empty list", optionalU8, "0101000200") { ["w": [1, 2], "v": [Int]()] },
        PackRow("lone value", optionalU8, "01010105020105") { ["w": [1, 2], "v": 5] },
        PackRow("bool full list", { try Scheme(1, .repeat(0, .u8(0, "w"), .flags(1, .bool(1, "on")))) }, "0101010200") {
            ["w": [1, 2], "on": [true, nil] as [Bool?]]
        },
        PackRow("times keeps a short list under flags",
                { try Scheme(1, .u8(0, "c"), .times(1, count: 0, .flags(1, .u8(1, "v")))) }, "0102010500") {
            ["c": 2, "v": [5]]
        },
        PackRow("a when outside flags keeps its short list", whenRepeat, "01010902") { ["k": [1, 2], "v": [9]] },
    ]

    @Test(arguments: shortOptionalPacks)
    func pack_repeatRowTheShortRuleDoesNotTouch_keepsItsBytes(_ c: PackRow) throws {
        try expectPacks(c)
    }

    static let longer: [RoundRefusal] = [
        RoundRefusal("longer list", timesOne, field: 1, "x", "x: 3 items, times count 2") { ["a": 2, "x": [1, 2, 3]] },
        RoundRefusal("count zero, one item", timesOne, field: 1, "x", "x: 1 items, times count 0") { ["a": 0, "x": [1]] },
        RoundRefusal("a second member", timesTwo, field: 2, "y", "y: 3 items, times count 2") {
            ["a": 2, "x": [1, 2], "y": [3, 4, 5]]
        },
        RoundRefusal("a member under when",
                     { try Scheme(1, .u8(0, "a"), .times(1, count: 0, .u8(1, "k"), .when(2, .eq(1, 1), .u8(2, "v")))) },
                     field: 2, "v", "v: 2 items, times count 1") { ["a": 1, "k": [1], "v": [7, 8]] },
        RoundRefusal("under flags", { try Scheme(1, .u8(0, "a"), .times(1, count: 0, .flags(1, .u8(1, "p"), .u8(2, "q")))) },
                     field: 2, "q", "q: 2 items, times count 1") { ["a": 1, "p": [1], "q": [2, 3]] },
        RoundRefusal("a group", { try Scheme(1, .u8(0, "a"), .times(1, count: 0, .group(1, "g", .u8(1, "p")))) },
                     field: 1, "g", "g: 2 items, times count 1") { ["a": 1, "g": [["p": 1], ["p": 2]]] },
        RoundRefusal("a group member given flat (Go-4)",
                     { try Scheme(1, .u8(0, "a"), .times(1, count: 0, .group(1, "g", .u8(1, "p")))) },
                     field: 1, "p", "member of group g") { ["a": 1, "p": [1, 2]] },
        RoundRefusal("shorter list is missing", timesOne, field: 1, "x", "missing x") { ["a": 2, "x": [1]] },
        RoundRefusal("count 0 with values, outside flags", timesPlain, field: 1, "pt", "pt: 1 items, times count 0") {
            ["n": 0, "pt": [5], "heading": 90]
        },
        RoundRefusal("count 0 with values, inside flags", timesCombined, field: 1, "pt", "pt: 1 items, times count 0") {
            ["n": 0, "pt": [5], "heading": 90]
        },
        RoundRefusal("count 0 names the second member",
                     { try Scheme(1, .u8(0, "n"), .times(1, count: 0, .u8(1, "pt"), .u8(2, "pu"))) },
                     field: 2, "pu", "pu: 1 items, times count 0") { ["n": 0, "pu": [6]] },
    ]

    @Test(arguments: longer)
    func pack_timesListLongerThanTheCount_isRefusedNamingItemsAndCount(_ c: RoundRefusal) throws {
        try expectRefused(c)
    }

    static let timesPacks: [PackRow] = [
        PackRow("count 0, empty list", timesOne, "0100") { ["a": 0, "x": [Int]()] },
        PackRow("count 0, absent", timesOne, "0100") { ["a": 0] },
        PackRow("exact list", timesOne, "01020102") { ["a": 2, "x": [1, 2]] },
        PackRow("lone scalar", timesOne, "01020505") { ["a": 2, "x": 5] },
        PackRow("lone scalar, one round", timesOne, "010105") { ["a": 1, "x": 5] },
        PackRow("two members", timesTwo, "010201030204") { ["a": 2, "x": [1, 2], "y": [3, 4]] },
        PackRow("short list under when",
                { try Scheme(1, .u8(0, "a"), .times(1, count: 0, .u8(1, "k"), .when(2, .eq(1, 1), .u8(2, "v")))) },
                "0102010700") { ["a": 2, "k": [1, 0], "v": [7]] },
        PackRow("count 0 without values, outside flags", timesPlain, "0100") { ["n": 0, "heading": 90] },
        PackRow("count 0 without values, inside flags", timesCombined, "0100025a00") { ["n": 0, "heading": 90] },
        PackRow("count 0 with an empty list, inside flags", timesCombined, "0100025a00") {
            ["n": 0, "pt": [Int](), "heading": 90]
        },
        PackRow("count 0 with a lone scalar", timesPlain, "0100") { ["n": 0, "pt": 5] },
    ]

    @Test(arguments: timesPacks)
    func pack_timesRowTheLengthRulesAccept_givesTypeScriptHex(_ c: PackRow) throws {
        try expectPacks(c)
    }

    @Test func packAndUnpack_timesRow_repacksTheSameBytes() throws {
        // Arrange
        let scheme = try timesOne()

        // Act
        let again = try packHex(scheme, try unpackMap(bytes("01020102"), scheme))

        // Assert
        #expect(again == "01020102")
    }

    @Test func pack_loneBufferForARoundName_isRefusedNamingIt() throws {
        // Arrange
        let sized = try Scheme(1, .u8(0, "n"), .times(1, count: 0, .u8(1, "c"), .sized(2, "p", count: 1)))
        let grouped = try Scheme(1, .u8(0, "n"), .times(1, count: 0, .group(1, "g", .bytes(1, "b", size: 1))))
        let bits = try Scheme(1, .repeat(0, .u8(0, "c"), .bits(1, "s", count: 0)))

        // Act
        let lone = packbinError { try pack(sized, ["n": 1, "c": 1, "p": [UInt8(7)]]) }
        let inGroup = packbinError { try pack(grouped, ["n": 2, "g": ["b": [UInt8(7)]]]) }
        let loneBits = packbinError { try pack(bits, ["c": 2, "s": [UInt8(1), 0]]) }
        let listed = try packHex(sized, ["n": 1, "c": 1, "p": [[UInt8(7)]]])

        // Assert
        for e in [lone, inGroup, loneBits] {
            #expect(e?.kind == .packError && e?.reason.contains("a byte buffer in a repeat or times round") == true)
        }
        #expect(lone?.field == 2 && inGroup?.name == "b" && loneBits?.name == "s")
        #expect(listed == "01010107")
    }
}
