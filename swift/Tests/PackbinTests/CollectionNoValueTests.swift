import Packbin
import Testing

struct OptionalCollections: PackbinRow, Equatable {
    var l: [UInt8]?
    var d: [String: UInt8]?
    var s: String?
}

struct RequiredCollections: PackbinRow, Equatable {
    var l: [UInt8]?
    var d: [String: UInt8] = [:]
}

private func optionalScheme() throws -> Scheme {
    try Scheme(1, .flags(0, .list("l", .u8(0, "e")).bind(get: { (r: OptionalCollections) in r.l }, set: { $0.l = $1 }),
                         .dict("d", .u8(0, "v")).bind(get: { (r: OptionalCollections) in r.d }, set: { $0.d = $1 }),
                         .utf8(0, "s").bind(get: { (r: OptionalCollections) in r.s }, set: { $0.s = $1 })))
}

private func requiredScheme() throws -> Scheme {
    try Scheme(1, .list("l", .u8(0, "e")).bind(get: { (r: RequiredCollections) in r.l }, set: { $0.l = $1 }),
               .dict("d", .u8(0, "v")).bind(get: { (r: RequiredCollections) in r.d }, set: { $0.d = $1 }))
}

/// AC-5 (SW-12, S8): `nil` is no value (a typed getter's `nil`, an absent key, a boxed `nil`): under
/// flags its bit is clear, and where a value is required the pack is refused naming the field. An
/// empty array or dictionary is a value with count 0 written. Typed and map rows give the same bytes.
@Suite struct CollectionNoValueTests {
    static let mapRows: [(String, @Sendable () -> [String: Any], String)] = [
        ("absent keys", { [:] }, "0100"),
        ("boxed nil", { ["l": [Int]?.none as Any, "d": [String: Int]?.none as Any, "s": String?.none as Any] }, "0100"),
        ("nested boxed nil", { ["l": Optional<Any>.some([Int]?.none as Any) as Any] }, "0100"),
        ("an empty list", { ["l": [Int]()] }, "01010000"),
        ("an empty dictionary", { ["d": [String: Int]()] }, "01020000"),
        ("an empty string", { ["s": ""] }, "01040000"),
        ("all three empty", { ["l": [Int](), "d": [String: Int](), "s": ""] }, "0107000000000000"),
    ]

    @Test(arguments: 0..<mapRows.count)
    func pack_mapNilOrEmptyUnderFlags_clearsTheBitOrWritesCount0(_ i: Int) throws {
        // Arrange
        let (name, row, wire) = Self.mapRows[i]

        // Act
        let packed = try packHex(try optionalScheme(), row())

        // Assert
        #expect(packed == wire, "\(name)")
    }

    @Test func pack_typedNilOrEmptyUnderFlags_givesTheMapBytes() throws {
        // Arrange
        let scheme = try optionalScheme()
        let rows = [OptionalCollections(), OptionalCollections(l: []), OptionalCollections(d: [:]), OptionalCollections(s: ""),
                    OptionalCollections(l: [], d: [:], s: "")]

        // Act
        let wires = try rows.map { try packHex(scheme, $0) }

        // Assert
        #expect(wires == ["0100", "01010000", "01020000", "01040000", "0107000000000000"])
    }

    @Test func unpack_clearBitVersusCount0_givesNilVersusEmpty() throws {
        // Arrange
        let scheme = try optionalScheme()

        // Act
        let clear = try unpack(bytes("0100"), scheme) as? OptionalCollections
        let empty = try unpack(bytes("0107000000000000"), scheme) as? OptionalCollections
        let clearMap = try unpackMap(bytes("0100"), scheme)
        let emptyMap = try unpackMap(bytes("01010000"), scheme)

        // Assert
        #expect(clear == OptionalCollections())
        #expect(empty == OptionalCollections(l: [], d: [:], s: ""))
        #expect(clearMap.isEmpty)
        #expect(canon(emptyMap) == canon(["l": [Any]()]))
    }

    static let required: [RoundRefusal] = [
        RoundRefusal("an absent list", { try requiredScheme() }, field: nil, "l", "l: expected a list, got no value") { ["d": [String: Int]()] },
        RoundRefusal("a boxed nil list", { try requiredScheme() }, field: nil, "l", "l: expected a list, got no value") {
            ["l": [Int]?.none as Any, "d": [String: Int]()]
        },
        RoundRefusal("an absent dictionary", { try requiredScheme() }, field: nil, "d", "d: expected a dictionary, got no value") {
            ["l": [Int]()]
        },
        RoundRefusal("an absent string", { try Scheme(1, .utf8(0, "s")) }, field: 0, "s", "missing s") { [:] },
        RoundRefusal("a number for a string", { try Scheme(1, .utf8(0, "s")) }, field: 0, "s",
                     "s: expected a String for utf8, got an integer (Int)") { ["s": 5] },
    ]

    @Test(arguments: required)
    func pack_noValueWhereOneIsRequired_isRefusedNamingTheField(_ c: RoundRefusal) throws {
        try expectRefused(c)
    }

    @Test func pack_typedNilRequiredList_isRefusedAndEmptyWritesCount0() throws {
        // Arrange
        let scheme = try requiredScheme()

        // Act
        let none = packbinError { try pack(scheme, RequiredCollections()) }
        let empty = try packHex(scheme, RequiredCollections(l: []))
        let back = try unpack(bytes("0100000000"), scheme) as? RequiredCollections

        // Assert
        #expect(none?.kind == .packError && none?.field == nil && none?.name == "l")
        #expect(empty == "0100000000")
        #expect(back == RequiredCollections(l: []))
    }
}
