import Packbin
import Testing

private let droppedBeforeByte = "is not written before the flag byte, so its bit is clear"

/// The split-form schemes of `split-form-loud-pack`: WS/TS have the condition or count written before
/// the byte; the others after it, in an earlier bit, or never.
private func split(_ fields: (FlagByte) -> [Field]) throws -> Scheme { try Scheme(1, fields(FlagByte("m"))) }
@Sendable private func splitWS() throws -> Scheme {
    try split { m in [.u8(0, "mode"), .flagByte(m), m.bit(.when(1, .eq(0, 1), .u8(1, "speed"))), m.bit(.u16(2, "heading"))] }
}
@Sendable private func splitWhenAfter() throws -> Scheme {
    try split { m in [.flagByte(m), .u8(0, "mode"), m.bit(.when(1, .eq(0, 1), .u8(1, "speed"))), m.bit(.u16(2, "heading"))] }
}
@Sendable private func splitWhenInBit() throws -> Scheme {
    try split { m in [.flagByte(m), m.bit(.u8(0, "mode")), m.bit(.when(1, .eq(0, 1), .u8(1, "speed"))), m.bit(.u16(2, "heading"))] }
}
@Sendable private func splitTS() throws -> Scheme {
    try split { m in [.u8(0, "n"), .flagByte(m), m.bit(.times(1, count: 0, .u8(1, "pt"))), m.bit(.u16(2, "heading"))] }
}
@Sendable private func splitTimesAfter() throws -> Scheme {
    try split { m in [.flagByte(m), .u8(0, "n"), m.bit(.times(1, count: 0, .u8(1, "pt"))), m.bit(.u16(2, "heading"))] }
}
@Sendable private func splitTimesSkipped() throws -> Scheme {
    try split { m in [.flagByte(m), m.bit(.u8(0, "n")), m.bit(.times(1, count: 0, .u8(1, "pt"))), m.bit(.u16(2, "heading"))] }
}
@Sendable private func splitTimesInGroup() throws -> Scheme {
    try split { m in
        [.flagByte(m), m.bit(.u8(0, "n")), m.bit(.group(1, "g", .times(1, count: 0, .u8(1, "pt")))), m.bit(.u16(2, "heading"))]
    }
}
/// Review B2/B7: a times under a when inside a split bit, its count in a bit of its own.
@Sendable private func splitTimesInWhen() throws -> Scheme {
    try split { m in [.u8(0, "mode"), .flagByte(m), m.bit(.u8(1, "n")), m.bit(.when(2, .eq(0, 1), .times(2, count: 1, .u8(2, "pt"))))] }
}
@Sendable private func combinedTimes() throws -> Scheme {
    try Scheme(1, .flags(0, .u8(0, "n"), .times(1, count: 0, .u8(1, "pt"))))
}

/// AC-2 (SW-3), TypeScript `split-form-loud-pack` (AZ-2331), `split-form-reference` (AZ-2115) and
/// `loop21-parity-probes` U4: a split flag byte pack refuses a body its bit cannot carry, naming the
/// body member; a false condition stays a silent skip.
@Suite struct SplitRoundTests {
    static let refusals: [RoundRefusal] = [
        RoundRefusal("when condition after the byte", splitWhenAfter, field: 1, "speed", droppedBeforeByte) {
            ["mode": 1, "speed": 7, "heading": 90]
        },
        RoundRefusal("when condition in an earlier bit", splitWhenInBit, field: 1, "speed", droppedBeforeByte) {
            ["mode": 1, "speed": 7, "heading": 90]
        },
        RoundRefusal("times count after the byte", splitTimesAfter, field: 1, "pt", droppedBeforeByte) {
            ["n": 2, "pt": [5, 6], "heading": 90]
        },
        RoundRefusal("times count skipped", splitTimesSkipped, field: 1, "pt", droppedBeforeByte) { ["pt": [5], "heading": 90] },
        // The given group sets its bit, so its times finds no count (as TypeScript given {g: {pt: [5]}}).
        RoundRefusal("times count skipped, in a group", splitTimesInGroup, field: 1, "pt", "times: count n was not written") {
            ["g": ["pt": [5]], "heading": 90]
        },
        RoundRefusal("split count rows: count 0 with a list", splitTS, field: 1, "pt", "pt: 1 items, times count 0") {
            ["n": 0, "pt": [5], "heading": 90]
        },
        RoundRefusal("split count rows: short list", splitTS, field: 1, "pt", "missing pt") { ["n": 2, "pt": [5], "heading": 90] },
        RoundRefusal("combined skipped count with values (AZ-2360)", combinedTimes, field: 1, "pt",
                     "the count of its times is not written") { ["pt": [5]] },
        RoundRefusal("value out of range, when body", splitWS, field: 1, "speed", "does not fit") {
            ["mode": 1, "speed": 300, "heading": 90]
        },
        RoundRefusal("value out of range, times body", splitTS, field: 1, "pt", "does not fit") {
            ["n": 1, "pt": [300], "heading": 90]
        },
        RoundRefusal("B2 skipped count under a when in a split bit", splitTimesInWhen, field: 2, "pt", droppedBeforeByte) {
            ["mode": 1, "pt": [5]]
        },
        RoundRefusal("U4 body present", splitTimesAfter, field: 1, "pt", droppedBeforeByte) {
            ["n": 2, "pt": [5, 6], "heading": 90]
        },
    ]

