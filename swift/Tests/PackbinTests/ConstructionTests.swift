import Packbin
import Testing

/// The construction checks the walker needs to run: each refusal throws `.schemeError` naming the
/// field id, with TypeScript's text where TypeScript has the check.
@Suite struct ConstructionTests {
    @Test(arguments: [-1, 256, Int.max, Int.min])
    func scheme_typeNumberOutsideAByte_isRefused(typeNumber: Int) {
        // Arrange, Act
        let error = packbinError { try Scheme(typeNumber, .u8(0, "a")) }

        // Assert
        #expect(error?.kind == .schemeError && error?.field == nil)
        #expect(error?.reason == "type number \(typeNumber): expected 0..255")
    }

    @Test func scheme_eqNamingAnUndeclaredOrLaterField_isRefused() {
        // Arrange, Act
        let undeclared = packbinError { try Scheme(1, .u8(0, "a"), .when(1, .eq(5, 1), .u8(1, "b"))) }
        let later = packbinError { try Scheme(1, .when(0, .eq(1, 1), .u8(0, "b")), .u8(1, "a")) }

        // Assert
        #expect(undeclared?.field == 1 && later?.field == 0)
        #expect(undeclared?.reason == "when 1: eq names field id 5, which is not declared earlier in the same scope")
        #expect(later?.reason == "when 0: eq names field id 1, which is not declared earlier in the same scope")
    }

    @Test func scheme_flagBitWithNoByteReadBefore_isRefused() {
        // Arrange
        let x = FlagByte("x")

        // Act
        let before = packbinError { try Scheme(1, x.bit(.u8(0, "a")), .flagByte(x)) }
        let otherWhen = packbinError {
            try Scheme(1, .u8(0, "m"), .when(1, .eq(0, 1), .flagByte(x)), x.bit(.u8(1, "a")))
        }

        // Assert
        #expect(before?.kind == .schemeError && before?.field == 0 && before?.name == "a")
        #expect(before?.reason == "flag bit 0 (a): its flag byte is not read earlier in the same scope")
        #expect(otherWhen?.reason == "flag bit 0 (a): its flag byte is not read earlier in the same scope")
    }

    @Test func scheme_ninthBit_isRefusedInBothForms() {
        // Arrange
        let x = FlagByte("x")
        let nine = (0..<9).map { Field.u8($0, "a\($0)") }

        // Act
        let combined = packbinError { try Scheme(1, .flags(0, nine)) }
        let split = packbinError { try Scheme(1, [.flagByte(x)] + nine.map { x.bit($0) }) }

        // Assert
        #expect(combined?.field == 8 && combined?.name == "a8")
        #expect(combined?.reason == "flags: ninth bit (a8); a flag byte holds 8 bits")
        #expect(split?.field == 8 && split?.reason == "flag byte \"x\": ninth bit (a8); a flag byte holds 8 bits")
    }

    @Test func scheme_eightBitsAndASecondRead_build() throws {
        // Arrange
        let x = FlagByte("x")
        let eight = (0..<8).map { Field.u8($0, "a\($0)") }

        // Act
        let scheme = try Scheme(1, [.flagByte(x)] + eight.map { x.bit($0) } + [.flagByte(x), x.bit(.u8(8, "b"))])
        let packed = try packHex(scheme, ["a7": 7, "b": 9])

        // Assert
        #expect(packed == "0180070109")
    }

    @Test func scheme_negativeBytesSize_isRefused() {
        // Arrange, Act
        let error = packbinError { try Scheme(1, .bytes(0, "b", size: -1)) }

        // Assert
        #expect(error?.kind == .schemeError && error?.field == 0 && error?.name == "b")
        #expect(error?.reason == "bytes size -1: expected 0 or more")
    }

    @Test func errorDescription_namesKindFieldAndCounts() {
        // Arrange
        let short = packbinError { try unpack(bytes("40010000"), try positionMapScheme()) }
        let refused = packbinError { try pack(try positionMapScheme(), ["sid": 1]) }

        // Act
        let texts = [short, refused].map { $0.map(String.init(describing:)) }

        // Assert
        #expect(texts == ["packbin: short packet at field 1 (lat): needed 4, left 1",
                          "packbin: pack refused at field 1 (lat): missing lat"])
    }
}
