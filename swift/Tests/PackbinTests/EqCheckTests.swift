import Packbin
import Testing

private func whenOn(_ source: Field, _ condition: Condition) throws -> Scheme {
    try Scheme(1, source, .when(1, condition, .u8(1, "v")))
}

private func onFlag(_ condition: Condition) throws -> Scheme {
    try whenOn(.flags(0, .bool(0, "on")), condition)
}

/// `eq-source-kinds`, `eq-value-checked` and the eq rows of `reference-scope`, probed in TypeScript at
/// HEAD. A Swift `eq` value is an integer or a `Bool`; TypeScript's float, string and object values
/// have no Swift spelling.
let refusedEqs: [RefusedScheme] = [
    RefusedScheme("eq names an unknown id", field: 1, "",
                  "when 1: eq names field id 9, which is not declared earlier in the same scope") {
        try Scheme(1, .u8(0, "k"), .when(1, .eq(9, 5), .u8(1, "a")))
    },
    RefusedScheme("eq names a later field", field: 0, "",
                  "when 0: eq names field id 1, which is not declared earlier in the same scope") {
        try Scheme(1, .when(0, .eq(1, 5), .u8(0, "a")), .u8(1, "k"))
    },
    RefusedScheme("eq bool false", field: 1, "", "when 1: eq names bool field id 0 (on) and accepts only true, not false") {
        try onFlag(.eq(0, false))
    },
    RefusedScheme("eq bool 1", field: 1, "", "when 1: eq names bool field id 0 (on) and accepts only true, not 1") {
        try onFlag(.eq(0, 1))
    },
    RefusedScheme("eq bool 0", field: 1, "", "when 1: eq names bool field id 0 (on) and accepts only true, not 0") {
        try onFlag(.eq(0, 0))
    },
    RefusedScheme("eq bool false on a split bit", field: 1, "",
                  "when 1: eq names bool field id 0 (on) and accepts only true, not false") {
        let m = FlagByte("m")
        return try Scheme(1, .flagByte(m), m.bit(.bool(0, "on")), .when(1, .eq(0, false), .u8(1, "v")))
    },
    RefusedScheme("eq f32 source", field: 1, "", "when 1: eq names field id 0 (x), which is not an integer or a bool") {
        try whenOn(.f32(0, "x"), .eq(0, 1))
    },
    RefusedScheme("eq f64 source", field: 1, "", "when 1: eq names field id 0 (x), which is not an integer or a bool") {
        try whenOn(.f64(0, "x"), .eq(0, 1))
    },
    RefusedScheme("eq bytes source", field: 1, "", "when 1: eq names field id 0 (x), which is not an integer or a bool") {
        try whenOn(.bytes(0, "x", size: 2), .eq(0, 1))
    },
    RefusedScheme("eq true on an integer", field: 1, "",
                  "when 1 tests u8 field 0 ('k') against true; the value must be a whole number from 0 to 255") {
        try whenOn(.u8(0, "k"), .eq(0, true))
    },
    RefusedScheme("eq false on an integer", field: 1, "",
                  "when 1 tests u8 field 0 ('k') against false; the value must be a whole number from 0 to 255") {
        try whenOn(.u8(0, "k"), .eq(0, false))
    },
    RefusedScheme("an empty group mark has no id", field: 0, "",
                  "when 0: eq names field id 0, which is not declared earlier in the same scope") {
        try Scheme(1, .flags(0, .group(0, "mark")), .when(0, .eq(0, true), .u8(0, "v")))
    },
    RefusedScheme("a source in a when body", field: 2, "",
                  "when 2 tests u8 field 1 ('a') against 999; the value must be a whole number from 0 to 255") {
        try Scheme(1, .u8(0, "mode"), .when(1, .eq(0, 5), .u8(1, "a"), .when(2, .eq(1, 999), .u8(2, "b"))))
    },
]

/// One `eq` value an integer source can never hold, with TypeScript's text for it.
struct OutOfRangeEq: CustomTestStringConvertible, Sendable {
    let source: @Sendable () -> Field
    let condition: Condition
    let kind: String
    let shown: String
    let range: String
    var testDescription: String { "\(kind) \(shown)" }
}


let outOfRangeEqs: [OutOfRangeEq] = [
    OutOfRangeEq(source: { .u8(0, "mode") }, condition: .eq(0, 300), kind: "u8", shown: "300", range: "0 to 255"),
    OutOfRangeEq(source: { .u8(0, "mode") }, condition: .eq(0, -1), kind: "u8", shown: "-1", range: "0 to 255"),
    OutOfRangeEq(source: { .u8(0, "mode") }, condition: .eq(0, UInt64(256)), kind: "u8", shown: "256", range: "0 to 255"),
    OutOfRangeEq(source: { .i8(0, "mode") }, condition: .eq(0, 128), kind: "i8", shown: "128", range: "-128 to 127"),
    OutOfRangeEq(source: { .i8(0, "mode") }, condition: .eq(0, -129), kind: "i8", shown: "-129", range: "-128 to 127"),
    OutOfRangeEq(source: { .u16(0, "mode") }, condition: .eq(0, 65_536), kind: "u16", shown: "65536", range: "0 to 65535"),
    OutOfRangeEq(source: { .i16(0, "mode") }, condition: .eq(0, -32_769), kind: "i16", shown: "-32769", range: "-32768 to 32767"),
    OutOfRangeEq(source: { .u32(0, "mode") }, condition: .eq(0, 4_294_967_296), kind: "u32", shown: "4294967296",
                 range: "0 to 4294967295"),
    OutOfRangeEq(source: { .i32(0, "mode") }, condition: .eq(0, 2_147_483_648), kind: "i32", shown: "2147483648",
                 range: "-2147483648 to 2147483647"),
    OutOfRangeEq(source: { .u64(0, "mode") }, condition: .eq(0, -1), kind: "u64", shown: "-1",
                 range: "0 to 18446744073709551615"),
    OutOfRangeEq(source: { .i64(0, "mode") }, condition: .eq(0, UInt64(1) << 63), kind: "i64", shown: "9223372036854775808",
                 range: "-9223372036854775808 to 9223372036854775807"),
]

