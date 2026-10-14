import Packbin
import Testing

/// A map row pack refuses: the field id and name the error names, and the start of its reason.
struct RefusedGroupRow: CustomTestStringConvertible, Sendable {
    let name: String
    let scheme: @Sendable () throws -> Scheme
    let row: @Sendable () -> [String: Any]
    let field: Int?
    let member: String
    let reason: String
    var testDescription: String { name }
}

private struct BStruct {
    var b: UInt8 = 2
}

/// The refusals of the TypeScript `flag-group-presence`, `nested-group` and `flags-when-member` rows
/// (TypeScript: `missing <member>`), and the map shapes the nested form refuses (owner ruling Go-4 A:
/// a group's value is a `[String: Any]`, and a member's value is read from it only; TypeScript packs a
/// flat key).
let refusedGroupRows: [RefusedGroupRow] = [
    RefusedGroupRow(name: "a set group with a required member missing", scheme: { try siblingAndFlagsScheme() },
                    row: { ["g": ["c": 2]] }, field: 0, member: "a", reason: "missing a"),
    RefusedGroupRow(name: "GS when body missing", scheme: { try groupSiblingScheme() },
                    row: { ["mode": 1, "g": ["extra": 4], "heading": 90] }, field: 2, member: "speed", reason: "missing speed"),
    RefusedGroupRow(name: "GS sibling missing, group on through the when", scheme: { try groupSiblingScheme() },
                    row: { ["mode": 1, "g": ["speed": 7], "heading": 90] }, field: 1, member: "extra", reason: "missing extra"),
    RefusedGroupRow(name: "a top-level group not given", scheme: { try anchoredFlagsScheme() },
                    row: { ["a": 1] }, field: 1, member: "b", reason: "missing b"),
    RefusedGroupRow(name: "a member out of range", scheme: { try anchoredFlagsScheme() },
                    row: { ["a": 1, "g": ["b": 300]] }, field: 1, member: "b", reason: "300 does not fit in u8"),
    RefusedGroupRow(name: "a group given a number", scheme: { try anchoredFlagsScheme() }, row: { ["a": 1, "g": 5] },
                    field: 1, member: "g", reason: "expected a [String: Any] for group g, got Int"),
    RefusedGroupRow(name: "a group given a struct", scheme: { try anchoredFlagsScheme() }, row: { ["a": 1, "g": BStruct()] },
                    field: 1, member: "g", reason: "expected a [String: Any] for group g, got BStruct"),
    RefusedGroupRow(name: "a member given flat", scheme: { try anchoredFlagsScheme() }, row: { ["a": 1, "b": 2] },
                    field: 1, member: "b", reason: "b is a member of group g, which is not given; give the value "
                        + "in the group's [String: Any], not in the row around it"),
    RefusedGroupRow(name: "a member given flat under flags", scheme: { try siblingAndFlagsScheme() }, row: { ["c": 2] },
                    field: 1, member: "c", reason: "c is a member of group g, which is not given..."),
    RefusedGroupRow(name: "a member of an inner group given flat", scheme: {
        try Scheme(1, .u8(0, "a"), .group(1, "g", .group(1, "h", .u8(1, "x"))))
    }, row: { ["a": 1, "g": [String: Any](), "x": 5] }, field: 1, member: "x",
       reason: "x is a member of group h, which is not given..."),
    RefusedGroupRow(name: "a member given flat inside the wrong group", scheme: {
        try Scheme(1, .u8(0, "a"), .group(1, "g", .u8(1, "b"), .group(2, "h", .u8(2, "x"))))
    }, row: { ["a": 1, "g": ["b": 1, "x": 5]] }, field: 2, member: "x",
       reason: "x is a member of group h, which is not given..."),
    RefusedGroupRow(name: "a mark given a number", scheme: { try Scheme(1, .flags(0, .group(0, "mark"))) },
                    row: { ["mark": 1] }, field: 0, member: "mark", reason: "expected a Bool for group mark, got Int"),
    RefusedGroupRow(name: "a split bit's when source written after the byte names the group", scheme: {
        let m = FlagByte("m")
        return try Scheme(1, .flagByte(m), .u8(0, "mode"), m.bit(.when(1, .eq(0, 1), .group(1, "g", .u8(1, "a")))))
    }, row: { ["mode": 1, "g": ["a": 5]] }, field: 1, member: "g",
       reason: "g: a value is given, but the condition or count of its when or times is not written before the flag byte..."),
]

@Suite struct GroupRefusalTests {
    @Test(arguments: refusedGroupRows)
    func pack_groupRowTheSchemeCannotWrite_isRefusedNamingTheField(_ c: RefusedGroupRow) throws {
        // Arrange
        let scheme = try c.scheme()

        // Act
        let error = packbinError { try pack(scheme, c.row()) }

        // Assert
        let prefix = c.reason.hasSuffix("...") ? String(c.reason.dropLast(3)) : nil
        let reason = error?.reason ?? ""
        #expect(error?.kind == .packError && error?.field == c.field && error?.name == c.member)
        #expect(prefix.map { reason.hasPrefix($0) } ?? (reason == c.reason), "reason: \(reason)")
    }

    @Test func pack_splitBitWhenSourceAfterTheByteFalse_skipsTheGroupSilently() throws {
        // Arrange
        let m = FlagByte("m")
        let scheme = try Scheme(1, .flagByte(m), .u8(0, "mode"), m.bit(.when(1, .eq(0, 1), .group(1, "g", .u8(1, "a")))))

        // Act
        let quiet = try packHex(scheme, ["mode": 0, "g": ["a": 5]])

        // Assert
        #expect(quiet == "010000")
    }

    @Test func pack_flatDuplicateBesideTheGivenMap_isNotRead() throws {
        // Arrange
        let scheme = try siblingAndFlagsScheme()

        // Act
        let nested = try packHex(scheme, ["g": ["a": 1, "c": 2]])
        let beside = try packHex(scheme, ["g": ["a": 1, "c": 2], "c": 9])

        // Assert
        #expect(nested == "0101010102" && beside == nested)
    }

    @Test func pack_groupGivenAsANestedOptionalOrTypedDictionary_readsIt() throws {
        // Arrange
        let scheme = try anchoredFlagsScheme()
        let inner: [String: Int]? = ["b": 2, "c": 3]

        // Act
        let wire = try packHex(scheme, ["a": 1, "g": inner as Any])

        // Assert
        #expect(wire == "0101020103")
    }
}
