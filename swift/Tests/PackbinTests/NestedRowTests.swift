import Packbin
import Testing

struct InnerRow: PackbinRow, Equatable {
    var mode: UInt8 = 0
    var x: UInt8 = 0
}

struct OuterRow: PackbinRow, Equatable {
    var mode: UInt8 = 0
    var inner = InnerRow()
}

struct OuterOptionalRow: PackbinRow, Equatable {
    var mode: UInt8 = 0
    var inner: InnerRow?
}

@Sendable func repeatingNamesScheme() throws -> Scheme { try Scheme(1, .u8(0, "mode"), .group("in", .u8(0, "mode"), .u8(1, "x"))) }

private func nestedInnerFields() -> [Field] {
    [.u8(0, "mode").bind(get: { (r: InnerRow) in r.mode }, set: { $0.mode = $1 }),
     .u8(1, "x").bind(get: { (r: InnerRow) in r.x }, set: { $0.x = $1 })]
}

private func outerTyped() throws -> Scheme {
    try Scheme(1, .u8(0, "mode").bind(get: { (r: OuterRow) in r.mode }, set: { $0.mode = $1 }),
               .group("in", nestedInnerFields()).bind(get: { (r: OuterRow) in r.inner }, set: { $0.inner = $1 }))
}

private func outerOptionalTyped() throws -> Scheme {
    try Scheme(1, .u8(0, "mode").bind(get: { (r: OuterOptionalRow) in r.mode }, set: { $0.mode = $1 }),
               .flags(1, .group("in", nestedInnerFields()).bind(get: { (r: OuterOptionalRow) in r.inner }, set: { $0.inner = $1 })))
}

/// AC-3 (SW-12, U26 A, S8): a nested row (a group without an anchor) whose names repeat the outer names
/// reads its values from the nested `[String: Any]` or the nested struct, never from the outer row; the
/// two forms give the same bytes, and unpack gives the nested map back (owner ruling Go-4 A). A nested
/// row has ids, references and names of its own (as Go and C#; TypeScript flattens it into the row).
@Suite struct NestedRowTests {
    @Test func pack_nestedMapAndNestedStruct_giveTheSameBytes() throws {
        // Arrange
        let wire = "01010203"

        // Act
        let fromMap = try packHex(try repeatingNamesScheme(), ["mode": 1, "in": ["mode": 2, "x": 3]])
        let fromStruct = try packHex(try outerTyped(), OuterRow(mode: 1, inner: InnerRow(mode: 2, x: 3)))
        let typedSchemeMapRow = try packHex(try outerTyped(), ["mode": 1, "in": ["mode": 2, "x": 3]] as [String: Any])

        // Assert
        #expect([fromMap, fromStruct, typedSchemeMapRow] == [wire, wire, wire])
    }

    @Test func unpack_nestedRow_givesTheNestedMapAndStructAndRepacks() throws {
        // Arrange
        let wire = bytes("01010203")

        // Act
        let asMap = try unpackMap(wire, try repeatingNamesScheme())
        let asStruct = try unpack(wire, try outerTyped()) as? OuterRow
        let again = try packHex(try repeatingNamesScheme(), asMap)

        // Assert
        #expect(canon(asMap) == canon(["mode": UInt8(1), "in": ["mode": UInt8(2), "x": UInt8(3)]]))
        #expect(asStruct == OuterRow(mode: 1, inner: InnerRow(mode: 2, x: 3)))
        #expect(again == "01010203")
    }

    @Test func packAndUnpack_optionalNestedStructUnderFlags_isNoValueWhenNil() throws {
        // Arrange
        let scheme = try outerOptionalTyped()

        // Act
        let none = try packHex(scheme, OuterOptionalRow(mode: 1))
        let some = try packHex(scheme, OuterOptionalRow(mode: 1, inner: InnerRow(mode: 2, x: 3)))
        let mapNone = try packHex(scheme, ["mode": 1] as [String: Any])
        let back = try unpack(bytes(some), scheme) as? OuterOptionalRow

        // Assert
        #expect(none == "010100" && mapNone == "010100")
        #expect(some == "0101010203")
        #expect(back == OuterOptionalRow(mode: 1, inner: InnerRow(mode: 2, x: 3)))
    }

