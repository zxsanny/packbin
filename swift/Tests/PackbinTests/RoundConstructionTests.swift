import Packbin
import Testing

private let emptyBody = "the body holds no member; a round of it would charge no slot and write nothing"
private let nested = "is inside a repeat or times round; a round cannot hold another repeat or times"

/// AC-2 (SW-3), TypeScript `empty-round-body` (AZ-2390) and `nested-round`, and the construction
/// checks of the counted kinds: a count id names an integer or a u2 slot declared earlier in the same
/// scope (a negative id included, U25 A); a slot stands only in u2; packed takes width 1 or 2 and bias
/// 0 or -1. Reasons are TypeScript's text where TypeScript has the refusal.
@Suite struct RoundConstructionTests {
    static let emptyBodies: [RefusedScheme] = [
        RefusedScheme("repeat with no member", field: 0, "", "repeat 0: " + emptyBody) { try Scheme(1, .repeat(0)) },
        RefusedScheme("times with no member", field: 1, "", "times 1: " + emptyBody) {
            try Scheme(1, .u8(0, "n"), .times(1, count: 0))
        },
        RefusedScheme("only an empty when", field: 0, "", "repeat 0: " + emptyBody) {
            try Scheme(1, .repeat(0, .when(0, .eq(0, 1))))
        },
        RefusedScheme("an empty when in an empty when", field: 0, "", "repeat 0: " + emptyBody) {
            try Scheme(1, .repeat(0, .when(0, .eq(0, 1), .when(0, .eq(0, 2)))))
        },
        RefusedScheme("only an empty group", field: 0, "g",
                      "empty group g: allowed only directly inside flags or a flag bit; move it into flags") {
            try Scheme(1, .repeat(0, .group(0, "g")))
        },
        RefusedScheme("in flags", field: 0, "", "repeat 0: " + emptyBody) { try Scheme(1, .flags(0, .repeat(0))) },
        RefusedScheme("in a flag bit", field: 0, "", "repeat 0: " + emptyBody) {
            let fb = FlagByte("m")
            return try Scheme(1, .flagByte(fb), fb.bit(.repeat(0)))
        },
        RefusedScheme("in a when", field: 1, "", "repeat 1: " + emptyBody) {
            try Scheme(1, .u8(0, "m"), .when(1, .eq(0, 1), .repeat(1)))
        },
        RefusedScheme("in a group", field: 0, "", "repeat 0: " + emptyBody) { try Scheme(1, .group(0, "g", .repeat(0))) },
    ]

    @Test(arguments: emptyBodies)
    func scheme_roundBodyWithNoMember_isRefused(_ c: RefusedScheme) { expectRefused(c) }

    static let zeroWidth: [PackRow] = [
        PackRow("a flag byte alone", { try Scheme(1, .repeat(0, .flagByte(FlagByte("m")))) }, "01") { [:] },
        PackRow("a flags with no member", { try Scheme(1, .repeat(0, .flags(0))) }, "01") { [:] },
        PackRow("an empty group under flags", { try Scheme(1, .repeat(0, .flags(0, .group(0, "g")))) }, "010100") {
            ["g": [true, nil] as [Bool?]]
        },
        PackRow("one u8", { try Scheme(1, .repeat(0, .u8(0, "k"))) }, "010708") { ["k": [7, 8]] },
        PackRow("one u8 counted", { try Scheme(1, .u8(0, "n"), .times(1, count: 0, .u8(1, "k"))) }, "01020708") {
            ["n": 2, "k": [7, 8]]
        },
    ]

    @Test(arguments: zeroWidth)
    func pack_roundBodyOfZeroWidthMembers_builds(_ c: PackRow) throws { try expectPacks(c) }

    @Test func unpack_zeroWidthRoundThatReadsNothing_endsTheRepeatWithTrailingBytes() throws {
        // Arrange
        let scheme = try Scheme(1, .u8(0, "k"), .repeat(1, .bytes(1, "v", size: 0)))

        // Act
        let error = packbinError { try unpackMap(bytes("01ff00"), scheme) }

        // Assert
        #expect(error?.kind == .trailing && error?.left == 1)
    }

