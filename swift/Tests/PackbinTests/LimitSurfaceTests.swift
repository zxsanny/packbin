import Packbin
import Testing

/// AC-1 (SW-5): the limits a scheme carries, their defaults and `withLimits` (TypeScript
/// `round-limits` "scheme limits surface" and "invalid limits", `pack-output-budget` AC-5).
@Suite struct LimitSurfaceTests {
    @Test func defaults_equalTheOtherPackages() throws {
        // Arrange
        let base = try repeatK()

        // Act
        let lowered = try base.withLimits(maxRounds: 10)

        // Assert
        #expect([Scheme.defaultMaxRounds, Scheme.defaultMaxSlots, Scheme.defaultMaxBytes] == [65_535, 1_048_576, 16_777_216])
        #expect([base.maxRounds, base.maxSlots, base.maxBytes] == [65_535, 1_048_576, 16_777_216])
        #expect([lowered.maxRounds, lowered.maxSlots, lowered.maxBytes] == [10, 1_048_576, 16_777_216])
    }

    @Test func withLimits_aLimitLeftOut_takesTheDefaultNotTheReceiversValue() throws {
        // Arrange
        let base = try repeatK().withLimits(maxRounds: 10, maxSlots: 20, maxBytes: 64)

        // Act
        let next = try base.withLimits(maxSlots: 30)
        let reset = try base.withLimits()

        // Assert
        #expect([next.maxRounds, next.maxSlots, next.maxBytes] == [65_535, 30, 16_777_216])
        #expect([reset.maxRounds, reset.maxSlots, reset.maxBytes] == [65_535, 1_048_576, 16_777_216])
    }

    @Test func withLimits_derivedScheme_keepsTheTypeNumberAndLeavesTheReceiverUnchanged() throws {
        // Arrange
        let base = try Scheme(9, .repeat(0, .u8(0, "k")))

        // Act
        let strict = try base.withLimits(maxRounds: 3)

        // Assert
        #expect(strict.typeNumber == 9 && strict.maxRounds == 3)
        #expect(base.maxRounds == 65_535)
    }

    @Test func withLimits_derivedSchemeWithABoundReference_packsAndUnpacksLikeItsSource() throws {
        // Arrange
        let base = try Scheme(1, .u8(0, "n"), .sized(1, "body", count: 0))
        let derived = try base.withLimits(maxRounds: 3)
        let row: [String: Any] = ["n": 2, "body": [UInt8]([5, 6])]

        // Act
        let wire = try pack(derived, row)
        let back = try unpackMap(wire, derived)

        // Assert
        #expect(wire == (try pack(base, row)))
        #expect(describeValues(back) == describeValues(row))
    }

    @Test(arguments: ["maxRounds", "maxSlots", "maxBytes"], [0, -1, Int.min])
    func withLimits_aLimitBelowOne_isRefusedNamingIt(limit: String, value: Int) throws {
        // Arrange
        let base = try repeatK()

        // Act
        let error = packbinError {
            switch limit {
            case "maxRounds": return try base.withLimits(maxRounds: value)
            case "maxSlots": return try base.withLimits(maxSlots: value)
            default: return try base.withLimits(maxBytes: value)
            }
        }

        // Assert
        #expect(error?.kind == .schemeError && error?.field == nil && error?.name == limit)
        #expect(error?.reason == "\(limit): expected a positive integer, got \(value)")
    }

    /// TypeScript's largest limit is 2^53 - 1 (its numbers); a Swift limit is any `Int` from 1, as in
    /// Go, C# and Python.
    @Test func withLimits_intMax_isTheWayToRaiseALimit() throws {
        // Arrange
        let layout = try repeatK().withLimits(maxRounds: Int.max, maxSlots: Int.max, maxBytes: Int.max)

        // Act
        let row = try unpackMap(roundsPacket(Scheme.defaultMaxRounds + 1), layout)

        // Assert
        #expect((row["k"] as? [Any?])?.count == Scheme.defaultMaxRounds + 1)
    }

    @Test func withLimits_existingLimitCalls_packTheSameBytes() throws {
        // Arrange
        let layout = try timesK32().withLimits(maxRounds: 3, maxSlots: 3)

        // Act
        let wire = try packHex(layout, ["n": 3, "k": 7])

        // Assert
        #expect(wire == "0103000000070707")
        #expect(layout.maxBytes == Scheme.defaultMaxBytes)
    }

    @Test func unpack_eachSchemeKeepsItsOwnLimits() throws {
        // Arrange
        let base = try repeatK()
        let strict = try base.withLimits(maxRounds: 3)
        let packet = bytes("01aabbccdd")

        // Act
        let loose = try unpackMap(packet, base)
        let tight = unpackError(packet, strict)

        // Assert
        #expect(canon(loose["k"]) == "[UInt8(170),UInt8(187),UInt8(204),UInt8(221)]")
        #expect(isRefusedRound(tight, "k", left: 1))
    }

    @Test func unpack_severalSchemes_usesTheLimitsOfTheMatchedOne() throws {
        // Arrange
        let base = try repeatK()
        let other = try Scheme(2, .repeat(0, .u8(0, "k"))).withLimits(maxRounds: 2)

        // Act
        let error = unpackError(bytes("02aabbcc"), base, other)

        // Assert
        #expect(isRefusedRound(error, "k", left: 1))
        #expect(error?.reason == "round 3 is above the limit of 2 rounds")
    }
}
