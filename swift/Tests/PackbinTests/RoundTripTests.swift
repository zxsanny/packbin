import Packbin
import Testing

/// One round-roundtrip shape and what TypeScript at HEAD does with the same 3000 seeded packets: how
/// many unpack, the sum of their indexes, and how many hold two rounds or more (probed with the
/// TypeScript suite's generator; the unanchored group of TypeScript's `group` shape is anchored here,
/// as Swift has no unanchored group, and gives the same bytes).
struct RoundTripShape: CustomTestStringConvertible, Sendable {
    let name: String
    let scheme: @Sendable () throws -> Scheme
    let accepted: Int
    let indexSum: Int
    let manyRounds: Int
    var testDescription: String { name }
}

/// AC-2 (SW-3), TypeScript `round-roundtrip`: each body is built so that each byte 0..3 is a canonical
/// value of whatever reads it, so a packet that unpacks repacks to the same bytes, with one entry a
/// round for every name.
@Suite struct RoundTripTests {
    static let shapes: [RoundTripShape] = [
        RoundTripShape(name: "whenRepeat", scheme: whenRepeat, accepted: 2454, indexSum: 3_688_544, manyRounds: 2045),
        RoundTripShape(name: "boolFlags", scheme: flagsRepeat, accepted: 2030, indexSum: 3_063_199, manyRounds: 1614),
        RoundTripShape(name: "groupInFlags", scheme: {
            try Scheme(1, .repeat(0, .u8(0, "k"), .flags(1, .group(1, "mark", .u8(1, "g")), .u16(2, "n"))))
        }, accepted: 897, indexSum: 1_340_668, manyRounds: 505),
        RoundTripShape(name: "u2AndWhen", scheme: {
            try Scheme(1, .repeat(0, .u8(0, "k"), .u2(.slot(1, "p"), .slot(2, "q")), .when(3, .eq(0, 2), .u8(3, "v"))))
        }, accepted: 1411, indexSum: 2_113_279, manyRounds: 996),
        RoundTripShape(name: "group", scheme: {
            try Scheme(1, .repeat(0, .u8(0, "k"), .group(1, "row", .u8(1, "v"), .when(2, .eq(1, 1), .u8(2, "w")))))
        }, accepted: 1418, indexSum: 2_119_080, manyRounds: 1015),
        RoundTripShape(name: "whenWithFlags", scheme: {
            try Scheme(1, .repeat(0, .u8(0, "k"), .flags(1, .u8(1, "a"), .u8(2, "b")),
                                  .when(3, .eq(0, 1), .flags(3, .u8(3, "c"), .bool(4, "d")))))
        }, accepted: 963, indexSum: 1_441_661, manyRounds: 556),
        RoundTripShape(name: "splitFlagByte", scheme: {
            let fb = FlagByte("m")
            return try Scheme(1, .repeat(0, .flagByte(fb), fb.bit(.u8(0, "a")), fb.bit(.bool(1, "b"))))
        }, accepted: 2027, indexSum: 3_059_007, manyRounds: 1611),
        RoundTripShape(name: "countInRound", scheme: { try Scheme(1, .repeat(0, .u8(0, "n"), .sized(1, "p", count: 0))) },
                       accepted: 1266, indexSum: 1_891_780, manyRounds: 854),
        RoundTripShape(name: "whenTimes", scheme: {
            try Scheme(1, .u8(0, "a"), .times(1, count: 0, .u8(1, "k"), .when(2, .eq(1, 1), .u8(2, "v")),
                                              .flags(3, .u8(3, "f"), .bool(4, "g"))))
        }, accepted: 238, indexSum: 362_827, manyRounds: 120),
        RoundTripShape(name: "flagsTimes", scheme: flagsTimes, accepted: 207, indexSum: 325_652, manyRounds: 89),
    ]

    @Test(arguments: shapes)
    func packAndUnpack_seededRoundPackets_acceptAsTypeScriptAndRepack(_ shape: RoundTripShape) throws {
        // Arrange
        let scheme = try shape.scheme()
        var rng = Mulberry32(0x5eed)
        var (accepted, indexSum, manyRounds) = (0, 0, 0)

        // Act and Assert
        for i in 0..<3000 {
            let body = (0..<rng.pick(14)).map { _ in UInt8(rng.pick(4)) }
            let wire = [UInt8(1)] + body
            guard let row = try? unpackMap(wire, scheme) else { continue }
            accepted += 1
            indexSum += i
            #expect(try pack(scheme, row) == wire, "repack of \(hex(wire))")
            let sizes = Set(row.values.compactMap { ($0 as? [Any?])?.count })
            #expect(sizes.count <= 1, "\(hex(wire)): lists of different lengths \(sizes)")
            if (sizes.max() ?? 0) >= 2 { manyRounds += 1 }
        }
        #expect(accepted == shape.accepted && indexSum == shape.indexSum && manyRounds == shape.manyRounds,
                "\(accepted) \(indexSum) \(manyRounds)")
    }

    /// 37 names a round (k and 36 more): every name keeps one entry per round of a large packet.
    @Test func unpackMap_largeRepeat_keepsOneEntryPerRoundForEveryName() throws {
        // Arrange
        let members: [Field] = (0..<36).map { i in i % 2 == 0 ? .u8(1 + i, "f\(i)") : .u16(1 + i, "f\(i)") }
        let scheme = try Scheme(1, .repeat(0, .u8(0, "k"), .when(1, .eq(0, 1), members)))
        let rounds = 28_000
        let wire = [UInt8(1)] + [UInt8](repeating: 0, count: rounds)

        // Act
        let row = try unpackMap(wire, scheme)

        // Assert
        #expect(row.count == 37)
        #expect(row.values.allSatisfy { ($0 as? [Any?])?.count == rounds })
    }
}
