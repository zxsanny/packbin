import Packbin
import Testing

/// reference_loop22.md 3a: a short times list under flags, shape A (the flags inside the body).
@Sendable private func shapeA() throws -> Scheme { try Scheme(1, .u8(0, "c"), .times(1, count: 0, .flags(1, .u8(1, "v")))) }
@Sendable private func shapeAWithW() throws -> Scheme {
    try Scheme(1, .u8(0, "c"), .times(1, count: 0, .u8(1, "w"), .flags(2, .u8(2, "v"))))
}
/// Shape B: the times as a flags member with its count (B1), after the count (B4), and as a split bit (B6).
@Sendable private func shapeB1() throws -> Scheme { try Scheme(1, .flags(0, .u8(0, "n"), .times(1, count: 0, .u8(1, "pt")))) }
@Sendable private func shapeB4() throws -> Scheme { try Scheme(1, .u8(0, "n"), .flags(1, .times(1, count: 0, .u8(1, "pt")))) }
@Sendable private func shapeB6() throws -> Scheme {
    let fb = FlagByte("fb")
    return try Scheme(1, .u8(0, "n"), .flagByte(fb), fb.bit(.times(1, count: 0, .u8(1, "pt"))))
}
/// reference_loop22.md 3b and 3c: the repeat shapes.
@Sendable private func repeatOne() throws -> Scheme { try Scheme(1, .repeat(0, .u8(0, "k"))) }
@Sendable private func repeatTwo() throws -> Scheme { try Scheme(1, .repeat(0, .u8(0, "a"), .u8(1, "b"))) }
@Sendable private func repeatNX() throws -> Scheme { try Scheme(1, .repeat(0, .u8(0, "n"), .u8(1, "x"))) }

private func u8List(_ v: [UInt8?]) -> [Any?] { u8s(v) }

/// AC-1 (SW-3): the reference rows of `reference_loop22.md` section 3 and `flags_member_reference_cases_loop18.md`
/// (R2, TG) that no earlier Swift test pins; TypeScript's hex and its unpacked rows (a round with no
/// value is `nil`, TypeScript's `undefined`).
@Suite struct ParityReferenceTests {
    static let shapeARows: [UnpackRow] = [
        UnpackRow("A2 empty", shapeA, "01020000", want: ["c": UInt8(2), "v": u8List([nil, nil])], row: { ["c": 2, "v": [Int]()] }),
        UnpackRow("A3 absent", shapeA, "01020000", want: ["c": UInt8(2), "v": u8List([nil, nil])], row: { ["c": 2] }),
        UnpackRow("A4 full", shapeA, "010201050106", want: ["c": UInt8(2), "v": u8List([5, 6])], row: { ["c": 2, "v": [5, 6]] }),
        UnpackRow("A5 an absent entry", shapeA, "0102010500", want: ["c": UInt8(2), "v": u8List([5, nil])],
                  row: { ["c": 2, "v": [5, nil] as [Int?]] }),
        UnpackRow("A6 lone", shapeA, "010201050105", want: ["c": UInt8(2), "v": u8List([5, 5])], row: { ["c": 2, "v": 5] }),
        UnpackRow("A7 count 0", shapeA, "0100", want: ["c": UInt8(0)], row: { ["c": 0] }),
        UnpackRow("A8", shapeAWithW, "01020101050200", want: ["c": UInt8(2), "w": u8List([1, 2]), "v": u8List([5, nil])],
                  row: { ["c": 2, "w": [1, 2], "v": [5]] }),
        UnpackRow("A9", shapeAWithW, "010201000200", want: ["c": UInt8(2), "w": u8List([1, 2]), "v": u8List([nil, nil])],
                  row: { ["c": 2, "w": [1, 2], "v": [Int]()] }),
        UnpackRow("A10", shapeAWithW, "0102010105020106", want: ["c": UInt8(2), "w": u8List([1, 2]), "v": u8List([5, 6])],
                  row: { ["c": 2, "w": [1, 2], "v": [5, 6]] }),
        UnpackRow("A11", shapeAWithW, "010301010502000300",
                  want: ["c": UInt8(3), "w": u8List([1, 2, 3]), "v": u8List([5, nil, nil])],
                  row: { ["c": 3, "w": [1, 2, 3], "v": [5]] }),
    ]

