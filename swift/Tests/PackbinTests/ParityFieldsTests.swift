import Packbin
import Testing

struct ParitySession: PackbinRow, Equatable {
    var login: UInt16 = 0
    var ts: UInt32 = 0
}

struct ParityHolder: PackbinRow, Equatable {
    var session: ParitySession?
}

@Sendable private func onFlags() throws -> Scheme { try Scheme(1, .flags(0, .bool(0, "on"))) }
@Sendable private func onSplit() throws -> Scheme {
    let m = FlagByte("m")
    return try Scheme(1, .flagByte(m), m.bit(.bool(0, "on")))
}
private func eightU8() -> [Field] { (0..<8).map { .u8($0, "f\($0)") } }
@Sendable private func eightFlags() throws -> Scheme { try Scheme(1, .flags(0, eightU8())) }
@Sendable private func eightSplit() throws -> Scheme {
    let m = FlagByte("m")
    return try Scheme(1, [.flagByte(m)] + eightU8().map { m.bit($0) })
}
/// packbin.test.ts: the session group, an unanchored TypeScript group, which is Swift's nested row.
@Sendable private func sessionScheme() throws -> Scheme {
    try Scheme(1, .flags(0, .group("session", .u16(0, "login"), .u32(1, "ts"))))
}
@Sendable private func wideFlags() throws -> Scheme {
    try Scheme(1, .flags(0, .u8(0, "b0"), .u8(1, "b1"), .u8(2, "b2"), .u8(3, "b3"), .u8(4, "b4"), .u16(5, "extra")))
}

/// AC-1 (SW-3): the rows of `bool-flag`, `fields` and `packbin` that no earlier Swift test pins, each
/// probed in TypeScript at HEAD.
@Suite struct ParityFieldsTests {
    static let boolSchemes: [RefusedScheme] = [
        RefusedScheme("bool in a times", field: 2, "inTimes", "bool inTimes: allowed only...") {
            try Scheme(1, .u8(0, "n"), .times(1, count: 0, .u8(1, "v"), .bool(2, "inTimes")))
        },
        RefusedScheme("bool in a dict", field: 0, "inDict", "bool inDict: allowed only...") {
            try Scheme(1, .dict("d", .bool(0, "inDict")))
        },
        RefusedScheme("a flags anchor that is not the next id", field: 1, "", "field id: expected 0, got 1") {
            try Scheme(1, .flags(1, .u16(0, "extra")))
        },
    ]

    @Test(arguments: boolSchemes)
    func init_schemeTypeScriptRefuses_isRefusedNamingTheMember(_ c: RefusedScheme) { expectRefused(c) }

    static let flagRows: [UnpackRow] = [
        UnpackRow("bool true sets the bit", onFlags, "0101", want: ["on": true], row: { ["on": true] }),
        UnpackRow("bool false leaves it clear", onFlags, "0100", want: [:], row: { ["on": false] }),
        UnpackRow("bool absent leaves it clear", onFlags, "0100", want: [:], row: { [:] }),
        UnpackRow("split bool true", onSplit, "0101", want: ["on": true], row: { ["on": true] }),
        UnpackRow("split bool false", onSplit, "0100", want: [:], row: { ["on": false] }),
        UnpackRow("eight flags bits, the first and the last", eightFlags, "01810107", want: ["f0": UInt8(1), "f7": UInt8(7)],
                  row: { ["f0": 1, "f7": 7] }),
        UnpackRow("eight split bits, the first and the last", eightSplit, "01810107", want: ["f0": UInt8(1), "f7": UInt8(7)],
                  row: { ["f0": 1, "f7": 7] }),
        UnpackRow("big-endian list element", { try Scheme(1, .list("xs", .be(.u16(0, "x")))) }, "0101000001",
                  want: ["xs": [UInt16(1)] as [Any]], row: { ["xs": [1]] }),
        UnpackRow("a list leaves the next field", { try Scheme(1, .list("xs", .u8(0, "x")), .u8(0, "y")) }, "0101000102",
                  want: ["xs": [UInt8(1)] as [Any], "y": UInt8(2)], row: { ["xs": [1], "y": 2] }),
        UnpackRow("empty utf8, list and dict", {
            try Scheme(1, .utf8(0, "name"), .list("xs", .utf8(0, "x")), .dict("d", .utf8(0, "v")))
        }, "010000000000", want: ["name": "", "xs": [Any](), "d": [String: Any]()],
                  row: { ["name": "", "xs": [String](), "d": [String: Any]()] }),
        UnpackRow("an empty sized payload", { try Scheme(1, .u16(0, "n"), .sized(1, "payload", count: 0)) }, "010000",
                  want: ["n": UInt16(0), "payload": [UInt8]()], row: { ["n": 0, "payload": [UInt8]()] }),
        UnpackRow("flag group u8 zero packs", { try Scheme(1, .flags(0, .group("g", .u8(0, "b")))) }, "010100",
                  want: ["g": ["b": UInt8(0)]], row: { ["g": ["b": 0]] }),
        UnpackRow("flag session group (nested map, Go-4 A)", sessionScheme, "01010700e8030000",
                  want: ["session": ["login": UInt16(7), "ts": UInt32(1000)]], row: { ["session": ["login": 7, "ts": 1000]] }),
        UnpackRow("flag session group absent", sessionScheme, "0100", want: [:], row: { [:] }),
    ]