    static let neverOuter: [RoundRefusal] = [
        RoundRefusal("the inner name only in the outer row", repeatingNamesScheme, field: 0, "mode", "missing mode") {
            ["mode": 1, "in": ["x": 3]]
        },
        RoundRefusal("a flat key naming an inner member", repeatingNamesScheme, field: 1, "x", "x is a member of group in") {
            ["mode": 1, "x": 3]
        },
        RoundRefusal("the group not given", repeatingNamesScheme, field: 0, "mode", "missing mode") { ["mode": 1] },
        RoundRefusal("the group given as a number", repeatingNamesScheme, field: nil, "in", "expected a [String: Any] for group in") {
            ["mode": 1, "in": 5]
        },
    ]

    @Test(arguments: neverOuter)
    func pack_innerValueOnlyOutsideTheNestedMap_isRefused(_ c: RoundRefusal) throws {
        try expectRefused(c)
    }

    static let rows: [UnpackRow] = [
        UnpackRow("flags inside a nested row", { try Scheme(1, .u8(0, "a"), .group("g", .u8(0, "b"), .flags(1, .u8(1, "c")))) },
                  "0101020103", want: ["a": UInt8(1), "g": ["b": UInt8(2), "c": UInt8(3)]], row: { ["a": 1, "g": ["b": 2, "c": 3]] }),
        UnpackRow("flags member left out", { try Scheme(1, .u8(0, "a"), .group("g", .u8(0, "b"), .flags(1, .u8(1, "c")))) },
                  "01010200", want: ["a": UInt8(1), "g": ["b": UInt8(2)]], row: { ["a": 1, "g": ["b": 2]] }),
        UnpackRow("a split flag byte finds its bits in the nested row", {
            let fb = FlagByte("m")
            return try Scheme(1, .group("g", .flagByte(fb), fb.bit(.u8(0, "c")), fb.bit(.u16(1, "d"))))
        }, "0103030400", want: ["g": ["c": UInt8(3), "d": UInt16(4)]], row: { ["g": ["c": 3, "d": 4]] }),
        UnpackRow("a split flag byte, one bit", {
            let fb = FlagByte("m")
            return try Scheme(1, .group("g", .flagByte(fb), fb.bit(.u8(0, "c")), fb.bit(.u16(1, "d"))))
        }, "01020400", want: ["g": ["d": UInt16(4)]], row: { ["g": ["d": 4]] }),
        UnpackRow("a split flag byte read around the nested row", {
            let fb = FlagByte("m")
            return try Scheme(1, .flagByte(fb), .group("g", fb.bit(.u8(0, "c"))))
        }, "010103", want: ["g": ["c": UInt8(3)]], row: { ["g": ["c": 3]] }),
        UnpackRow("a split flag byte read around, bit clear", {
            let fb = FlagByte("m")
            return try Scheme(1, .flagByte(fb), .group("g", fb.bit(.u8(0, "c"))))
        }, "0100", want: ["g": [String: Any]()], row: { ["g": [String: Any]()] }),
        UnpackRow("a flag byte read in a nested row sees only its own bits",
                  { try Scheme(1, .flags(0, .u8(0, "a")), .group("g", .flags(0, .u8(0, "b")))) }, "01000102",
                  want: ["g": ["b": UInt8(2)]], row: { ["g": ["b": 2]] }),
        UnpackRow("a nested row under flags", { try Scheme(1, .flags(0, .group("g", .u8(0, "b")))) }, "010102",
                  want: ["g": ["b": UInt8(2)]], row: { ["g": ["b": 2]] }),
        UnpackRow("an absent nested row clears its bit", { try Scheme(1, .flags(0, .group("g", .u8(0, "b")))) }, "0100",
                  want: [:], row: { [:] }),
        UnpackRow("an empty nested row is a mark; the next field takes no new id",
                  { try Scheme(1, .flags(0, .group("mark")), .u8(0, "n")) }, "010105", want: ["mark": true, "n": UInt8(5)],
                  row: { ["mark": true, "n": 5] }),
        UnpackRow("ids restart at 0 inside and go on outside",
                  { try Scheme(1, .u8(0, "a"), .group("g", .u8(0, "b"), .u8(1, "c")), .u8(1, "d")) }, "0101020304",
                  want: ["a": UInt8(1), "g": ["b": UInt8(2), "c": UInt8(3)], "d": UInt8(4)],
                  row: { ["a": 1, "g": ["b": 2, "c": 3], "d": 4] }),
        UnpackRow("the when reads the nested field 0",
                  { try Scheme(1, .u8(0, "k"), .group("g", .u8(0, "m"), .when(1, .eq(0, 1), .u8(1, "v")))) }, "01000107",
                  want: ["k": UInt8(0), "g": ["m": UInt8(1), "v": UInt8(7)]], row: { ["k": 0, "g": ["m": 1, "v": 7]] }),
        UnpackRow("not the outer field 0",
                  { try Scheme(1, .u8(0, "k"), .group("g", .u8(0, "m"), .when(1, .eq(0, 1), .u8(1, "v")))) }, "010100",
                  want: ["k": UInt8(1), "g": ["m": UInt8(0)]], row: { ["k": 1, "g": ["m": 0]] }),
        UnpackRow("the when reads the nested m, which was not written, not the outer m",
                  { try Scheme(1, .u8(0, "m"), .group("g", .flags(0, .u8(0, "m")), .when(1, .eq(0, 1), .u8(1, "v")))) },
                  "010100", want: ["m": UInt8(1), "g": [String: Any]()], row: { ["m": 1, "g": ["v": 7]] }),
        UnpackRow("the sized reads the nested count (names repeat)",
                  { try Scheme(1, .u8(0, "n"), .group("g", .u8(0, "n"), .sized(1, "d", count: 0))) }, "0109020506",
                  want: ["n": UInt8(9), "g": ["n": UInt8(2), "d": [UInt8(5), UInt8(6)]]],
                  row: { ["n": 9, "g": ["n": 2, "d": [UInt8(5), UInt8(6)]]] }),
    ]

