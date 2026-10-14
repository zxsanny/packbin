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
        var input = try Input(key, nonce)
        defer { input.wipe() }
        var out = [UInt8](repeating: 0, count: blockSize)
        fill(&out, input, counter)
        return out
    }

    /// XORs `data` with the key stream that starts at block `counter` (RFC 8439 §2.4). The block
    /// counter is 32 bits: data that would need a block after 2^32 - 1 is refused with a `.badValue`
    /// and left unchanged, never wrapped onto block 0.
    public static func xor(_ data: inout [UInt8], key: [UInt8], nonce: [UInt8], counter: UInt32) throws {
        var input = try Input(key, nonce)
        defer { input.wipe() }
        let blocks = (UInt64(data.count) + UInt64(blockSize - 1)) / UInt64(blockSize)
        guard UInt64(counter) + blocks <= 1 << 32 else {
            throw PackbinError(.badValue, field: nil, reason:
                "session: \(data.count) bytes from ChaCha20 block \(counter) pass the last block counter (4294967295)")
        }
        var pad = [UInt8](repeating: 0, count: blockSize)
        var block = counter
        var offset = 0
        while offset < data.count {
            fill(&pad, input, block)
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

    /// The state of §2.3 but the constants and the counter: the 8 key words and the 3 nonce words.
    /// They are stored properties, so they live in the caller's frame and never in a heap array, and
    /// the caller zeroes them when it is done (with no guarantee against a copy the compiler made in
    /// registers or a spill slot).
    private struct Input {
        var k0, k1, k2, k3, k4, k5, k6, k7: UInt32
        var n0, n1, n2: UInt32

        init(_ key: [UInt8], _ nonce: [UInt8]) throws {
            guard key.count == keySize else {
                throw PackbinError(.badValue, field: nil, reason: "session: the ChaCha20 key is \(key.count) bytes, not \(keySize)")
            }
            guard nonce.count == nonceSize else {
                throw PackbinError(.badValue, field: nil, reason: "session: the ChaCha20 nonce is \(nonce.count) bytes, not \(nonceSize)")
            }
            (k0, k1, k2, k3) = (littleEndian(key, 0), littleEndian(key, 4), littleEndian(key, 8), littleEndian(key, 12))
            (k4, k5, k6, k7) = (littleEndian(key, 16), littleEndian(key, 20), littleEndian(key, 24), littleEndian(key, 28))
            (n0, n1, n2) = (littleEndian(nonce, 0), littleEndian(nonce, 4), littleEndian(nonce, 8))
        }

        mutating func wipe() {
            withUnsafeMutableBytes(of: &self) { zero($0) }
        }
    }

    /// Zeroes `bytes` in a call the optimizer keeps. Zeroing a value whose frame is about to end is a
    /// dead store that `-O` removes (the assembly of `xor` showed no store to the key words), so the
    /// stores happen in a function that is neither inlined nor optimized.
    @inline(never) @_optimize(none)
    private static func zero(_ bytes: UnsafeMutableRawBufferPointer) {
        _ = bytes.initializeMemory(as: UInt8.self, repeating: 0)
    }

    private static func littleEndian(_ bytes: [UInt8], _ at: Int) -> UInt32 {
        UInt32(bytes[at]) | UInt32(bytes[at + 1]) &<< 8 | UInt32(bytes[at + 2]) &<< 16 | UInt32(bytes[at + 3]) &<< 24
    }

    /// One block into `out` (64 bytes): the state of §2.3 (constants, key, counter, nonce), 20 rounds,
    /// the input state added back, serialized little-endian. The state is 16 local words, no array.
    private static func fill(_ out: inout [UInt8], _ i: Input, _ counter: UInt32) {
        let c0: UInt32 = 0x6170_7865, c1: UInt32 = 0x3320_646e, c2: UInt32 = 0x7962_2d32, c3: UInt32 = 0x6b20_6574
        var x0 = c0, x1 = c1, x2 = c2, x3 = c3
        var x4 = i.k0, x5 = i.k1, x6 = i.k2, x7 = i.k3
        var x8 = i.k4, x9 = i.k5, x10 = i.k6, x11 = i.k7
        var x12 = counter, x13 = i.n0, x14 = i.n1, x15 = i.n2
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
        put(&out, 0, x0 &+ c0); put(&out, 1, x1 &+ c1); put(&out, 2, x2 &+ c2); put(&out, 3, x3 &+ c3)
        put(&out, 4, x4 &+ i.k0); put(&out, 5, x5 &+ i.k1); put(&out, 6, x6 &+ i.k2); put(&out, 7, x7 &+ i.k3)
        put(&out, 8, x8 &+ i.k4); put(&out, 9, x9 &+ i.k5); put(&out, 10, x10 &+ i.k6); put(&out, 11, x11 &+ i.k7)
        put(&out, 12, x12 &+ counter); put(&out, 13, x13 &+ i.n0); put(&out, 14, x14 &+ i.n1); put(&out, 15, x15 &+ i.n2)
    }

    /// Word `index` of a block, little-endian.
    private static func put(_ out: inout [UInt8], _ index: Int, _ word: UInt32) {
        out[index * 4] = UInt8(truncatingIfNeeded: word)
        out[index * 4 + 1] = UInt8(truncatingIfNeeded: word &>> 8)
        out[index * 4 + 2] = UInt8(truncatingIfNeeded: word &>> 16)
        out[index * 4 + 3] = UInt8(truncatingIfNeeded: word &>> 24)
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
