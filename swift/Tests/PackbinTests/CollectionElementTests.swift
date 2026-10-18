import Packbin
import Testing

private let anchoredText = "element is an anchored group (p); use a group without an anchor"
private func anchored() -> Field { .group(0, "p", .u8(0, "a")) }

/// AC-2 (SW-3), TypeScript `list-element-kinds` and `list-group-elements`: the elements a list or dict
/// holds, refused when the scheme is built or packed and unpacked item by item. The element's ids start
/// at 0 and its names and references are its own.
@Suite struct CollectionElementTests {
    static let refused: [RefusedScheme] = [
        RefusedScheme("AC-1 a list of anchored groups", field: nil, "g", "list g: \(anchoredText)") {
            try Scheme(1, .list("g", anchored()))
        },
        RefusedScheme("AC-2 a dict of anchored groups", field: nil, "g", "dict g: \(anchoredText)") {
            try Scheme(1, .dict("g", anchored()))
        },
        RefusedScheme("AC-3 in a when body", field: nil, "g", "list g: \(anchoredText)") {
            try Scheme(1, .u8(0, "k"), .when(1, .eq(0, 1), .list("g", anchored())))
        },
        RefusedScheme("AC-3 in a repeat body", field: nil, "g", "list g: \(anchoredText)") {
            try Scheme(1, .repeat(0, .list("g", anchored())))
        },
        RefusedScheme("AC-3 in a times body", field: nil, "g", "list g: \(anchoredText)") {
            try Scheme(1, .u8(0, "n"), .times(1, count: 0, .list("g", anchored())))
        },
        RefusedScheme("AC-3 in a group element", field: nil, "g", "list g: \(anchoredText)") {
            try Scheme(1, .list("t", .group("q", .list("g", anchored()))))
        },
        RefusedScheme("AC-3 in a flags member", field: nil, "g", "list g: \(anchoredText)") {
            try Scheme(1, .flags(0, .list("g", anchored())))
        },
        RefusedScheme("AC-3 under a flag bit", field: nil, "g", "list g: \(anchoredText)") {
            let m = FlagByte("m")
            return try Scheme(1, .flagByte(m), m.bit(.list("g", anchored())))
        },
        RefusedScheme("AC-3 in flags nested in flags", field: nil, "g", "list g: \(anchoredText)") {
            try Scheme(1, .flags(0, .flags(0, .list("g", anchored()))))
        },
        RefusedScheme("AC-3 the element of an inner dict", field: nil, "u",
                      "dict u: element is an anchored group (g); use a group without an anchor") {
            try Scheme(1, .dict("t", .dict("u", .group(0, "g", .u8(0, "a")))))
        },
        RefusedScheme("AC-4 a when element keeps its refusal", field: 0, "",
                      "when 0: eq names field id 0, which is not declared earlier in the same scope") {
            try Scheme(1, .list("w", .when(0, .eq(0, 1), .u8(0, "a"))))
        },
        RefusedScheme("AC-4 a times element keeps its refusal", field: 0, "",
                      "times 0: count names field id 0, which is not declared earlier in the same scope") {
            try Scheme(1, .list("t", .times(0, count: 0, .u8(0, "a"))))
        },
        RefusedScheme("AC-5 a wrong field id keeps its message", field: 1, "p", "field id: expected 0, got 1") {
            try Scheme(1, .list("g", .group(1, "p", .u8(1, "a"))))
        },
        RefusedScheme("AC-5 an empty anchored group keeps its message", field: 0, "p",
                      "empty group p: allowed only directly inside flags or a flag bit; move it into flags") {
            try Scheme(1, .list("g", .group(0, "p")))
        },
        RefusedScheme("AC-5 an earlier refusal elsewhere comes first", field: 0, "",
                      "when 0: eq names field id 5, which is not declared earlier in the same scope") {
            try Scheme(1, .list("g", anchored()), .when(0, .eq(5, 1), .u8(0, "b")))
        },
        RefusedScheme("a flags element anchor must be 0", field: 1, "", "field id: expected 0, got 1") {
            try Scheme(1, .list("pts", .flags(1, .u8(1, "a"))))
        },
        RefusedScheme("a repeat element", field: nil, "l", "list element must be one field") {
            try Scheme(1, .list("l", .repeat(0, .u8(0, "e"))))
        },
        RefusedScheme("a repeat dict element", field: nil, "d", "repeat is not a dictionary element") {
            try Scheme(1, .dict("d", .repeat(0, .u8(0, "e"))))
        },
        RefusedScheme("a bool element", field: 0, "e",
                      "bool e: allowed only directly inside flags or a flag bit; move it into flags") {
            try Scheme(1, .list("l", .bool(0, "e")))
        },
        RefusedScheme("a sized element", field: 0, "e",
                      "sized 0: count names field id 0, which is not declared earlier in the same scope") {
            try Scheme(1, .list("l", .sized(0, "e", count: 0)))
        },
        RefusedScheme("a split bit of the row around", field: 0, "a",
                      "flag bit 0 (a): its flag byte is not read earlier in the same scope") {
            let m = FlagByte("m")
            return try Scheme(1, .flagByte(m), .list("xs", m.bit(.u8(0, "a"))))
        },
        RefusedScheme("a u2 element (loop 25 D2 A, as Go; TypeScript builds it)", field: nil, "l",
                      "list l: a u2 cannot be an element; use an integer, float, bytes, utf8, list, dict, flags or a group without an anchor") {
            try Scheme(1, .list("l", .u2(.slot(0, "a"))))
        },
        RefusedScheme("a flag byte element (as Go; TypeScript builds it)", field: nil, "l",
                      "list l: a flag byte cannot be an element; use an integer, float, bytes, utf8, list, dict, flags or a group without an anchor") {
            try Scheme(1, .list("l", .flagByte(FlagByte("m"))))
        },
        RefusedScheme("a slot element", field: 0, "a", "slot a: allowed only directly inside u2") {
            try Scheme(1, .list("l", .slot(0, "a")))
        },
        RefusedScheme("a name twice in a group element", field: 1, "a", "member a: declared twice in one scope...") {
            try Scheme(1, .list("pts", .group("g", .u8(0, "a"), .u8(1, "a"))))
        },
        RefusedScheme("a name twice in a dict group element", field: 1, "a", "member a: declared twice in one scope...") {
            try Scheme(1, .dict("m", .group("g", .u8(0, "a"), .u8(1, "a"))))
        },
        RefusedScheme("a repeat in a repeat inside a list element", field: 1, "", "repeat 1 is inside a repeat or times round...") {
            try Scheme(1, .list("rows", .group("row", .repeat(0, .u8(0, "a"), .repeat(1, .u8(1, "b"))))))
        },
        RefusedScheme("an empty round in a list item", field: 0, "", "repeat 0: the body holds no member...") {
            try Scheme(1, .list("xs", .group("item", .repeat(0))))
        },
    ]

