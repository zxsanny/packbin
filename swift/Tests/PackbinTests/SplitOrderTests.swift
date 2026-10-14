import Packbin
import Testing

/// The built rows of the TypeScript `split-bits-field-order` and `flag-scope` tests and the README
/// schemes of the kinds Swift has so far, each probed in TypeScript at HEAD first.
@Suite struct SplitOrderTests {
    @Test func pack_bitsNumberedByFieldOrder_notByTheOrderOfTheBitCalls() throws {
        // Arrange
        let m = FlagByte("m")
        let late = m.bit(.u8(1, "b"))
        let early = m.bit(.u8(0, "a"))
        let scheme = try Scheme(1, .flagByte(m), early, late)

        // Act
        let wire = try packHex(scheme, ["b": 9])
        let back = try unpackMap(bytes(wire), scheme)

        // Assert
        #expect(wire == "010209")
        #expect(describeMap(back) == "b=UInt8:9")
    }

    @Test func pack_handleSharedByTwoFiveBitSchemes_numbersEachFromZero() throws {
        // Arrange
        let m = FlagByte("m")
        let five = { (type: Int) in try Scheme(type, [.flagByte(m)] + (0..<5).map { m.bit(.u8($0, "f\($0)")) }) }
        let first = try five(1), second = try five(2)

        // Act
        let wires = [try packHex(first, ["f4": 7]), try packHex(second, ["f0": 3, "f4": 7])]

        // Assert
        #expect(wires == ["011007", "02110307"])
        #expect(describeMap(try unpackMap(bytes(wires[1]), second)) == "f0=UInt8:3,f4=UInt8:7")
    }

    @Test func packAndUnpack_byteReadInsideAWhen_numbersItsOwnBits() throws {
        // Arrange
        let m = FlagByte("m")
        let scheme = try Scheme(1, .u8(0, "k"), .flagByte(m), .when(1, .eq(0, 1), .flagByte(m), m.bit(.u8(1, "x"))),
                                m.bit(.u8(2, "y")))

        // Act
        let taken = try packHex(scheme, ["k": 1, "x": 5, "y": 6])
        let skipped = try packHex(scheme, ["k": 0, "y": 6])
        let back = try unpackMap(bytes(taken), scheme)

        // Assert
        #expect(taken == "010101010506" && skipped == "01000106")
        #expect(describeMap(back) == "k=UInt8:1,x=UInt8:5,y=UInt8:6")
    }

    @Test func packAndUnpack_splitBitInAnUntakenWhen_keepsItsBit() throws {
        // Arrange
        let m = FlagByte("m")
        let scheme = try Scheme(1, .u8(0, "k"), .flagByte(m), .when(1, .eq(0, 1), m.bit(.u8(1, "v"))))

        // Act
        let untaken = try packHex(scheme, ["k": 0, "v": 5])
        let taken = try packHex(scheme, ["k": 1, "v": 5])
        let back = try unpackMap(bytes(untaken), scheme)

        // Assert
        #expect(untaken == "010001" && taken == "01010105")
        #expect(describeMap(back) == "k=UInt8:0")
    }

    @Test func pack_bitUnderAWhenFindsTheByteOfTheScopeAround() throws {
        // Arrange
        let fb = FlagByte("fb")
        let scheme = try Scheme(1, .u8(0, "k"), .flagByte(fb), .when(1, .eq(0, 1), fb.bit(.u8(1, "a"))))

        // Act
        let wire = try packHex(scheme, ["k": 1, "a": 4])

        // Assert
        #expect(wire == "01010104")
    }

    @Test func pack_byteAndBitInsideAWhenOrASplitBitInAFlagsMember_build() throws {
        // Arrange
        let earlier = FlagByte("earlier"), inWhen = FlagByte("fb")
        let member = try Scheme(1, .flagByte(earlier), earlier.bit(.flags(0, earlier.bit(.u8(0, "nested")))))
        let when = try Scheme(1, .u8(0, "k"), .when(1, .eq(0, 1), .flagByte(inWhen), inWhen.bit(.u8(1, "a"))))

        // Act
        let memberHex = try packHex(member, [:])
        let whenHex = try packHex(when, ["k": 1, "a": 5])

        // Assert
        #expect(memberHex == "0100" && whenHex == "01010105")
    }

    @Test func pack_goldenRowInSplitForm_givesTheGoldenBytes() throws {
        // Arrange
        let m = FlagByte("m")
        let split = try Scheme(0x40, .u16(0, "sid"), .i32(1, "lat"), .i32(2, "lon"), .u8(3, "profile"), .flagByte(m),
                               m.bit(.u16(4, "heading")), m.bit(.u8(5, "speed")), m.bit(.i16(6, "altitude")))
        var moving = goldenMap()
        moving["speed"] = 7
        moving["altitude"] = -2

        // Act
        let wire = try packHex(split, goldenMap())
        let movingWire = try packHex(split, moving)

        // Assert
        #expect(wire == (try goldenHex()))
        #expect(movingWire == "4001000065cd1d00a3e111010607feff")
        #expect(movingWire == (try packHex(try positionMapScheme(), moving)))
    }

    @Test func packAndUnpack_readmeGroupExample_isANestedMapBothWays() throws {
        // Arrange
        let scheme = try Scheme(1, .u8(0, "a"), .group(1, "g", .u8(1, "b")))

        // Act
        let wire = try packHex(scheme, ["a": 1, "g": ["b": 2]])
        let back = try unpackMap(bytes(wire), scheme)
        let flat = packbinError { try pack(scheme, ["a": 1, "b": 2]) }

        // Assert
        #expect(wire == "010102")
        #expect(describeMap(back) == "a=UInt8:1,g={b=UInt8:2}")
        #expect(flat?.kind == .packError && flat?.field == 1 && flat?.name == "b")
    }

    @Test func pack_readmeFlagsGroupWithAFalseWhen_setsTheBitWhenTheGroupIsGiven() throws {
        // Arrange
        let scheme = try whenGroupScheme()

        // Act
        let given = try packHex(scheme, ["mode": 0, "g": ["speed": 7], "heading": 90])
        let neither = try packHex(scheme, ["mode": 0, "heading": 90])
        let flat = packbinError { try pack(scheme, ["mode": 0, "speed": 7, "heading": 90]) }
        let back = try unpackMap(bytes(given), scheme)

        // Assert
        #expect(given == "0100035a00" && neither == "0100025a00")
        #expect(flat?.kind == .packError && flat?.name == "speed")
        #expect(describeMap(back) == "g={},heading=UInt16:90,mode=UInt8:0")
    }
}