    @Test(arguments: rows)
    func packAndUnpack_nestedRow_givesTypeScriptsHexAndTheNestedMap(_ c: UnpackRow) throws {
        try expectUnpacks(c)
    }

    /// TypeScript refuses these names for its flat group (`declared inside a group and outside it`);
    /// a nested row names its members in a scope of its own, as Go.
    static let builds: [(String, @Sendable () throws -> Scheme)] = [
        ("a member shadowing an outer member", { try Scheme(1, .u8(0, "sid"), .group("g", .u8(0, "sid"))) }),
        ("a group named like its child", { try Scheme(1, .flags(0, .group("session", .u16(0, "session")))) }),
        ("two groups sharing a member name", { try Scheme(1, .group("first", .u8(0, "n")), .group("second", .u8(0, "n"))) }),
        ("a group in a group sharing a member", { try Scheme(1, .group("outer", .u8(0, "n"), .group("inner", .u8(0, "n")))) }),
        ("a group in a round, an outer name", { try Scheme(1, .u8(0, "k"), .repeat(1, .group("g", .u8(0, "k")))) }),
        ("a list named like a member of a group", { try Scheme(1, .list("l", .u8(0, "e")), .group("g", .u8(0, "l"))) }),
        ("a dict named like a member of a group", { try Scheme(1, .dict("d", .u8(0, "e")), .group("g", .u8(0, "d"))) }),
        ("a member under flags and in the group", { try Scheme(1, .flags(0, .u8(0, "v")), .group("g", .u8(0, "v"))) }),
        ("a member under a when and in the group", {
            try Scheme(1, .u8(0, "k"), .when(1, .eq(0, 1), .u8(1, "v")), .group("g", .u8(0, "v")))
        }),
        ("a u2 slot named like a member of the group", {
            try Scheme(1, .u2(.slot(0, "a"), .slot(1, "b")), .group("g", .u8(0, "b")))
        }),
    ]

