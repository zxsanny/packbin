import Packbin
import Testing

struct User: PackbinRow, Equatable {
    var username = ""
    var roles: [String] = []
    var access: [String: [String]] = [:]
}

struct Pair: PackbinRow, Equatable {
    var a: UInt8 = 0
    var b: UInt8 = 0
}

struct PairRows: PackbinRow, Equatable {
    var pts: [Pair] = []
    var m: [String: Pair] = [:]
}

struct OptionalPair: PackbinRow, Equatable {
    var a: UInt8?
    var b: UInt16?
}

struct OptionalPairs: PackbinRow, Equatable {
    var pts: [OptionalPair] = []
}

struct NestedAccess: PackbinRow, Equatable {
    var access: [String: [[String: String]]] = [:]
}

struct ByteList: PackbinRow, Equatable {
    var l: [UInt8] = []
    var wide: [[Int]] = []
}

private func userTyped() throws -> Scheme {
    try Scheme(1, .utf8(0, "username").bind(get: { (r: User) in r.username }, set: { $0.username = $1 }),
               .list("roles", .utf8(0, "role")).bind(get: { (r: User) in r.roles }, set: { $0.roles = $1 }),
               .dict("access", .list("actions", .utf8(0, "action"))).bind(get: { (r: User) in r.access }, set: { $0.access = $1 }))
}

private func pairFields() -> [Field] {
    [.u8(0, "a").bind(get: { (r: Pair) in r.a }, set: { $0.a = $1 }), .u8(1, "b").bind(get: { (r: Pair) in r.b }, set: { $0.b = $1 })]
}

private func pairsTyped() throws -> Scheme {
    try Scheme(1, .list("pts", .group("p", pairFields())).bind(get: { (r: PairRows) in r.pts }, set: { $0.pts = $1 }),
               .dict("m", .group("p", pairFields())).bind(get: { (r: PairRows) in r.m }, set: { $0.m = $1 }))
}

private func optionalPairsTyped() throws -> Scheme {
    try Scheme(1, .list("pts", .flags(0, .u8(0, "a").bind(get: { (r: OptionalPair) in r.a }, set: { $0.a = $1 }),
                                      .u16(1, "b").bind(get: { (r: OptionalPair) in r.b }, set: { $0.b = $1 })))
        .bind(get: { (r: OptionalPairs) in r.pts }, set: { $0.pts = $1 }))
}

/// AC-2 (SW-3, SW-15), AC-4: lists and dicts in a typed row, TypeScript `binding` (a list of u16 bound
/// to its own ids). A typed row and its `[String: Any]` give the same bytes; a member type that cannot
/// hold every value of the list or dict is refused when the scheme is built.
@Suite struct CollectionTypedTests {
    @Test func packAndUnpack_typedUser_givesTheRingHexAndTheSameRow() throws {
        // Arrange
        let scheme = try userTyped()
        let row = User(username: "zxsanny", roles: ["user", "dispatcher"],
                       access: ["channel": ["read"], "map": ["read", "gps_fix", "set", "edit"], "store": ["read", "write"]])

        // Act
        let wire = try packHex(scheme, row)
        let back = try unpack(bytes(userHex), scheme) as? User
        let fromMap = try packHex(scheme, userRow())

        // Assert
        #expect(wire == userHex && fromMap == userHex)
        #expect(back == row)
    }

    @Test func packAndUnpack_typedNestedRowItems_giveTheRingHex() throws {
        // Arrange
        let scheme = try pairsTyped()
        let row = PairRows(pts: [Pair(a: 1, b: 2), Pair(a: 3, b: 4)], m: ["y": Pair(a: 3, b: 4), "x": Pair(a: 1, b: 2)])
        let wire = "0102000102030402000210780102021079" + "0304"

        // Act
        let packed = try packHex(scheme, row)
        let back = try unpack(bytes(wire), scheme) as? PairRows

        // Assert
        #expect(packed == wire)
        #expect(back == row)
    }

    @Test func packAndUnpack_typedFlagsItems_leaveNilMembersOut() throws {
        // Arrange
        let scheme = try optionalPairsTyped()
        let row = OptionalPairs(pts: [OptionalPair(a: 1), OptionalPair(), OptionalPair(b: 2)])

        // Act
        let packed = try packHex(scheme, row)
        let back = try unpack(bytes("010300010100020200"), scheme) as? OptionalPairs

        // Assert
        #expect(packed == "010300010100020200")
        #expect(back == row)
    }

