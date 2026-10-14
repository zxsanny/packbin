import Packbin
import Testing

/// AC-1 (SW-2): the README data-type examples for repeat, sized, two-bit slots, bits, packed and
/// times, in the map form. Hex from the README and TypeScript at HEAD (`round-values`, the README
/// Repeat and Times notes); each packs to it, the hex unpacks, and the unpacked row packs to it again.
@Suite struct ReadmeRoundTests {
    static let rows: [PackRow] = [
        PackRow("repeat two points", { try Scheme(1, .repeat(0, .i32(0, "lat"), .i32(1, "lon"))) },
                "010a000000140000001e00000028000000") { ["lat": [10, 30], "lon": [Int32(20), 40]] },
        PackRow("repeat when", whenRepeat, "01010902") { ["k": [1, 2], "v": [9]] },
        PackRow("sized uav", { try Scheme(1, .u16(0, "n"), .sized(1, "payload", count: 0)) },
                "010300756176") { ["n": 3, "payload": Array("uav".utf8)] },
        PackRow("u2 four slots", { try Scheme(1, .u2(.slot(0, "a"), .slot(1, "b"), .slot(2, "c"), .slot(3, "d"))) },
                "01e4") { ["a": 0, "b": 1, "c": 2, "d": 3] },
        PackRow("u2 one slot", { try Scheme(1, .u2(.slot(0, "a"))) }, "0101") { ["a": 1] },
        PackRow("bits eight", { try Scheme(1, .u8(0, "n"), .bits(1, "segs", count: 0)) }, "0108ff") {
            ["n": 8, "segs": [1, 1, 1, 1, 1, 1, 1, 1]]
        },
        PackRow("bits nine", { try Scheme(1, .u8(0, "n"), .bits(1, "segs", count: 0)) }, "0109ff01") {
            ["n": 9, "segs": [1, 1, 1, 1, 1, 1, 1, 1, 1]]
        },
        PackRow("packed width 2", { try Scheme(1, .u8(0, "n"), .packed(2, 1, "kinds", count: 0)) }, "0104e4") {
            ["n": 4, "kinds": [0, 1, 2, 3]]
        },
        PackRow("packed width 1 bias -1", { try Scheme(1, .u8(0, "n"), .packed(1, 1, "legs", count: 0, bias: -1)) },
                "0109ff") { ["n": 9, "legs": [1, 1, 1, 1, 1, 1, 1, 1]] },
        PackRow("packed count 1 bias -1 writes nothing",
                { try Scheme(1, .u8(0, "n"), .packed(1, 1, "legs", count: 0, bias: -1)) }, "0101") {
            ["n": 1, "legs": [Int]()]
        },
        PackRow("times then tail", routeScheme, "01020a000000140000001e0000002800000007") {
            ["n": 2, "lat": [10, 30], "lon": [20, 40], "tail": 7]
        },
        PackRow("times lone scalar, count 0", { try Scheme(1, .u8(0, "a"), .times(1, count: 0, .u8(1, "x"))) },
                "0100") { ["a": 0, "x": 5] },
        PackRow("times flags short bool list",
                { try Scheme(1, .u8(0, "c"), .times(1, count: 0, .flags(1, .bool(1, "on")))) }, "01020100") {
            ["c": 2, "on": [true]]
        },
        PackRow("times flags short u8 list",
                { try Scheme(1, .u8(0, "c"), .times(1, count: 0, .flags(1, .u8(1, "v")))) }, "0102010500") {
            ["c": 2, "v": [5]]
        },
        PackRow("repeat scalar to every round", { try Scheme(1, .repeat(0, .u8(0, "x"), .u8(1, "y"))) },
                "0101040105") { ["x": 1, "y": [4, 5]] },
        PackRow("repeat flags scalar sets every bit", { try Scheme(1, .repeat(0, .flags(0, .u8(0, "a")), .u8(1, "b"))) },
                "01010501010502") { ["a": 5, "b": [1, 2]] },
        PackRow("times scalar to every round",
                { try Scheme(1, .u8(0, "n"), .times(1, count: 0, .u8(1, "x"), .u8(2, "y"))) }, "010201040105") {
            ["n": 2, "x": 1, "y": [4, 5]]
        },
    ]

    @Test(arguments: rows)
    func packAndUnpack_readmeRoundExample_givesTheReadmeHexBothWays(_ c: PackRow) throws {
        // Arrange
        let scheme = try c.scheme()

        // Act
        let raw = try pack(scheme, c.row())
        let back = try unpackMap(bytes(c.wire), scheme)
        let again = try packHex(scheme, back)

        // Assert
        #expect(mismatchedBytes(raw, bytes(c.wire)) == 0, "\(c.name): \(hex(raw))")
        #expect(again == c.wire, "\(c.name) repack")
    }

