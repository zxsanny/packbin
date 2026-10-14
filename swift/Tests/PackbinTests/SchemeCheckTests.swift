import Packbin
import Testing

/// The construction refusals of the TypeScript tests `scheme`, `scheme-constructor`, `flag-scope`,
/// `duplicate-names`, `nested-group` and `bool-flag` that need no round, list or dict; each probed in
/// TypeScript at HEAD, which refuses them with the same reason. Swift names the field id as well.
let refusedSchemes: [RefusedScheme] = [
    RefusedScheme("bool outside flags", field: 0, "on",
                  "bool on: allowed only directly inside flags or a flag bit; move it into flags") {
        try Scheme(1, .bool(0, "on"))
    },
    RefusedScheme("wrong field id", field: 1, "a", "field id: expected 0, got 1") { try Scheme(1, .u8(1, "a")) },
    RefusedScheme("id gap", field: 2, "b", "field id: expected 1, got 2") { try Scheme(1, .u8(0, "a"), .u8(2, "b")) },
    RefusedScheme("repeated id", field: 0, "b", "field id: expected 1, got 0") { try Scheme(1, .u8(0, "a"), .u8(0, "b")) },
    RefusedScheme("group anchor not the next id", field: 1, "g", "field id: expected 0, got 1") {
        try Scheme(1, .group(1, "g", .u8(1, "a")))
    },
    RefusedScheme("member after an empty group takes its anchor", field: 1, "n", "field id: expected 0, got 1") {
        try Scheme(1, .flags(0, .group(0, "mark"), .u8(1, "n")))
    },
    RefusedScheme("bool at the top level after a field", field: 1, "top", "bool top: allowed only...") {
        try Scheme(1, .u8(0, "a"), .bool(1, "top"))
    },
    RefusedScheme("bool in an anchored group", field: 1, "inGroup", "bool inGroup: allowed only...") {
        try Scheme(1, .group(0, "g", .u8(0, "n"), .bool(1, "inGroup")))
    },
    RefusedScheme("bool in a group under flags", field: 1, "underFlags", "bool underFlags: allowed only...") {
        try Scheme(1, .flags(0, .group(0, "g", .u8(0, "n"), .bool(1, "underFlags"))))
    },
    RefusedScheme("bool in a when", field: 1, "inWhen", "bool inWhen: allowed only...") {
        try Scheme(1, .u8(0, "k"), .when(1, .eq(0, 1), .bool(1, "inWhen")))
    },
    RefusedScheme("empty group outside flags", field: 1, "mark",
                  "empty group mark: allowed only directly inside flags or a flag bit; move it into flags") {
        try Scheme(1, .u8(0, "n"), .group(1, "mark"))
    },
    RefusedScheme("empty group at the top level", field: 0, "mark", "empty group mark: allowed only...") {
        try Scheme(1, .group(0, "mark"))
    },
    RefusedScheme("empty group in a group under a bit", field: 1, "inner", "empty group inner: allowed only...") {
        let m = FlagByte("m")
        return try Scheme(1, .flagByte(m), m.bit(.group(0, "g", .u8(0, "n"), .group(1, "inner"))))
    },
    RefusedScheme("split bit with no byte", field: 0, "early",
                  "flag bit 0 (early): its flag byte is not read earlier in the same scope") {
        try Scheme(1, FlagByte("fb").bit(.u8(0, "early")))
    },
    RefusedScheme("orphan bit after a byte read in a when", field: 1, "alpha", "flag bit 0 (alpha): its flag...") {
        let fb = FlagByte("fb")
        return try Scheme(1, .u8(0, "k"), .when(1, .eq(0, 1), .flagByte(fb)), fb.bit(.u8(1, "alpha")))
    },
    RefusedScheme("bit under a when before its byte", field: 0, "early", "flag bit 0 (early): its flag...") {
        let fb = FlagByte("fb")
        return try Scheme(1, .when(0, .eq(0, 1), fb.bit(.u8(0, "early"))), .flagByte(fb))
    },
    RefusedScheme("bit inside a when before its byte", field: 1, "early", "flag bit 0 (early): its flag...") {
        let fb = FlagByte("fb")
        return try Scheme(1, .u8(0, "k"), .when(1, .eq(0, 1), fb.bit(.u8(1, "early")), .flagByte(fb)))
    },
    RefusedScheme("a byte read in a bit's group does not leak", field: 0, "leaked", "flag bit 0 (leaked): its flag...") {
        let outer = FlagByte("outer"), inner = FlagByte("inner")
        return try Scheme(1, .flagByte(outer), outer.bit(.group(0, "g", .flagByte(inner))), inner.bit(.u8(0, "leaked")))
    },
    RefusedScheme("split bit inside a combined flags member", field: 0, "nested", "flag bit 0 (nested): its flag...") {
        let outer = FlagByte("outer"), missing = FlagByte("missing")
        return try Scheme(1, .flagByte(outer), outer.bit(.flags(0, missing.bit(.u8(0, "nested")))))
    },
    RefusedScheme("when names its own body", field: 0, "",
                  "when 0: eq names field id 0, which is not declared earlier in the same scope") {
        try Scheme(1, .when(0, .eq(0, 1), .u8(0, "a")))
    },
    RefusedScheme("same name twice", field: 1, "a",
                  "member a: declared twice in one scope; a row holds one value per name, so one would be lost") {
        try Scheme(1, .u8(0, "a"), .u8(1, "a"))
    },
    RefusedScheme("flags member named like a top-level field", field: 1, "a", "member a: declared twice...") {
        try Scheme(1, .u8(0, "a"), .flags(1, .u8(1, "a")))
    },
    RefusedScheme("anchored group member named like an outer member", field: 1, "a", "member a: declared twice...") {
        try Scheme(1, .u8(0, "a"), .group(1, "g", .u8(1, "a")))
    },
    RefusedScheme("group named like its member", field: 0, "session", "member session: declared twice...") {
        try Scheme(1, .flags(0, .group(0, "session", .u16(0, "session"))))
    },
    RefusedScheme("group named like an outer member", field: 1, "g", "member g: declared twice...") {
        try Scheme(1, .u8(0, "g"), .group(1, "g", .u8(1, "a")))
    },
    RefusedScheme("twice outside every when after a when", field: 3, "shape", "member shape: declared twice...") {
        try Scheme(1, .u8(0, "kind"), .when(1, .eq(0, 0), .u8(1, "shape")), .u8(2, "shape"), .u8(3, "shape"))
    },
]