    @Test func unpack_zeroWidthTimesRoundThatReadsNothing_isAnUnreadableCount() throws {
        // Arrange
        let scheme = try Scheme(1, .u8(0, "n"), .times(1, count: 0, .bytes(1, "v", size: 0)))

        // Act
        let error = shortError { try unpackMap(bytes("0103"), scheme) }
        let none = try unpackMap(bytes("0100"), scheme)

        // Assert
        #expect(error?.0 == "v" && error?.1 == 0 && error?.2 == 0)
        #expect(canon(none) == canon(["n": UInt8(0)]))
    }

    static let nesting: [RefusedScheme] = [
        RefusedScheme("repeat in repeat", field: 1, "", "repeat 1 " + nested) {
            try Scheme(1, .repeat(0, .u8(0, "m"), .repeat(1, .u8(1, "v"))))
        },
        RefusedScheme("times in repeat", field: 1, "", "times 1 " + nested) {
            try Scheme(1, .repeat(0, .u8(0, "c"), .times(1, count: 0, .u8(1, "v"))))
        },
        RefusedScheme("repeat in times", field: 2, "", "repeat 2 " + nested) {
            try Scheme(1, .u8(0, "n"), .times(1, count: 0, .u8(1, "m"), .repeat(2, .u8(2, "v"))))
        },
        RefusedScheme("times in times", field: 2, "", "times 2 " + nested) {
            try Scheme(1, .u8(0, "n"), .times(1, count: 0, .u8(1, "c"), .times(2, count: 1, .u8(2, "v"))))
        },
        RefusedScheme("repeat in a when in a repeat", field: 1, "", "repeat 1 " + nested) {
            try Scheme(1, .repeat(0, .u8(0, "k"), .when(1, .eq(0, 1), .repeat(1, .u8(1, "v")))))
        },
        RefusedScheme("repeat in flags in a repeat", field: 0, "", "repeat 0 " + nested) {
            try Scheme(1, .repeat(0, .flags(0, .repeat(0, .u8(0, "v")))))
        },
        RefusedScheme("repeat in flags in flags in a repeat", field: 0, "", "repeat 0 " + nested) {
            try Scheme(1, .repeat(0, .flags(0, .flags(0, .repeat(0, .u8(0, "v"))))))
        },
        RefusedScheme("repeat in a split bit in a repeat", field: 0, "", "repeat 0 " + nested) {
            let fb = FlagByte("m")
            return try Scheme(1, .repeat(0, .flagByte(fb), fb.bit(.repeat(0, .u8(0, "v"))), fb.bit(.bool(1, "on"))))
        },
        RefusedScheme("repeat in a group in a repeat", field: 0, "", "repeat 0 " + nested) {
            try Scheme(1, .repeat(0, .group(0, "g", .repeat(0, .u8(0, "v")))))
        },
        RefusedScheme("times in a group in a repeat", field: 1, "", "times 1 " + nested) {
            try Scheme(1, .repeat(0, .group(0, "g", .u8(0, "n"), .times(1, count: 0, .u8(1, "v")))))
        },
        RefusedScheme("repeat in a group in a group in a times", field: 1, "", "repeat 1 " + nested) {
            try Scheme(1, .u8(0, "n"), .times(1, count: 0, .group(1, "a", .group(1, "b", .repeat(1, .u8(1, "v"))))))
        },
    ]

    @Test(arguments: nesting)
    func scheme_roundInsideARound_isRefused(_ c: RefusedScheme) { expectRefused(c) }

