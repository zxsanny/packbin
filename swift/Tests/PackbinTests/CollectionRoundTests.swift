import Packbin
import Testing

private let loneBuffer = "a byte buffer in a repeat or times round needs a list with one buffer per round"
private let loneDict = "a dictionary in a repeat or times round needs a list with one dictionary per round"

@Sendable func timesBytes() throws -> Scheme { try Scheme(1, .u8(0, "n"), .times(1, count: 0, .bytes(1, "b", size: 2))) }
@Sendable func repeatBytes() throws -> Scheme { try Scheme(1, .repeat(0, .bytes(0, "b", size: 2))) }
@Sendable func timesSized() throws -> Scheme {
    try Scheme(1, .u8(0, "n"), .times(1, count: 0, .u8(1, "c"), .sized(2, "s", count: 1)))
}
@Sendable func listInRepeat() throws -> Scheme { try Scheme(1, .repeat(0, .u8(0, "k"), .list("tags", .u8(0, "t")))) }
@Sendable func optionalListInRepeat() throws -> Scheme {
    try Scheme(1, .repeat(0, .u8(0, "k"), .flags(1, .list("tags", .u8(0, "t")))))
}
@Sendable func unwrittenTimes() throws -> Scheme {
    try Scheme(1, .u8(0, "k"), .when(1, .eq(0, 1), .u8(1, "n")), .flags(2, .times(2, count: 1, .dict("d", .u8(0, "e")))))
}
@Sendable func listInRoundGroup() throws -> Scheme {
    try Scheme(1, .u8(0, "n"), .times(1, count: 0, .u8(1, "k"), .group("g", .list("tags", .u8(0, "t")))))
}

/// AC-2 (SW-3), TypeScript `lone-bytes-in-round` and `lone-dict-in-round`: one byte run or dictionary
/// given for a name of a round would reach every round, so it is refused; a string still goes to every
/// round. A list of a round takes one list a round. A group in a round takes one map a round (Go-4 A),
/// so where TypeScript flattens a group's members into the round, Swift reads them from the group's
/// map, and a lone group map holding a buffer, a list or a dictionary is refused as Go refuses it.
@Suite struct CollectionRoundTests {
    static let refusals: [RoundRefusal] = [
        RoundRefusal("AC-1 a lone buffer in a times", timesBytes, field: 1, "b", "b: \(loneBuffer)") { ["n": 2, "b": [UInt8(1), 2]] },
        RoundRefusal("AC-1 a lone buffer for a one-round times", timesBytes, field: 1, "b", "b: \(loneBuffer)") {
            ["n": 1, "b": [UInt8(1), 2]]
        },
        RoundRefusal("AC-1 a lone buffer in a repeat", repeatBytes, field: 0, "b", "b: \(loneBuffer)") { ["b": [UInt8(1), 2]] },
        RoundRefusal("AC-1 a lone buffer for a sized name whose length fits", timesSized, field: 2, "s", "s: \(loneBuffer)") {
            ["n": 1, "c": 1, "s": [UInt8(9)]]
        },
        RoundRefusal("AC-1 a lone buffer under a when, a group and a flags of the round", {
            try Scheme(1, .u8(0, "n"), .times(1, count: 0, .u8(1, "k"),
                                               .flags(2, .group(2, "g", .when(2, .eq(1, 2), .bytes(2, "b", size: 2))))))
        }, field: 2, "b", "b: \(loneBuffer)") { ["n": 2, "k": [2, 2], "g": ["b": [UInt8(9), 9]]] },
        RoundRefusal("AC-2 a lone dictionary under a when and a group of the round", {
            try Scheme(1, .u8(0, "n"), .times(1, count: 0, .u8(1, "k"), .when(2, .eq(1, 1), .group("g", .dict("d", .utf8(0, "e"))))))
        }, field: nil, "d", "d: \(loneDict)") { ["n": 1, "k": [1], "g": ["d": ["a": "x"]]] },
        RoundRefusal("a lone group map holding a list (as Go)", listInRoundGroup, field: nil, "tags",
                     "tags: a list in a repeat or times round needs a list with one list per round") {
            ["n": 1, "k": [1], "g": ["tags": [1]]]
        },
        RoundRefusal("an empty list for a dict of a times whose count is not written", unwrittenTimes, field: nil, "d",
                     "d: a value is given, but the count of its times is not written") { ["k": 0, "d": [Any]()] },
        RoundRefusal("a lone dict for a times whose count is not written", unwrittenTimes, field: nil, "d",
                     "d: a value is given, but the count of its times is not written") { ["k": 0, "d": ["a": 1]] },
        RoundRefusal("a lone list is the lists of the rounds", listInRepeat, field: nil, "tags",
                     "tags: expected a list, got an integer (Int)") { ["k": [1, 2], "tags": [7, 8]] },
        RoundRefusal("an entry that is no list", listInRepeat, field: nil, "tags", "tags: expected a list") {
            ["k": [1], "tags": [7]]
        },
    ]

    @Test(arguments: refusals)
    func pack_loneValueForEveryRound_isRefusedNamingTheMember(_ c: RoundRefusal) throws {
        try expectRefused(c)
    }

