import Foundation
import Packbin
import Testing

/// AZ-2713: a decoded dict key must be strictly greater than the key before it, compared by UTF-8 bytes
/// (not by Swift's canonical-equivalence order, nor by UTF-16 units). An equal key is a repeated one, a
/// smaller key is out of order; both are the "dict key given twice" refusal, and a canonical packet
/// (every encoder writes the pairs sorted by bytes) reads as before.
@Suite struct DictKeyOrderTests {
    /// The raw field of a key (the mode byte 0x10 and the UTF-8 bytes) for a short key.
    private func rawKey(_ bytes: [UInt8]) -> [UInt8] { [UInt8(bytes.count + 1), 0x10] + bytes }

    /// A packet of a `dict m` of u8: the keys as UTF-8 bytes, in the given order, each with value 0.
    private func packet(_ keys: [[UInt8]]) -> [UInt8] {
        [1, UInt8(keys.count), 0] + keys.flatMap { rawKey($0) + [0] }
    }

    private func scheme() throws -> Scheme { try Scheme(1, .dict("m", .u8(0, "v"))) }

    static let ascending: [(String, [[UInt8]])] = [
        ("a then b", [[0x61], [0x62]]),
        ("a prefix before the longer key", [[0x61], [0x61, 0x62]]),
        ("the empty key first", [[], [0x61]]),
        ("U+FF5E then U+10000 (ascending in UTF-8, descending in UTF-16)", [[0xEF, 0xBD, 0x9E], [0xF0, 0x90, 0x80, 0x80]]),
        ("e then U+00E9 (bytes 65 < c3 a9)", [[0x65], [0xC3, 0xA9]]),
    ]

    @Test(arguments: ascending)
    func unpack_keysAscendingByUtf8Bytes_areAccepted(_ name: String, _ keys: [[UInt8]]) throws {
        // Arrange
        let wire = packet(keys)

        // Act
        let map = try unpackMap(wire, try scheme())

        // Assert
        let held = try #require(map["m"] as? [String: Any], "\(name)")
        #expect(Set(held.keys.map { Array($0.utf8) }) == Set(keys), "\(name)")
    }

    static let refused: [(String, [[UInt8]])] = [
        ("b then a", [[0x62], [0x61]]),
        ("a key twice", [[0x61], [0x61]]),
        ("a longer key then its prefix", [[0x61, 0x62], [0x61]]),
        ("U+10000 then U+FF5E", [[0xF0, 0x90, 0x80, 0x80], [0xEF, 0xBD, 0x9E]]),
        ("a then the empty key", [[0x61], []]),
        ("the empty key twice", [[], []]),
        ("the third key out of order", [[0x61], [0x63], [0x62]]),
        ("U+00E9 then e (precomposed, then the plain letter)", [[0xC3, 0xA9], [0x65]]),
        ("NFC then NFD of one key (descending bytes, equal as strings)", [[0xC3, 0xA9], [0x65, 0xCC, 0x81]]),
        ("NFD then NFC of one key (ascending bytes, equal as strings)", [[0x65, 0xCC, 0x81], [0xC3, 0xA9]]),
    ]

    @Test(arguments: refused)
    func unpack_keysNotStrictlyAscendingByUtf8Bytes_areRefusedAsAKeyGivenTwiceWithNoRow(_ name: String, _ keys: [[UInt8]]) throws {
        // Arrange
        let wire = packet(keys)
        let scheme = try scheme()

        // Act
        let asMap = packbinError { try unpackMap(wire, scheme) }
        let asAny = packbinError { try unpack(wire, scheme) }

        // Assert
        for e in [asMap, asAny] {
            #expect(e?.kind == .short && e?.field == nil && e?.name == "m", "\(name)")
            #expect(e?.needed == 0 && e?.left == 0 && e?.reason == "dict key given twice", "\(name)")
        }
    }

    @Test func unpack_keyOutOfOrderInANestedDict_isRefused() throws {
        // Arrange: dict d of dict e of u8, the inner keys b then a
        let scheme = try Scheme(1, .dict("d", .dict("e", .u8(0, "v"))))
        let wire: [UInt8] = [1, 1, 0] + rawKey([0x78]) + [2, 0] + rawKey([0x62]) + [0] + rawKey([0x61]) + [0]

        // Act
        let error = packbinError { try unpackMap(wire, scheme) }

        // Assert
        #expect(error?.kind == .short && error?.name == "e" && error?.reason == "dict key given twice")
    }

    @Test(.enabled(if: !threadSanitized, "the thread sanitizer runs one thread about ten times slower"))
    func packAndUnpack_65535AscendingKeys_takeAtMostOneSecond() throws {
        // Arrange: zero-padded keys sort the same by bytes and by number
        let scheme = try Scheme(1, .dict("m", .u8(0, "v")))
        var dict: [String: Any] = [:]
        for i in 0..<65_535 { dict[String(format: "k%05d", i)] = 1 }
        var fastest = Double.infinity
        var limit = LoadBound(nominal: 1, factor: 1)

        // Act
        #if DEBUG
        let passes = 1
        #else
        let passes = 3
        #endif
        var count = 0
        for _ in 0..<passes where !limit.holds(fastest) {
            limit = bound(1)
            let (back, seconds) = try timed { () throws -> [String: Any] in
                try unpackMap(try pack(scheme, ["m": dict]), scheme)
            }
            count = (back["m"] as? [String: Any])?.count ?? 0
            fastest = min(fastest, seconds)
        }

        // Assert
        print("65535 ascending dict keys: fastest pack and unpack \(fastest) s (\(buildKind))")
        #expect(count == 65_535)
        #if !DEBUG
        expectWithin(fastest, limit)
        #endif
    }
}

#if DEBUG
private let buildKind = "debug build: not asserted"
#else
private let buildKind = "release build"
#endif
