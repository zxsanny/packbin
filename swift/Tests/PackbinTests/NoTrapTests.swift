import Packbin
import Testing

/// A seeded generator (SplitMix64), so a failing input can be replayed from its seed.
struct SeededRandom: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

@Sendable func noTrapSchemes() throws -> [Scheme] {
    let m = FlagByte("m")
    return [
        try positionTypedScheme(),
        try Scheme(1, .u8(0, "mode"), .flagByte(m), m.bit(.when(1, .eq(0, 1), .u8(1, "speed"))),
                   m.bit(.be(.u64(2, "q"))), .bytes(3, "b", size: 5)),
        try Scheme(2, .flags(0, .bool(0, "on"), .flags(1, .f32(1, "x"), .i64(2, "y"))),
                   .when(3, .eq(0, true), .f64(3, "z"))),
    ]
}

/// AC-3 and AC-5 "traps 0": random buffers and random map values only ever throw a `PackbinError`
/// or give a row; a trap would end the test process.
@Suite struct NoTrapTests {
    @Test func unpack_randomBuffers_throwOrGiveARow() throws {
        // Arrange
        let schemes = try noTrapSchemes()
        var random = SeededRandom(state: 2026_10_14)
        var rows = 0
        var refused = 0

        // Act
        for _ in 0..<20_000 {
            let count = Int.random(in: 0...24, using: &random)
            var buffer = (0..<count).map { _ in UInt8.random(in: 0...255, using: &random) }
            if !buffer.isEmpty { buffer[0] = UInt8.random(in: 0...3, using: &random) | (buffer[0] & 0x40) }
            do {
                _ = try unpack(buffer, schemes)
                rows += 1
            } catch is PackbinError {
                refused += 1
            }
        }

        // Assert
        #expect(rows + refused == 20_000)
        #expect(rows > 0 && refused > 0)
    }

    @Test func pack_randomMapValues_throwOrGiveBytes() throws {
        // Arrange
        let schemes = try noTrapSchemes()
        var random = SeededRandom(state: 14)
        let pool: [Any] = [0, -1, 1, 255, 256, Int.max, Int.min, UInt64.max, Int8.min, UInt8(7), 1.5, 2.0,
                           -Double.infinity, Double.nan, 1e39, Float(3), true, false, "x", [UInt8](),
                           [UInt8](repeating: 1, count: 5), Int?.none as Any, Int??.some(nil) as Any]
        let names = ["sid", "lat", "lon", "profile", "heading", "speed", "altitude", "mode", "q", "b", "on",
                     "x", "y", "z"]
        var packed = 0
        var refused = 0

        // Act
        for i in 0..<20_000 {
            var row: [String: Any] = [:]
            for name in names where Bool.random(using: &random) {
                row[name] = pool[Int.random(in: 0..<pool.count, using: &random)]
            }
            do {
                _ = try pack(schemes[i % schemes.count], row)
                packed += 1
            } catch is PackbinError {
                refused += 1
            }
        }

        // Assert
        #expect(packed + refused == 20_000)
        #expect(refused > 0)
    }
}