    static let packs: [UnpackRow] = [
        UnpackRow("AC-2 a buffer per round in a times", timesBytes, "010201020304",
                  want: ["n": UInt8(2), "b": [[UInt8(1), 2], [UInt8(3), 4]] as [Any?]],
                  row: { ["n": 2, "b": [[UInt8(1), 2], [UInt8(3), 4]]] }),
        UnpackRow("AC-2 a buffer per round in a repeat", repeatBytes, "0101020304",
                  want: ["b": [[UInt8(1), 2], [UInt8(3), 4]] as [Any?]], row: { ["b": [[UInt8(1), 2], [UInt8(3), 4]]] }),
        UnpackRow("AC-2 a sized buffer per round", timesSized, "010201090108",
                  want: ["n": UInt8(2), "c": [UInt8(1), UInt8(1)] as [Any?], "s": [[UInt8(9)], [UInt8(8)]] as [Any?]],
                  row: { ["n": 2, "c": [1, 1], "s": [[UInt8(9)], [UInt8(8)]]] }),
        UnpackRow("AC-2 one buffer for one round, in a list", timesBytes, "01010102",
                  want: ["n": UInt8(1), "b": [[UInt8(1), 2]] as [Any?]], row: { ["n": 1, "b": [[UInt8(1), 2]]] }),
        UnpackRow("AC-3 a dictionary per round in a times", dictInTimes, "010201000100610100780100010062010079",
                  want: ["n": UInt8(2), "d": [["a": "x"], ["b": "y"]] as [Any?]], row: { ["n": 2, "d": [["a": "x"], ["b": "y"]]] }),
        UnpackRow("AC-3 a dictionary per round in a repeat", { try Scheme(1, .repeat(0, .dict("d", .utf8(0, "e")))) },
                  "0101000100610100780100010062010079", want: ["d": [["a": "x"], ["b": "y"]] as [Any?]],
                  row: { ["d": [["a": "x"], ["b": "y"]]] }),
        UnpackRow("a list per round", listInRepeat, "010102000708020000",
                  want: ["k": [UInt8(1), UInt8(2)] as [Any?], "tags": [[UInt8(7), UInt8(8)] as [Any], [Any]()] as [Any?]],
                  row: { ["k": [1, 2], "tags": [[7, 8], [Int]()]] }),
        UnpackRow("a nil entry leaves the list out of its round", optionalListInRepeat, "0101010100050200",
                  want: ["k": [UInt8(1), UInt8(2)] as [Any?], "tags": [[UInt8(5)] as [Any], nil] as [Any?]],
                  row: { ["k": [1, 2], "tags": [[5], nil] as [Any?]] }),
        UnpackRow("a group map a round holding a list", listInRoundGroup, "01020101000502" + "0000",
                  want: ["n": UInt8(2), "k": [UInt8(1), UInt8(2)] as [Any?],
                         "g": [["tags": [UInt8(5)] as [Any]], ["tags": [Any]()]] as [Any?]],
                  row: { ["n": 2, "k": [1, 2], "g": [["tags": [5]], ["tags": [Int]()]]] }),
        UnpackRow("a times in a list item in a round (the element starts outside the round)", {
            try Scheme(1, .repeat(0, .u8(0, "k"), .list("rows", .group("row", .u8(0, "c"), .times(1, count: 0, .u8(1, "v"))))))
        }, "01010100020506020000",
                  want: ["k": [UInt8(1), UInt8(2)] as [Any?],
                         "rows": [[["c": UInt8(2), "v": [UInt8(5), UInt8(6)] as [Any?]]] as [Any], [Any]()] as [Any?]],
                  row: { ["k": [1, 2], "rows": [[["c": 2, "v": [5, 6]]], [Any]()]] }),
        UnpackRow("a string under a when of a round", {
            try Scheme(1, .repeat(0, .u8(0, "k"), .when(1, .eq(0, 1), .utf8(1, "s"))))
        }, "010101006100", want: ["k": [UInt8(1), UInt8(0)] as [Any?], "s": ["a", nil] as [Any?]],
                  row: { ["k": [1, 0], "s": ["a", nil] as [String?]] }),
    ]

    @Test(arguments: packs)
    func packAndUnpack_oneValueARound_givesTypeScriptsHexAndRepacks(_ c: UnpackRow) throws {
        try expectUnpacks(c)
        let scheme = try c.scheme()
        #expect(try packHex(scheme, try unpackMap(bytes(c.wire), scheme)) == c.wire, "\(c.name) repacks")
    }

    @Test func pack_loneStringForAUtf8NameOfARound_goesToEveryRound() throws {
        // Arrange
        let scheme = try Scheme(1, .u8(0, "n"), .times(1, count: 0, .utf8(1, "s")))

        // Act
        let two = try packHex(scheme, ["n": 2, "s": "ab"])
        let one = try packHex(scheme, ["n": 2, "s": "a"])

        // Assert
        #expect(two == "01020200616202006162")
        #expect(one == "0102010061010061")
    }

    @Test func pack_repeatInAListItemInARound_buildsAndPacksAsTypeScript() throws {
        // Arrange
        let scheme = try Scheme(1, .repeat(0, .u8(0, "k"), .list("rows", .group("row", .repeat(0, .u8(0, "v"))))))

        // Act
        let wire = try packHex(scheme, ["k": [1], "rows": [[["v": [5]]]]])

        // Assert
        #expect(wire == "0101010005")
    }

    @Test func pack_bytesFieldOutsideARound_takesOneBuffer() throws {
        #expect(try packHex(try Scheme(1, .bytes(0, "b", size: 2)), ["b": [UInt8(1), 2]]) == "010102")
    }
}
