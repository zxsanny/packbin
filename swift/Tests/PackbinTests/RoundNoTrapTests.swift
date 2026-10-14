import Packbin
import Testing

/// Round and counted shapes for the no-trap sweeps: counts from u64, i64 and a u2 slot, groups and
/// split bytes in rounds, typed rounds.
@Sendable func hostileRoundSchemes() throws -> [Scheme] {
    let fb = FlagByte("m")
    return [
        try Scheme(1, .u64(0, "n"), .sized(1, "p", count: 0), .packed(2, 2, "q", count: 0, bias: -1),
                   .times(3, count: 0, .u8(3, "x"))),
        try Scheme(1, .i64(0, "n"), .bits(1, "b", count: 0),
                   .times(2, count: 0, .flags(2, .bool(2, "on"), .group(3, "g", .u16(3, "v"))))),
        try Scheme(1, .u2(.slot(0, "a"), .slot(1, "c")), .sized(2, "p", count: 1),
                   .repeat(3, .flagByte(fb), fb.bit(.u8(3, "k")), fb.bit(.group(4, "h", .u8(4, "n"), .sized(5, "s", count: 4))),
                           .when(6, .eq(3, 1), .u8(6, "w")))),
        try Scheme(1, .flags(0, .u8(0, "n"), .times(1, count: 0, .u8(1, "pt"), .bits(2, "bb", count: 1)), .repeat(3, .u8(3, "r")))),
        try samplesScheme(),
        try typedRouteScheme(),
    ]
}

private let hostileNames = ["n", "p", "q", "x", "b", "on", "g", "v", "a", "c", "k", "h", "s", "w", "pt", "bb", "r", "mark"]

private func hostileValue(_ random: inout SeededRandom, _ depth: Int) -> Any? {
    switch Int.random(in: 0..<12, using: &random) {
    case 0: return nil
    case 1: return Int.random(in: 0..<5, using: &random)
    case 2: return UInt64(1) << 63
    case 3: return -1
    case 4: return [UInt8(1), 0]
    case 5: return "x"
    case 6: return true
    case 7: return 1.5
    default: break
    }
    if depth > 1 { return Int.random(in: 0..<3, using: &random) }
    if Bool.random(using: &random) {
        var map: [String: Any] = [:]
        for _ in 0..<Int.random(in: 0..<3, using: &random) {
            map[hostileNames[Int.random(in: 0..<hostileNames.count, using: &random)]] = hostileValue(&random, depth + 1) as Any
        }
        return map
    }
    return (0..<Int.random(in: 0..<4, using: &random)).map { _ in hostileValue(&random, depth + 1) } as [Any?]
}

/// The no-trap rule for rounds: no buffer or row makes unpack or pack of a round or counted kind
/// trap; each ends in a row, bytes or a `PackbinError`. A huge pack count is refused by the round
/// limits before any round (AZ-2517).
@Suite struct RoundNoTrapTests {
    @Test func unpackAndPack_randomRoundBuffersAndRows_throwOrGiveAValue() throws {
        // Arrange
        let schemes = try hostileRoundSchemes()
        var random = SeededRandom(state: 2515)
        var outcomes = 0

        // Act
        for (index, scheme) in schemes.enumerated() {
            for _ in 0..<3000 {
                var buffer = [UInt8(1)]
                for _ in 0..<Int.random(in: 0..<24, using: &random) {
                    buffer.append(Int.random(in: 0..<8, using: &random) == 0 ? 0xff : UInt8.random(in: 0...3, using: &random))
                }
                // A packet pack would not write (a times bit clear beside a count above 0) can unpack to
                // a row pack refuses, as in TypeScript; either way the result is a value.
                if let row = try? unpackMap(buffer, scheme) {
                    _ = try? pack(scheme, row)
                }
                if index < 4 {
                    var row: [String: Any] = [:]
                    for name in hostileNames where Bool.random(using: &random) { row[name] = hostileValue(&random, 0) as Any }
                    _ = try? pack(scheme, row)
                }
                outcomes += 1
            }
        }

        // Assert
        #expect(outcomes == schemes.count * 3000)
    }

    /// A count of 2^64-1 or 2^63-1 with a short input is refused at once, with no storage reserved
    /// from the count.
    @Test func unpack_maximalCountsWithAShortInput_areRefusedAtOnce() throws {
        // Arrange
        let unsigned = try Scheme(1, .u64(0, "n"), .bits(1, "b", count: 0))
        let signed = try Scheme(1, .i64(0, "n"), .packed(2, 1, "q", count: 0))
        let times = try Scheme(1, .i64(0, "n"), .times(1, count: 0, .u8(1, "x")))

        // Act
        let bits = shortError { try unpackMap(bytes("01ffffffffffffffff01"), unsigned) }
        let packed = shortError { try unpackMap(bytes("01ffffffffffffff7f01"), signed) }
        let rounds = shortError { try unpackMap(bytes("01ffffffffffffff7f0102"), times) }

        // Assert
        #expect(bits?.0 == "b" && bits?.1 == 0 && bits?.2 == 1)
        #expect(packed?.0 == "q" && packed?.1 == Int.max / 4 + 1 && packed?.2 == 1)
        #expect(rounds?.0 == "x" && rounds?.1 == 1 && rounds?.2 == 0)
    }
}