    @Test func packAndUnpack_typedListsOfDictsAndByteArrays_roundTrip() throws {
        // Arrange
        let nested = try Scheme(1, .dict("access", .list("rows", .dict("row", .utf8(0, "op"))))
            .bind(get: { (r: NestedAccess) in r.access }, set: { $0.access = $1 }))
        let lists = try Scheme(1, .list("l", .u8(0, "e")).bind(get: { (r: ByteList) in r.l }, set: { $0.l = $1 }),
                               .list("wide", .list("w", .u16(0, "x"))).bind(get: { (r: ByteList) in r.wide }, set: { $0.wide = $1 }))
        let access = NestedAccess(access: ["map": [["op": "gps_fix"]], "store": [["op": "read"], ["op": "write"]]])
        let byteRow = ByteList(l: [1, 2], wide: [[300], []])

        // Act
        let accessWire = try packHex(nested, access)
        let accessBack = try unpack(bytes(nestedRingHex), nested) as? NestedAccess
        let byteWire = try packHex(lists, byteRow)
        let byteBack = try unpack(bytes(byteWire), lists) as? ByteList

        // Assert: a typed [UInt8] holds the items of a list of u8; a map row's [UInt8] is a byte run.
        #expect(accessWire == nestedRingHex && accessBack == access)
        #expect(byteWire == "0102000102" + "0200" + "0100" + "2c01" + "0000")
        #expect(byteBack == byteRow)
    }

    static let marker: [Field] = [
        .u16(0, "sid").bind(get: { (r: Marker) in r.sid }, set: { $0.sid = $1 }),
        .i32(1, "lat").bind(get: { (r: Marker) in r.lat }, set: { $0.lat = $1 }),
        .i32(2, "lon").bind(get: { (r: Marker) in r.lon }, set: { $0.lon = $1 }),
        .u8(3, "kind").bind(get: { (r: Marker) in r.kind }, set: { $0.kind = $1 }),
        .when(4, .eq(3, 1), .u16(4, "kindId").bind(get: { (r: Marker) in r.kindId }, set: { $0.kindId = $1 })),
        .u16(5, "title").bind(get: { (r: Marker) in r.title }, set: { $0.title = $1 }),
        .flags(6, .bool(6, "hidden").bind(get: { (r: Marker) in r.hidden }, set: { $0.hidden = $1 }),
               .bool(7, "delta").bind(get: { (r: Marker) in r.delta }, set: { $0.delta = $1 })),
    ]

