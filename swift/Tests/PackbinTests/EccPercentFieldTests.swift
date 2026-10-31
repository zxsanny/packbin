import Packbin
import Testing

/// AZ-3513 AC-1 to AC-3 (assessment 97 S12b, S12c, D4): a percentage scheme with an optional field, a string field read
/// after the repair, and the refusal of a dispatch mix that tells a percentage from a count of the same number.
@Suite struct EccPercentFieldTests {
    /// A type byte, a u64 and an optional 3-byte field behind a flag byte: 13 clear bytes with it, 10 without.
    private func optionalScheme() throws -> Scheme {
        try Scheme(5, .u64(0, "id"), .flags(1, .bytes(1, "extra", size: 3))).withLimits(parityPercent: 25)
    }

    @Test func pack_optionalFieldUnder25Percent_eachMessageCarriesItsOwnCount() throws {
        // Arrange
        let scheme = try optionalScheme()
        let id: UInt64 = 0x0102_0304_0506_0708

        // Act
        let long = try pack(scheme, ["id": id, "extra": [UInt8]([9, 8, 7])])
        let short = try pack(scheme, ["id": id])
        let backLong = try unpackMapRepair(long, limit: 0, scheme)
        let backShort = try unpackMapRepair(short, limit: 0, scheme)

        // Assert
        #expect(long.count == 17 && short.count == 13)
        #expect(expectedCount(25, 13) == 4 && expectedCount(25, 10) == 3)
        #expect(backLong.repaired == 0 && backShort.repaired == 0)
        #expect(backLong.row["id"] as? UInt64 == id && backLong.row["extra"] as? [UInt8] == [9, 8, 7])
        #expect(backShort.row["id"] as? UInt64 == id && backShort.row["extra"] == nil)
    }

    @Test func unpackRepair_stringFieldUnder25Percent_isTheOriginalAfterOneWrongByteAnywhere() throws {
        // Arrange
        let scheme = try Scheme(6, .utf8(0, "s")).withLimits(parityPercent: 25)
        let text = "hello packbin"
        let sent = try pack(scheme, ["s": text])

        // Act
        let failures = sent.indices.filter { at in
            let got = try? unpackMapRepair(corrupt(sent, [at], [0x5a]), limit: 1, scheme)
            return got?.repaired != 1 || got?.row["s"] as? String != text
        }

        // Assert
        #expect(failures.isEmpty, "wrong byte at \(failures) of \(sent.count)")
    }

    @Test func unpack_aPercentageMixedWithTheSameNumberOfParityBytes_isRefusedNamingThePercentage() throws {
        // Arrange
        let percent = try Scheme(1, .u8(0, "x")).withLimits(parityPercent: 25)
        let count = try Scheme(2, .u8(0, "y")).withLimits(parity: 25)

        // Act
        let percentFirst = packbinError { try unpackMapRepair([], limit: 0, percent, count) }
        let countFirst = packbinError { try unpackMapRepair([], limit: 0, count, percent) }

        // Assert
        #expect(percentFirst?.kind == .schemeError && percentFirst?.name == "parity")
        #expect(percentFirst?.reason.contains("schemes declare 25 percent and 25 parity bytes") == true)
        #expect(countFirst?.kind == .schemeError && countFirst?.name == "parity")
        #expect(countFirst?.reason.contains("schemes declare 25 parity bytes and 25 percent") == true)
    }
}