    @Test(arguments: 0..<builds.count)
    func init_nestedRowRepeatingAnOuterName_builds(_ i: Int) {
        #expect(throws: Never.self, "\(Self.builds[i].0)") { _ = try Self.builds[i].1() }
    }

    static let refused: [RefusedScheme] = [
        RefusedScheme("the group named like a member beside it", field: nil, "g", "member g: declared twice in one scope...") {
            try Scheme(1, .u8(0, "g"), .group("g", .u8(0, "b")))
        },
        RefusedScheme("a name twice inside the group", field: 1, "b", "member b: declared twice in one scope...") {
            try Scheme(1, .group("g", .u8(0, "b"), .u8(1, "b")))
        },
        RefusedScheme("an anchored group member named like an outer one", field: 1, "a", "member a: declared twice in one scope...") {
            try Scheme(1, .u8(0, "a"), .group(1, "g", .u8(1, "a")))
        },
        RefusedScheme("ids start at 0 in a nested row", field: 1, "b", "field id: expected 0, got 1") {
            try Scheme(1, .group("g", .u8(1, "b")))
        },
        RefusedScheme("a when in a nested row cannot read the row around", field: 0, "",
                      "when 0: eq names field id 0, which is not declared earlier in the same scope") {
            try Scheme(1, .u8(0, "k"), .group("g", .when(0, .eq(0, 1), .u8(0, "v"))))
        },
    ]

    @Test(arguments: refused)
    func init_nestedRowNameOrIdTwice_isRefused(_ c: RefusedScheme) {
        expectRefused(c)
    }

    @Test func pack_countBehindAClearWhenInANestedRowOrListItem_isRefusedAsU11() throws {
        // Arrange: TypeScript refuses both rows with this text.
        let body: [Field] = [.u8(0, "mode"), .when(1, .eq(0, 1), .u8(1, "c")), .flags(2, .bits(2, "v", count: 1))]
        let nested = try Scheme(1, .group("g", body))
        let element = try Scheme(1, .list("rows", .group("r", body)))
        let text = "v: the count c is 3 in the row, but no field wrote it (the when that holds it is clear), so the member reads nothing"

        // Act
        let inNested = packbinError { try pack(nested, ["g": ["mode": 0, "c": 3]]) }
        let inItem = packbinError { try pack(element, ["rows": [["mode": 0, "c": 3]]]) }
        let packs = try packHex(element, ["rows": [["mode": 0, "c": 0], ["mode": 1, "c": 3, "v": [1, 0, 1]]]])

        // Assert
        for e in [inNested, inItem] { #expect(e?.field == 2 && e?.name == "v" && e?.reason.hasPrefix(text) == true) }
        #expect(packs == "010200000001030105")
    }

    @Test func pack_absentNestedRowUnderFlags_readsNoCountFromTheRowAround() throws {
        // Arrange: the outer c is not the nested row's c; the nested row is not given, so it holds none.
        let scheme = try Scheme(1, .u8(0, "k"), .when(1, .eq(0, 1), .u8(1, "c")),
                                .flags(2, .group("g", .u8(0, "mode"), .when(1, .eq(0, 1), .u8(1, "c")), .bits(2, "v", count: 1))))

        // Act
        let wire = try packHex(scheme, ["k": 0, "c": 3])

        // Assert
        #expect(wire == "010000")
    }
}
