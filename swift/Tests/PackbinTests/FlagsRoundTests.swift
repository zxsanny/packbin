import Packbin
import Testing

@Sendable func timesInFlags() throws -> Scheme {
    try Scheme(1, .u8(0, "n"), .flags(1, .times(1, count: 0, .u8(1, "pt")), .u16(2, "heading")))
}
@Sendable func timesInSplit() throws -> Scheme {
    let fb = FlagByte("m")
    return try Scheme(1, .u8(0, "n"), .flagByte(fb), fb.bit(.times(1, count: 0, .u8(1, "pt"))), fb.bit(.u16(2, "heading")))
}
@Sendable func timesInGroup() throws -> Scheme {
    try Scheme(1, .u8(0, "n"), .flags(1, .group(1, "g", .times(1, count: 0, .u8(1, "pt"))), .u16(2, "heading")))
}
@Sendable func repeatInFlags() throws -> Scheme {
    try Scheme(1, .u8(0, "mode"), .flags(1, .u16(1, "heading"), .repeat(2, .u8(2, "pt"))))
}
@Sendable func twoInTimes() throws -> Scheme {
    try Scheme(1, .u8(0, "n"), .flags(1, .times(1, count: 0, .u8(1, "pt"), .u8(2, "pu")), .u16(3, "heading")))
}
@Sendable func twoInRepeat() throws -> Scheme {
    try Scheme(1, .u8(0, "mode"), .flags(1, .u16(1, "heading"), .repeat(2, .u8(2, "pt"), .u8(3, "pu"))))
}
@Sendable func groupWithFlagsInSplitBit() throws -> Scheme {
    let fb = FlagByte("m")
    return try Scheme(1, .flagByte(fb), fb.bit(.group(0, "g", .u8(0, "a"), .flags(1, .u8(1, "c")))))
}

/// AC-2 (SW-3), TypeScript `flags-times-repeat-member` and `flags-under-split-bit`: a times or repeat
/// as a flags member, a split bit's field, or in a group under flags (the group's values a map of
/// their own, Go-4 A) is written like any other value: its bit is set exactly when it writes a value.
@Suite struct FlagsRoundTests {
    static let members: [UnpackRow] = {
        let h = UInt16(90)
        var rows: [UnpackRow] = []
        for (kind, scheme) in [("flags", timesInFlags), ("split", timesInSplit)] as [(String, @Sendable () throws -> Scheme)] {
            rows += [
                UnpackRow("\(kind) times 0 rounds", scheme, "0100025a00", want: ["n": UInt8(0), "heading": h],
                          row: { ["n": 0, "heading": 90] }),
                UnpackRow("\(kind) times 1 round", scheme, "010103055a00", want: ["n": UInt8(1), "pt": u8s([5]), "heading": h],
                          row: { ["n": 1, "pt": [5], "heading": 90] }),
                UnpackRow("\(kind) times 2 rounds", scheme, "01020305065a00",
                          want: ["n": UInt8(2), "pt": u8s([5, 6]), "heading": h], row: { ["n": 2, "pt": [5, 6], "heading": 90] }),
            ]
        }
        return rows + [
            UnpackRow("group times 0 rounds", timesInGroup, "0100025a00", want: ["n": UInt8(0), "heading": h],
                      row: { ["n": 0, "heading": 90] }),
            UnpackRow("group times 1 round", timesInGroup, "010103055a00",
                      want: ["n": UInt8(1), "g": ["pt": u8s([5])], "heading": h], row: { ["n": 1, "g": ["pt": [5]], "heading": 90] }),
            UnpackRow("group times 2 rounds", timesInGroup, "01020305065a00",
                      want: ["n": UInt8(2), "g": ["pt": u8s([5, 6])], "heading": h],
                      row: { ["n": 2, "g": ["pt": [5, 6]], "heading": 90] }),
            UnpackRow("times only", timesInFlags, "0102010506", want: ["n": UInt8(2), "pt": u8s([5, 6])],
                      row: { ["n": 2, "pt": [5, 6]] }),
            UnpackRow("count only", timesInFlags, "010000", want: ["n": UInt8(0)], row: { ["n": 0] }),
            UnpackRow("two values, one round", twoInTimes, "01010305065a00",
                      want: ["n": UInt8(1), "pt": u8s([5]), "pu": u8s([6]), "heading": h],
                      row: { ["n": 1, "pt": [5], "pu": [6], "heading": 90] }),
            UnpackRow("two values, two rounds", twoInTimes, "010203050706085a00",
                      want: ["n": UInt8(2), "pt": u8s([5, 6]), "pu": u8s([7, 8]), "heading": h],
                      row: { ["n": 2, "pt": [5, 6], "pu": [7, 8], "heading": 90] }),
            UnpackRow("repeat 0 rounds", repeatInFlags, "0101015a00", want: ["mode": UInt8(1), "heading": h],
                      row: { ["mode": 1, "heading": 90] }),
            UnpackRow("repeat 1 round", repeatInFlags, "0101035a0005", want: ["mode": UInt8(1), "pt": u8s([5]), "heading": h],
                      row: { ["mode": 1, "pt": [5], "heading": 90] }),
            UnpackRow("repeat 2 rounds", repeatInFlags, "0101035a000506",
                      want: ["mode": UInt8(1), "pt": u8s([5, 6]), "heading": h], row: { ["mode": 1, "pt": [5, 6], "heading": 90] }),
            UnpackRow("repeat only", repeatInFlags, "0101020506", want: ["mode": UInt8(1), "pt": u8s([5, 6])],
                      row: { ["mode": 1, "pt": [5, 6]] }),
            UnpackRow("repeat none", repeatInFlags, "010100", want: ["mode": UInt8(1)], row: { ["mode": 1] }),
            UnpackRow("repeat two values from the wire", twoInRepeat, "0101035a0005060708",
                      want: ["mode": UInt8(1), "pt": u8s([5, 7]), "pu": u8s([6, 8]), "heading": h]),
            UnpackRow("count in the scope written", {
                try Scheme(1, .u8(0, "p"), .flags(1, .times(1, count: 0, .u8(1, "pt")), .u16(2, "heading")))
            }, "010103055a00", want: ["p": UInt8(1), "pt": u8s([5]), "heading": h], row: { ["p": 1, "pt": [5], "heading": 90] }),
            UnpackRow("count member skipped, times bit clear", {
                try Scheme(1, .flags(0, .u8(0, "n"), .times(1, count: 0, .u8(1, "pt")), .u16(2, "heading")))
            }, "01045a00", want: ["heading": h], row: { ["heading": 90] }),
        ]
    }()

