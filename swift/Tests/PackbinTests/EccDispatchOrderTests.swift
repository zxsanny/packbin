import Packbin
import Testing

/// AZ-2704: the checks of an unpack call run in one order in every package (no scheme, duplicate type, parity mix,
/// limit).
@Suite struct EccDispatchOrderTests {
    @Test(arguments: [0, 4]) func unpack_noScheme_isRefused(parity: Int) throws {
        // Arrange
        let packet = try pack(try positionScheme(parity: parity), goldenMap())
        let none: [Scheme] = []

        // Act
        let refused = [packbinError { try unpack(packet, none) },
                       packbinError { try unpackRepair(packet, limit: 0, none) }]

        // Assert
        #expect(refused.allSatisfy { $0?.kind == .schemeError && $0?.reason == "unpack needs at least one scheme" })
    }

    @Test(arguments: [0, 4]) func unpack_aDuplicateTypeWithAParityMixOrABadLimit_isTheDuplicateRefusal(parity: Int) throws {
        // Arrange
        let scheme = try positionScheme(parity: parity)
        let mixed = try positionScheme(parity: parity == 0 ? 4 : 0)
        let buffer = [UInt8](repeating: 0, count: 4)
        let duplicate = "duplicate type number \(scheme.typeNumber)"

        // Act
        let refused = [packbinError { try unpackRepair(buffer, limit: 0, [scheme, mixed]) },
                       packbinError { try unpackMapRepair(buffer, limit: 9, [scheme, scheme]) }]

        // Assert
        #expect(refused.allSatisfy { $0?.kind == .schemeError && $0?.reason == duplicate })
    }
}