    @Test(arguments: flagRows)
    func packAndUnpack_flagAndFieldRow_givesTypeScriptHexBothWays(_ c: UnpackRow) throws { try expectUnpacks(c) }

    /// A bool takes only a `Bool` (Go-1 B); TypeScript leaves the bit clear for "yes".
    @Test func pack_stringForABool_isRefusedNamingIt() throws {
        // Act
        let error = packbinError { try pack(try onFlags(), ["on": "yes"]) }

        // Assert
        #expect(error?.kind == .packError && error?.field == 0 && error?.reason == "expected a Bool for bool on, got String")
    }

    static let shorts: [(String, @Sendable () throws -> Scheme, String, Int, String, Int, Int)] = [
        ("sized payload cut short", { try Scheme(1, .u16(0, "n"), .sized(1, "payload", count: 0)) }, "01030075", 1, "payload", 3, 1),
        ("bits cut short", { try Scheme(1, .u8(0, "n"), .bits(1, "segs", count: 0)) }, "010901", 1, "segs", 2, 1),
        ("utf8 cut short", { try Scheme(1, .utf8(0, "name")) }, "0107107a", 0, "name", 7, 2),
        ("AC-5 a flags member cut short", wideFlags, "012034", 5, "extra", 2, 1),
        ("flag session group short read", sessionScheme, "010107", 0, "login", 2, 1),
        ("IT-07 a byte after the last whole round", {
            try Scheme(1, .u8(0, "type"), .repeat(1, .u8(1, "a"), .u8(2, "b")))
        }, "0101020304", 2, "b", 1, 0),
    ]

    @Test(arguments: 0..<shorts.count)
    func unpack_bufferCutShort_namesTheMemberWithNeededAndLeftAndGivesNoRow(_ i: Int) throws {
        // Arrange
        let (name, makeScheme, wire, field, member, needed, left) = Self.shorts[i]
        let scheme = try makeScheme()
        var row: [String: Any]?

        // Act
        let error = packbinError {
            row = try unpackMap(bytes(wire), scheme)
            return row as Any
        }

        // Assert
        #expect(row == nil, "\(name)")
        #expect(error?.kind == .short && error?.field == field && error?.name == member, "\(name): \(String(describing: error))")
        #expect(error?.needed == needed && error?.left == left, "\(name)")
    }

    @Test func packAndUnpack_shortReadThenPosition_stillGivesTheGoldenBytes() throws {
        // Act
        let short = packbinError { try unpackMap(bytes("012034"), try wideFlags()) }
        let position = try packHex(try positionMapScheme(), goldenMap())
        let trailing = packbinError { try unpackMap(bytes(expectedHex + "ff"), try positionMapScheme()) }

        // Assert
        #expect(short?.kind == .short && position == expectedHex)
        #expect(trailing?.kind == .trailing && trailing?.left == 1, "IT-09")
    }

    @Test func pack_whenGroupWidthAndRepeatOnGroupBoundary_giveTypeScriptLengths() throws {
        // Arrange
        let when = try Scheme(1, .u8(0, "profile"), .when(1, .eq(0, 0), .u8(1, "shape")))
        let repeated = try Scheme(1, .u8(0, "type"), .repeat(1, .u8(1, "a"), .u8(2, "b")))

        // Act
        let miss = try packHex(when, ["profile": 1])
        let hit = try packHex(when, ["profile": 0, "shape": 9])
        let complete = try unpackMap(bytes("01010203"), repeated)

        // Assert
        #expect(miss == "0101" && hit == "010009", "IT-06")
        #expect(canon(complete) == canon(["type": UInt8(1), "a": u8s([2]), "b": u8s([3])]), "IT-07")
    }

    /// packbin.test.ts "packs a class instance": the typed form of the session group.
    @Test func packAndUnpack_typedSessionGroup_givesTheMapFormsBytes() throws {
        // Arrange
        let fields: [Field] = [.u16(0, "login").bind(get: { (r: ParitySession) in r.login }, set: { $0.login = $1 }),
                               .u32(1, "ts").bind(get: { (r: ParitySession) in r.ts }, set: { $0.ts = $1 })]
        let scheme = try Scheme(1, .flags(0, .group("session", fields)
            .bind(get: { (r: ParityHolder) in r.session }, set: { $0.session = $1 })))
        let given = ParityHolder(session: ParitySession(login: 7, ts: 1000))

        // Act
        let wire = try packHex(scheme, given)
        let absent = try packHex(scheme, ParityHolder())
        let back = try unpack(bytes(wire), scheme) as? ParityHolder
        let clear = try unpack(bytes("0100"), scheme) as? ParityHolder

        // Assert
        #expect(wire == "01010700e8030000" && absent == "0100")
        #expect(back == given && clear == ParityHolder())
    }
}
