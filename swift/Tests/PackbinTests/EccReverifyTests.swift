import Packbin
import Testing

/// AZ-2695 AC-1: the check that the repaired bytes are a code word. Each buffer is a protected message with more
/// wrong bytes than the limit `t`, found by a seeded search on `scripts/ecc/eccfmt.py`, for which the locator has
/// a degree up to `t` and as many roots, so the repair writes values and only the syndromes of the repaired
/// bytes show that the result is not a code word. Without that check the repair would return a message.
@Suite struct EccReverifyTests {
    /// `(n, t, received)`: the decoder reaches the final syndrome check and that check fails.
    static let notCodeWordAfterRepair: [(Int, Int, String)] = [
        (4, 1, "839cde7f8afd336eddd7f2491a"),
        (4, 2, "f53ab73e0c939f0a59061698b4012b"),
        (6, 2, "a068880818bdb904ec8c6d20308ec18d55"),
    ]

    @Test func unpackMapRepair_aRepairThatDoesNotYieldACodeWord_isRefusedAsUncorrectable() throws {
        // Arrange
        var wrong: [String] = []

        // Act
        for (n, t, received) in Self.notCodeWordAfterRepair {
            let scheme = try Scheme(0, [Field]()).withLimits(parity: n)
            let error = packbinError { try unpackMapRepair(bytes(received), limit: t, scheme) }
            if !(error?.kind == .uncorrectable && error?.name == "" && error?.field == nil) {
                wrong.append("\(received): \(String(describing: error))")
            }
        }

        // Assert
        #expect(wrong.isEmpty, "\(wrong)")
    }

    @Test func unpackRepair_aRepairThatDoesNotYieldACodeWord_isRefusedAsUncorrectable() throws {
        // Arrange
        var wrong: [String] = []

        // Act
        for (n, t, received) in Self.notCodeWordAfterRepair {
            let scheme = try Scheme(0, [Field]()).withLimits(parity: n)
            let error = packbinError { try unpackRepair(bytes(received), limit: t, scheme) }
            if !(error?.kind == .uncorrectable && error?.name == "" && error?.field == nil) {
                wrong.append("\(received): \(String(describing: error))")
            }
        }

        // Assert
        #expect(wrong.isEmpty, "\(wrong)")
    }
}
