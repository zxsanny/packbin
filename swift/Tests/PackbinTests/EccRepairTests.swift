import Packbin
import Testing

/// AZ-2686 AC-3 and AC-4 (EC-4 to EC-8, EC-14): repair and refusal of the position fixture under n parity bytes.
@Suite struct EccRepairTests {
    @Test func unpackRepair_n2_everyPositionAndEveryWrongValueIsRepaired() throws {
        // Arrange
        let message = try pack(try positionScheme(parity: 2), goldenMap())
        var failures = 0
        var cases = 0

        // Act
        for p in 0..<message.count {
            for v in 1...255 {
                let got = try readPosition(corrupt(message, [p], [UInt8(v)]), parity: 2, limit: 1)
                cases += 1
                if !got.isGolden(repaired: 1) { failures += 1 }
            }
        }

        // Assert
        #expect(message.count == 15)
        #expect(cases == 15 * 255)
        #expect(failures == 0)
    }

    @Test(arguments: [4, 8, 16])
    func unpackRepair_thousandSeededCasesOfUpToHalfTheParityWrongBytes_areRepaired(n: Int) throws {
        // Arrange
        var random = SeededRandom(state: UInt64(n))
        let message = try pack(try positionScheme(parity: n), goldenMap())
        let t = n / 2
        var failures = 0

        // Act
        for i in 0..<1_000 {
            let count = 1 + i % t
            let wrong = pickWrong(&random, size: message.count, count: count)
            let got = try readPosition(corrupt(message, wrong.positions, wrong.values), parity: n, limit: t)
            if !got.isGolden(repaired: count) { failures += 1 }
        }

        // Assert
        #expect(failures == 0)
    }

    @Test func unpackRepair_aWrongByteCountsOnceHoweverManyBitsDiffer() throws {
        // Arrange
        let message = try pack(try positionScheme(parity: 2), goldenMap())

        // Act
        let got = try readPosition(corrupt(message, [6], [0xff]), parity: 2, limit: 1)

        // Assert
        #expect(got.isGolden(repaired: 1))
    }

    @Test func unpackRepair_typedScheme_givesTheTypedRowAndTheCount() throws {
        // Arrange
        let scheme = try positionTypedScheme(parity: 4)
        let message = corrupt(try pack(scheme, goldenRow()), [3, 9], [0x55, 0x01])

        // Act
        let got = try unpackRepair(message, limit: 2, scheme)

        // Assert
        #expect(got.row as? Position == goldenRow())
        #expect(got.repaired == 2)
    }

    @Test func unpackRepair_repairLeavesTheCallersBufferAsItWas() throws {
        // Arrange
        let message = corrupt(try pack(try positionScheme(parity: 4), goldenMap()), [3, 9], [0x55, 0x01])
        let before = message

        // Act
        _ = try readPosition(message, parity: 4, limit: 2)

        // Assert
        #expect(message == before)
    }

    @Test func unpackRepair_n4t1_tenThousandSeededCasesOfTwoOrThreeWrongBytes_areAllRefusedWithNoRow() throws {
        // Arrange
        var random = SeededRandom(state: 61)
        let message = try pack(try positionScheme(parity: 4), goldenMap())
        var accepted = 0
        var otherErrors = 0

        // Act
        for i in 0..<10_000 {
            let wrong = pickWrong(&random, size: message.count, count: 2 + i % 2)
            let got = try readPosition(corrupt(message, wrong.positions, wrong.values), parity: 4, limit: 1)
            accepted += got.rowCount
            if let error = got.error, error.kind != .uncorrectable { otherErrors += 1 }
        }

        // Assert
        #expect(accepted == 0)
        #expect(otherErrors == 0)
    }

    @Test func unpack_n4t0_tenThousandSeededCasesOfOneToFourWrongBytes_areAllRefusedWithNoRow() throws {
        // Arrange
        var random = SeededRandom(state: 60)
        let message = try pack(try positionScheme(parity: 4), goldenMap())
        var accepted = 0
        var otherErrors = 0

        // Act
        for i in 0..<10_000 {
            let wrong = pickWrong(&random, size: message.count, count: 1 + i % 4)
            let got = try readPosition(corrupt(message, wrong.positions, wrong.values), parity: 4, limit: 0)
            accepted += got.rowCount
            if let error = got.error, error.kind != .uncorrectable { otherErrors += 1 }
        }

        // Assert
        #expect(accepted == 0)
        #expect(otherErrors == 0)
    }

    @Test func unpack_n2t0_atMostTwelveOfTwoHundredThousandRandomBuffersAreAccepted() throws {
        // Arrange: a refusal by the code is `.uncorrectable`; anything else (an unknown type byte, a short field)
        // means the code accepted the buffer and the walk then read it.
        var random = SeededRandom(state: 7)
        let scheme = try positionScheme(parity: 2)
        var accepted = 0

        // Act
        for _ in 0..<200_000 {
            let buffer = (0..<15).map { _ in UInt8.random(in: 0...255, using: &random) }
            if packbinError({ try unpackMap(buffer, scheme) })?.kind != .uncorrectable { accepted += 1 }
        }

        // Assert
        #expect(accepted <= 12, "accepted \(accepted)")
    }

