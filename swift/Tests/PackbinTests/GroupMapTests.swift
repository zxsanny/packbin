import Packbin
import Testing

/// One map row of an anchored group: the scheme, the row, the hex (probed in TypeScript at HEAD with the
/// group given as a nested object) and the map unpack gives (`nil`: the row back). The group is a
/// nested `[String: Any]` both ways (owner ruling 2026-10-14, Go-4 A); TypeScript unpacks it flat.
struct GroupMapRow: CustomTestStringConvertible, Sendable {
    let name: String
    let scheme: @Sendable () throws -> Scheme
    let row: @Sendable () -> [String: Any]
    let wire: String
    let back: String?
    var testDescription: String { name }

    init(_ name: String, _ scheme: @escaping @Sendable () throws -> Scheme, _ row: @escaping @Sendable () -> [String: Any],
         _ wire: String, back: String? = nil) {
        self.name = name
        self.scheme = scheme
        self.row = row
        self.wire = wire
        self.back = back
    }
}

func nestedFlagsScheme() throws -> Scheme { try Scheme(1, .flags(0, .group(0, "g", .flags(0, .u8(0, "n"))))) }
func nestedGroupScheme() throws -> Scheme { try Scheme(1, .flags(0, .group(0, "g", .group(0, "h", .u8(0, "n"))))) }
func siblingAndFlagsScheme() throws -> Scheme {
    try Scheme(1, .flags(0, .group(0, "g", .u8(0, "a"), .flags(1, .u8(1, "c")))))
}
func anchoredFlagsScheme() throws -> Scheme {
    try Scheme(1, .u8(0, "a"), .group(1, "g", .u8(1, "b"), .flags(2, .u8(2, "c"))))
}
func groupUnderFlagsScheme() throws -> Scheme {
    try Scheme(1, .u8(0, "a"), .flags(1, .group(1, "g", .u8(1, "b"), .flags(2, .u8(2, "c")))))
}
/// flags-when-member WG: a when inside a group under flags.
func whenGroupScheme() throws -> Scheme {
    try Scheme(1, .u8(0, "mode"), .flags(1, .group(1, "g", .when(1, .eq(0, 1), .u8(1, "speed"))), .u16(2, "heading")))
}
/// flags-when-member GS: a group sibling of the when.
func groupSiblingScheme() throws -> Scheme {
    try Scheme(1, .u8(0, "mode"),
               .flags(1, .group(1, "g", .u8(1, "extra"), .when(2, .eq(0, 1), .u8(2, "speed"))), .u16(3, "heading")))
}
func splitInGroupScheme() throws -> Scheme {
    let m = FlagByte("m")
    return try Scheme(1, .group(0, "g", .flagByte(m), m.bit(.u8(0, "c")), m.bit(.u16(1, "d"))))
}
func whenBranchGroupScheme() throws -> Scheme {
    try Scheme(1, .u8(0, "kind"), .when(1, .eq(0, 0), .group(1, "g", .u8(1, "shape"))), .when(2, .eq(0, 1), .u16(2, "shape")))
}
/// README Flags (loop 21): a late when in a split bit's group packs when another member holds a value.
func readmeLateWhenScheme() throws -> Scheme {
    let fb = FlagByte("fb")
    return try Scheme(1, .flagByte(fb), .u8(0, "mode"),
                      fb.bit(.group(1, "g", .u8(1, "d"), .when(2, .eq(0, 1), .u8(2, "a")), .when(3, .eq(0, 2), .u8(3, "b")))))
}
/// The loop 25 probe row D1: an empty anchored group as a flags member takes no id.
func emptyGroupMarkScheme() throws -> Scheme { try Scheme(1, .flags(0, .group(0, "mark")), .u8(0, "n")) }

