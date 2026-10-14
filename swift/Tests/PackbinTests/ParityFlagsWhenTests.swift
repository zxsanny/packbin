import Packbin
import Testing

/// flags-when-member WA (a when as a flags member) and WS (the same in a split flag byte); WG, GS and
/// the group rows are in `GroupMapTests` and `GroupRefusalTests`.
@Sendable private func whenAsFlagsMember() throws -> Scheme {
    try Scheme(1, .u8(0, "mode"), .flags(1, .when(1, .eq(0, 1), .u8(1, "speed")), .u16(2, "heading")))
}
@Sendable private func whenInSplitByte() throws -> Scheme {
    let fb = FlagByte("m")
    return try Scheme(1, .u8(0, "mode"), .flagByte(fb), fb.bit(.when(1, .eq(0, 1), .u8(1, "speed"))), fb.bit(.u16(2, "heading")))
}
@Sendable private func twoBodyValues() throws -> Scheme {
    try Scheme(1, .u8(0, "mode"), .flags(1, .when(1, .eq(0, 1), .u8(1, "speed"), .u8(2, "extra")), .u16(3, "heading")))
}
@Sendable private func sameFlagsWhen() throws -> Scheme {
    try Scheme(1, .flags(0, .u8(0, "mode"), .when(1, .eq(0, 1), .u8(1, "speed"))))
}

/// flag-group-presence: a group under flags holding only one counted or slot kind.
@Sendable private func u2Only() throws -> Scheme { try Scheme(1, .flags(0, .group(0, "g", .u2(.slot(0, "p"), .slot(1, "q"))))) }
@Sendable private func bitsOnly() throws -> Scheme { try Scheme(1, .u8(0, "n"), .flags(1, .group(1, "g", .bits(1, "b", count: 0)))) }
@Sendable private func sizedOnly() throws -> Scheme { try Scheme(1, .u8(0, "n"), .flags(1, .group(1, "g", .sized(1, "d", count: 0)))) }
@Sendable private func packedOnly() throws -> Scheme {
    try Scheme(1, .u8(0, "n"), .flags(1, .group(1, "g", .packed(2, 1, "k", count: 0))))
}

/// The loop 25 probe row D7: a split flag bit inside a false when, the member given.
@Sendable private func splitBitInWhen() throws -> Scheme {
    let m = FlagByte("m")
    return try Scheme(1, .u8(0, "k"), .flagByte(m), .when(1, .eq(0, 1), m.bit(.u8(1, "a"))), m.bit(.u8(2, "b")))
}

private func whenRows(_ kind: String, _ scheme: @escaping @Sendable () throws -> Scheme) -> [UnpackRow] {
    let (one, zero, seven, h) = (UInt8(1), UInt8(0), UInt8(7), UInt16(90))
    return [
        UnpackRow("\(kind) when true", scheme, "010103075a00", want: ["mode": one, "speed": seven, "heading": h],
                  row: { ["mode": 1, "speed": 7, "heading": 90] }),
        UnpackRow("\(kind) when false", scheme, "0100025a00", want: ["mode": zero, "heading": h], row: { ["mode": 0, "heading": 90] }),
        UnpackRow("\(kind) when true without body", scheme, "0101025a00", want: ["mode": one, "heading": h],
                  row: { ["mode": 1, "heading": 90] }),
        UnpackRow("\(kind) when false with a body given", scheme, "0100025a00", want: ["mode": zero, "heading": h],
                  row: { ["mode": 0, "speed": 7, "heading": 90] }),
        UnpackRow("\(kind) AC-5 old packet", scheme, "0101025a00", want: ["mode": one, "heading": h]),
        UnpackRow("\(kind) only the when", scheme, "01010107", want: ["mode": one, "speed": seven], row: { ["mode": 1, "speed": 7] }),
        UnpackRow("\(kind) only mode", scheme, "010000", want: ["mode": zero], row: { ["mode": 0] }),
        UnpackRow("\(kind) AC-5 new packet", scheme, "010103075a00", want: ["mode": one, "speed": seven, "heading": h]),
    ]
}

/// AC-1 (SW-3): the AC-3 tables of `flags-when-member` and `flag-group-presence`, and the loop 25 probe
/// rows D1 and D7 (`batch_02_loop25_report.md`) no earlier Swift test pins; each probed in TypeScript
/// at HEAD. A group's values are a map of their own (Go-4 A); the bytes are TypeScript's.
@Suite struct ParityFlagsWhenTests {
    static let whens: [UnpackRow] = whenRows("WA", whenAsFlagsMember) + whenRows("WS", whenInSplitByte) + [
        UnpackRow("W2 two body values", twoBodyValues, "01010307085a00",
                  want: ["mode": UInt8(1), "speed": UInt8(7), "extra": UInt8(8), "heading": UInt16(90)],
                  row: { ["mode": 1, "speed": 7, "extra": 8, "heading": 90] }),
        UnpackRow("WE when names an earlier member of its own flags", sameFlagsWhen, "01030107",
                  want: ["mode": UInt8(1), "speed": UInt8(7)], row: { ["mode": 1, "speed": 7] }),
        UnpackRow("WE same-flags when false", sameFlagsWhen, "010100", want: ["mode": UInt8(0)], row: { ["mode": 0, "speed": 7] }),
        UnpackRow("WE same-flags when without body", sameFlagsWhen, "010101", want: ["mode": UInt8(1)], row: { ["mode": 1] }),
        UnpackRow("WE same-flags when without mode", sameFlagsWhen, "0100", want: [:], row: { ["speed": 7] }),
        UnpackRow("AC-6 a row that does not use the shape", { try Scheme(1, .flags(0, .u8(0, "a"), .u16(1, "b"))) },
                  "0103010200", want: ["a": UInt8(1), "b": UInt16(2)], row: { ["a": 1, "b": 2] }),
    ]

