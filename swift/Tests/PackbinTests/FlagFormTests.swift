import Packbin
import Testing

/// Split flag bytes, nested flags and `when` rows, each probed in TypeScript at HEAD first.
@Suite struct FlagFormTests {
    @Test func pack_splitBitWhoseWhenSourceFollowsTheByte_refusesTheDroppedValue() throws {
        // Arrange
        let m = FlagByte("m")
        let scheme = try Scheme(1, .flagByte(m), .u8(0, "mode"), m.bit(.when(1, .eq(0, 1), .u8(1, "speed"))),
                                m.bit(.u16(2, "heading")))

        // Act
        let error = packbinError { try pack(scheme, ["mode": 1, "speed": 7, "heading": 90]) }

        // Assert
        #expect(error?.kind == .packError && error?.field == 1 && error?.name == "speed")
        #expect(error?.reason.hasPrefix("speed: a value is given, but the condition or count") == true)
    }

    @Test func pack_splitBitWhoseWhenIsFalse_skipsSilently() throws {
        // Arrange
        let m = FlagByte("m")
        let scheme = try Scheme(1, .flagByte(m), .u8(0, "mode"), m.bit(.when(1, .eq(0, 1), .u8(1, "speed"))),
                                m.bit(.u16(2, "heading")))

        // Act
        let mode0 = try packHex(scheme, ["mode": 0, "speed": 7, "heading": 90])
        let noSpeed = try packHex(scheme, ["mode": 1, "heading": 90])

        // Assert
        #expect(mode0 == "0102005a00")
        #expect(noSpeed == "0102015a00")
    }

    @Test func packAndUnpack_splitByteWithBool_giveTypeScriptHex() throws {
        // Arrange
        let f = FlagByte("f")
        let scheme = try Scheme(1, .flagByte(f), .u8(0, "a"), f.bit(.u8(1, "b")), f.bit(.bool(2, "on")))

        // Act
        let full = try packHex(scheme, ["a": 5, "b": 6, "on": true])
        let none = try packHex(scheme, ["a": 5])
        let back = try unpackMap(bytes("01030506"), scheme)

        // Assert
        #expect(full == "01030506" && none == "010005")
        #expect(describeMap(back) == "a=UInt8:5,b=UInt8:6,on=Bool:true")
    }

    @Test func packAndUnpack_handleReadTwice_givesEachReadItsOwnBits() throws {
        // Arrange
        let t = FlagByte("t")
        let scheme = try Scheme(1, .flagByte(t), t.bit(.u8(0, "a")), .flagByte(t), t.bit(.u8(1, "b")))

        // Act
        let both = try packHex(scheme, ["a": 1, "b": 2])
        let bOnly = try packHex(scheme, ["b": 2])
        let back = try unpackMap(bytes("0101010102"), scheme)

        // Assert
        #expect(both == "0101010102" && bOnly == "01000102")
        #expect(describeMap(back) == "a=UInt8:1,b=UInt8:2")
    }

    @Test func packAndUnpack_flagsInsideFlags_giveTypeScriptHex() throws {
        // Arrange
        let scheme = try Scheme(1, .flags(0, .u8(0, "a"), .flags(1, .u8(1, "b"), .u8(2, "c"))))

        // Act
        let c = try packHex(scheme, ["c": 3])
        let a = try packHex(scheme, ["a": 1])
        let none = try packHex(scheme, [:])
        let back = try unpackMap(bytes("01020203"), scheme)

        // Assert
        #expect(c == "01020203" && a == "010101" && none == "0100")
        #expect(describeMap(back) == "c=UInt8:3")
    }

    @Test func packAndUnpack_whenOnABool_matchesOnlyASetBit() throws {
        // Arrange
        let scheme = try Scheme(1, .flags(0, .bool(0, "on")), .when(1, .eq(0, true), .u8(1, "x")))

        // Act
        let on = try packHex(scheme, ["on": true, "x": 4])
        let off = try packHex(scheme, ["x": 4])
        let back = try unpackMap(bytes("010104"), scheme)

        // Assert
        #expect(on == "010104" && off == "0100")
        #expect(describeMap(back) == "on=Bool:true,x=UInt8:4")
    }

    @Test func pack_bigEndianInFlagsAndOnASplitBit_giveTypeScriptHex() throws {
        // Arrange
        let hb = FlagByte("hb")
        let inFlags = try Scheme(1, .be(.i16(0, "n")), .flags(1, .be(.u16(1, "h"))))
        let onBit = try Scheme(1, .flagByte(hb), .be(hb.bit(.u16(0, "h"))))

        // Act
        let flagsHex = try packHex(inFlags, ["n": -2, "h": 1])
        let bitHex = try packHex(onBit, ["h": 1])

        // Assert
        #expect(flagsHex == "01fffe010001")
        #expect(bitHex == "01010001")
    }

    @Test func unpack_whenReadsTheValueRead_notTheRow() throws {
        // Arrange
        let scheme = try Scheme(1, .flags(0, .u8(0, "mode")), .when(1, .eq(0, 1), .u8(1, "x")))

        // Act
        let skipped = try packHex(scheme, ["x": 4])
        let back = try unpackMap(bytes("0100"), scheme)

        // Assert
        #expect(skipped == "0100", "mode is skipped, so the when does not match")
        #expect(back.isEmpty)
    }
}