    @Test(arguments: shapeARows)
    func packAndUnpack_shortTimesListUnderFlagsInTheBody_givesTypeScriptHexAndRow(_ c: UnpackRow) throws {
        try expectUnpacks(c)
    }

    static let shapeBRows: [UnpackRow] = [
        UnpackRow("B1 lone", shapeB1, "0103020505", want: ["n": UInt8(2), "pt": u8List([5, 5])], row: { ["n": 2, "pt": 5] }),
        UnpackRow("B1 count 0", shapeB1, "010100", want: ["n": UInt8(0)], row: { ["n": 0] }),
        UnpackRow("B4 full", shapeB4, "0102010506", want: ["n": UInt8(2), "pt": u8List([5, 6])], row: { ["n": 2, "pt": [5, 6]] }),
        UnpackRow("B4 lone", shapeB4, "0102010505", want: ["n": UInt8(2), "pt": u8List([5, 5])], row: { ["n": 2, "pt": 5] }),
        UnpackRow("B4 count 0", shapeB4, "010000", want: ["n": UInt8(0)], row: { ["n": 0] }),
        UnpackRow("B6 full", shapeB6, "0102010506", want: ["n": UInt8(2), "pt": u8List([5, 6])], row: { ["n": 2, "pt": [5, 6]] }),
        UnpackRow("B6 lone", shapeB6, "0102010505", want: ["n": UInt8(2), "pt": u8List([5, 5])], row: { ["n": 2, "pt": 5] }),
        UnpackRow("B6 count 0", shapeB6, "010000", want: ["n": UInt8(0)], row: { ["n": 0] }),
    ]

    @Test(arguments: shapeBRows)
    func packAndUnpack_timesAsAFlagsMemberOrSplitBit_givesTypeScriptHexAndRow(_ c: UnpackRow) throws { try expectUnpacks(c) }

    static let shapeBRefusals: [RoundRefusal] = {
        let shapes: [(String, @Sendable () throws -> Scheme)] = [("B1", shapeB1), ("B4", shapeB4), ("B6", shapeB6)]
        return shapes.flatMap { name, scheme in [
            RoundRefusal("\(name) short", scheme, field: 1, "pt", "missing pt") { ["n": 2, "pt": [5]] },
            RoundRefusal("\(name) empty", scheme, field: 1, "pt", "missing pt") { ["n": 2, "pt": [Int]()] },
            RoundRefusal("\(name) absent", scheme, field: 1, "pt", "missing pt") { ["n": 2] },
            RoundRefusal("\(name) too long", scheme, field: 1, "pt", "pt: 2 items, times count 1") { ["n": 1, "pt": [5, 6]] },
        ] }
    }()

    @Test(arguments: shapeBRefusals)
    func pack_shortOrLongTimesListAsAFlagsMember_isRefusedNamingIt(_ c: RoundRefusal) throws { try expectRefused(c) }