    @Test(arguments: whens)
    func packAndUnpack_whenAsAFlagsMember_givesTypeScriptHexBothWays(_ c: UnpackRow) throws { try expectUnpacks(c) }

    static let whenRefusals: [RoundRefusal] = [
        RoundRefusal("W2 body value missing", twoBodyValues, field: 2, "extra", "missing extra") {
            ["mode": 1, "speed": 7, "heading": 90]
        },
        RoundRefusal("WA a body value outside its field range", whenAsFlagsMember, field: 1, "speed", "300 does not fit in u8") {
            ["mode": 1, "speed": 300, "heading": 90]
        },
    ]

    @Test(arguments: whenRefusals)
    func pack_whenBodyTypeScriptRefuses_isRefusedNamingTheMember(_ c: RoundRefusal) throws { try expectRefused(c) }

    static let presence: [UnpackRow] = [
        UnpackRow("AC-1 a u2-only group sets its bit", u2Only, "010109", want: ["g": ["p": UInt8(1), "q": UInt8(2)]],
                  row: { ["g": ["p": 1, "q": 2]] }),
        UnpackRow("AC-1 an anchored bits-only group sets its bit", bitsOnly, "01080155",
                  want: ["n": UInt8(8), "g": ["b": [UInt8(1), 0, 1, 0, 1, 0, 1, 0]]],
                  row: { ["n": 8, "g": ["b": [1, 0, 1, 0, 1, 0, 1, 0]]] }),
        UnpackRow("AC-1 a sized-only group sets its bit", sizedOnly, "01010109", want: ["n": UInt8(1), "g": ["d": [UInt8(9)]]],
                  row: { ["n": 1, "g": ["d": [UInt8(9)]]] }),
        UnpackRow("AC-1 a packed-only group sets its bit", packedOnly, "01020109", want: ["n": UInt8(2), "g": ["k": [UInt8(1), 2]]],
                  row: { ["n": 2, "g": ["k": [1, 2]]] }),
        UnpackRow("an absent u2 group keeps its bit clear", u2Only, "0100", want: [:], row: { [:] }),
        UnpackRow("an absent bits group keeps its bit clear", bitsOnly, "010100", want: ["n": UInt8(1)], row: { ["n": 1] }),
        UnpackRow("an absent sized group keeps its bit clear", sizedOnly, "010100", want: ["n": UInt8(1)], row: { ["n": 1] }),
        UnpackRow("an absent packed group keeps its bit clear", packedOnly, "010100", want: ["n": UInt8(1)], row: { ["n": 1] }),
    ]

    @Test(arguments: presence)
    func packAndUnpack_groupOfOneCountedKind_isOnWhenAValueIsPresent(_ c: UnpackRow) throws {
        try expectUnpacks(c)
        let scheme = try c.scheme()
        #expect(try packHex(scheme, try unpackMap(bytes(c.wire), scheme)) == c.wire, "\(c.name) repacks")
    }

    static let presenceRefusals: [RoundRefusal] = [
        RoundRefusal("AC-2 a u2 group with one slot set names the missing slot", u2Only, field: 1, "q", "2-bit") {
            ["g": ["p": 1]]
        },
        RoundRefusal("a u2 group with only its second slot set names the first", u2Only, field: 0, "p", "2-bit") {
            ["g": ["q": 1]]
        },
        RoundRefusal("D1 a row with no n", { try emptyGroupMarkScheme() }, field: 0, "n", "missing n") { [:] },
    ]

    @Test(arguments: presenceRefusals)
    func pack_groupRowTypeScriptRefuses_isRefusedNamingTheValue(_ c: RoundRefusal) throws { try expectRefused(c) }

    @Test func packAndUnpack_d1MarkLeftOut_givesTypeScriptHex() throws {
        try expectUnpacks(UnpackRow("D1 n 1", { try emptyGroupMarkScheme() }, "010001", want: ["n": UInt8(1)], row: { ["n": 1] }))
    }

    /// D7 (Go-3, all seven packages): the split byte sets a's bit although its when does not match (a is
    /// given); unpack reads no a, because the when does not match there either, so the repack differs.
    @Test func packAndUnpack_d7SplitBitInsideAFalseWhen_givesTypeScriptHexAndRow() throws {
        // Arrange
        let scheme = try splitBitInWhen()

        // Act
        let taken = try packHex(scheme, ["k": 1, "a": 5, "b": 6])
        let skipped = try packHex(scheme, ["k": 0, "a": 5, "b": 6])
        let back = try unpackMap(bytes(skipped), scheme)
        let again = try packHex(scheme, back)
        let full = try unpackMap(bytes(taken), scheme)

        // Assert
        #expect(taken == "0101030506" && skipped == "01000306")
        #expect(canon(back) == canon(["k": UInt8(0), "b": UInt8(6)]))
        #expect(again == "01000206")
        #expect(canon(full) == canon(["k": UInt8(1), "a": UInt8(5), "b": UInt8(6)]))
    }
}