    static let counted: [RefusedScheme] = [
        RefusedScheme("count names a later field", field: 0, "p",
                      "sized 0: count names field id 1, which is not declared earlier in the same scope") {
            try Scheme(1, .sized(0, "p", count: 1), .u8(1, "n"))
        },
        RefusedScheme("count names a float", field: 1, "b", "bits 1: count names field id 0 (x), which is not an integer") {
            try Scheme(1, .f32(0, "x"), .bits(1, "b", count: 0))
        },
        RefusedScheme("count names a bool", field: 1, "p", "packed 1: count names field id 0 (on), which is not an integer") {
            try Scheme(1, .flags(0, .bool(0, "on")), .packed(1, 1, "p", count: 0))
        },
        RefusedScheme("count names a sized", field: 2, "",
                      "times 2: count names field id 1 (p), which is not an integer") {
            try Scheme(1, .u8(0, "n"), .sized(1, "p", count: 0), .times(2, count: 1, .u8(2, "v")))
        },
        RefusedScheme("U25: a negative count id", field: 1, "b",
                      "bits 1: count names field id -1, which is not declared earlier in the same scope") {
            try Scheme(1, .u8(0, "n"), .bits(1, "b", count: -1))
        },
        RefusedScheme("U25: a negative times count id", field: 1, "",
                      "times 1: count names field id -1, which is not declared earlier in the same scope") {
            try Scheme(1, .u8(0, "n"), .times(1, count: -1, .u8(1, "v")))
        },
        RefusedScheme("count names a field outside the round", field: 1, "p",
                      "sized 1: count names field id 0, which is not declared earlier in the same scope") {
            try Scheme(1, .u8(0, "n"), .repeat(1, .sized(1, "p", count: 0)))
        },
        RefusedScheme("times count names a field of a round", field: 2, "",
                      "times 2: count names field id 1, which is not declared earlier in the same scope") {
            try Scheme(1, .u8(0, "n"), .repeat(1, .u8(1, "c")), .times(2, count: 1, .u8(2, "v")))
        },
        RefusedScheme("a slot outside u2", field: 0, "a", "slot a: allowed only directly inside u2") {
            try Scheme(1, .slot(0, "a"))
        },
        RefusedScheme("u2 with no slot", field: nil, "", "u2 needs at least one slot") { try Scheme(1, .u2()) },
        RefusedScheme("u2 with a u8", field: 0, "a", "u2 takes slot fields, not u8") { try Scheme(1, .u2(.u8(0, "a"))) },
        RefusedScheme("u2 slot ids", field: 2, "b", "field id: expected 1, got 2") {
            try Scheme(1, .u2(.slot(0, "a"), .slot(2, "b")))
        },
        RefusedScheme("packed width 3", field: 1, "p", "packed width must be 1 or 2") {
            try Scheme(1, .u8(0, "n"), .packed(3, 1, "p", count: 0))
        },
        RefusedScheme("packed bias 1", field: 1, "p", "packed bias must be 0 or -1") {
            try Scheme(1, .u8(0, "n"), .packed(1, 1, "p", count: 0, bias: 1))
        },
        RefusedScheme("repeat anchor", field: 2, "", "field id: expected 1, got 2") {
            try Scheme(1, .u8(0, "n"), .repeat(2, .u8(2, "v")))
        },
        RefusedScheme("eq on a slot out of range", field: 1, "",
                      "when 1 tests u2 field 0 ('a') against 4; the value must be a whole number from 0 to 3") {
            try Scheme(1, .u2(.slot(0, "a")), .when(1, .eq(0, 4), .u8(1, "v")))
        },
        RefusedScheme("eq on a counted field", field: 2, "", "when 2: eq names field id 1 (p), which is not an integer or a bool") {
            try Scheme(1, .u8(0, "n"), .sized(1, "p", count: 0), .when(2, .eq(1, 1), .u8(2, "v")))
        },
        RefusedScheme("a slot named twice", field: 1, "a", "member a: declared twice in one scope; a row holds one value per name, "
                      + "so one would be lost") {
            try Scheme(1, .u8(0, "a"), .u2(.slot(1, "a")))
        },
        RefusedScheme("a bool in a round outside flags", field: 0, "on",
                      "bool on: allowed only directly inside flags or a flag bit; move it into flags") {
            try Scheme(1, .repeat(0, .bool(0, "on")))
        },
        RefusedScheme("a split bit whose byte is outside the round", field: 0, "v",
                      "flag bit 0 (v): its flag byte is not read earlier in the same scope") {
            let fb = FlagByte("m")
            return try Scheme(1, .flagByte(fb), .repeat(0, fb.bit(.u8(0, "v"))))
        },
    ]

    @Test(arguments: counted)
    func scheme_countedKindOrRoundTheChecksRefuse_isRefusedNamingTheField(_ c: RefusedScheme) { expectRefused(c) }

    @Test func scheme_slotAsACountAndAnEqSource_builds() throws {
        // Arrange
        let scheme = try Scheme(1, .u2(.slot(0, "a")), .bits(1, "b", count: 0), .when(2, .eq(0, 3), .u8(2, "v")))

        // Act
        let wire = try packHex(scheme, ["a": 3, "b": [1, 0, 1], "v": 9])

        // Assert
        #expect(wire == "01030509")
    }
}
