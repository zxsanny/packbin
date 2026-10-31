import Packbin
import Testing

/// AZ-3505 AC-1 to AC-7: the parity percentage setting, the count and bytes, the largest message, the count found from
/// the received length, repair, the correction limit and dispatch. An independent integer formula (`EccPercentSupport`).
@Suite struct EccPercentTests {
    @Test func parityPercent_defaultsToZeroAndTheLastSetterWins() throws {
        // Arrange
        let plain = try positionMapScheme()

        // Act
        let percent = try plain.withLimits(parityPercent: 25)
        let kept = try percent.withLimits(maxBytes: 100)
        let counted = try percent.withLimits(parity: 4)
        let backToPercent = try counted.withLimits(parityPercent: 10)
        let zeroed = try counted.withLimits(parityPercent: 0)

        // Assert
        #expect(plain.parityPercent == 0 && percent.parityPercent == 25 && percent.parity == 0)
        #expect(kept.parityPercent == 25 && kept.parity == 0)
        #expect(counted.parity == 4 && counted.parityPercent == 0)
        #expect(backToPercent.parityPercent == 10 && backToPercent.parity == 0)
        #expect(zeroed.parityPercent == 0 && zeroed.parity == 0)
    }

    @Test(arguments: [101, -1, 1_000])
    func withLimits_percentOutOfRange_isRefusedNamingThePercentageAnd100(_ p: Int) throws {
        // Act
        let error = packbinError { try positionMapScheme().withLimits(parityPercent: p) }

        // Assert
        #expect(error?.kind == .schemeError && error?.name == "parity")
        #expect(error?.reason.contains(String(p)) == true && error?.reason.contains("100") == true)
    }

    @Test func withLimits_aPercentageAndACountInOneCall_isRefusedButZeroOfEitherIsNot() throws {
        // Arrange
        let plain = try positionMapScheme()

        // Act
        let both = packbinError { try plain.withLimits(parity: 4, parityPercent: 10) }
        let zeroCount = try plain.withLimits(parity: 0, parityPercent: 10)
        let zeroPercent = try plain.withLimits(parity: 4, parityPercent: 0)

        // Assert
        #expect(both?.kind == .schemeError && both?.name == "parity")
        #expect(zeroCount.parityPercent == 10 && zeroCount.parity == 0)
        #expect(zeroPercent.parity == 0 && zeroPercent.parityPercent == 0)
    }

    @Test(arguments: [0, 10, 25, 50, 100], [1, 3, 10, 40, 100, 222])
    func pack_percentage_writesTheClearBytesThenTheParityOfTheDerivedCount(p: Int, length: Int) throws {
        // Arrange
        let clear = patternClear(length, seed: p)
        let n = expectedCount(p, length)
        let byPercent = try rawScheme(for: clear, percent: p)
        let byCount = try rawScheme(for: clear, parity: n)

        // Act
        let packed = try pack(byPercent, rawRow(clear))

        // Assert
        #expect(packed == (try pack(byCount, rawRow(clear))))
        #expect(packed.count == length + n && Array(packed.prefix(length)) == clear)
        #expect(p != 0 || packed == clear)
    }

    @Test(arguments: [1, 10, 25, 50, 100])
    func pack_oneByteAboveTheLargestClearLength_isRefusedNamingBothAndWritesNothing(p: Int) throws {
        // Arrange
        let largest = expectedLargest(p)
        let over = [UInt8](repeating: 0, count: largest + 1)
        let scheme = try rawScheme(for: over, percent: p)

        // Act
        let error = packbinError { try pack(scheme, rawRow(over)) }
        let written = (try? pack(scheme, rawRow(over)).count) ?? 0
        let atLimit = [UInt8](repeating: 0, count: largest)
        let fits = try pack(try rawScheme(for: atLimit, percent: p), rawRow(atLimit)).count

        // Assert
        #expect(error?.kind == .packError && written == 0)
        #expect(error?.reason.contains(String(largest + 1)) == true && error?.reason.contains(String(largest)) == true)
        #expect(fits <= 254)
        #expect([1, 10, 25, 50, 100].map(expectedLargest) == [251, 230, 222, 222, 222])
    }

