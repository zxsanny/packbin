/// The keys of one (key, epoch) for the three directions: the ChaCha20 key and the HMAC key of each, 32 bytes
/// each, all zero for a direction that was not loaded. Each is an array of its own that nothing else
/// references, so `wipe()` overwrites the stored bytes in place.
@available(tvOS 14.0, watchOS 7.0, *)
struct FrameSlotKeys: Sendable {
    let epoch: UInt32
    private(set) var enc: [[UInt8]]
    private(set) var mac: [[UInt8]]

    init(key: [UInt8], epoch: UInt32, directions: FrameDirections) {
        self.epoch = epoch
        var enc = [[UInt8]](repeating: [UInt8](repeating: 0, count: FrameCrypto.keySize), count: 3)
        var mac = enc
        for direction in FrameDirection.allCases where directions.contains(direction: direction) {
            let d = direction.rawValue
            enc[direction.index] = FrameCrypto.derive(key: key, epoch: epoch, info: [d] + Array("enc".utf8))
            mac[direction.index] = FrameCrypto.derive(key: key, epoch: epoch, info: [d] + Array("mac".utf8))
        }
        self.enc = enc
        self.mac = mac
    }

    mutating func wipe() {
        for i in 0..<3 {
            FrameCrypto.wipe(&enc[i])
            FrameCrypto.wipe(&mac[i])
        }
    }

    /// Every key byte, in the order enc(up), mac(up), enc(down), mac(down), enc(group), mac(group).
    var allBytes: [UInt8] {
        (0..<3).flatMap { enc[$0] + mac[$0] }
    }
}

/// Frame mode of the session (contract `_docs/02_document/contracts/library/pack-session.md` 2.0.0): sealed,
/// authenticated frames for links that lose, reorder and duplicate messages, and can be written to by anyone
/// with a radio. A frame is `clear ‖ ciphertext ‖ tag`: ChaCha20 under a key per (key, epoch, direction) from
/// HKDF-SHA256, a nonce built from the caller's 8-byte `msgID`, the `kind` nibble, the direction and the epoch,
/// and a tag that is the first 4, 8 or 16 bytes of HMAC-SHA256 over the nonce, the associated data, the clear
/// part and the ciphertext (encrypt, then MAC). Unlike the stream `PackSession` it detects a changed byte.
///
/// The keys of each loaded direction are derived once, at load. `seal` is deterministic (the same inputs give
/// the same bytes) and keeps no state; `open` checks the caller's ``ReplayWindow`` first (no hashing for a
/// duplicate or an old counter), then the tag in constant time, then decrypts into the caller's buffer, which
/// is not written unless the frame opened.
///
/// **Threads.** After `load(key:epoch:config:)` a session changes only through `setPrevious(key:epoch:)`,
/// `clearPrevious()` and `close()`. `seal` and `open` may run on any number of threads at once as long as none
/// of those three runs at the same time (a session is shared between tasks, so the type is `@unchecked
/// Sendable` on that rule). A ``ReplayWindow`` is the caller's: one window is not shared between two `open`
/// calls at once.
///
/// **Keys.** The derived keys are held in arrays no one else references and are overwritten by `close()` and
/// when the session is released. The wipe and the constant-time compare are best effort: Swift gives no
/// guarantee that the optimizer keeps a store to memory about to be freed, that the runtime made no copy of an
/// array (a copy-on-write copy, a spill) before it, or that a compare takes constant time. CryptoKit zeroes the
/// storage of its own key objects. The key array the caller passes is the caller's to wipe.
///
/// Every refusal throws a ``PackbinError`` (kinds `.badValue`, `.tooLong`, `.short` for a short packet,
/// `.bufferFull`, `.tagMismatch`, `.duplicate`, `.tooOld`); no input traps.
@available(tvOS 14.0, watchOS 7.0, *)
public final class FrameSession: @unchecked Sendable, CustomStringConvertible {
    /// The length of the key `load(key:epoch:config:)` takes.
    public static let keySize = FrameCrypto.keySize
    /// The largest epoch (24 bits).
    public static let maxEpoch = FrameCrypto.maxEpoch
    /// The longest frame body: clear part, ciphertext and tag together.
    public static let maxBody = FrameCrypto.maxBody

    private let tagLength: Int
    private let directions: FrameDirections
    private var current: FrameSlotKeys
    private var previous: FrameSlotKeys?
    private var closed = false
    private let probe: FrameProbe?