/// AC-3 (U25 A for Swift `Int` ids): a negative field id, eq id or anchor is refused, naming it.
let negativeIDs: [RefusedScheme] = [
    RefusedScheme("field id", field: -1, "a", "field id: expected 0, got -1") { try Scheme(1, .u8(-1, "a")) },
    RefusedScheme("Int.min field id", field: Int.min, "a", "field id: expected 0, got \(Int.min)") {
        try Scheme(1, .u8(Int.min, "a"))
    },
    RefusedScheme("eq id", field: 1, "", "when 1: eq names field id -1, which is not declared earlier in the same scope") {
        try Scheme(1, .u8(0, "k"), .when(1, .eq(-1, 1), .u8(1, "v")))
    },
    RefusedScheme("flags anchor", field: -1, "", "field id: expected 0, got -1") { try Scheme(1, .flags(-1, .u8(0, "a"))) },
    RefusedScheme("when anchor", field: -1, "", "field id: expected 1, got -1") {
        try Scheme(1, .u8(0, "k"), .when(-1, .eq(0, 1), .u8(1, "v")))
    },
    RefusedScheme("group anchor", field: -1, "g", "field id: expected 0, got -1") { try Scheme(1, .group(-1, "g", .u8(0, "a"))) },
    RefusedScheme("member of a group", field: -1, "a", "field id: expected 0, got -1") {
        try Scheme(1, .group(0, "g", .u8(-1, "a")))
    },
    RefusedScheme("member of a split bit", field: -5, "a", "field id: expected 0, got -5") {
        let fb = FlagByte("fb")
        return try Scheme(1, .flagByte(fb), fb.bit(.u8(-5, "a")))
    },
]

@Suite struct SchemeCheckTests {
    @Test(arguments: refusedSchemes)
    func scheme_refusedByTypeScript_throwsNamingTheField(_ c: RefusedScheme) {
        expectRefused(c)
    }

    @Test(arguments: negativeIDs)
    func scheme_negativeID_isRefusedNamingIt(_ c: RefusedScheme) {
        expectRefused(c)
    }

    @Test func scheme_arrayForm_refusesAsTheVariadicForm() {
        // Arrange
        let fields: [Field] = [.u8(0, "a"), .u8(1, "a")]

        // Act
        let variadic = packbinError { try Scheme(1, .u8(0, "a"), .u8(1, "a")) }
        let array = packbinError { try Scheme(1, fields) }

        // Assert
        #expect(variadic != nil && variadic == array)
    }

    @Test func scheme_idsTakenByFlagsWhenAndGroupMembers_build() throws {
        // Arrange
        let fb = FlagByte("fb")

        // Act
        let scheme = try Scheme(1, .u8(0, "k"), .flags(1, .u8(1, "a"), .group(2, "g", .u8(2, "b"))),
                                .when(3, .eq(0, 1), .u8(3, "c")), .flagByte(fb), fb.bit(.u8(4, "d")))
        let packed = try packHex(scheme, ["k": 1, "g": ["b": 2], "c": 3, "d": 4])

        // Assert
        #expect(packed == "01010202030104")
    }

    @Test func scheme_nameSharedByWhenBranchesOrOnceOutside_builds() throws {
        // Arrange
        let branches = try Scheme(1, .u8(0, "kind"), .when(1, .eq(0, 0), .u8(1, "shape")),
                                  .when(2, .eq(0, 1), .u16(2, "shape")))
        let outside = try Scheme(1, .u8(0, "kind"), .u8(1, "shape"), .when(2, .eq(0, 1), .u16(2, "shape")))

        // Act
        let branchHex = try packHex(branches, ["kind": 1, "shape": 300])
        let outsideHex = try packHex(outside, ["kind": 1, "shape": 7])

        // Assert
        #expect(branchHex == "01012c01")
        #expect(outsideHex == "0101070700")
    }
}
