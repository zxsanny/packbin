import Packbin
import Testing

private let skippedCount = "pt: a value is given, but the count of its times is not written, so its bit is clear; "
    + "write the count before the times"
private let droppedSplit = "pt: a value is given, but the condition or count of its when or times is not written before the "
    + "flag byte, so its bit is clear; write that field before the flag byte"
private let u11Three = "v: the count c is 3 in the row, but no field wrote it (the when that holds it is clear), so the "
    + "member reads nothing; give the count 0, leave it out, or make the when hold"

/// AZ-2360: a combined flags whose first member is the count of its second.
@Sendable private func combinedCount() throws -> Scheme {
    try Scheme(1, .flags(0, .u8(0, "n"), .times(1, count: 0, .u8(1, "pt"))))
}
@Sendable private func combinedUnderWhen() throws -> Scheme {
    try Scheme(1, .u8(0, "mode"), .flags(1, .u8(1, "n"), .when(2, .eq(0, 1), .times(2, count: 1, .u8(2, "pt")))))
}
/// AZ-2363: a times inside a when inside a split bit; its count n sits under a when that is false for mode 1.
@Sendable private func timesInWhen() throws -> Scheme {
    let fb = FlagByte("fb")
    return try Scheme(1, .u8(0, "mode"), .when(1, .eq(0, 9), .u8(1, "n")), .flagByte(fb),
                      fb.bit(.when(2, .eq(0, 1), .times(2, count: 1, .u8(2, "pt")))))
}
@Sendable private func timesInWhenConditionAfterByte() throws -> Scheme {
    let fb = FlagByte("fb")
    return try Scheme(1, .flagByte(fb), .u8(0, "mode"), .when(1, .eq(0, 9), .u8(1, "n")),
                      fb.bit(.when(2, .eq(0, 1), .times(2, count: 1, .u8(2, "pt")))))
}

/// FT-X-82 (AZ-2437): a round body `u8 mode; when mode == 1 { u8 c }; <bit> { member(count c) }`.
struct RoundCountShape: CustomTestStringConvertible, Sendable {
    let name: String
    let scheme: @Sendable () throws -> Scheme
    let times: Bool
    var testDescription: String { name }
}

private let roundMembers: [(String, @Sendable (Int, Int) -> Field)] = [
    ("bits", { .bits($0, "v", count: $1) }), ("packed", { .packed(1, $0, "v", count: $1) }),
    ("sized", { .sized($0, "v", count: $1) }),
]

private let roundCountShapes: [RoundCountShape] = roundMembers.flatMap { kind, member in
    [true, false].flatMap { split -> [RoundCountShape] in
        let bit = { @Sendable (id: Int, count: Int) -> [Field] in
            guard split else { return [.flags(id, member(id, count))] }
            let fb = FlagByte("fb")
            return [.flagByte(fb), fb.bit(member(id, count))]
        }
        let form = split ? "split bit" : "combined flags"
        return [
            RoundCountShape(name: "times \(kind) \(form)", scheme: {
                try Scheme(1, [.u8(0, "n"), .times(1, count: 0, [.u8(1, "mode"), .when(2, .eq(1, 1), .u8(2, "c"))] + bit(3, 2))])
            }, times: true),
            RoundCountShape(name: "repeat \(kind) \(form)", scheme: {
                try Scheme(1, [.repeat(0, [.u8(0, "mode"), .when(1, .eq(0, 1), .u8(1, "c"))] + bit(2, 1))])
            }, times: false),
        ]
    }
}

/// AC-1 (SW-3): `loop20-parity-pins` rows no earlier Swift test pins (AZ-2360, AZ-2363, AZ-2359) and
/// FT-X-82 of `blackbox-tests-16-loop23-parity-rows.md`; every outcome probed in TypeScript at HEAD.
@Suite struct ParityLoop20Tests {
    static let refusals: [RoundRefusal] = [
        RoundRefusal("AZ-2360 AC-1 a list of values, the whole text", combinedCount, field: 1, "pt", skippedCount) {
            ["pt": [5, 6]]
        },
        RoundRefusal("AZ-2360 AC-1 a lone scalar is a value too", combinedCount, field: 1, "pt", "pt: a value is given") {
            ["pt": 5]
        },
        RoundRefusal("AZ-2360 a times under a when inside combined flags", combinedUnderWhen, field: 2, "pt",
                     "pt: a value is given, but the count of its times is not written") { ["mode": 1, "pt": [5]] },
        RoundRefusal("AZ-2363 AC-1 its count under a false when", timesInWhen, field: 2, "pt", droppedSplit) {
            ["mode": 1, "pt": [5, 6]]
        },
        RoundRefusal("AZ-2363 AC-1 the when condition written after the byte", timesInWhenConditionAfterByte, field: 2, "pt",
                     droppedSplit) { ["mode": 1, "pt": [5, 6]] },
    ]