    @Test(arguments: members)
    func packAndUnpack_roundAsAFlagsMember_setsItsBitExactlyWhenItWrites(_ c: UnpackRow) throws {
        try expectUnpacks(c)
    }

    static let memberRefusals: [RoundRefusal] = {
        var rows: [RoundRefusal] = []
        let shapes: [(String, @Sendable () throws -> Scheme, Bool)] = [
            ("flags", timesInFlags, false), ("split", timesInSplit, false), ("group", timesInGroup, true),
        ]
        for (kind, scheme, grouped) in shapes {
            let with = { @Sendable (count: Int, pt: [Int]?) -> [String: Any] in
                var row: [String: Any] = ["n": count, "heading": 90]
                if let pt { row[grouped ? "g" : "pt"] = grouped ? ["pt": pt] as [String: Any] : pt }
                return row
            }
            rows += [
                RoundRefusal("\(kind) list shorter than the count", scheme, field: 1, "pt", "missing pt") { with(2, [5]) },
                RoundRefusal("\(kind) body values missing", scheme, field: 1, "pt", "missing pt") { with(1, nil) },
                RoundRefusal("\(kind) count 0 with a list", scheme, field: 1, "pt", "times count 0") { with(0, [5]) },
                RoundRefusal("\(kind) list longer than the count", scheme, field: 1, "pt", "times count 1") { with(1, [5, 6]) },
            ]
        }
        return rows + [
            RoundRefusal("second body value missing", twoInTimes, field: 2, "pu", "missing pu") {
                ["n": 1, "pt": [5], "heading": 90]
            },
            RoundRefusal("repeat second body value missing", twoInRepeat, field: 3, "pu", "missing pu") {
                ["mode": 1, "pt": [5], "heading": 90]
            },
        ]
    }()

    @Test(arguments: memberRefusals)
    func pack_roundFlagsMemberItsBitCannotCarry_isRefusedNamingTheValue(_ c: RoundRefusal) throws {
        try expectRefused(c)
    }