    @Test func packAndUnpack_bindingMarkerRow_followsTheIdsNotTheMemberNames() throws {
        // Arrange
        let scheme = try Scheme(0x20, Self.marker)
        let ac1 = Marker(sid: 1, lat: 500_000_000, lon: 300_000_000, kind: 1, kindId: 0)
        let hit = Marker(sid: 1, lat: 500_000_000, lon: 300_000_000, kind: 1, kindId: 40, title: 7)
        let miss = Marker(sid: 1, lat: 500_000_000, lon: 300_000_000, title: 7)
        let flagged = Marker(sid: 1, lat: 500_000_000, lon: 300_000_000, title: 7, hidden: true)

        // Act
        let wires = try [ac1, hit, miss, flagged].map { try packHex(scheme, $0) }
        let backs = try wires.map { try unpack(bytes($0), scheme) as? Marker }

        // Assert: TypeScript `binding` AC-1, AC-2 and AC-3.
        #expect(wires == ["2001000065cd1d00a3e111010000000000", "2001000065cd1d00a3e111012800070000",
                          "2001000065cd1d00a3e11100070000", "2001000065cd1d00a3e11100070001"])
        #expect(backs == [ac1, hit, miss, flagged])
    }

    @Test func packAndUnpack_bindingListOfU16WithItsOwnIds_givesTypeScriptsHex() throws {
        // Arrange
        let scheme = try Scheme(0x20, .u16(0, "sid").bind(get: { (r: Parent) in r.sid }, set: { $0.sid = $1 }),
                                .list("items", .u16(0, "id")).bind(get: { (r: Parent) in r.items }, set: { $0.items = $1 }))

        // Act
        let wire = try packHex(scheme, Parent(sid: 1, items: [9, 10]))
        let back = try unpack(bytes(wire), scheme) as? Parent

        // Assert
        #expect(wire == "200100020009000a00")
        #expect(back == Parent(sid: 1, items: [9, 10]))
    }

    @Test func unpack_roundInAListItem_isReachedPerItem() throws {
        // Arrange: TypeScript unpacks 010200010000 to [{a: 1, n: 0}, {a: 0}]; the first item read its
        // times (0 rounds), the second did not.
        let scheme = try Scheme(1, .list("t", .group("g",
            .u8(0, "a").bind(get: { (r: Item) in r.a }, set: { $0.a = $1 }),
            .when(1, .eq(0, 1), .u8(1, "n").bind(get: { (r: Item) in r.n }, set: { $0.n = $1 }),
                  .times(2, count: 1, .u8(2, "b").bind(get: { (r: Leaf) in r.b }, set: { $0.b = $1 }))
                .bind(get: { (r: Item) in r.b }, set: { $0.b = $1 }))))
            .bind(get: { (r: Items) in r.t }, set: { $0.t = $1 }))

        // Act
        let back = try unpack(bytes("010200010000"), scheme) as? Items
        let again = try packHex(scheme, try #require(back))

        // Assert
        #expect(back == Items(t: [Item(a: 1, n: 0, b: []), Item(a: 0)]))
        #expect(again == "010200010000")
    }

    @Test func packAndUnpack_typedIntItems_areCheckedAgainstTheElementAndWidened() throws {
        // Arrange
        let scheme = try Scheme(1, .list("l", .u8(0, "e")).bind(get: { (r: Wrong) in r.ints }, set: { $0.ints = $1 }))

        // Act
        let tooBig = packbinError { try pack(scheme, Wrong(ints: [1, 300])) }
        let back = try unpack(bytes("0102000102"), scheme) as? Wrong

        // Assert
        #expect(tooBig?.kind == .packError && tooBig?.field == 0 && tooBig?.name == "e" && tooBig?.reason == "300 does not fit in u8")
        #expect(back?.ints == [1, 2])
    }

    @Test func packAndUnpack_typedListInARound_givesTheMapBytes() throws {
        // Arrange
        let scheme = try Scheme(1, .repeat(0, .u8(0, "k").bind(get: { (r: TagRound) in r.k }, set: { $0.k = $1 }),
                                           .list("tags", .u8(0, "t")).bind(get: { (r: TagRound) in r.tags }, set: { $0.tags = $1 }))
            .bind(get: { (r: TagRounds) in r.rounds }, set: { $0.rounds = $1 }))
        let row = TagRounds(rounds: [TagRound(k: 1, tags: [7, 8]), TagRound(k: 2, tags: [])])

        // Act
        let wire = try packHex(scheme, row)
        let back = try unpack(bytes(wire), scheme) as? TagRounds

        // Assert: the map row ["k": [1, 2], "tags": [[7, 8], []]] packs these bytes too.
        #expect(wire == "010102000708020000")
        #expect(back == row)
    }

    /// TypeScript `borrowed-count`: packed with bias -1, and a list whose length is not the count.
    @Test func packAndUnpack_typedBorrowedCounts_giveTypeScriptsBytes() throws {
        // Arrange
        let biased = try Scheme(1, .u8(0, "n").bind(get: { (r: Kinds) in r.n }, set: { $0.n = $1 }),
                                .packed(1, 1, "kinds", count: 0, bias: -1).bind(get: { (r: Kinds) in r.kinds }, set: { $0.kinds = $1 }))
        let plain = try Scheme(1, .u8(0, "n").bind(get: { (r: Kinds) in r.n }, set: { $0.n = $1 }),
                               .packed(2, 1, "kinds", count: 0).bind(get: { (r: Kinds) in r.kinds }, set: { $0.kinds = $1 }))

        // Act
        let eight = try packHex(biased, Kinds(n: 9, kinds: [1, 1, 1, 1, 1, 1, 1, 1]))
        let none = try packHex(biased, Kinds(n: 1, kinds: []))
        let back = try unpack(bytes(none), biased) as? Kinds
        let mismatch = packbinError { try pack(plain, Kinds(n: 2, kinds: [1])) }

        // Assert
        #expect(eight == "0109ff" && none == "0101")
        #expect(back == Kinds(n: 1, kinds: []))
        #expect(mismatch?.kind == .packError && mismatch?.name == "kinds")
    }

    static let refused: [RefusedScheme] = [
        RefusedScheme("a list bound to an Int", field: nil, "l", "a Int member cannot hold list l; bind an array") {
            try Scheme(1, .list("l", .u8(0, "e")).bind(get: { (r: Wrong) in r.int }, set: { $0.int = $1 }))
        },
        RefusedScheme("a list bound to a dictionary", field: nil, "l", "a Dictionary<String, Int> member cannot hold list l; bind an array") {
            try Scheme(1, .list("l", .u8(0, "e")).bind(get: { (r: Wrong) in r.dict }, set: { $0.dict = $1 }))
        },
        RefusedScheme("a dict bound to an array", field: nil, "d", "a Array<UInt8> member cannot hold dict d; bind a [String: E]") {
            try Scheme(1, .dict("d", .u8(0, "e")).bind(get: { (r: Wrong) in r.bytes }, set: { $0.bytes = $1 }))
        },
        RefusedScheme("[UInt8] items for a list of u16", field: nil, "l", "a UInt8 member cannot hold every u16 value") {
            try Scheme(1, .list("l", .u16(0, "e")).bind(get: { (r: Wrong) in r.bytes }, set: { $0.bytes = $1 }))
        },
        RefusedScheme("String items for a nested-row element", field: nil, "l", "a String item cannot hold a nested row; bind a PackbinRow") {
            try Scheme(1, .list("l", .group("g", .u8(0, "a"))).bind(get: { (r: Wrong) in r.strings }, set: { $0.strings = $1 }))
        },
        RefusedScheme("Int items for a utf8 element", field: nil, "l", "a Int member cannot hold utf8; bind a String") {
            try Scheme(1, .list("l", .utf8(0, "s")).bind(get: { (r: Wrong) in r.ints }, set: { $0.ints = $1 }))
        },
        RefusedScheme("an element bound on its own", field: nil, "l", "list l: the element is bound...") {
            try Scheme(1, .list("l", .u8(0, "e").bind(get: { (r: Pair) in r.a }, set: { $0.a = $1 })))
        },
        RefusedScheme("element fields bound while the list is not", field: 0, "a", "bound to row type Pair, but its list l is not bound") {
            try Scheme(1, .list("l", .group("g", pairFields())))
        },
        RefusedScheme("a list bound to rows of another type than its element's", field: 0, "a",
                      "bound to row type Pair, but its list pts is bound to Leaf") {
            try Scheme(1, .list("pts", .group("p", pairFields())).bind(get: { (r: Wrong) in r.leaves }, set: { $0.leaves = $1 }))
        },
        RefusedScheme("a list beside bound fields that is not bound", field: nil, "l", "not bound to row type Pair...") {
            try Scheme(1, .u8(0, "a").bind(get: { (r: Pair) in r.a }, set: { $0.a = $1 }), .list("l", .u8(0, "e")))
        },
    ]

    @Test(arguments: refused)
    func init_memberThatCannotHoldTheListOrDict_isRefused(_ c: RefusedScheme) {
        expectRefused(c)
    }
}

