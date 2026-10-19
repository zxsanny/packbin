import Packbin
import Testing

/// AZ-2704: the checks of an unpack call run in one order in every package (not open, no scheme, duplicate
/// type, parity mix, limit), and none of them spends a receive position.
@Suite struct EccDispatchOrderTests {
    @Test(arguments: [0, 4]) func sessionUnpack_noScheme_isRefusedBeforeThePositionAdvances(parity: Int) throws {
        // Arrange
        let (opener, waiter) = try sessionPair()
        let scheme = try positionScheme(parity: parity)
        let first = try opener.pack(scheme, goldenMap())
        let none: [Scheme] = []

        // Act
        let refused = [packbinError { try waiter.unpack(first, none) },
                       packbinError { try waiter.unpackRepair(first, limit: 0, none) }]
        let readFirst = try waiter.unpackMap(first, scheme)

        // Assert
        #expect(refused.allSatisfy { $0?.kind == .schemeError && $0?.reason == "unpack needs at least one scheme" })
        #expect(goldenFieldMismatches(readFirst) == 0, "the first payload still reads at position 0")
    }

    @Test(arguments: [0, 4]) func unpack_aDuplicateTypeWithAParityMixOrABadLimit_isTheDuplicateRefusal(parity: Int) throws {
        // Arrange
        let scheme = try positionScheme(parity: parity)
        let mixed = try positionScheme(parity: parity == 0 ? 4 : 0)
        let (_, waiter) = try sessionPair()
        let buffer = [UInt8](repeating: 0, count: 4)
        let duplicate = "duplicate type number \(scheme.typeNumber)"

        // Act
        let refused = [packbinError { try unpackRepair(buffer, limit: 0, [scheme, mixed]) },
                       packbinError { try unpackMapRepair(buffer, limit: 9, [scheme, scheme]) },
                       packbinError { try waiter.unpackRepair(buffer, limit: 9, scheme, scheme) }]

        // Assert
        #expect(refused.allSatisfy { $0?.kind == .schemeError && $0?.reason == duplicate })
    }
}
