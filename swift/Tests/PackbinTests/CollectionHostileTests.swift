import Packbin
import Testing

/// Constraints (no trap, SW-2): a u16 length or count read from input is checked against the bytes left
/// before anything it sizes; invalid UTF-8 is refused as TypeScript's fatal decoder refuses it, never
/// repaired; a string, list or dict over 65 535 is refused on pack. Every outcome here is TypeScript's.
@Suite struct CollectionHostileTests {
    static let short: [(String, @Sendable () throws -> Scheme, String, String, Int, Int)] = [
        ("a list count of 65535 over 3 bytes", { try Scheme(1, .list("l", .u8(0, "e"))) }, "01ffff010203", "e", 1, 0),
        ("a list of 65535 nested rows over no byte", { try Scheme(1, .list("l", .group("g", .u8(0, "a")))) }, "01ffff", "a", 1, 0),
        ("a dict count of 65535 over 1 byte", { try Scheme(1, .dict("d", .u8(0, "e"))) }, "01ffff01", "d", 1, 0),
        ("a utf8 length of 65535 over 1 byte", { try Scheme(1, .utf8(0, "s")) }, "01ffff0361", "s", 65535, 1),
        ("a utf8 length cut short", { try Scheme(1, .utf8(0, "s")) }, "0180", "s", 2, 1),
        ("a list count cut short", { try Scheme(1, .list("l", .u8(0, "e"))) }, "01ff", "l", 2, 1),
        ("65535 zero-width items stop at the first", { try Scheme(1, .list("l", .bytes(0, "e", size: 0))) }, "01ffff", "l", 0, 0),
    ]

    @Test(arguments: 0..<short.count)
    func unpack_countOrLengthPastTheBuffer_throwsShortWithNoRow(_ i: Int) throws {
        // Arrange
        let (name, makeScheme, wire, member, needed, left) = Self.short[i]
        let scheme = try makeScheme()

        // Act
        let e = shortError { try unpackMap(bytes(wire), scheme) }

        // Assert
        #expect(e?.0 == member && e?.1 == needed && e?.2 == left, "\(name): \(String(describing: e))")
    }

    static let invalid: [(String, String)] = [
        ("a lone continuation byte", "80"), ("an overlong NUL", "c080"), ("a surrogate", "eda080"),
        ("above U+10FFFF", "f4908080"), ("a cut sequence", "e282"), ("a lead byte at the end", "61c3"),
    ]

    @Test(arguments: 0..<invalid.count)
    func unpack_invalidUTF8InAStringOrKey_isRefusedNotRepaired(_ i: Int) throws {
        // Arrange
        let (name, raw) = Self.invalid[i]
        let count = raw.count / 2
        // The only way to hold invalid UTF-8 without an escape sequence is the raw payload: 0x10, then the bytes.
        let length = hex([UInt8(count + 1)]) + "10"
        let text = try Scheme(1, .utf8(0, "s"))
        let keyed = try Scheme(1, .dict("d", .u8(0, "e")))

        // Act
        let inText = shortError { try unpackMap(bytes("01" + length + raw), text) }
        let inKey = shortError { try unpackMap(bytes("010100" + length + raw + "05"), keyed) }

        // Assert: the field, needed 0, the bytes left where the string starts (its length included).
        #expect(inText?.0 == "s" && inText?.1 == 0 && inText?.2 == 2 + count, "\(name)")
        #expect(inKey?.0 == "d" && inKey?.1 == 0 && inKey?.2 == 3 + count, "\(name)")
    }

    @Test func unpack_validUTF8FourByteAndNul_areKept() throws {
        // Arrange
        let text = try Scheme(1, .utf8(0, "s"))

        // Act
        let emoji = try unpackMap(bytes("010510f09f9880"), text)["s"] as? String
        let nul = try unpackMap(bytes("01021000"), text)["s"] as? String

        // Assert
        #expect(emoji == "\u{1F600}" && nul == "\u{0}")
    }

    @Test func pack_stringListOrDictOver65535_isRefusedNamingTheMember() throws {
        // Arrange
        let text = try Scheme(1, .utf8(0, "s"))
        let list = try Scheme(1, .list("l", .u8(0, "e")))
        let dict = try Scheme(1, .dict("d", .u8(0, "e")))
        var many: [String: Int] = [:]
        for i in 0..<65_536 { many["k\(i)"] = 1 }

        // Act
        let longText = packbinError { try pack(text, ["s": String(repeating: "a", count: 65_536)]) }
        let fullText = try pack(text, ["s": String(repeating: "a", count: 65_535)])
        let longList = packbinError { try pack(list, ["l": [Int](repeating: 1, count: 65_536)]) }
        let longDict = packbinError { try pack(dict, ["d": many]) }

        // Assert
        #expect(longText?.field == 0 && longText?.reason == "s: utf-8 length 65536")
        // 65 535 letters 'a' pack to a payload of 32 769 bytes (a 3-byte count), the reference's bytes.
        #expect(fullText.count == 1 + 3 + 32_769 && Array(fullText.prefix(8)) == [1, 0x81, 0x80, 0x02, 0xc9, 0x11, 0x11, 0x11])
        #expect(utf8Of(try unpackMap(fullText, text)["s"]) == [UInt8](repeating: 0x61, count: 65_535))
        #expect(longList?.name == "l" && longList?.reason == "l: length 65536")
        #expect(longDict?.name == "d" && longDict?.reason == "d: length 65536")
    }

    @Test func unpack_randomBytesForCollectionSchemes_throwOnlyPackbinErrors() throws {
        // Arrange: no input may trap; a trap ends the test process.
        let schemes = try [
            userScheme(), nestedRingScheme(), pairList(), pairDict(), flagsList(),
            Scheme(1, .list("t", .group("g", .u8(0, "a"), .times(1, count: 0, .utf8(1, "s")), .dict("m", .list("x", .u16(0, "y")))))),
            Scheme(1, .repeat(0, .u8(0, "k"), .list("rows", .group("r", .u8(0, "n"), .sized(1, "d", count: 0))))),
        ]
        var rng = Mulberry32(2516)
        var refused = 0
        var read = 0

        // Act
        for scheme in schemes {
            for _ in 0..<3000 {
                var buf: [UInt8] = [1]
                for _ in 0..<rng.pick(24) { buf.append(UInt8(rng.pick(256))) }
                if rng.pick(4) == 0 { buf.insert(0xff, at: 1) }
                do {
                    let row = try unpackMap(buf, scheme)
                    read += 1
                    // A dict whose keys were not in byte order repacks sorted, as in TypeScript.
                    #expect(throws: Never.self) { _ = try pack(scheme, row) }
                } catch is PackbinError {
                    refused += 1
                }
            }
        }

        // Assert
        #expect(refused + read == schemes.count * 3000)
    }
}
