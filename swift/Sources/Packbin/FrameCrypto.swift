#if canImport(CryptoKit)
import CryptoKit
#else
import Crypto
#endif

/// The primitives of frame mode on the platform's HKDF-SHA256 and HMAC-SHA256 (CryptoKit on Apple platforms,
/// swift-crypto's `Crypto` elsewhere: the same API and bytes), beside the in-package ChaCha20.
@available(tvOS 14.0, watchOS 7.0, *)
enum FrameCrypto {
    static let keySize = 32
    static let maxEpoch: UInt32 = 0x00FF_FFFF
    static let maxBody = 255
    private static let label = Array("packbin-frame".utf8)

    /// `"packbin-frame" ‖ epoch` as a 32-bit little-endian integer.
    static func salt(_ epoch: UInt32) -> [UInt8] {
        label + (0..<4).map { UInt8(truncatingIfNeeded: epoch &>> UInt32($0 * 8)) }
    }

    /// `HKDF(IKM = key, salt, info, L = 32)`.
    static func derive(key: [UInt8], epoch: UInt32, info: [UInt8]) -> [UInt8] {
        let derived = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: key), salt: salt(epoch),
                                             info: info, outputByteCount: keySize)
        return derived.withUnsafeBytes { [UInt8]($0) }
    }

    /// Zeroes the bytes in place in a call the optimizer keeps. Swift gives no guarantee that no copy was made
    /// earlier (see the notes on `FrameSession`).
    @inline(never) @_optimize(none)
    static func wipe(_ bytes: inout [UInt8]) {
        bytes.withUnsafeMutableBytes { _ = $0.initializeMemory(as: UInt8.self, repeating: 0) }
    }

    /// True when the buffers are equal. It folds every byte into one accumulator and decides after the last
    /// one, so the time does not depend on where they differ; only the lengths, which are public, end it early.
    /// The call is not inlined and not optimized, so the optimizer cannot turn the fold into an early exit
    /// (best effort: Swift states no constant-time guarantee).
    @inline(never) @_optimize(none)
    static func equal(_ a: UnsafeRawBufferPointer, _ b: UnsafeRawBufferPointer) -> Bool {
        guard a.count == b.count else { return false }
        var diff: UInt8 = 0
        for i in 0..<a.count {
            diff |= a[i] ^ b[i]
        }
        return diff == 0
    }

    static func equal(_ a: [UInt8], _ b: [UInt8]) -> Bool {
        a.withUnsafeBytes { x in b.withUnsafeBytes { y in equal(x, y) } }
    }
}

/// HMAC-SHA256 over a message given in parts, hashed as they come with no joined copy.
@available(tvOS 14.0, watchOS 7.0, *)
struct MacStream {
    private var hmac: HMAC<SHA256>

    init(key: [UInt8]) {
        hmac = HMAC<SHA256>(key: SymmetricKey(data: key))
    }

    mutating func add(_ bytes: UnsafeRawBufferPointer) {
        hmac.update(data: bytes)
    }

    mutating func add(_ bytes: [UInt8]) {
        bytes.withUnsafeBytes { hmac.update(data: $0) }
    }

    mutating func add(byte: UInt8) {
        var one = byte
        withUnsafeBytes(of: &one) { hmac.update(data: $0) }
    }

    /// The 32-byte HMAC.
    mutating func finish() -> [UInt8] {
        Array(hmac.finalize())
    }
}

/// The primitives the package uses, for the shared primitive vectors (`fixtures/crypto/vectors.txt`): each call
/// is the platform function the frame code calls. Package access: the package's tests use it; apps cannot.
@available(tvOS 14.0, watchOS 7.0, *)
package enum FramePrimitives {
    /// SHA-256 of the message.
    package static func sha256(_ message: [UInt8]) -> [UInt8] {
        Array(SHA256.hash(data: message))
    }

    /// HMAC-SHA256 of the message under the key, in one piece.
    package static func hmac256(key: [UInt8], data: [UInt8]) -> [UInt8] {
        var stream = MacStream(key: key)
        stream.add(data)
        return stream.finish()
    }

    /// The HKDF-SHA256 extract step (RFC 5869 §2.2); an empty salt is the RFC's string of zeros.
    package static func hkdfExtract(ikm: [UInt8], salt: [UInt8]) -> [UInt8] {
        Array(HKDF<SHA256>.extract(inputKeyMaterial: SymmetricKey(data: ikm), salt: salt))
    }

    /// The HKDF-SHA256 output of `length` bytes (extract and expand).
    package static func hkdf256(ikm: [UInt8], salt: [UInt8], info: [UInt8], length: Int) -> [UInt8] {
        let derived = HKDF<SHA256>.deriveKey(inputKeyMaterial: SymmetricKey(data: ikm), salt: salt, info: info,
                                             outputByteCount: length)
        return derived.withUnsafeBytes { [UInt8]($0) }
    }

    /// The tag compare of frame mode: equal lengths and all bytes equal, every byte read before the decision.
    package static func tagsEqual(_ a: [UInt8], _ b: [UInt8]) -> Bool {
        FrameCrypto.equal(a, b)
    }
}

/// Hooks for the tests: a count of MAC computations and a look at the key bytes once a session or key object is
/// released. Package access: the package's tests use it; apps cannot.
package struct FrameProbe: Sendable {
    /// Called once per HMAC computation of a session (seal, and each slot an open tries).
    package var onMac: (@Sendable () -> Void)?
    /// Called from `deinit` after the keys were overwritten, with every key byte the object held (all zero
    /// when the wipe worked).
    package var onRelease: (@Sendable ([UInt8]) -> Void)?

    package init(onMac: (@Sendable () -> Void)? = nil, onRelease: (@Sendable ([UInt8]) -> Void)? = nil) {
        self.onMac = onMac
        self.onRelease = onRelease
    }
}