    @Test func unpack_n4t0_tenThousandSeededRemovedOrAddedTailBytes_areAllRefusedWithNoRow() throws {
        // Arrange
        var random = SeededRandom(state: 14)
        let message = try pack(try positionScheme(parity: 4), goldenMap())
        var accepted = 0

        // Act
        for i in 0..<10_000 {
            let k = 1 + i % 3
            let changed = i % 2 == 0
                ? Array(message.dropLast(k))
                : message + (0..<k).map { _ in UInt8.random(in: 0...255, using: &random) }
            accepted += try readPosition(changed, parity: 4, limit: 0).rowCount
        }

        // Assert
        #expect(accepted == 0)
    }

    @Test func unpack_aTrailingZeroAnAbsentLastByteAndALastParityByteOf00_areRefused() throws {
        // Arrange: a protected message whose last parity byte is 00
        let scheme = try positionScheme(parity: 4)
        var zeroParity: [UInt8]?
        for sid in 0..<65_536 where zeroParity == nil {
            let candidate = try pack(scheme, ["sid": sid, "lat": 500_000_000, "lon": 300_000_000, "profile": 1])
            if candidate.last == 0 { zeroParity = candidate }
        }
        let zero = try #require(zeroParity)
        let message = try pack(scheme, goldenMap())

        // Act
        let changed = [message + [0], Array(message.dropLast()), zero + [0], Array(zero.dropLast())]
        let results = try changed.map { try readPosition($0, parity: 4, limit: 0) }
        let intact = try readPosition(zero, parity: 4, limit: 0)

        // Assert
        #expect(results.allSatisfy { $0.rowCount == 0 })
        #expect(intact.rowCount == 1 && intact.error == nil)
    }

    @Test func unpack_theUnprotectedMessageReadWithFourParityBytes_isRefusedWithNoRow() throws {
        // Arrange
        let clear = try pack(try positionScheme(parity: 0), goldenMap())

        // Act
        let detect = try readPosition(clear, parity: 4, limit: 0)
        let repairing = try readPosition(clear, parity: 4, limit: 2)

        // Assert
        #expect(detect.error?.kind == .uncorrectable)
        #expect(repairing.rowCount == 0 && repairing.error != nil)
    }

    @Test func unpack_aSchemeWithoutParityGivenAProtectedMessage_returnsTheTrailingBytesError() throws {
        // Arrange
        let message = try pack(try positionScheme(parity: 4), goldenMap())

        // Act
        let got = try readPosition(message, parity: 0, limit: 0)

        // Assert
        #expect(got.error?.kind == .trailing && got.error?.left == 4)
    }

    @Test func unpack_aBufferAbove254Bytes_isRefusedAsTooLongNotTooManyWithNoRow() throws {
        // Act
        let got = try readPosition([UInt8](repeating: 0, count: 255), parity: 4, limit: 2)

        // Assert
        #expect(got.error?.kind == .tooLong && got.error?.left == 255 && got.rowCount == 0)
        #expect(got.error?.reason.contains("255") == true && got.error?.reason.contains("254") == true)
    }

    @Test func unpack_aBufferShorterThanTheParity_namesTheParityTheBytesNeededAndPresent() throws {
        // Act
        let got = try readPosition(bytes("400100"), parity: 4, limit: 2)
        let empty = try readPosition([], parity: 1, limit: 0)

        // Assert
        #expect(got.error?.kind == .short && got.error?.name == "parity" && got.error?.needed == 4 && got.error?.left == 3)
        #expect(empty.error?.kind == .short && empty.error?.needed == 1 && empty.error?.left == 0)
    }

    @Test func unpack_thirtyThousandSeededBuffersAndNearMisses_giveARowOrAPackbinErrorAndNeverTrap() throws {
        // Arrange
        var random = SeededRandom(state: 99)
        let scheme = try positionScheme(parity: 16)
        let valid = try pack(scheme, goldenMap())
        var outcomes = 0

        // Act
        for i in 0..<30_000 {
            let size = i % 3 == 0 ? Int.random(in: 0..<300, using: &random) : valid.count
            var buffer = (0..<size).map { k in
                i % 3 == 2 && k < valid.count ? valid[k] : UInt8.random(in: 0...255, using: &random)
            }
            if i % 3 == 2, !buffer.isEmpty {
                buffer[Int.random(in: 0..<size, using: &random)] ^= UInt8.random(in: 1...255, using: &random)
            }
            _ = try readPosition(buffer, parity: 16, limit: i % 9)
            outcomes += 1
        }

        // Assert
        #expect(outcomes == 30_000)
    }
}