    @Test func pack_readmeFlagsRoundMembers_giveTheReadmeHex() throws {
        // Arrange
        let when = try Scheme(1, .u8(0, "mode"), .flags(1, .when(1, .eq(0, 1), .u8(1, "speed")), .u16(2, "heading")))
        let times = try Scheme(1, .u8(0, "n"), .flags(1, .times(1, count: 0, .u8(1, "pt")), .u16(2, "heading")))
        let repeated = try Scheme(1, .u8(0, "mode"), .flags(1, .u16(1, "heading"), .repeat(2, .u8(2, "pt"))))
        let cases: [(Scheme, [String: Any], String)] = [
            (when, ["mode": 1, "speed": 7, "heading": 90], "010103075a00"),
            (when, ["mode": 0, "speed": 7, "heading": 90], "0100025a00"),
            (times, ["n": 0, "pt": [Int](), "heading": 90], "0100025a00"),
            (times, ["n": 1, "pt": [5], "heading": 90], "010103055a00"),
            (times, ["n": 2, "pt": [5, 6], "heading": 90], "01020305065a00"),
            (repeated, ["mode": 1, "heading": 90], "0101015a00"),
            (repeated, ["mode": 1, "heading": 90, "pt": [5]], "0101035a0005"),
            (repeated, ["mode": 1, "heading": 90, "pt": [5, 6]], "0101035a000506"),
        ]

        // Act
        let wires = try cases.map { try packHex($0.0, $0.1) }

        // Assert
        #expect(wires == cases.map(\.2))
    }

    /// The route fixture of schema.md (borrowed-count): header, flags with a bool, a count, packed
    /// kinds, times pairs and a when on the bool holding packed(1) bias -1.
    @Test func packAndUnpack_routeFixture_repacksAndNamesTheShortField() throws {
        // Arrange
        let routeHex = "3410001500062d00020d0065cd1d00a3e111108ccd1d10cae11101"
        let route = try Scheme(0x34,
                               .u16(0, "sid"), .u16(1, "name"),
                               .flags(2, .u16(2, "unit"), .bool(3, "straight"), .u16(4, "routeId")),
                               .u8(5, "count"),
                               .packed(2, 6, "kinds", count: 5),
                               .times(7, count: 5, .i32(7, "lat"), .i32(8, "lon")),
                               .when(9, .eq(3, true), .packed(1, 9, "mask", count: 5, bias: -1)))

        // Act
        var back = try unpackMap(bytes(routeHex), route)
        let again = try packHex(route, back)
        back["straight"] = false
        let cleared = try packHex(route, back)
        let short = shortError { try unpackMap(Array(bytes(routeHex).prefix(24)), route) }

        // Assert
        let want: [String: Any] = [
            "sid": UInt16(16), "name": UInt16(21), "straight": true, "routeId": UInt16(45), "count": UInt8(2),
            "kinds": [UInt8(1), 3], "lat": [Int32(500_000_000), Int32(500_010_000)] as [Any?],
            "lon": [Int32(300_000_000), Int32(300_010_000)] as [Any?], "mask": [UInt8(1)],
        ]
        #expect(again == routeHex)
        #expect(canon(try unpackMap(bytes(routeHex), route)) == canon(want))
        #expect(cleared == "3410001500042d00020d0065cd1d00a3e111108ccd1d10cae111")
        #expect(short?.0 == "lon" && short?.1 == 4 && short?.2 == 2)
    }

    @Test func unpack_shortCountedAndRoundBuffers_nameTheFieldNeededAndLeft() throws {
        // Arrange
        let sized = try Scheme(1, .u16(0, "n"), .sized(1, "payload", count: 0))
        let points = try Scheme(1, .repeat(0, .i32(0, "lat"), .i32(1, "lon")))
        let u2 = try Scheme(1, .u8(0, "k"), .u2(.slot(1, "a"), .slot(2, "b")))

        // Act
        let shortSized = shortError { try unpackMap(bytes("0103007561"), sized) }
        let shortRound = shortError { try unpackMap(bytes("010a00000014"), points) }
        let shortSlots = shortError { try unpackMap(bytes("0107"), u2) }
        let trailing = packbinError { try unpackMap(bytes("010300756176ff"), sized) }

        // Assert
        #expect(shortSized?.0 == "payload" && shortSized?.1 == 3 && shortSized?.2 == 2)
        #expect(shortRound?.0 == "lon" && shortRound?.1 == 4 && shortRound?.2 == 1)
        #expect(shortSlots?.0 == "a" && shortSlots?.1 == 1 && shortSlots?.2 == 0)
        #expect(trailing?.kind == .trailing && trailing?.left == 1)
    }
}

@Sendable func routeScheme() throws -> Scheme {
    try Scheme(1, .u8(0, "n"), .times(1, count: 0, .i32(1, "lat"), .i32(2, "lon")), .u8(3, "tail"))
}
