import Foundation
import Packbin
import Testing

private let proto = "5f5f70726f746f5f5f"
@Sendable func dictOfNumbers() throws -> Scheme { try Scheme(1, .u8(0, "a"), .dict("m", .u8(0, "v"))) }
@Sendable func dictOfDicts() throws -> Scheme { try Scheme(1, .u8(0, "a"), .dict("m", .dict("n", .u8(0, "v")))) }
@Sendable func dictOfGroups() throws -> Scheme { try Scheme(1, .u8(0, "a"), .dict("m", .group("p", .u8(0, "a"), .u8(1, "b")))) }
@Sendable func dictOfUtf8() throws -> Scheme { try Scheme(1, .dict("d", .utf8(0, "e"))) }
@Sendable func dictInTimes() throws -> Scheme { try Scheme(1, .u8(0, "n"), .times(1, count: 0, .dict("d", .utf8(0, "e")))) }
@Sendable func dictInFlagsTimes() throws -> Scheme {
    try Scheme(1, .u8(0, "n"), .flags(1, .times(1, count: 0, .dict("d", .utf8(0, "e"))), .u16(1, "h")))
}

private struct Rowish {
    var a = "x"
}

/// AC-2 (SW-3), TypeScript `dict-keys-not-flattened`, `dict-non-plain-object` and `value-fidelity`;
/// AC-3b: dict keys are values, never members of the row, and keys a `[String: Any]` cannot hold apart
/// are refused.
@Suite struct DictKeyTests {
    static let packs: [PackRow] = [
        PackRow("AC-1 one key order", dictOfNumbers, "0101010001006109") { ["a": 1, "m": ["a": 9]] },
        PackRow("AC-1 the other key order", dictOfNumbers, "0101010001006109") { ["m": ["a": 9], "a": 1] },
        PackRow("AC-2 a key named like the dictionary", dictOfNumbers, "0101010001006d09") { ["a": 1, "m": ["m": 9]] },
        PackRow("AC-2 a key named like the element", dictOfNumbers, "0101010001007609") { ["a": 1, "m": ["v": 9]] },
        PackRow("AC-4 nested dictionaries keep to themselves", dictOfDicts, "01010100010078010001006109") {
            ["a": 1, "m": ["x": ["a": 9]]]
        },
        PackRow("AC-5 a __proto__ key is an ordinary key", dictOfDicts, "0101010009005f5f70726f746f5f5f010001006109") {
            ["m": ["__proto__": ["a": 9]], "a": 1]
        },
        PackRow("TS-F1 a dict group member named like a row member", dictOfGroups, "010901000100780102") {
            ["a": 9, "m": ["x": ["a": 1, "b": 2]]]
        },
        PackRow("TS-F1 inside a group element", {
            try Scheme(1, .list("xs", .group("g", .u8(0, "a"), .dict("m", .group("p", .u8(0, "a"), .u8(1, "b"))))))
        }, "0101000901000100780102") { ["xs": [["m": ["x": ["a": 1, "b": 2]], "a": 9]]] },
        PackRow("TS-F1 a dict of group inside a dict group element", {
            try Scheme(1, .dict("outer", .group("g", .u8(0, "a"), .dict("m", .group("p", .u8(0, "a"))))))
        }, "01010001006b07010001007801") { ["outer": ["k": ["m": ["x": ["a": 1]], "a": 7]]] },
        PackRow("an empty key sorts first", { try Scheme(1, .dict("d", .u8(0, "e"))) }, "0103000000030100610201006201") {
            ["d": ["b": 1, "a": 2, "": 3]]
        },
        PackRow("a plain dictionary packs", dictOfUtf8, "010100010061010078") { ["d": ["a": "x"]] },
        PackRow("a [String: String] packs", dictOfUtf8, "010100010061010078") { ["d": ["a": "x"] as [String: String]] },
        PackRow("a Foundation dictionary packs", dictOfUtf8, "010100010061010078") { ["d": NSDictionary(dictionary: ["a": "x"])] },
        PackRow("a list of dictionaries in a round", dictInTimes, "01010100010061010078") { ["n": 1, "d": [["a": "x"]]] },
        PackRow("a times with count 0 in flags and no dictionary", dictInFlagsTimes, "0100020500") { ["n": 0, "h": 5] },
        PackRow("declared group map: a key it does not declare stays out", {
            try Scheme(1, .u8(0, "a"), .group("g", .u8(0, "b")))
        }, "010102") { ["a": 1, "g": ["a": 9, "b": 2]] },
        PackRow("declared group map: the group's value wins over a flat one", {
            try Scheme(1, .u8(0, "a"), .group("g", .u8(0, "b")))
        }, "010102") { ["a": 1, "b": 3, "g": ["b": 2]] },
        PackRow("declared group map: a group in a group", {
            try Scheme(1, .u8(0, "a"), .group("g", .u8(0, "b"), .group("h", .u8(0, "c"))))
        }, "01010203") { ["a": 1, "g": ["b": 2, "h": ["c": 3]]] },
    ]