    private init(key: [UInt8], epoch: UInt32, config: FrameConfig, probe: FrameProbe?) throws {
        guard key.count == Self.keySize else {
            throw PackbinError.frame(.badValue, "the key is \(key.count) bytes, not \(Self.keySize)")
        }
        guard epoch <= Self.maxEpoch else {
            throw PackbinError.frame(.badValue, "the epoch \(epoch) is above \(Self.maxEpoch)")
        }
        guard [4, 8, 16].contains(config.tagLength) else {
            throw PackbinError.frame(.badValue, "the tag length is \(config.tagLength), not 4, 8 or 16")
        }
        tagLength = config.tagLength
        directions = config.directions
        current = FrameSlotKeys(key: key, epoch: epoch, directions: config.directions)
        self.probe = probe
    }

    deinit {
        overwriteKeys()
        probe?.onRelease?(current.allBytes + (previous?.allBytes ?? []))
    }

    public var description: String { "FrameSession(epoch: \(current.epoch), tagLength: \(tagLength))" }

    /// A frame session: the keys of each direction in `config` are derived here, once. A key of any length
    /// other than 32, an `epoch` above 0xFFFFFF or a `tagLength` other than 4, 8 or 16 creates no session and
    /// throws a `.badValue`. The caller's key array is not changed.
    public static func load(key: [UInt8], epoch: UInt32, config: FrameConfig) throws -> FrameSession {
        try FrameSession(key: key, epoch: epoch, config: config, probe: nil)
    }

    /// `load(key:epoch:config:)` with the test hooks of `FrameProbe`. Package access: the package's tests use it;
    /// apps cannot.
    package static func load(key: [UInt8], epoch: UInt32, config: FrameConfig, probe: FrameProbe) throws -> FrameSession {
        try FrameSession(key: key, epoch: epoch, config: config, probe: probe)
    }

    /// Keeps a previous (key, epoch) that `open` tries when the current key's tag does not match: the key just
    /// replaced, for frames sealed before the change. `seal` never uses it. A key of another length or an epoch
    /// above 0xFFFFFF throws a `.badValue` and keeps the slot as it was. A frame that opens under the previous
    /// key commits into the same window, so keep the previous key only for the changeover and call
    /// `clearPrevious()` when it ends. Not to be called while another call on this session runs.
    public func setPrevious(key: [UInt8], epoch: UInt32) throws {
        try requireOpen()
        guard key.count == Self.keySize else {
            throw PackbinError.frame(.badValue, "the previous key is \(key.count) bytes, not \(Self.keySize)")
        }
        guard epoch <= Self.maxEpoch else {
            throw PackbinError.frame(.badValue, "the previous epoch \(epoch) is above \(Self.maxEpoch)")
        }
        previous?.wipe()
        previous = FrameSlotKeys(key: key, epoch: epoch, directions: directions)
    }

    /// Drops the previous (key, epoch) and overwrites its keys. Not to be called while another call on this
    /// session runs.
    public func clearPrevious() {
        previous?.wipe()
        previous = nil
    }

    /// Overwrites every key the session holds and refuses every later call with a `.badValue`. Calling it
    /// again does nothing. Not to be called while another call on this session runs. Releasing the session does
    /// the same overwrite.
    public func close() {
        closed = true
        overwriteKeys()
    }

    /// Whether `close()` ran.
    public var isClosed: Bool { closed }

    /// Seals `clear ‖ plain` into the start of `out` as `clear ‖ ciphertext ‖ tag` and returns the body length.
    /// `clear` is sent as is and authenticated, `plain` is encrypted, `ad` (0 to 255 bytes) is authenticated and
    /// not sent. The same inputs give the same bytes; the session does not change, the previous key is not
    /// used, and any number of threads may seal at once.
    ///
    /// A direction the session did not load, a `kind` above 15, a `context.msgID` that is not 8 bytes or a
    /// closed session throws a `.badValue`; `ad` above 255 bytes, or `clear.count + plain.count + tagLength`
    /// above 255, throws a `.tooLong`; an `out` shorter than the body throws a `.bufferFull`. Every check runs
    /// before the first byte is written, so on a refusal `out` is unchanged.
    ///
    /// **The uniqueness rule (the caller's duty): for one (key, epoch, direction), never seal two different
    /// messages with the same `context.msgID`.** The library keeps no record and cannot check it; a reused
    /// `msgID` repeats the key stream and breaks the confidentiality of both messages. A new epoch derives new
    /// keys and nonces. See ``MessageContext``.
    public func seal(direction: FrameDirection, context: MessageContext, ad: [UInt8], clear: [UInt8],
                     plain: [UInt8], into out: inout [UInt8]) throws -> Int {
        try requireOpen()
        try checkCall(direction, context, ad)
        let bodyLength = clear.count + plain.count + tagLength
        guard bodyLength <= Self.maxBody else {
            throw PackbinError.frame(.tooLong, "the body would be \(bodyLength) bytes, above \(Self.maxBody)")
        }
        guard out.count >= bodyLength else {
            throw PackbinError.frame(.bufferFull, "the body is \(bodyLength) bytes, the buffer \(out.count)",
                                     needed: bodyLength, left: out.count)
        }
        let nonce = Self.nonce(context, direction, current.epoch)
        var ciphertext = plain
        try ChaCha20.xor(&ciphertext, key: current.enc[direction.index], nonce: nonce, counter: 0)
        var tag = clear.withUnsafeBytes { c in
            ciphertext.withUnsafeBytes { e in
                fullTag(current.mac[direction.index], nonce, ad, clear: c, cipher: e)
            }
        }
        out.replaceSubrange(0..<clear.count, with: clear)
        out.replaceSubrange(clear.count..<(clear.count + ciphertext.count), with: ciphertext)
        out.replaceSubrange((bodyLength - tagLength)..<bodyLength, with: tag[0..<tagLength])
        FrameCrypto.wipe(&tag)
        return bodyLength
    }