    @Test(arguments: refused)
    func init_elementTheListCannotHold_isRefusedNamingIt(_ c: RefusedScheme) {
        expectRefused(c)
    }

    static let packs: [UnpackRow] = [
        UnpackRow("AC-6 list of group", pairList, "01020001020304",
                  want: ["pts": [["a": UInt8(1), "b": UInt8(2)], ["a": UInt8(3), "b": UInt8(4)]] as [Any]],
                  row: { ["pts": [["a": 1, "b": 2], ["a": 3, "b": 4]]] }),
        UnpackRow("AC-6 dict of group", pairDict, "01020002107801020210790304",
                  want: ["m": ["x": ["a": UInt8(1), "b": UInt8(2)], "y": ["a": UInt8(3), "b": UInt8(4)]]],
                  row: { ["m": ["y": ["a": 3, "b": 4], "x": ["a": 1, "b": 2]]] }),
        UnpackRow("AC-6 list of flags", flagsList, "010300010100020200",
                  want: ["pts": [["a": UInt8(1)], [String: Any](), ["b": UInt16(2)]] as [Any]],
                  row: { ["pts": [["a": 1], [String: Any](), ["b": 2]]] }),
        UnpackRow("AC-4 dict of flags", { try Scheme(1, .dict("m", .flags(0, .u8(0, "a"), .u16(1, "b")))) },
                  "01020002107800021079020200", want: ["m": ["x": [String: Any](), "y": ["b": UInt16(2)]]],
                  row: { ["m": ["y": ["b": 2], "x": [String: Any]()]] }),
        UnpackRow("AC-6 list of leaf", { try Scheme(1, .list("t", .u8(0, "p"))) }, "0102000102",
                  want: ["t": [UInt8(1), UInt8(2)] as [Any]], row: { ["t": [1, 2]] }),
        UnpackRow("AC-6 list of list of group", { try Scheme(1, .list("t", .list("u", .group("g", .u8(0, "a"))))) },
                  "010100010001", want: ["t": [[["a": UInt8(1)]] as [Any]] as [Any]], row: { ["t": [[["a": 1]]]] }),
        UnpackRow("AC-6 anchored group inside the element (its own map, Go-4 A)",
                  { try Scheme(1, .list("t", .group("g", .u8(0, "a"), .group(1, "q", .u8(1, "b"))))) }, "0101000102",
                  want: ["t": [["a": UInt8(1), "q": ["b": UInt8(2)]]] as [Any]], row: { ["t": [["a": 1, "q": ["b": 2]]]] }),
        UnpackRow("AC-6 when inside the element",
                  { try Scheme(1, .list("t", .group("g", .u8(0, "a"), .when(1, .eq(0, 1), .u8(1, "b"))))) }, "010200010200",
                  want: ["t": [["a": UInt8(1), "b": UInt8(2)], ["a": UInt8(0)]] as [Any]],
                  row: { ["t": [["a": 1, "b": 2], ["a": 0]]] }),
        UnpackRow("AC-6 times inside the element",
                  { try Scheme(1, .list("t", .group("g", .u8(0, "a"), .times(1, count: 0, .u8(1, "b"))))) },
                  "01020002030400", want: ["t": [["a": UInt8(2), "b": [UInt8(3), UInt8(4)] as [Any?]], ["a": UInt8(0)]] as [Any]],
                  row: { ["t": [["a": 2, "b": [3, 4]], ["a": 0]]] }),
        UnpackRow("AC-6 anchored group beside a list of group",
                  { try Scheme(1, .group(0, "h", .u8(0, "k")), .list("pts", .group("p", .u8(0, "a")))) }, "0107010001",
                  want: ["h": ["k": UInt8(7)], "pts": [["a": UInt8(1)]] as [Any]], row: { ["h": ["k": 7], "pts": [["a": 1]]] }),
        UnpackRow("AC-6 leaf elements keep their bytes",
                  { try Scheme(1, .list("ids", .u16(0, "id")), .dict("names", .utf8(0, "name"))) }, "0102000100020001" + "00" + "02106b" + "021076",
                  want: ["ids": [UInt16(1), UInt16(2)] as [Any], "names": ["k": "v"]], row: { ["ids": [1, 2], "names": ["k": "v"]] }),
        UnpackRow("element members do not collide with row members", { try Scheme(1, .u8(0, "a"), .list("pts", .group("p", .u8(0, "a"), .u8(1, "b")))) },
                  "010901000102", want: ["a": UInt8(9), "pts": [["a": UInt8(1), "b": UInt8(2)]] as [Any]],
                  row: { ["a": 9, "pts": [["a": 1, "b": 2]]] }),
        UnpackRow("a reference inside an element reads its item",
                  { try Scheme(1, .list("rows", .group("row", .u8(0, "n"), .sized(1, "d", count: 0)))) }, "01020001aa020102",
                  want: ["rows": [["n": UInt8(1), "d": [UInt8(0xaa)]], ["n": UInt8(2), "d": [UInt8(1), UInt8(2)]]] as [Any]],
                  row: { ["rows": [["n": 1, "d": [UInt8(0xaa)]], ["n": 2, "d": [UInt8(1), UInt8(2)]]]] }),
        UnpackRow("a list inside a group element has its own ids and items",
                  { try Scheme(1, .list("pts", .group("p", .u8(0, "a"), .list("tags", .u8(0, "t"))))) }, "010200010200070802" + "0000",
                  want: ["pts": [["a": UInt8(1), "tags": [UInt8(7), UInt8(8)] as [Any]], ["a": UInt8(2), "tags": [Any]()]] as [Any]],
                  row: { ["pts": [["a": 1, "tags": [7, 8]], ["a": 2, "tags": [Int]()]]] }),
        UnpackRow("a flags element keeps its flag byte apart from the row's",
                  { try Scheme(1, .flags(0, .u8(0, "t")), .list("pts", .flags(0, .u8(0, "a")))) }, "0101050200010100",
                  want: ["t": UInt8(5), "pts": [["a": UInt8(1)], [String: Any]()] as [Any]],
                  row: { ["t": 5, "pts": [["a": 1], [String: Any]()]] }),
        UnpackRow("a bool in a flags element sets its bit only for true",
                  { try Scheme(1, .list("pts", .flags(0, .bool(0, "on"), .u8(1, "n")))) }, "0103000303020401",
                  want: ["pts": [["on": true, "n": UInt8(3)], ["n": UInt8(4)], ["on": true]] as [Any]],
                  row: { ["pts": [["on": true, "n": 3], ["n": 4], ["on": true]]] }),
        UnpackRow("a split flag byte in an element", {
            let fb = FlagByte("fb")
            return try Scheme(1, .list("xs", .group("g", .flagByte(fb), fb.bit(.u8(0, "a")), fb.bit(.u8(1, "b")))))
        }, "0103000101020200", want: ["xs": [["a": UInt8(1)], ["b": UInt8(2)], [String: Any]()] as [Any]],
                  row: { ["xs": [["a": 1], ["b": 2], [String: Any]()]] }),
        UnpackRow("a group element in a repeat round packs the items of each round",
                  { try Scheme(1, .repeat(0, .u8(0, "k"), .list("rows", .group("p", .u8(0, "a"), .u8(1, "b"))))) },
                  "0101010001020202000304" + "0506",
                  want: ["k": [UInt8(1), UInt8(2)] as [Any?],
                         "rows": [[["a": UInt8(1), "b": UInt8(2)]] as [Any], [["a": UInt8(3), "b": UInt8(4)], ["a": UInt8(5), "b": UInt8(6)]] as [Any]] as [Any?]],
                  row: { ["k": [1, 2], "rows": [[["a": 1, "b": 2]], [["a": 3, "b": 4], ["a": 5, "b": 6]]]] }),
    ]