let groupMapRows: [GroupMapRow] = [
    GroupMapRow("presence: group holding only flags", { try nestedFlagsScheme() }, { ["g": ["n": 5]] }, "01010105"),
    GroupMapRow("presence: group holding only a group", { try nestedGroupScheme() }, { ["g": ["h": ["n": 5]]] }, "010105"),
    GroupMapRow("presence: absent nested flags", { try nestedFlagsScheme() }, { [:] }, "0100"),
    GroupMapRow("presence: absent nested group", { try nestedGroupScheme() }, { [:] }, "0100"),
    GroupMapRow("presence: sibling and nested value", { try siblingAndFlagsScheme() }, { ["g": ["a": 1, "c": 2]] }, "0101010102"),
    GroupMapRow("presence: an empty map sets the bit", { try nestedFlagsScheme() }, { ["g": [String: Any]()] }, "010100"),
    GroupMapRow("nested: flags inside an anchored group", { try anchoredFlagsScheme() }, { ["a": 1, "g": ["b": 2, "c": 3]] },
                "0101020103"),
    GroupMapRow("nested: flags member left out", { try anchoredFlagsScheme() }, { ["a": 1, "g": ["b": 2]] }, "01010200"),
    GroupMapRow("a group under flags, given", { try groupUnderFlagsScheme() }, { ["a": 1, "g": ["b": 2, "c": 3]] }, "010101020103"),
    GroupMapRow("a group under flags, not given", { try groupUnderFlagsScheme() }, { ["a": 1] }, "010100"),
    GroupMapRow("split byte in a group, both bits", { try splitInGroupScheme() }, { ["g": ["c": 3, "d": 4]] }, "0103030400"),
    GroupMapRow("split byte in a group, one bit", { try splitInGroupScheme() }, { ["g": ["d": 4]] }, "01020400"),
    GroupMapRow("a flag byte in a group sees its own bits", {
        try Scheme(1, .flags(0, .u8(0, "a")), .group(1, "g", .flags(1, .u8(1, "b"))))
    }, { ["g": ["b": 2]] }, "01000102"),
    GroupMapRow("an anchored group shares the scope, other branch", { try whenBranchGroupScheme() }, { ["kind": 1, "shape": 300] },
                "01012c01"),
    GroupMapRow("an anchored group shares the scope, group branch", { try whenBranchGroupScheme() },
                { ["kind": 0, "g": ["shape": 5]] }, "010005"),
    GroupMapRow("a group under flags given as a map", { try Scheme(1, .flags(0, .group(0, "g", .u8(0, "b")))) },
                { ["g": ["b": 2]] }, "010102"),
    GroupMapRow("a top-level anchored group", { try Scheme(1, .group(0, "g", .u8(0, "a"))) }, { ["g": ["a": 1]] }, "0101"),
    GroupMapRow("a when after a group names its member", {
        try Scheme(1, .group(0, "g", .u8(0, "n")), .when(1, .eq(0, 1), .u8(1, "v")))
    }, { ["g": ["n": 1], "v": 7] }, "010107"),
    GroupMapRow("a when inside a group names a member outside it", { try whenGroupScheme() },
                { ["mode": 1, "g": ["speed": 7], "heading": 90] }, "010103075a00"),
    GroupMapRow("a group is transparent to the flag byte scope", {
        let fb = FlagByte("fb")
        return try Scheme(1, .group(0, "g", .flagByte(fb)), fb.bit(.u8(0, "a")))
    }, { ["a": 5] }, "010105", back: "a=UInt8:5,g={}"),
    GroupMapRow("a bit is numbered before the bits nested in its group", {
        let m = FlagByte("m")
        return try Scheme(1, .flagByte(m), m.bit(.group(0, "g", .u8(0, "y"), m.bit(.u8(1, "x")))))
    }, { ["g": ["y": 1, "x": 2]] }, "01030102"),
    GroupMapRow("the outer bit alone", {
        let m = FlagByte("m")
        return try Scheme(1, .flagByte(m), m.bit(.group(0, "g", .u8(0, "y"), m.bit(.u8(1, "x")))))
    }, { ["g": ["y": 1]] }, "010101"),
    GroupMapRow("README late when in a group", { try readmeLateWhenScheme() }, { ["mode": 1, "g": ["d": 5, "a": 9]] }, "0101010509"),
    GroupMapRow("empty group mark set", { try Scheme(1, .flags(0, .group(0, "mark"))) }, { ["mark": true] }, "0101"),
    GroupMapRow("empty group mark false", { try Scheme(1, .flags(0, .group(0, "mark"))) }, { ["mark": false] }, "0100",
                back: ""),
    GroupMapRow("empty group mark on a split bit", {
        let m = FlagByte("m")
        return try Scheme(1, .flagByte(m), m.bit(.group(0, "mark")), m.bit(.u8(0, "n")))
    }, { ["mark": true, "n": 3] }, "010303"),
    GroupMapRow("D1 mark set", { try emptyGroupMarkScheme() }, { ["mark": true, "n": 3] }, "010103"),
    GroupMapRow("D1 mark not given", { try emptyGroupMarkScheme() }, { ["n": 3] }, "010003"),
    GroupMapRow("D1 mark false", { try emptyGroupMarkScheme() }, { ["mark": false, "n": 3] }, "010003", back: "n=UInt8:3"),
    GroupMapRow("WG when true", { try whenGroupScheme() }, { ["mode": 1, "g": ["speed": 7], "heading": 90] }, "010103075a00"),
    GroupMapRow("WG when false", { try whenGroupScheme() }, { ["mode": 0, "heading": 90] }, "0100025a00"),
    GroupMapRow("WG when true without body", { try whenGroupScheme() }, { ["mode": 1, "heading": 90] }, "0101025a00"),
    GroupMapRow("WG only the when", { try whenGroupScheme() }, { ["mode": 1, "g": ["speed": 7]] }, "01010107"),
    GroupMapRow("WG group given, when false", { try whenGroupScheme() }, { ["mode": 0, "g": ["speed": 7], "heading": 90] },
                "0100035a00", back: "g={},heading=UInt16:90,mode=UInt8:0"),
    GroupMapRow("GS sibling with the when true", { try groupSiblingScheme() },
                { ["mode": 1, "g": ["extra": 4, "speed": 7], "heading": 90] }, "01010304075a00"),
    GroupMapRow("GS sibling with the when false", { try groupSiblingScheme() }, { ["mode": 0, "g": ["extra": 4], "heading": 90] },
                "010003045a00"),
    GroupMapRow("GS group with nothing in it", { try groupSiblingScheme() }, { ["mode": 1, "heading": 90] }, "0101025a00"),
    GroupMapRow("a group inside a group", {
        try Scheme(1, .u8(0, "a"), .group(1, "g", .group(1, "h", .u8(1, "x"))))
    }, { ["a": 1, "g": ["h": ["x": 5]]] }, "010105"),
]

@Suite struct GroupMapTests {
    @Test(arguments: groupMapRows)
    func packAndUnpack_anchoredGroupMapRow_giveTypeScriptHex(_ c: GroupMapRow) throws {
        // Arrange
        let scheme = try c.scheme()
        let row = c.row()

        // Act
        let wire = try packHex(scheme, row)
        let back = try unpackMap(bytes(c.wire), scheme)
        let again = try packHex(scheme, back)

        // Assert
        #expect(wire == c.wire)
        if let want = c.back {
            #expect(describeMap(back) == want)
        } else {
            #expect(describeValues(back) == describeValues(row))
        }
        #expect(again == c.wire)
    }

    @Test func unpack_shortPacketInAGroup_namesTheField() throws {
        // Arrange
        let scheme = try anchoredFlagsScheme()

        // Act
        let error = packbinError { try unpackMap(bytes("010102"), scheme) }

        // Assert
        #expect(error?.kind == .short && error?.field == 2 && error?.needed == 1 && error?.left == 0)
    }
}
