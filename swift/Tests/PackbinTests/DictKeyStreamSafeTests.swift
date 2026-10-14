import Foundation
import Packbin
import Testing

/// A key of `marks` combining marks after "a": U+0301 (class 230) and U+0316 (class 220) in turn, which
/// NFC must reorder.
private func markKey(_ marks: Int) -> String {
    "a" + String(String.UnicodeScalarView((0..<marks).map { Unicode.Scalar($0 % 2 == 0 ? 0x301 : 0x316)! }))
}

/// A `dict("d", u8)` packet whose keys are `keys`, each with the value 1.
private func dictPacket(_ keys: [[UInt8]]) -> [UInt8] {
    var packet: [UInt8] = [1, UInt8(keys.count & 0xff), UInt8(keys.count >> 8)]
    for key in keys { packet += [UInt8(key.count & 0xff), UInt8(key.count >> 8)] + key + [1] }
    return packet
}

private struct Marked: PackbinRow {
    var d: [String: UInt8] = [:]
}

@Sendable private func dictScheme() throws -> Scheme { try Scheme(1, .dict("d", .u8(0, "e"))) }

/// F47 of the loop 26 security audit: Swift hashes and compares a dict key in NFC and reorders a run of
/// combining marks in quadratic time, so a key that is not in Unicode's stream-safe form (more than 30
/// marks in a row) is refused on unpack, with the shape of a key that is not UTF-8, and on pack.
@Suite struct DictKeyStreamSafeTests {
    @Test(arguments: [[30], [30, 30], [1, 29]])
    func roundTrip_keyOfAtMostThirtyMarksInARun_packsAndUnpacks(_ runs: [Int]) throws {
        // Arrange: a run of marks ends at the next base letter.
        let key = runs.map(markKey).joined()
        let scheme = try dictScheme()
        let typed = try Scheme(1, .dict("d", .u8(0, "e")).bind(get: { (r: Marked) in r.d }, set: { $0.d = $1 }))

        // Act
        let packet = try pack(scheme, ["d": [key: 1]])
        let map = try unpackMap(packet, scheme)
        let row = try unpack(packet, typed) as? Marked

        // Assert
        #expect(packet == dictPacket([Array(key.utf8)]))
        #expect((map["d"] as? [String: Any])?[key] as? UInt8 == 1)
        #expect(row?.d == [key: 1])
        #expect(try pack(scheme, map) == packet)
    }

    @Test func unpack_keyOfThirtyOneMarksInARun_isRefusedAsAnUnreadableKey() throws {
        // Arrange: one good key first, so the refusal points at the start of the second.
        let scheme = try dictScheme()
        let typed = try Scheme(1, .dict("d", .u8(0, "e")).bind(get: { (r: Marked) in r.d }, set: { $0.d = $1 }))
        let second = Array(markKey(31).utf8)
        let packet = dictPacket([Array("b".utf8), second])

        // Act
        let asMap = packbinError { try unpackMap(packet, scheme) }
        let asTyped = packbinError { try unpack(packet, typed) }

        // Assert: as invalid UTF-8 is, `.short` naming the dict, nothing needed, the key's bytes left.
        for e in [asMap, asTyped] {
            #expect(e?.kind == .short && e?.field == nil && e?.name == "d")
            #expect(e?.needed == 0 && e?.left == 2 + second.count + 1)
        }
    }

    @Test func pack_keyOfThirtyOneMarksInARun_isRefusedNamingTheDict() throws {
        // Arrange
        let scheme = try dictScheme()

        // Act
        let error = packError(scheme, ["d": ["b": 1, markKey(31): 2]])

        // Assert
        #expect(error?.kind == .packError && error?.field == nil && error?.name == "d")
        #expect(error?.reason.hasPrefix("d: a dict key holds more than 30 combining marks in a row") == true)
    }

    @Test(.enabled(if: !threadSanitized, "one thread, no shared state: the thread sanitizer adds nothing and runs it about ten times slower"))
    func unpack_mebibyteOfSixteenKeysOfCombiningMarks_isRefusedWithinASecond() throws {
        // Arrange: the audit's packet, 16 keys of 4 digits and 32 498 marks (65 000 bytes), 1 040 051 bytes;
        // unrefused it took 25 s.
        let keys = (0..<16).map { k in Array(String(format: "%04d", k).utf8) + Array(markKey(32_498).utf8.dropFirst()) }
        let packet = dictPacket(keys)
        let scheme = try dictScheme()

        // Act
        let (error, seconds) = timed { unpackError(packet, scheme) }

        // Assert
        #expect(keys[0].count == 65_000 && packet.count == 1_040_051)
        #expect(error?.kind == .short && error?.name == "d" && error?.needed == 0 && error?.left == packet.count - 3)
        #expect(withinOneSecond(seconds), "took \(seconds) s")
    }

    @Test(.enabled(if: !threadSanitized, "one thread, no shared state: the thread sanitizer adds nothing and runs it about ten times slower"))
    func unpack_sixteenAsciiKeysOfTheLongestLength_unpackWithinASecond() throws {
        // Arrange
        let keys = (0..<16).map { k in Array(String(format: "%04d", k).utf8) + [UInt8](repeating: 0x61, count: 65_531) }
        let packet = dictPacket(keys)
        let scheme = try dictScheme()

        // Act
        let (map, seconds) = try timed { try unpackMap(packet, scheme) }

        // Assert
        #expect((map["d"] as? [String: Any])?.count == 16)
        #expect(withinOneSecond(seconds), "took \(seconds) s")
    }
}