@Suite struct EqCheckTests {
    @Test(arguments: refusedEqs)
    func scheme_eqItsSourceCannotMatch_isRefused(_ c: RefusedScheme) {
        expectRefused(c)
    }

    @Test(arguments: outOfRangeEqs)
    func scheme_eqValueOutsideItsIntegerSource_isRefused(_ c: OutOfRangeEq) {
        // Arrange, Act
        let error = packbinError { try Scheme(1, c.source(), .when(1, c.condition, .u8(1, "speed"))) }

        // Assert
        #expect(error?.kind == .schemeError && error?.field == 1)
        #expect(error?.reason == "when 1 tests \(c.kind) field 0 ('mode') against \(c.shown); "
            + "the value must be a whole number from \(c.range)")
    }

    @Test func scheme_eqValueWiderThan64Bits_isRefused() throws {
        guard #available(macOS 15.0, iOS 18.0, *) else { return }
        #if compiler(>=6.0)
        // Arrange, Act
        let u64 = packbinError { try whenOn(.u64(0, "mode"), .eq(0, Int128(1) << 64)) }
        let i64 = packbinError { try whenOn(.i64(0, "mode"), .eq(0, -(Int128(1) << 63) - 1)) }

        // Assert
        #expect(u64?.reason == "when 1 tests u64 field 0 ('mode') against 18446744073709551616; "
            + "the value must be a whole number from 0 to 18446744073709551615")
        #expect(i64?.reason == "when 1 tests i64 field 0 ('mode') against -9223372036854775809; "
            + "the value must be a whole number from -9223372036854775808 to 9223372036854775807")
        #endif
    }

    @Test func scheme_eqValueAtTheEdgesOfItsSource_builds() throws {
        // Arrange, Act
        let built = [
            try whenOn(.u8(0, "mode"), .eq(0, 5)), try whenOn(.u8(0, "mode"), .eq(0, 255)),
            try whenOn(.u8(0, "mode"), .eq(0, 0)), try whenOn(.u8(0, "mode"), .eq(0, UInt64(5))),
            try whenOn(.i8(0, "mode"), .eq(0, -128)), try whenOn(.i8(0, "mode"), .eq(0, 127)),
            try whenOn(.u16(0, "mode"), .eq(0, 65_535)), try whenOn(.u32(0, "mode"), .eq(0, 4_294_967_295)),
            try whenOn(.u64(0, "mode"), .eq(0, UInt64.max)), try whenOn(.i64(0, "mode"), .eq(0, Int64.min)),
            try whenOn(.i64(0, "mode"), .eq(0, Int64.max)), try onFlag(.eq(0, true)),
        ]

        // Assert
        #expect(built.count == 12)
    }

    @Test func pack_eqOnABoolOrAnInteger_givesTypeScriptHex() throws {
        // Arrange
        let bool = try onFlag(.eq(0, true))
        let negative = try whenOn(.i16(0, "k"), .eq(0, -1))
        let inGroup = try Scheme(1, .group(0, "g", .u8(0, "n")), .when(1, .eq(0, 1), .u8(1, "v")))

        // Act
        let set = try packHex(bool, ["on": true, "v": 5])
        let clear = try packHex(bool, ["on": false, "v": 5])
        let minusOne = try packHex(negative, ["k": -1, "v": 2])
        let groupMember = try packHex(inGroup, ["g": ["n": 1], "v": 7])
        let otherValue = try packHex(inGroup, ["g": ["n": 2], "v": 7])

        // Assert
        #expect(set == "010105" && clear == "0100")
        #expect(minusOne == "01ffff02")
        #expect(groupMember == "010107" && otherValue == "0102")
    }

    @Test func unpack_whenAfterAGroup_readsTheGroupMember() throws {
        // Arrange
        let scheme = try Scheme(1, .group(0, "g", .u8(0, "n")), .when(1, .eq(0, 1), .u8(1, "v")))

        // Act
        let matched = try unpackMap(bytes("010107"), scheme)
        let other = try unpackMap(bytes("0102"), scheme)

        // Assert
        #expect(describeMap(matched) == "g={n=UInt8:1},v=UInt8:7")
        #expect(describeMap(other) == "g={n=UInt8:2}")
    }
}