    static let repeatRows: [UnpackRow] = [
        UnpackRow("R1a lone value", repeatOne, "0107", want: ["k": u8List([7])], row: { ["k": 7] }),
        UnpackRow("R1b one", repeatOne, "0107", want: ["k": u8List([7])], row: { ["k": [7]] }),
        UnpackRow("R1b two", repeatOne, "010708", want: ["k": u8List([7, 8])], row: { ["k": [7, 8]] }),
        UnpackRow("R2a lone b", repeatTwo, "0101070207", want: ["a": u8List([1, 2]), "b": u8List([7, 7])],
                  row: { ["a": [1, 2], "b": 7] }),
        UnpackRow("R2b lone a", repeatTwo, "0101050106", want: ["a": u8List([1, 1]), "b": u8List([5, 6])],
                  row: { ["a": 1, "b": [5, 6]] }),
        UnpackRow("R2c both full", repeatTwo, "0101050206", want: ["a": u8List([1, 2]), "b": u8List([5, 6])],
                  row: { ["a": [1, 2], "b": [5, 6]] }),
        UnpackRow("R3b extra entry ignored", whenRepeat, "01010902", want: ["k": u8List([1, 2]), "v": u8List([9, nil])],
                  row: { ["k": [1, 2], "v": [9, 8]] }),
        UnpackRow("R3c", whenRepeat, "0101090108", want: ["k": u8List([1, 1]), "v": u8List([9, 8])],
                  row: { ["k": [1, 1], "v": [9, 8]] }),
        UnpackRow("R3e lone", whenRepeat, "0101090109", want: ["k": u8List([1, 1]), "v": u8List([9, 9])],
                  row: { ["k": [1, 1], "v": 9] }),
        UnpackRow("R3f no value needed", whenRepeat, "010202", want: ["k": u8List([2, 2]), "v": u8List([nil, nil])],
                  row: { ["k": [2, 2], "v": [9]] }),
        UnpackRow("C1", repeatNX, "0101050206", want: ["n": u8List([1, 2]), "x": u8List([5, 6])], row: { ["n": [1, 2], "x": [5, 6]] }),
        UnpackRow("C3 lone x", repeatNX, "0101050205", want: ["n": u8List([1, 2]), "x": u8List([5, 5])], row: { ["n": [1, 2], "x": 5] }),
        UnpackRow("C4 nothing", repeatNX, "01", want: [:], row: { [:] }),
    ]

    @Test(arguments: repeatRows)
    func packAndUnpack_repeatPerNameLists_giveTypeScriptHexAndRow(_ c: UnpackRow) throws { try expectUnpacks(c) }

    static let repeatRefusals: [RoundRefusal] = [
        RoundRefusal("R2d short required b", repeatTwo, field: 1, "b", "missing b") { ["a": [1, 2, 3], "b": [5]] },
        RoundRefusal("R2e short required a", repeatTwo, field: 0, "a", "missing a") { ["a": [1], "b": [5, 6, 7]] },
        RoundRefusal("R2f empty required b", repeatTwo, field: 1, "b", "missing b") { ["a": [1, 2], "b": [Int]()] },
        RoundRefusal("R2f absent required b", repeatTwo, field: 1, "b", "missing b") { ["a": [1, 2]] },
        RoundRefusal("R3d short held when", whenRepeat, field: 1, "v", "missing v") { ["k": [1, 1], "v": [9]] },
        RoundRefusal("R3g absent but needed", whenRepeat, field: 1, "v", "missing v") { ["k": [1, 2]] },
        RoundRefusal("R3g absent but needed, both", whenRepeat, field: 1, "v", "missing v") { ["k": [1, 1]] },
        RoundRefusal("C2 x missing", repeatNX, field: 1, "x", "missing x") { ["n": [1, 2]] },
        RoundRefusal("C2 n missing", repeatNX, field: 0, "n", "missing n") { ["x": [5, 6]] },
    ]

    @Test(arguments: repeatRefusals)
    func pack_repeatRequiredListShortOrAbsent_isRefusedNamingIt(_ c: RoundRefusal) throws { try expectRefused(c) }

    static let loop18Rows: [UnpackRow] = [
        UnpackRow("R-two-values-1", twoInRepeat, "0101035a000506",
                  want: ["mode": UInt8(1), "pt": u8List([5]), "pu": u8List([6]), "heading": UInt16(90)],
                  row: { ["mode": 1, "pt": [5], "pu": [6], "heading": 90] }),
        UnpackRow("R-two-values-2", twoInRepeat, "0101035a0005070608",
                  want: ["mode": UInt8(1), "pt": u8List([5, 6]), "pu": u8List([7, 8]), "heading": UInt16(90)],
                  row: { ["mode": 1, "pt": [5, 6], "pu": [7, 8], "heading": 90] }),
        UnpackRow("TG only times", timesInGroup, "0102010506", want: ["n": UInt8(2), "g": ["pt": u8List([5, 6])]],
                  row: { ["n": 2, "g": ["pt": [5, 6]]] }),
        UnpackRow("TG only n", timesInGroup, "010000", want: ["n": UInt8(0)], row: { ["n": 0] }),
    ]

    @Test(arguments: loop18Rows)
    func packAndUnpack_loop18ReferenceRow_givesTypeScriptHexAndRow(_ c: UnpackRow) throws { try expectUnpacks(c) }
}