    @Test func pack_percentageZero_hasNoLimitAsACountOfZeroHasNone() throws {
        // Arrange
        let clear = [UInt8](repeating: 7, count: 1_000)

        // Act
        let packed = try pack(try rawScheme(for: clear, percent: 0), rawRow(clear))

        // Assert
        #expect(packed == clear)
    }

    @Test func roundTrip_everyPercentageAndEveryClearLength_givesTheRowBackWithNothingRepaired() throws {
        // Arrange
        var pairs = 0
        var wrong: [String] = []

        // Act
        for p in 0...100 {
            for length in 1...(p == 0 ? 254 : expectedLargest(p)) {
                let clear = patternClear(length, seed: p &+ length)
                let scheme = try rawScheme(for: clear, percent: p)
                let packed = try pack(scheme, rawRow(clear))
                let got = packbinError { try unpackMapRepair(packed, limit: 0, scheme) }
                let back = try? unpackMapRepair(packed, limit: 0, scheme)
                pairs += 1
                if got != nil || back?.repaired != 0 || packed.count != length + expectedCount(p, length)
                    || describeMap(back?.row ?? [:]) != describeMap(rawRow(clear)) {
                    wrong.append("p \(p) L \(length)")
                }
            }
        }

        // Assert: 22,752 pairs with the clear length 0, which a scheme message never has (a type byte)
        #expect(pairs == 22_752 - 101)
        #expect(wrong.isEmpty, "\(wrong.count) pairs: \(wrong.prefix(5))")
    }

    @Test(arguments: [1, 10, 25, 50, 100])
    func unpackRepair_aLengthNoClearLengthGives_isUncorrectableWithNoField(p: Int) throws {
        // Arrange
        let scheme = try Scheme(0, [Field]()).withLimits(parityPercent: p)
        let lengths = (0...254).filter { n in !(0...n).contains { $0 + expectedCount(p, $0) == n } }

        // Act
        let errors = lengths.map { n in packbinError { try unpackMapRepair([UInt8](repeating: 0, count: n), limit: 0, scheme) } }

        // Assert
        #expect(lengths.count == [3, 24, 32, 32, 32][[1, 10, 25, 50, 100].firstIndex(of: p) ?? 0])
        #expect(errors.allSatisfy { $0?.kind == .uncorrectable && $0?.field == nil && $0?.name == "" })
    }

    @Test func unpackRepair_aBufferAbove254Bytes_isTooLongAsToday() throws {
        // Arrange
        let scheme = try Scheme(0, [Field]()).withLimits(parityPercent: 10)

        // Act
        let error = packbinError { try unpackMapRepair([UInt8](repeating: 0, count: 255), limit: 0, scheme) }

        // Assert
        #expect(error?.kind == .tooLong && error?.left == 255)
    }

    @Test(arguments: [(50, 10, 10), (25, 5, 5)])
    func unpackRepair_wrongBytesWithinTheLimit_areRepairedWithTheCountOfThatMessage(_ c: (p: Int, wrong: Int, count: Int)) throws {
        // Arrange
        let clear = patternClear(40, seed: 5)
        let scheme = try rawScheme(for: clear, percent: c.p)
        let packed = try pack(scheme, rawRow(clear))
        var random = SeededRandom(state: UInt64(c.p))
        let hit = pickWrong(&random, size: packed.count, count: c.wrong)

        // Act
        let got = try unpackMapRepair(corrupt(packed, hit.positions, hit.values), limit: c.wrong, scheme)

        // Assert
        #expect(got.repaired == c.count && describeMap(got.row) == describeMap(rawRow(clear)))
    }