    @Test(arguments: packs)
    func pack_dictRow_givesTypeScriptsHex(_ c: PackRow) throws {
        try expectPacks(c)
    }

    static let refusals: [RoundRefusal] = [
        RoundRefusal("AC-3 a key does not supply a missing member", dictOfNumbers, field: 0, "a", "missing a") { ["m": ["a": 9]] },
        RoundRefusal("AC-3 nor does another key", dictOfNumbers, field: 0, "a", "missing a") { ["m": ["b": 9]] },
        RoundRefusal("a __proto__ key at the top does not supply a member", { try Scheme(1, .u8(0, "a"), .u8(1, "b")) },
                     field: 1, "b", "missing b") { ["a": 1, "__proto__": ["b": 2]] },
        RoundRefusal("an undeclared map does not supply a member", { try Scheme(1, .u8(0, "a"), .group("g", .u8(0, "b"))) },
                     field: 0, "a", "missing a") { ["g": ["b": 2], "other": ["a": 1]] },
        RoundRefusal("a nil entry", { try Scheme(1, .dict("d", .u8(0, "e"))) }, field: 0, "e", "missing e") {
            ["d": ["a": nil] as [String: Int?]]
        },
        RoundRefusal("a Set is no dictionary", dictOfUtf8, field: nil, "d", "d: expected a dictionary, got Set<String>") { ["d": Set(["a"])] },
        RoundRefusal("an array is no dictionary", dictOfUtf8, field: nil, "d", "d: expected a dictionary, got Array<String>") { ["d": ["a"]] },
        RoundRefusal("a string is no dictionary", dictOfUtf8, field: nil, "d", "d: expected a dictionary, got String") { ["d": "a"] },
        RoundRefusal("a struct is no dictionary", dictOfUtf8, field: nil, "d", "d: expected a dictionary, got Rowish") { ["d": Rowish()] },
        RoundRefusal("keys that are not strings", dictOfUtf8, field: nil, "d", "d: expected a dictionary") { ["d": [1: "x"]] },
        RoundRefusal("no dictionary", dictOfUtf8, field: nil, "d", "d: expected a dictionary, got no value") { [:] },
        RoundRefusal("a lone dictionary in a times round", dictInTimes, field: nil, "d",
                     "d: a dictionary in a repeat or times round needs a list with one dictionary per round") { ["n": 2, "d": ["a": "x"]] },
        RoundRefusal("a lone dictionary in a repeat round", { try Scheme(1, .repeat(0, .dict("d", .utf8(0, "e")))) }, field: nil, "d",
                     "d: a dictionary in a repeat or times round needs a list with one dictionary per round") { ["d": ["a": "x"]] },
        RoundRefusal("a lone Set in a times round (as Go; TypeScript refuses a Set as a lone dictionary too)", dictInTimes, field: nil, "d",
                     "d: a dictionary in a repeat or times round") { ["n": 2, "d": Set(["a"])] },
        RoundRefusal("a lone dictionary in a times of count 0 in flags", dictInFlagsTimes, field: nil, "d",
                     "d: a dictionary in a repeat or times round needs a list with one dictionary per round") { ["n": 0, "d": ["a": "x"], "h": 5] },
        RoundRefusal("a lone dictionary in a times of count 0", dictInTimes, field: nil, "d",
                     "d: a dictionary in a repeat or times round needs a list with one dictionary per round") { ["n": 0, "d": ["a": "x"]] },
    ]