    @Test(arguments: refusals)
    func pack_splitBodyItsBitCannotCarry_isRefusedNamingTheMember(_ c: RoundRefusal) throws { try expectRefused(c) }

    static let packs: [PackRow] = [
        PackRow("no body after the byte", splitWhenAfter, "0102015a00") { ["mode": 1, "heading": 90] },
        PackRow("no values after the byte", splitTimesAfter, "0102005a00") { ["n": 0, "heading": 90] },
        PackRow("no count", splitTimesSkipped, "01045a00") { ["heading": 90] },
        PackRow("false condition, source before", splitWS, "0100025a00") { ["mode": 0, "speed": 7, "heading": 90] },
        PackRow("false condition, source after", splitWhenAfter, "0102005a00") { ["mode": 0, "speed": 7, "heading": 90] },
        PackRow("reference true row", splitWS, "010103075a00") { ["mode": 1, "speed": 7, "heading": 90] },
        PackRow("reference no body", splitWS, "0101025a00") { ["mode": 1, "heading": 90] },
        PackRow("times 0", splitTS, "0100025a00") { ["n": 0, "heading": 90] },
        PackRow("times 1", splitTS, "010103055a00") { ["n": 1, "pt": [5], "heading": 90] },
        PackRow("times 2", splitTS, "01020305065a00") { ["n": 2, "pt": [5, 6], "heading": 90] },
        PackRow("times only", splitTS, "0102010506") { ["n": 2, "pt": [5, 6]] },
        PackRow("combined false when body", {
            try Scheme(1, .u8(0, "mode"), .flags(1, .when(1, .eq(0, 1), .u8(1, "speed")), .u16(2, "heading")))
        }, "0100025a00") { ["mode": 0, "speed": 7, "heading": 90] },
        PackRow("combined count skipped", combinedTimes, "0100") { [:] },
        PackRow("combined count given", combinedTimes, "0103020506") { ["n": 2, "pt": [5, 6]] },
        PackRow("B2 false condition", splitTimesInWhen, "010000") { ["mode": 0, "pt": [5]] },
        PackRow("B7 empty list under a skipped count in a when", splitTimesInWhen, "010100") { ["mode": 1, "pt": [Int]()] },
        PackRow("B7 empty list, bare", splitTimesSkipped, "01045a00") { ["pt": [Int](), "heading": 90] },
        PackRow("U4 body absent", splitTimesAfter, "0102025a00") { ["n": 2, "heading": 90] },
        PackRow("U4 body empty", splitTimesAfter, "0102025a00") { ["n": 2, "pt": [Int](), "heading": 90] },
        PackRow("U4 count 0, body absent", splitTimesAfter, "0102005a00") { ["n": 0, "heading": 90] },
        PackRow("AZ-2356 split count 0 after the byte, lone scalar", splitTimesAfter, "010000") { ["n": 0, "pt": 5] },
    ]

    @Test(arguments: packs)
    func pack_splitRowItsBitCanCarry_givesTypeScriptHex(_ c: PackRow) throws { try expectPacks(c) }

    static let unpacks: [UnpackRow] = [
        UnpackRow("false condition reads no body", splitWS, "0100025a00", want: ["mode": UInt8(0), "heading": UInt16(90)]),
        UnpackRow("times 2 reads its rounds", splitTS, "01020305065a00",
                  want: ["n": UInt8(2), "pt": u8s([5, 6]), "heading": UInt16(90)]),
        UnpackRow("reference row", splitReference, "010901045a00",
                  want: ["sid": UInt8(9), "shape": UInt8(4), "heading": UInt16(90)],
                  row: { ["sid": 9, "shape": 4, "heading": 90] }),
        UnpackRow("reference short row", splitReference, "010100", want: ["sid": UInt8(1)], row: { ["sid": 1] }),
    ]

    @Test(arguments: unpacks)
    func unpackMap_splitPacket_givesTypeScriptRow(_ c: UnpackRow) throws { try expectUnpacks(c) }
}

/// `split-form-reference`: a when between the flag byte and its bit.
@Sendable private func splitReference() throws -> Scheme {
    try split { m in [.u8(0, "sid"), .flagByte(m), .when(1, .eq(0, 9), .u8(1, "shape")), m.bit(.u16(2, "heading"))] }
}