    @Test(arguments: [-1, 17, 100])
    func unpackRepair_aLimitOutside0To16_isBadLimitBeforeAnyByteIsRead(_ t: Int) throws {
        // Arrange
        let scheme = try rawScheme(for: patternClear(40, seed: 1), percent: 25)

        // Act
        let error = packbinError { try unpackMapRepair([], limit: t, scheme) }

        // Assert
        #expect(error?.kind == .schemeError && error?.name == "limit")
    }

    @Test func unpackRepair_aLimitAboveHalfTheCount_isLoweredToIt() throws {
        // Arrange: 40 clear bytes at 25 percent have 10 parity bytes, so limit 16 behaves as limit 5
        let clear = patternClear(40, seed: 2)
        let scheme = try rawScheme(for: clear, percent: 25)
        let packed = try pack(scheme, rawRow(clear))
        var random = SeededRandom(state: 77)
        let five = pickWrong(&random, size: packed.count, count: 5)

        // Act
        let repaired = try unpackMapRepair(corrupt(packed, five.positions, five.values), limit: 16, scheme)
        let sixth = pickWrong(&random, size: packed.count, count: 6)
        let six = packbinError { try unpackMapRepair(corrupt(packed, sixth.positions, sixth.values), limit: 16, scheme) }

        // Assert
        #expect(repaired.repaired == 5)
        #expect(six == nil || six?.kind == .uncorrectable, "six wrong bytes are not repaired")
        #expect((try? unpackMapRepair(corrupt(packed, sixth.positions, sixth.values), limit: 16, scheme).repaired) != 6)
    }

    @Test func unpackRepair_percentageZero_keepsTheLimitRuleOfCountZero() throws {
        // Arrange
        let scheme = try positionMapScheme().withLimits(parityPercent: 0)
        let packet = try pack(scheme, goldenMap())

        // Act
        let error = packbinError { try unpackMapRepair(packet, limit: 1, scheme) }
        let ok = try unpackMapRepair(packet, limit: 0, scheme)

        // Assert
        #expect(error?.kind == .schemeError && error?.name == "limit")
        #expect(ok.repaired == 0 && packet == bytes(expectedHex))
    }

    @Test func unpackRepair_aFixedCountKeepsItsExactRule() throws {
        // Arrange
        let scheme = try positionScheme(parity: 4)

        // Act
        let error = packbinError { try unpackMapRepair([], limit: 3, scheme) }

        // Assert
        #expect(error?.kind == .schemeError && error?.name == "limit")
    }

    @Test func unpack_handlersOfTheSamePercentage_dispatchAfterTheRepair() throws {
        // Arrange
        let a = try Scheme(1, .u8(0, "x")).withLimits(parityPercent: 50)
        let b = try Scheme(2, .u16(0, "y")).withLimits(parityPercent: 50)
        var packed = try pack(b, ["y": 513])
        packed[1] ^= 0x55

        // Act
        let got = try unpackMapRepair(packed, limit: 1, a, b)

        // Assert
        #expect(got.repaired == 1 && got.row["y"] as? UInt16 == 513)
    }

    @Test func unpack_aMixOfSettings_isRefusedBeforeAnyByteIsRead() throws {
        // Arrange
        let ten = try Scheme(1, [Field]()).withLimits(parityPercent: 10)
        let twenty = try Scheme(2, [Field]()).withLimits(parityPercent: 20)
        let counted = try Scheme(3, [Field]()).withLimits(parity: 4)
        let plain = try Scheme(4, [Field]())
        let percentZero = try Scheme(5, [Field]()).withLimits(parityPercent: 0)

        // Act
        let mixes = [packbinError { try unpackMapRepair([], limit: 0, ten, twenty) },
                     packbinError { try unpackMapRepair([], limit: 0, ten, counted) },
                     packbinError { try unpackMapRepair([], limit: 0, plain, ten) }]
        let zeros = packbinError { try unpackMapRepair([5], limit: 0, plain, percentZero) }

        // Assert
        #expect(mixes.allSatisfy { $0?.kind == .schemeError && $0?.name == "parity" })
        #expect(zeros == nil)
    }
}
