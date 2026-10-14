import Foundation
import Packbin
import Testing

/// AC-4 (SW-12 scalars): nil is no value (its bit is clear and it adds 0 bytes); a stored 0 is a value
/// (its bit is set and the 0 is written).
@Suite struct NoValueTests {
    @Test func pack_getterReturnsNilOrZero_clearsOrSetsTheBit() throws {
        // Arrange
        let scheme = try positionTypedScheme()
        var zero = goldenRow()
        zero.heading = 0

        // Act
        let clear = try pack(scheme, goldenRow())
        let set = try pack(scheme, zero)
        let back = try #require(try unpack(set, scheme) as? Position)

        // Assert
        #expect(hex(clear) == expectedHex)
        #expect(hex(set) == "4001000065cd1d00a3e11101010000")
        #expect(set.count - clear.count == 2)
        #expect(back.heading == 0)
    }

    @Test(arguments: ["absent", "boxed nil", "boxed nil Optional<Any>", "nested boxed nil"])
    func pack_mapMemberWithNoValue_leavesTheBitClear(form: String) throws {
        // Arrange
        let scheme = try positionMapScheme()
        var row = goldenMap()
        switch form {
        case "boxed nil": row["heading"] = UInt16?.none as Any
        case "boxed nil Optional<Any>": row["heading"] = Any?.none as Any
        case "nested boxed nil": row["heading"] = UInt16??.some(nil) as Any
        default: break
        }

        // Act
        let packed = try pack(scheme, row)

        // Assert
        #expect(hex(packed) == expectedHex)
        #expect(packed.count == 13, "the absent member adds 0 bytes")
    }

    @Test func pack_mapMemberGivenZero_setsTheBitAndWritesZero() throws {
        // Arrange
        let scheme = try Scheme(1, .flags(0, .u8(0, "b0"), .u8(1, "b1"), .u8(2, "b2"), .u8(3, "b3"),
                                          .u8(4, "b4"), .u16(5, "extra")))
        let cases: [([String: Any], String)] = [
            ([:], "0100"),
            (["extra": UInt16?.none as Any], "0100"),
            (["extra": 0x1234], "01203412"),
            (["extra": 0], "01200000"),
            (["extra": UInt16?.some(0) as Any], "01200000"),
        ]
        for (row, wire) in cases {
            // Act
            let packed = try packHex(scheme, row)

            // Assert
            #expect(packed == wire, "\(row)")
        }
    }

    @Test func pack_mapMemberGivenNSNull_isRefusedAsNoNumber() throws {
        // Arrange
        let scheme = try positionMapScheme()
        var row = goldenMap()
        row["heading"] = NSNull()

        // Act
        let error = packbinError { try pack(scheme, row) }

        // Assert
        #expect(error?.kind == .packError && error?.field == 4 && error?.name == "heading")
    }

    @Test func unpack_clearBit_leavesTheTypedMemberNilAndTheMapKeyOut() throws {
        // Arrange
        let typed = try positionTypedScheme()
        let map = try positionMapScheme()

        // Act
        let row = try #require(try unpack(bytes("4001000065cd1d00a3e11101020a"), typed) as? Position)
        let values = try unpackMap(bytes("4001000065cd1d00a3e11101020a"), map)

        // Assert
        #expect(row.speed == 10 && row.heading == nil && row.altitude == nil)
        #expect(values["speed"] as? UInt8 == 10 && values["heading"] == nil)
    }

    @Test func pack_boolGivenFalseOrNil_leavesTheBitClear() throws {
        // Arrange
        let scheme = try Scheme(1, .flags(0, .bool(0, "on"), .u8(1, "n")))

        // Act
        let isFalse = try packHex(scheme, ["on": false, "n": 7])
        let isNil = try packHex(scheme, ["on": Bool?.none as Any, "n": 7])
        let isTrue = try packHex(scheme, ["on": true, "n": 7])

        // Assert
        #expect(isFalse == "010207" && isNil == "010207" && isTrue == "010307")
    }
}