    @Test(arguments: refusals)
    func pack_valueThatIsNoDictionaryOrLoneInARound_isRefusedNamingTheMember(_ c: RoundRefusal) throws {
        try expectRefused(c)
    }

    static let unpacks: [UnpackRow] = [
        UnpackRow("TS-F1 the unpacked row repacks", dictOfGroups, "010901000100780102",
                  want: ["a": UInt8(9), "m": ["x": ["a": UInt8(1), "b": UInt8(2)]]]),
        UnpackRow("AC-5 a decoded __proto__ entry", dictOfDicts, "0101010009005f5f70726f746f5f5f010001006109",
                  want: ["a": UInt8(1), "m": ["__proto__": ["a": UInt8(9)]]]),
        UnpackRow("a __proto__ key with a dict value", { try Scheme(1, .dict("acl", .dict("inner", .u8(0, "v")))) },
                  "010100" + "0900" + proto + "0100" + "0500" + "61646d696e01", want: ["acl": ["__proto__": ["admin": UInt8(1)]]]),
        UnpackRow("a __proto__ key with a scalar value", { try Scheme(1, .dict("m", .u8(0, "v"))) },
                  "010100" + "0900" + proto + "07", want: ["m": ["__proto__": UInt8(7)]]),
        UnpackRow("a byte order mark is kept", { try Scheme(1, .utf8(0, "s")) }, "010600efbbbf616263", want: ["s": "\u{FEFF}abc"],
                  row: { ["s": "\u{FEFF}abc"] }),
    ]

    @Test(arguments: unpacks)
    func unpack_dictKeysAndText_keepEveryEntryAndRepack(_ c: UnpackRow) throws {
        try expectUnpacks(c)
        let scheme = try c.scheme()
        #expect(try packHex(scheme, try unpackMap(bytes(c.wire), scheme)) == c.wire, "\(c.name) repacks")
    }

    static let twice: [(String, String)] = [
        ("a key given twice", "0102000900\(proto)00000900\(proto)0000"),
        ("NFC and NFD forms of one key (AC-3b)", "0102000200c3a90000030065cc810000"),
        ("NFD then NFC", "010200030065cc8100000200c3a90000"),
    ]

    @Test(arguments: twice)
    func unpack_keysEqualAsSwiftStrings_throwDictKeyGivenTwiceWithNoRow(_ name: String, _ wire: String) throws {
        // Arrange
        let scheme = try Scheme(1, .dict("acl", .dict("inner", .u8(0, "v"))))

        // Act
        let asMap = packbinError { try unpackMap(bytes(wire), scheme) }
        let asAny = packbinError { try unpack(bytes(wire), scheme) }

        // Assert: TypeScript refuses byte-equal keys as {field: "acl", needed: 0, left: 0}.
        for e in [asMap, asAny] {
            #expect(e?.kind == .short && e?.field == nil && e?.name == "acl", "\(name)")
            #expect(e?.needed == 0 && e?.left == 0 && e?.reason == "dict key given twice", "\(name)")
        }
    }

    @Test func pack_foundationDictionaryWithNFCAndNFDKeys_isRefusedNotMerged() throws {
        // Arrange: an NSDictionary keeps both keys; a [String: Any] would hold only one.
        let both = NSDictionary(objects: [1, 2], forKeys: ["\u{e9}" as NSString, "e\u{301}" as NSString])
        let scheme = try Scheme(1, .dict("d", .u8(0, "e")))
        // Linux Foundation decides per process (its hash seed) whether the two keys collide and merge: a dictionary
        // that already holds one key has nothing left to refuse, so the premise of this test is two kept keys.
        guard both.count == 2 else { return }

        // Act
        let error = packbinError { try pack(scheme, ["d": both]) }

        // Assert
        #expect(error?.kind == .packError && error?.field == nil && error?.name == "d")
        #expect(error?.reason.hasPrefix("d: dict key given twice") == true)
    }
}
