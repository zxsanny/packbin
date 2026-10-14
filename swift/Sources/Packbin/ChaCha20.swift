/// ChaCha20 (RFC 8439 §2.3 and §2.4), written in the package (owner decision S-2): CryptoKit has no
/// raw ChaCha20 stream. It is the pad of `PackSession` and is not public API; the `Vectors` SPI lets
/// the tests check it against the RFC, in a release build too, where `@testable` does not work.
///
/// Every 32-bit addition wraps (`&+`), as the RFC defines it, and every shift is a masking shift, so
/// no input traps.
@_spi(Vectors) public enum ChaCha20 {
    public static let keySize = 32
    public static let nonceSize = 12
    public static let blockSize = 64

    /// The 64-byte block for `key`, `nonce` and the block counter (RFC 8439 §2.3).
    public static func block(key: [UInt8], nonce: [UInt8], counter: UInt32) throws -> [UInt8] {
        let (k, n) = try words(key, nonce)
        var out = [UInt8](repeating: 0, count: blockSize)
        fill(&out, k, n, counter)
        return out
    }

    /// XORs `data` with the key stream that starts at block `counter` (RFC 8439 §2.4). The block
    /// counter is 32 bits: data that would need a block after 2^32 - 1 is refused with a `.badValue`
    /// and left unchanged, never wrapped onto block 0.
    public static func xor(_ data: inout [UInt8], key: [UInt8], nonce: [UInt8], counter: UInt32) throws {
        let (k, n) = try words(key, nonce)
        let blocks = (UInt64(data.count) + UInt64(blockSize - 1)) / UInt64(blockSize)
        guard UInt64(counter) + blocks <= 1 << 32 else {
            throw PackbinError(.badValue, field: nil, reason:
                "session: \(data.count) bytes from ChaCha20 block \(counter) pass the last block counter (4294967295)")
        }
        var pad = [UInt8](repeating: 0, count: blockSize)
        var block = counter
        var offset = 0
        while offset < data.count {
            fill(&pad, k, n, block)
            let count = min(blockSize, data.count - offset)
            for i in 0..<count {
                data[offset + i] ^= pad[i]
            }
            offset += count
            // Wraps only after the last block a run may use (checked above), and is not used again.
            block = block &+ 1
        }
        for i in pad.indices {
            pad[i] = 0
        }
    }

    private static func words(_ key: [UInt8], _ nonce: [UInt8]) throws -> ([UInt32], [UInt32]) {
        guard key.count == keySize else {
            throw PackbinError(.badValue, field: nil, reason: "session: the ChaCha20 key is \(key.count) bytes, not \(keySize)")
        }
        guard nonce.count == nonceSize else {
            throw PackbinError(.badValue, field: nil, reason: "session: the ChaCha20 nonce is \(nonce.count) bytes, not \(nonceSize)")
        }
        return ((0..<8).map { littleEndian(key, $0 * 4) }, (0..<3).map { littleEndian(nonce, $0 * 4) })
    }

    private static func littleEndian(_ bytes: [UInt8], _ at: Int) -> UInt32 {
        UInt32(bytes[at]) | UInt32(bytes[at + 1]) &<< 8 | UInt32(bytes[at + 2]) &<< 16 | UInt32(bytes[at + 3]) &<< 24
    }

    /// One block into `out` (64 bytes): the state of §2.3 (constants, key, counter, nonce), 20 rounds,
    /// the input state added back, serialized little-endian.
    private static func fill(_ out: inout [UInt8], _ k: [UInt32], _ n: [UInt32], _ counter: UInt32) {
        let s: [UInt32] = [0x6170_7865, 0x3320_646e, 0x7962_2d32, 0x6b20_6574,
                           k[0], k[1], k[2], k[3], k[4], k[5], k[6], k[7],
                           counter, n[0], n[1], n[2]]
        var x0 = s[0], x1 = s[1], x2 = s[2], x3 = s[3]
        var x4 = s[4], x5 = s[5], x6 = s[6], x7 = s[7]
        var x8 = s[8], x9 = s[9], x10 = s[10], x11 = s[11]
        var x12 = s[12], x13 = s[13], x14 = s[14], x15 = s[15]
        for _ in 0..<10 {
            quarter(&x0, &x4, &x8, &x12)
            quarter(&x1, &x5, &x9, &x13)
            quarter(&x2, &x6, &x10, &x14)
            quarter(&x3, &x7, &x11, &x15)
            quarter(&x0, &x5, &x10, &x15)
            quarter(&x1, &x6, &x11, &x12)
            quarter(&x2, &x7, &x8, &x13)
            quarter(&x3, &x4, &x9, &x14)
        }
        let x = [x0, x1, x2, x3, x4, x5, x6, x7, x8, x9, x10, x11, x12, x13, x14, x15]
        for i in 0..<16 {
            let word = x[i] &+ s[i]
            out[i * 4] = UInt8(truncatingIfNeeded: word)
            out[i * 4 + 1] = UInt8(truncatingIfNeeded: word &>> 8)
            out[i * 4 + 2] = UInt8(truncatingIfNeeded: word &>> 16)
            out[i * 4 + 3] = UInt8(truncatingIfNeeded: word &>> 24)
        }
    }

    /// The quarter round of RFC 8439 §2.1.
    private static func quarter(_ a: inout UInt32, _ b: inout UInt32, _ c: inout UInt32, _ d: inout UInt32) {
        a = a &+ b; d = rotate(d ^ a, 16)
        c = c &+ d; b = rotate(b ^ c, 12)
        a = a &+ b; d = rotate(d ^ a, 8)
        c = c &+ d; b = rotate(b ^ c, 7)
    }

    private static func rotate(_ v: UInt32, _ bits: UInt32) -> UInt32 {
        v &<< bits | v &>> (32 &- bits)
    }
}