struct Marker: PackbinRow, Equatable {
    var sid: UInt16 = 0
    var lat: Int32 = 0
    var lon: Int32 = 0
    var kind: UInt8 = 0
    var kindId: UInt16?
    var title: UInt16 = 0
    var hidden: Bool?
    var delta: Bool?
}

struct Parent: PackbinRow, Equatable {
    var sid: UInt16 = 0
    var items: [UInt16] = []
}

struct Leaf: PackbinRow, Equatable {
    var b: UInt8 = 0
}

struct Item: PackbinRow, Equatable {
    var a: UInt8 = 0
    var n: UInt8?
    var b: [Leaf]?
}

struct Items: PackbinRow, Equatable {
    var t: [Item] = []
}

struct TagRound: PackbinRow, Equatable {
    var k: UInt8 = 0
    var tags: [UInt8] = []
}

struct TagRounds: PackbinRow, Equatable {
    var rounds: [TagRound] = []
}

struct Kinds: PackbinRow, Equatable {
    var n: UInt8 = 0
    var kinds: [UInt8] = []
}

struct Wrong: PackbinRow {
    var int = 0
    var dict: [String: Int] = [:]
    var bytes: [UInt8] = []
    var strings: [String] = []
    var ints: [Int] = []
    var leaves: [Leaf] = []
}
