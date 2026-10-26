/// The MAC-only call of frame mode (contract `pack-session.md` 2.0.0): a tag without encryption, for a
/// per-hop network check and for key fingerprints.
///
/// `K_label = HKDF(key, "packbin-frame" ‖ epoch, 0x00 ‖ label)`; the tag is the first `n` bytes of
/// `HMAC(K_label, message)`, with `n` 4, 8, 16 or 32. The message is given in parts and hashed as they come,
/// with no joined copy, and the tag does not depend on how it is split. `verify` compares every byte of the tag
/// with no early exit.
///
/// The object holds the 32-byte `K_label` (CryptoKit keeps the HMAC pad states inside the HMAC object that
/// every call builds, so they cannot be precomputed here). It is overwritten by `close()` and when the object
/// is released; as for ``FrameSession``, the wipe and the constant-time compare are best effort (the runtime
/// may have copied the bytes, and Swift states no constant-time guarantee). After `derive` the object changes
/// only through `close()`, which is not to be called while another call on the object runs; `tag` and `verify`
/// may run on any number of threads at once, so the type is `@unchecked Sendable` on that rule.
@available(tvOS 14.0, watchOS 7.0, *)
public final class MacKey: @unchecked Sendable, CustomStringConvertible {
    /// The epoch the key was derived for.
    public let epoch: UInt32

    private var labelKey: [UInt8]
    private var closed = false
    private let probe: FrameProbe?

    private init(key: [UInt8], epoch: UInt32, label: [UInt8], probe: FrameProbe?) throws {
        guard key.count == FrameCrypto.keySize else {
            throw PackbinError.frame(.badValue, "the key is \(key.count) bytes, not \(FrameCrypto.keySize)")
        }
        guard epoch <= FrameCrypto.maxEpoch else {
            throw PackbinError.frame(.badValue, "the epoch \(epoch) is above \(FrameCrypto.maxEpoch)")
        }
        guard (1...32).contains(label.count) else {
            throw PackbinError.frame(.badValue, "the label is \(label.count) bytes, not 1 to 32")
        }
        self.epoch = epoch
        self.probe = probe
        labelKey = FrameCrypto.derive(key: key, epoch: epoch, info: [0] + label)
    }

    deinit {
        FrameCrypto.wipe(&labelKey)
        probe?.onRelease?(labelKey)
    }

    public var description: String { "MacKey(epoch: \(epoch))" }

    /// The key for `label` (1 to 32 bytes) under `key` (32 bytes) and `epoch` (at most 0xFFFFFF). Any other
    /// size or epoch creates no key and throws a `.badValue`.
    public static func derive(key: [UInt8], epoch: UInt32, label: [UInt8]) throws -> MacKey {
        try MacKey(key: key, epoch: epoch, label: label, probe: nil)
    }

    /// `derive(key:epoch:label:)` with the test hooks of `FrameProbe` (only `onRelease` is used). Package access:
    /// the package's tests use it; apps cannot.
    package static func derive(key: [UInt8], epoch: UInt32, label: [UInt8], probe: FrameProbe) throws -> MacKey {
        try MacKey(key: key, epoch: epoch, label: label, probe: probe)
    }

    /// The first `n` bytes of the HMAC of the parts joined; `n` is 4, 8, 16 or 32, any other value throws a
    /// `.badValue`, as does a closed key.
    public func tag(_ parts: [[UInt8]], length n: Int) throws -> [UInt8] {
        guard !closed else { throw PackbinError.frame(.badValue, "the key is closed") }
        guard [4, 8, 16, 32].contains(n) else {
            throw PackbinError.frame(.badValue, "the tag length is \(n), not 4, 8, 16 or 32")
        }
        var full = fullTag(parts)
        defer { FrameCrypto.wipe(&full) }
        return Array(full[0..<n])
    }

    /// True when `tag` (4, 8, 16 or 32 bytes) is the tag of the parts joined. Every byte is compared with no
    /// early exit. A tag of another length, or a closed key, gives false.
    public func verify(_ parts: [[UInt8]], tag: [UInt8]) -> Bool {
        guard !closed, [4, 8, 16, 32].contains(tag.count) else { return false }
        var full = fullTag(parts)
        defer { FrameCrypto.wipe(&full) }
        return full.withUnsafeBytes { f in
            tag.withUnsafeBytes { FrameCrypto.equal(UnsafeRawBufferPointer(rebasing: f[..<tag.count]), $0) }
        }
    }

    /// Overwrites the key and refuses every later `tag` with a `.badValue` (and every `verify` with false).
    /// Calling it again does nothing.
    public func close() {
        closed = true
        FrameCrypto.wipe(&labelKey)
    }

    /// Whether `close()` ran.
    public var isClosed: Bool { closed }

    private func fullTag(_ parts: [[UInt8]]) -> [UInt8] {
        var stream = MacStream(key: labelKey)
        for part in parts {
            stream.add(part)
        }
        return stream.finish()
    }

    /// The stored `K_label`, all zero once the key is closed. Package access: the package's tests use it; apps
    /// cannot.
    package var storedKey: [UInt8] { labelKey }
}
