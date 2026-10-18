import Packbin
import Testing

/// The `ref.user` and `ref.nested` packets of fixtures/text/vectors.txt.
let userHex = "01062bfcfee119b20200030ba818078a8b1ca4ed51800300056b6aa330b00100032b0128036ae9c80400032b0128"
    + "08106770735f66697803ea04800348516404ca25f0000200032b0128048bbc2c80"
let nestedRingHex = "010200036ae9c8010001000209f908106770735f66697804ca25f000020001000209f9032b012801000209f9048bbc2c80"

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
        UnpackRow("utf8 zxsanny", { try Scheme(1, .utf8(0, "name")) }, "01062bfcfee119b2", want: ["name": "zxsanny"],
                  row: { ["name": "zxsanny"] }),
        UnpackRow("utf8 empty", { try Scheme(1, .utf8(0, "name")) }, "0100", want: ["name": ""], row: { ["name": ""] }),
        UnpackRow("list of u16", { try Scheme(1, .list("xs", .u16(0, "x"))) }, "01020001000200",
                  want: ["xs": [UInt16(1), UInt16(2)] as [Any]], row: { ["xs": [1, 2]] }),
        UnpackRow("list empty", { try Scheme(1, .list("xs", .u16(0, "x"))) }, "010000", want: ["xs": [Any]()],
                  row: { ["xs": [Int]()] }),
        UnpackRow("empty list leaves the next field readable", { try Scheme(1, .list("xs", .u16(0, "x")), .u8(0, "t")) },
                  "01000007", want: ["xs": [Any](), "t": UInt8(7)], row: { ["xs": [Int](), "t": 7] }),
        UnpackRow("dict of u8, keys in byte order", { try Scheme(1, .dict("m", .u8(0, "v"))) }, "0102000210610202106201",
                  want: ["m": ["a": UInt8(2), "b": UInt8(1)]], row: { ["m": ["b": 1, "a": 2]] }),
        UnpackRow("the package docs example", {
            try Scheme(1, .utf8(0, "name"), .list("xs", .u16(0, "x")), .dict("m", .u8(0, "v")))
        }, "01032ba4f8" + "020001000200" + "02000210610202106201",
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
        #expect(wire == "01040002107a020310c3a9010410efbd9e040510f09f988003")
        #expect(angstrom == "0102000310c386020410e284ab01")
    }

    static let ring: [(String, @Sendable () throws -> Scheme, @Sendable () -> [String: Any], String)] = [
        ("user", userScheme, userRow, userHex),
        ("nested", nestedRingScheme, {
            ["access": ["map": [["op": "gps_fix"]], "store": [["op": "read"], ["op": "write"]]]]
        }, nestedRingHex),
        ("listgroup", pairList, { ["pts": [["a": 1, "b": 2], ["a": 3, "b": 4]]] }, "01020001020304"),
        ("dictgroup", pairDict, { ["m": ["y": ["a": 3, "b": 4], "x": ["a": 1, "b": 2]]] }, "01020002107801020210790304"),
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
        ("dictgroup", pairDict, "010200021078010202107903", 1, "b", 1, 0),
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