    /// Opens `body` (`clear ‖ ciphertext ‖ tag`, the first `clearLength` bytes clear) in the contract's order and
    /// writes the plaintext to the start of `out`. The order is fixed: the argument checks, the tag with the
    /// current key and then, when `setPrevious` loaded one, once with the previous key (`.tagMismatch` when
    /// neither matches), and the decryption. `out` is not written unless the frame opened.
    ///
    /// A closed session, a direction not loaded, a `kind` above 15, a `context.msgID` that is not 8 bytes or a
    /// negative `clearLength` throws a `.badValue`; `ad`, `body` or `clearLength` above 255 throws a `.tooLong`
    /// (before any hashing); a body shorter than `clearLength` plus the tag throws a `.short`; an `out` shorter
    /// than the plaintext throws a `.bufferFull`.
    public func open(direction: FrameDirection, context: MessageContext, ad: [UInt8], body: [UInt8],
                     clearLength: Int, into out: inout [UInt8]) throws -> FrameOpened {
        try opened(direction, context, ad, body, clearLength, nil, &out)
    }

    /// `open` with a replay window and the message's counter. After the argument checks, a counter the window
    /// has seen throws a `.duplicate` and one 64 or more behind its highest a `.tooOld`, with no MAC computed;
    /// only a frame that opened is committed into `window`, so any refusal leaves it as it was.
    ///
    /// **The counter must come from bytes the tag covers** (the `msgID` or the associated data), never from an
    /// unauthenticated field of the wire; see ``ReplayWindow``. A frame that opens under the previous key
    /// commits into the same window.
    public func open(direction: FrameDirection, context: MessageContext, ad: [UInt8], body: [UInt8],
                     clearLength: Int, window: inout ReplayWindow, counter: UInt64,
                     into out: inout [UInt8]) throws -> FrameOpened {
        let result = try opened(direction, context, ad, body, clearLength, (window, counter), &out)
        window.commit(counter)
        return result
    }

    private func opened(_ direction: FrameDirection, _ context: MessageContext, _ ad: [UInt8], _ body: [UInt8],
                        _ clearLength: Int, _ replay: (window: ReplayWindow, counter: UInt64)?,
                        _ out: inout [UInt8]) throws -> FrameOpened {
        try requireOpen()
        guard clearLength >= 0 else {
            throw PackbinError.frame(.badValue, "the clear length is \(clearLength)")
        }
        try checkCall(direction, context, ad)
        guard body.count <= Self.maxBody, clearLength <= Self.maxBody else {
            throw PackbinError.frame(.tooLong, "the body is \(body.count) bytes and the clear part \(clearLength), above \(Self.maxBody)")
        }
        let framing = clearLength + tagLength
        guard body.count >= framing else {
            throw PackbinError.frame(.short, "the body is \(body.count) bytes, the clear part and tag \(framing)",
                                     needed: framing, left: body.count)
        }
        let plainLength = body.count - framing
        guard out.count >= plainLength else {
            throw PackbinError.frame(.bufferFull, "the plaintext is \(plainLength) bytes, the buffer \(out.count)",
                                     needed: plainLength, left: out.count)
        }
        if let replay {
            switch replay.window.check(replay.counter) {
            case .fresh: break
            case .duplicate: throw PackbinError.frame(.duplicate, "counter \(replay.counter) was already committed")
            case .tooOld: throw PackbinError.frame(.tooOld, "counter \(replay.counter) is 64 or more behind the window")
            }
        }
        let cipherEnd = clearLength + plainLength
        let (slot, keys) = try body.withUnsafeBytes { raw -> (FrameSlot, FrameSlotKeys) in
            let clear = UnsafeRawBufferPointer(rebasing: raw[..<clearLength])
            let cipher = UnsafeRawBufferPointer(rebasing: raw[clearLength..<cipherEnd])
            let tag = UnsafeRawBufferPointer(rebasing: raw[cipherEnd...])
            if tagMatches(current, direction, context, ad, clear, cipher, tag) { return (.current, current) }
            if let previous, tagMatches(previous, direction, context, ad, clear, cipher, tag) {
                return (.previous, previous)
            }
            throw PackbinError.frame(.tagMismatch, "the tag does not match")
        }
        var plain = Array(body[clearLength..<cipherEnd])
        try ChaCha20.xor(&plain, key: keys.enc[direction.index], nonce: Self.nonce(context, direction, keys.epoch),
                         counter: 0)
        out.replaceSubrange(0..<plainLength, with: plain)
        FrameCrypto.wipe(&plain)
        return FrameOpened(slot: slot, clearLength: clearLength, plainLength: plainLength)
    }