    static let underSplit: [UnpackRow] = [
        UnpackRow("flags in a group under a split bit", groupWithFlagsInSplitBit, "0101010102",
                  want: ["g": ["a": UInt8(1), "c": UInt8(2)]], row: { ["g": ["a": 1, "c": 2]] }),
        UnpackRow("absent member stays absent", groupWithFlagsInSplitBit, "01010100", want: ["g": ["a": UInt8(1)]],
                  row: { ["g": ["a": 1]] }),
        UnpackRow("absent group", groupWithFlagsInSplitBit, "0100", want: [:], row: { [:] }),
        UnpackRow("flags in flags", { try Scheme(1, .flags(0, .flags(0, .u8(0, "c")))) }, "01010102", want: ["c": UInt8(2)],
                  row: { ["c": 2] }),
        UnpackRow("flags in flags absent", { try Scheme(1, .flags(0, .flags(0, .u8(0, "c")))) }, "0100", want: [:],
                  row: { [:] }),
        UnpackRow("flags three deep", { try Scheme(1, .flags(0, .flags(0, .flags(0, .u8(0, "c"))))) }, "0101010109",
                  want: ["c": UInt8(9)], row: { ["c": 9] }),
        UnpackRow("a split bit holding flags", {
            let fb = FlagByte("m")
            return try Scheme(1, .flagByte(fb), fb.bit(.flags(0, .u8(0, "c"))))
        }, "01010103", want: ["c": UInt8(3)], row: { ["c": 3] }),
        UnpackRow("two flags in one group under a split bit", {
            let fb = FlagByte("m")
            return try Scheme(1, .flagByte(fb), fb.bit(.group(0, "g", .flags(0, .u8(0, "c")), .flags(1, .u8(1, "d")))))
        }, "010101010102", want: ["g": ["c": UInt8(1), "d": UInt8(2)]], row: { ["g": ["c": 1, "d": 2]] }),
    ]

    @Test(arguments: underSplit)
    func packAndUnpack_flagsUnderASplitBit_giveTypeScriptHex(_ c: UnpackRow) throws { try expectUnpacks(c) }

    static let underSplitRefusals: [RoundRefusal] = [
        RoundRefusal("a missing required member in a given group", groupWithFlagsInSplitBit, field: 0, "a", "missing a") {
            ["g": ["c": 2]]
        },
        RoundRefusal("a member given flat (Go-4; TypeScript: missing a)", groupWithFlagsInSplitBit, field: 1, "c",
                     "member of group g") { ["c": 2] },
    ]

    @Test(arguments: underSplitRefusals)
    func pack_flagsUnderASplitBitRowTheSchemeCannotWrite_isRefused(_ c: RoundRefusal) throws { try expectRefused(c) }

    /// A round in flags nested in flags, a split bit or a group under flags: the outer bit looks into
    /// the round as the inner one does.
    static let nestedFlags: [UnpackRow] = {
        let inFlags: @Sendable () throws -> Scheme = {
            try Scheme(1, .u8(0, "n"), .flags(1, .flags(1, .times(1, count: 0, .u8(1, "pt")))))
        }
        let inSplit: @Sendable () throws -> Scheme = {
            let fb = FlagByte("m")
            return try Scheme(1, .u8(0, "n"), .flagByte(fb), fb.bit(.flags(1, .repeat(1, .u8(1, "pt")))))
        }
        return [
            UnpackRow("times in flags in flags", inFlags, "0101010105", want: ["n": UInt8(1), "pt": u8s([5])],
                      row: { ["n": 1, "pt": [5]] }),
            UnpackRow("count 0 in flags in flags", inFlags, "010000", want: ["n": UInt8(0)], row: { ["n": 0] }),
            UnpackRow("repeat in flags in a split bit", inSplit, "010101010506", want: ["n": UInt8(1), "pt": u8s([5, 6])],
                      row: { ["n": 1, "pt": [5, 6]] }),
            UnpackRow("repeat with no round", inSplit, "010100", want: ["n": UInt8(1)], row: { ["n": 1] }),
            UnpackRow("times in flags in a group", timesInFlagsInGroup, "0101010105",
                      want: ["n": UInt8(1), "g": ["pt": u8s([5])]], row: { ["n": 1, "g": ["pt": [5]]] }),
        ]
    }()

    @Test(arguments: nestedFlags)
    func packAndUnpack_roundInNestedFlags_givesTypeScriptHex(_ c: UnpackRow) throws { try expectUnpacks(c) }

    @Test func pack_countAbove0InAGroupNotGiven_setsTheBitSoItsRoundsAreMissing() throws {
        try expectRefused(RoundRefusal("count above 0", timesInFlagsInGroup, field: 1, "pt", "missing pt") { ["n": 1] })
    }
}

@Sendable func timesInFlagsInGroup() throws -> Scheme {
    try Scheme(1, .u8(0, "n"), .flags(1, .group(1, "g", .flags(1, .times(1, count: 0, .u8(1, "pt"))))))
}
