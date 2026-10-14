import Packbin
import Testing

/// AC-1 (SW-1): the AC-1 row as a typed struct and as a map packs fixtures/golden.hex and unpacks back.
@Suite struct GoldenTests {
    @Test func pack_typedGoldenRow_givesGoldenHexAndUnpacksBack() throws {
        // Arrange
        let scheme = try positionTypedScheme()
        let golden = bytes(try goldenHex())

        // Act
        let raw = try pack(scheme, goldenRow())
        let row = try unpack(golden, scheme)

        // Assert
        #expect(mismatchedBytes(raw, golden) == 0)
        #expect(hex(raw) == expectedHex && raw.count == 13)
        let back = try #require(row as? Position)
        #expect(back == goldenRow())
        #expect(back.heading == nil && back.speed == nil && back.altitude == nil)
    }

    @Test(arguments: ["map", "typed"])
    func pack_mapGoldenRow_givesGoldenHexAndUnpacksToFiveFields(form: String) throws {
        // Arrange
        let scheme = form == "map" ? try positionMapScheme() : try positionTypedScheme()
        let golden = try goldenHex()

        // Act
        let wire = try packHex(scheme, goldenMap())
        let back = try unpackMap(bytes(golden), scheme)

        // Assert
        #expect(wire == golden)
        #expect(describeMap(back) == "lat=Int32:500000000,lon=Int32:300000000,profile=UInt8:1,sid=UInt16:1")
        #expect(back.count == 4, "four values and 0 motion fields")
        #expect(try packHex(scheme, back) == golden)
    }

    @Test func pack_typedAndMapWithHeading_agree() throws {
        // Arrange
        let typed = try positionTypedScheme()
        var row = goldenRow()
        row.heading = 90
        var map = goldenMap()
        map["heading"] = 90

        // Act
        let wire = try packHex(typed, row)
        let asMap = try packHex(try positionMapScheme(), map)
        let back = try #require(try unpack(bytes(wire), typed) as? Position)

        // Assert
        #expect(wire == "4001000065cd1d00a3e11101015a00")
        #expect(asMap == wire)
        #expect(back.heading == 90 && back.speed == nil)
    }

    @Test func pack_typedRowGivenAsAny_packsGoldenHex() throws {
        // Arrange
        let scheme = try positionTypedScheme()
        let row: Any = goldenRow()

        // Act
        let wire = try packHex(scheme, row)

        // Assert
        #expect(wire == expectedHex)
    }
}