    @Test(arguments: refusals)
    func pack_valueItsBitCannotCarry_isRefusedNamingTheMember(_ c: RoundRefusal) throws {
        try expectRefused(c)
        let error = packbinError { try pack(try c.scheme(), c.row()) }
        if c.reason == skippedCount || c.reason == droppedSplit { #expect(error?.reason == c.reason, "\(c.name)") }
    }

    static let packs: [PackRow] = [
        PackRow("AZ-2360 AC-2 an empty list packs the clear bit", combinedCount, "0100") { ["pt": [Int]()] },
        PackRow("AZ-2360 a false when stays silent", combinedUnderWhen, "010000") { ["mode": 0, "pt": [5]] },
        PackRow("AZ-2363 after the byte, no values", timesInWhenConditionAfterByte, "010001") { ["mode": 1] },
        PackRow("AZ-2363 after the byte, a false condition", timesInWhenConditionAfterByte, "010002") {
            ["mode": 2, "pt": [5, 6]]
        },
    ]

    @Test(arguments: packs)
    func pack_rowTheBitCanCarry_givesTypeScriptHex(_ c: PackRow) throws { try expectPacks(c) }

    /// AZ-2359: a TypeScript numeric enum is a plain number at runtime; Swift has no such value, and the
    /// spelling that is one (`rawValue`) packs the same byte. A Swift enum case and a string raw value
    /// are not integers and are refused naming the field (TypeScript: "expected a number for u8").
    @Test func pack_enumRawValueInAU8_packsTheIntegersByteAndAnEnumCaseIsRefused() throws {
        // Arrange
        let scheme = try Scheme(1, .u8(0, "level"))

        // Act
        let raw = try packHex(scheme, ["level": ParityLevel.high.rawValue])
        let enumCase = packbinError { try pack(scheme, ["level": ParityLevel.high]) }
        let text = packbinError { try pack(scheme, ["level": ParityMode.fast.rawValue]) }

        // Assert
        #expect(raw == "01c8")
        #expect(enumCase?.kind == .packError && enumCase?.field == 0 && enumCase?.name == "level")
        #expect(text?.field == 0 && text?.reason == "expected an integer for u8, got String")
    }

    @Test(arguments: roundCountShapes)
    func pack_shortCountListWhoseMissingRoundIsClear_givesTypeScriptHex(_ s: RoundCountShape) throws {
        // Arrange
        let scheme = try s.scheme()
        let row: [String: Any] = s.times ? ["n": 2, "mode": [1, 0], "c": [3]] : ["mode": [1, 0], "c": [3]]

        // Act
        let wire = try packHex(scheme, row)

        // Assert
        #expect(wire == (s.times ? "01020103000000" : "010103000000"))
    }

    @Test(arguments: roundCountShapes)
    func pack_roundCountListTypeScriptRefuses_isRefusedNamingTheMember(_ s: RoundCountShape) throws {
        // Arrange
        let scheme = try s.scheme()
        let unwritten: [String: Any] = s.times ? ["n": 2, "mode": [0, 1], "c": [3]] : ["mode": [0, 1], "c": [3]]
        let noEntry: [String: Any] = s.times ? ["n": 2, "mode": [0, 1], "c": [0]] : ["mode": [0, 1], "c": [0]]

        // Act
        let u11 = packbinError { try pack(scheme, unwritten) }
        let missing = packbinError { try pack(scheme, noEntry) }

        // Assert
        #expect(u11?.name == "v" && u11?.reason == u11Three, "\(String(describing: u11))")
        #expect(missing?.kind == .packError && missing?.name == "c" && missing?.reason == "missing c")
    }
}

enum ParityLevel: UInt8 { case low = 7, high = 200 }
enum ParityMode: String { case fast }
