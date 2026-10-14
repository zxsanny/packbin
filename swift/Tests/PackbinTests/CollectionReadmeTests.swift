import Packbin
import Testing

let userHex = "0107007a7873616e6e7902000400757365720a0064697370617463686572030007006368616e6e656c0100040072656164"
    + "03006d6170040004007265616407006770735f6669780300736574040065646974050073746f7265020004007265616405007772697465"
let nestedRingHex = "01020003006d61700100010002006f7007006770735f666978050073746f72650200010002006f7004007265"
    + "6164010002006f7005007772697465"

@Sendable func userScheme() throws -> Scheme {
    try Scheme(1, .utf8(0, "username"), .list("roles", .utf8(0, "role")),
               .dict("access", .list("actions", .utf8(0, "action"))))
}
@Sendable func nestedRingScheme() throws -> Scheme { try Scheme(1, .dict("access", .list("rows", .dict("row", .utf8(0, "op"))))) }
@Sendable func pairList() throws -> Scheme { try Scheme(1, .list("pts", .group("p", .u8(0, "a"), .u8(1, "b")))) }
@Sendable func pairDict() throws -> Scheme { try Scheme(1, .dict("m", .group("p", .u8(0, "a"), .u8(1, "b")))) }
@Sendable func flagsList() throws -> Scheme { try Scheme(1, .list("pts", .flags(0, .u8(0, "a"), .u16(1, "b")))) }

@Sendable func userRow() -> [String: Any] {
    ["username": "zxsanny", "roles": ["user", "dispatcher"],
     "access": ["channel": ["read"], "map": ["read", "gps_fix", "set", "edit"], "store": ["read", "write"]]]
}

/// AC-1 (SW-2): the README UTF-8, list and dictionary examples; AC-4: the `language-pair.sh` ring
/// payloads of the collection kinds and their three `-short` packets.
@Suite struct CollectionReadmeTests {
    static let readme: [UnpackRow] = [
        UnpackRow("utf8 zxsanny", { try Scheme(1, .utf8(0, "name")) }, "0107007a7873616e6e79", want: ["name": "zxsanny"],
                  row: { ["name": "zxsanny"] }),
        UnpackRow("utf8 empty", { try Scheme(1, .utf8(0, "name")) }, "010000", want: ["name": ""], row: { ["name": ""] }),
        UnpackRow("list of u16", { try Scheme(1, .list("xs", .u16(0, "x"))) }, "01020001000200",
                  want: ["xs": [UInt16(1), UInt16(2)] as [Any]], row: { ["xs": [1, 2]] }),
        UnpackRow("list empty", { try Scheme(1, .list("xs", .u16(0, "x"))) }, "010000", want: ["xs": [Any]()],
                  row: { ["xs": [Int]()] }),
        UnpackRow("empty list leaves the next field readable", { try Scheme(1, .list("xs", .u16(0, "x")), .u8(0, "t")) },
                  "01000007", want: ["xs": [Any](), "t": UInt8(7)], row: { ["xs": [Int](), "t": 7] }),
        UnpackRow("dict of u8, keys in byte order", { try Scheme(1, .dict("m", .u8(0, "v"))) }, "0102000100610201006201",
                  want: ["m": ["a": UInt8(2), "b": UInt8(1)]], row: { ["m": ["b": 1, "a": 2]] }),
        UnpackRow("the package docs example", {
            try Scheme(1, .utf8(0, "name"), .list("xs", .u16(0, "x")), .dict("m", .u8(0, "v")))
        }, "010300756176" + "020001000200" + "02000100610201006201",
                  want: ["name": "uav", "xs": [UInt16(1), UInt16(2)] as [Any], "m": ["a": UInt8(2), "b": UInt8(1)]],
                  row: { ["name": "uav", "xs": [1, 2], "m": ["b": 1, "a": 2]] }),
    ]

    @Test(arguments: readme)
    func packAndUnpack_readmeCollectionExample_givesTheReadmeHexBothWays(_ c: UnpackRow) throws {
        // Arrange
        let scheme = try c.scheme()

        // Act
        let back = try unpackMap(bytes(c.wire), scheme)
        let again = try pack(scheme, back)

        // Assert
        try expectUnpacks(c)
        #expect(mismatchedBytes(again, bytes(c.wire)) == 0)
    }

    @Test func pack_dictKeys_areWrittenInUnsignedUTF8ByteOrderNotSwiftOrder() throws {
        // Arrange: TypeScript packs these keys z, é, ～ (U+FF5E), 😀 (U+1F600).
        let scheme = try Scheme(1, .dict("d", .u8(0, "e")))
        let row: [String: Any] = ["d": ["\u{e9}": 1, "z": 2, "\u{1F600}": 3, "\u{FF5E}": 4]]

        // Act
        let wire = try packHex(scheme, row)

        let angstrom = try packHex(scheme, ["d": ["\u{212B}": 1, "\u{C6}": 2]])

        // Assert: Swift's String order puts U+212B (canonically U+00C5) before U+00C6; byte order does not.
        #expect(wire == "01040001007a020200c3a9010300efbd9e040400f09f988003")
        #expect(angstrom == "0102000200c386020300e284ab01")
    }

    static let ring: [(String, @Sendable () throws -> Scheme, @Sendable () -> [String: Any], String)] = [
        ("user", userScheme, userRow, userHex),
        ("nested", nestedRingScheme, {
            ["access": ["map": [["op": "gps_fix"]], "store": [["op": "read"], ["op": "write"]]]]
        }, nestedRingHex),
        ("listgroup", pairList, { ["pts": [["a": 1, "b": 2], ["a": 3, "b": 4]]] }, "01020001020304"),
        ("dictgroup", pairDict, { ["m": ["y": ["a": 3, "b": 4], "x": ["a": 1, "b": 2]]] }, "01020001007801020100790304"),
        ("listflags", flagsList, { ["pts": [["a": 1], [String: Any](), ["b": 2]]] }, "010300010100020200"),
    ]

    @Test(arguments: 0..<ring.count)
    func packAndRepack_ringPayload_givesTheRingHex(_ i: Int) throws {
        // Arrange
        let (name, makeScheme, row, wire) = Self.ring[i]
        let scheme = try makeScheme()

        // Act
        let packed = try packHex(scheme, row())
        let again = try packHex(scheme, try unpackMap(bytes(wire), scheme))

        // Assert
        #expect(packed == wire, "\(name)")
        #expect(again == wire, "\(name)")
    }

    static let short: [(String, @Sendable () throws -> Scheme, String, Int, String, Int, Int)] = [
        ("listgroup", pairList, "010200010203", 1, "b", 1, 0),
        ("dictgroup", pairDict, "010200010078010201007903", 1, "b", 1, 0),
        ("listflags", flagsList, "0103000101000202", 1, "b", 2, 1),
    ]

    @Test(arguments: 0..<short.count)
    func unpack_shortRingPayload_throwsNamingTheFieldWithNoRow(_ i: Int) throws {
        // Arrange
        let (name, makeScheme, wire, field, member, needed, left) = Self.short[i]
        let scheme = try makeScheme()

        // Act
        let asMap = packbinError { try unpackMap(bytes(wire), scheme) }
        let asAny = packbinError { try unpack(bytes(wire), scheme) }

        // Assert
        for e in [asMap, asAny] {
            #expect(e?.kind == .short, "\(name)")
            #expect(e?.field == field && e?.name == member && e?.needed == needed && e?.left == left, "\(name): \(String(describing: e))")
        }
    }
}
