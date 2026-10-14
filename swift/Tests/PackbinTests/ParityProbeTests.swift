import Packbin
import Testing

private let u11Three = "v: the count c is 3 in the row, but no field wrote it (the when that holds it is clear), so the "
    + "member reads nothing; give the count 0, leave it out, or make the when hold"

/// The two open probes of AZ-2520. The U11 shape inside a nested row behind a split bit, with names
/// TypeScript can build (the outer count is `oc`, the nested row's `c`).
@Sendable private func nestedRowBehindASplitBit() throws -> Scheme {
    let fb = FlagByte("fb")
    return try Scheme(1, .u8(0, "k"), .when(1, .eq(0, 1), .u8(1, "oc")), .flagByte(fb),
                      fb.bit(.group("g", .u8(0, "mode"), .when(1, .eq(0, 1), .u8(1, "c")), .flags(2, .bits(2, "v", count: 1)))))
}

@Suite struct ParityProbeTests {
    /// Probe (a). Swift and Go read the nested row's pending count from the nested map: given there
    /// behind its clear when, it is refused as U11, as in TypeScript.
    @Test func pack_countBehindAClearWhenInsideAGivenNestedRow_isRefusedAsU11() throws {
        // Act
        let error = packbinError { try pack(try nestedRowBehindASplitBit(), ["k": 0, "g": ["mode": 0, "c": 3]]) }

        // Assert
        #expect(error?.kind == .packError && error?.field == 2 && error?.name == "v" && error?.reason == u11Three)
    }

    /// Probe (a), observed and open: a flat `c` beside the given nested row is not read (Go-4 A), so the
    /// row packs, as in Go; TypeScript reads the flat key for the missing member and refuses it as U11.
    @Test func pack_flatCountBesideAGivenNestedRow_isNotReadAsInGo() throws {
        // Act
        let wire = try packHex(try nestedRowBehindASplitBit(), ["k": 0, "c": 3, "g": ["mode": 0]])

        // Assert
        #expect(wire == "0100010000")
    }

    /// A flat member key beside a given group is not read (Go-4 A, as Go): the group's map lacks b, so b
    /// is missing; TypeScript reads the flat key (`01010102`). With b in the map both give `01010103`.
    @Test(arguments: [true, false])
    func pack_flatMemberBesideAGivenGroup_isNotRead(anchored: Bool) throws {
        // Arrange
        let members: [Field] = [.u8(0, "a"), .u8(1, "b")]
        let scheme = try Scheme(1, .flags(0, anchored ? .group(0, "g", members) : .group("g", members)))

        // Act
        let beside = packbinError { try pack(scheme, ["g": ["a": 1], "b": 2]) }
        let inMap = try packHex(scheme, ["g": ["a": 1, "b": 3], "b": 2])

        // Assert
        #expect(beside?.kind == .packError && beside?.field == 1 && beside?.name == "b" && beside?.reason == "missing b")
        #expect(inMap == "01010103")
    }

    /// Probe (b), copied from TypeScript and no documented difference: a zero-width element packs, and
    /// unpack refuses the same packet, because an item that reads no byte would let a count of 65 535
    /// spend nothing (short at the list, needed 0, left 0). An empty list reads back.
    static let zeroWidth: [(String, @Sendable () throws -> Scheme, @Sendable () -> [String: Any], String)] = [
        ("a list of one empty bytes", { try Scheme(1, .list("l", .bytes(0, "e", size: 0))) }, { ["l": [[UInt8]()]] }, "010100"),
        ("a list of two empty bytes", { try Scheme(1, .list("l", .bytes(0, "e", size: 0))) },
         { ["l": [[UInt8](), [UInt8]()]] }, "010200"),
        ("a dict of one empty bytes", { try Scheme(1, .dict("d", .bytes(0, "e", size: 0))) }, { ["d": ["a": [UInt8]()]] },
         "010100010061"),
        ("a list of nested rows of empty bytes", { try Scheme(1, .list("l", .group("g", .bytes(0, "b", size: 0)))) },
         { ["l": [["b": [UInt8]()]]] }, "010100"),
    ]

    @Test(arguments: 0..<zeroWidth.count)
    func packAndUnpack_zeroWidthElement_packsAndUnpackRefusesTheSamePacket(_ i: Int) throws {
        // Arrange
        let (name, makeScheme, row, wire) = Self.zeroWidth[i]
        let scheme = try makeScheme()
        let member = name.hasPrefix("a dict") ? "d" : "l"

        // Act
        let packed = try packHex(scheme, row())
        let error = shortError { try unpackMap(bytes(wire), scheme) }
        let empty = try unpackMap(bytes("010000"), scheme)

        // Assert
        #expect(packed == wire, "\(name)")
        #expect(error?.0 == member && error?.1 == 0 && error?.2 == 0, "\(name): \(String(describing: error))")
        #expect(empty.count == 1, "\(name)")
    }
}