    @Test(arguments: packs)
    func packAndUnpack_elementKind_givesTypeScriptsHexAndItemsBack(_ c: UnpackRow) throws {
        try expectUnpacks(c)
        let scheme = try c.scheme()
        #expect(try packHex(scheme, try unpackMap(bytes(c.wire), scheme)) == c.wire, "\(c.name) repacks")
    }

    static let packRefusals: [RoundRefusal] = [
        RoundRefusal("an absent required member", pairList, field: 1, "b", "missing b") { ["pts": [["a": 1, "b": 2], ["a": 3]]] },
        RoundRefusal("an item that is not a map", pairList, field: nil, "pts",
                     "pts: expected a [String: Any] for each item, got an integer (Int)") { ["pts": [7]] },
        RoundRefusal("a nil item of a group element", pairList, field: nil, "pts", "expected a [String: Any] for each item, got no value") {
            ["pts": [nil] as [Any?]]
        },
        RoundRefusal("a nil item of a flags element", flagsList, field: nil, "pts", "expected a [String: Any] for each item") {
            ["pts": [nil] as [Any?]]
        },
        RoundRefusal("not a list", pairList, field: nil, "pts", "pts: expected a list, got an integer (Int)") { ["pts": 7] },
        RoundRefusal("no list", pairList, field: nil, "pts", "pts: expected a list, got no value") { [:] },
        RoundRefusal("a [UInt8] is a byte run, never a list", { try Scheme(1, .list("l", .u8(0, "e"))) }, field: nil, "l",
                     "l: expected a list, got [UInt8]") { ["l": [UInt8(1), 2]] },
        RoundRefusal("a nil leaf item", { try Scheme(1, .list("l", .u8(0, "e"))) }, field: 0, "e", "missing e") {
            ["l": [1, nil] as [Int?]]
        },
        RoundRefusal("a leaf item out of range", { try Scheme(1, .list("l", .u8(0, "e"))) }, field: 0, "e",
                     "300 does not fit in u8") { ["l": [300]] },
        RoundRefusal("a leaf item of the wrong Swift type", { try Scheme(1, .list("l", .u8(0, "e"))) }, field: 0, "e",
                     "expected an integer for u8, got String") { ["l": ["a"]] },
        RoundRefusal("an unnamed element is named by its list", { try Scheme(1, .list("l", .u8(0, ""))) }, field: 0, "l",
                     "300 does not fit in u8") { ["l": [300]] },
        RoundRefusal("a nil item of an inner list", { try Scheme(1, .list("l", .list("m", .u8(0, "a")))) }, field: nil, "m",
                     "m: expected a list, got no value") { ["l": [nil] as [Any?]] },
        RoundRefusal("a nil item of an inner dict", { try Scheme(1, .list("l", .dict("m", .u8(0, "a")))) }, field: nil, "m",
                     "m: expected a dictionary, got no value") { ["l": [nil] as [Any?]] },
    ]

    @Test(arguments: packRefusals)
    func pack_itemTheElementCannotTake_isRefusedNamingIt(_ c: RoundRefusal) throws {
        try expectRefused(c)
    }

    @Test func unpack_shortFlagsElementAndZeroWidthElement_throwWithNoRow() throws {
        // Arrange
        let zeroWidth = try Scheme(1, .list("l", .bytes(0, "e", size: 0)))

        // Act
        let shortFlags = shortError { try unpackMap(bytes("0101000205"), try flagsList()) }
        let nothingRead = shortError { try unpackMap(bytes("010100"), zeroWidth) }
        let packed = try packHex(zeroWidth, ["l": [[UInt8]()]])

        // Assert: TypeScript gives {field: "b", needed: 2, left: 1}, packs the zero-width item and refuses
        // to read it back ({field: "l", needed: 0, left: 0}).
        #expect(shortFlags?.0 == "b" && shortFlags?.1 == 2 && shortFlags?.2 == 1)
        #expect(packed == "010100")
        #expect(nothingRead?.0 == "l" && nothingRead?.1 == 0 && nothingRead?.2 == 0)
    }
}