    private func requireOpen() throws {
        if closed { throw PackbinError.frame(.badValue, "the session is closed") }
    }

    private func checkCall(_ direction: FrameDirection, _ context: MessageContext, _ ad: [UInt8]) throws {
        guard directions.contains(direction: direction) else {
            throw PackbinError.frame(.badValue, "direction \(direction.rawValue) is not loaded")
        }
        guard context.kind <= 15 else {
            throw PackbinError.frame(.badValue, "the kind is \(context.kind), above 15")
        }
        guard context.msgID.count == 8 else {
            throw PackbinError.frame(.badValue, "the msg_id is \(context.msgID.count) bytes, not 8")
        }
        guard ad.count <= Self.maxBody else {
            throw PackbinError.frame(.tooLong, "the associated data is \(ad.count) bytes, above \(Self.maxBody)")
        }
    }

    /// `msg_id ‖ ((kind << 4) | direction) ‖ epoch` as 24 bits.
    private static func nonce(_ context: MessageContext, _ direction: FrameDirection, _ epoch: UInt32) -> [UInt8] {
        context.msgID + [context.kind << 4 | direction.rawValue, UInt8(truncatingIfNeeded: epoch),
                         UInt8(truncatingIfNeeded: epoch >> 8), UInt8(truncatingIfNeeded: epoch >> 16)]
    }

    /// The full HMAC over the contract's `M`: nonce, `len(ad)`, `ad`, `len(clear)`, `clear`, ciphertext.
    private func fullTag(_ macKey: [UInt8], _ nonce: [UInt8], _ ad: [UInt8], clear: UnsafeRawBufferPointer,
                         cipher: UnsafeRawBufferPointer) -> [UInt8] {
        probe?.onMac?()
        var stream = MacStream(key: macKey)
        stream.add(nonce)
        stream.add(byte: UInt8(ad.count))
        stream.add(ad)
        stream.add(byte: UInt8(clear.count))
        stream.add(clear)
        stream.add(cipher)
        return stream.finish()
    }

    /// Whether the received tag is the first `tagLength` bytes of the slot's tag. All of them are compared.
    private func tagMatches(_ slot: FrameSlotKeys, _ direction: FrameDirection, _ context: MessageContext,
                            _ ad: [UInt8], _ clear: UnsafeRawBufferPointer, _ cipher: UnsafeRawBufferPointer,
                            _ received: UnsafeRawBufferPointer) -> Bool {
        let nonce = Self.nonce(context, direction, slot.epoch)
        var expected = fullTag(slot.mac[direction.index], nonce, ad, clear: clear, cipher: cipher)
        defer { FrameCrypto.wipe(&expected) }
        return expected.withUnsafeBytes { FrameCrypto.equal(UnsafeRawBufferPointer(rebasing: $0[..<tagLength]), received) }
    }

    private func overwriteKeys() {
        current.wipe()
        previous?.wipe()
    }

    /// The stored key bytes of `direction` (the HMAC key is the "pad state" of this implementation: CryptoKit
    /// keeps the pad states inside its HMAC object, which is built per call). All zero once the session is
    /// closed. Nil for the previous slot when none is loaded. Package access: the package's tests use it; apps
    /// cannot.
    package func derivedKeys(for direction: FrameDirection, previous wantPrevious: Bool = false)
        -> (enc: [UInt8], mac: [UInt8])? {
        guard let slot = wantPrevious ? previous : current else { return nil }
        return (slot.enc[direction.index], slot.mac[direction.index])
    }
}
