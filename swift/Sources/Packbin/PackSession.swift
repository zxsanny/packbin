/// One optional encrypted connection beside clear `pack` and `unpack` (contract
/// `_docs/02_document/contracts/library/pack-session.md` v1.0.0). Both sides load the same 32-byte
/// seed; the opener calls `start()` and sends the 16 bytes it returns once, in the clear; the waiter
/// calls `join(_:)` with them. A payload keeps the length of the clear packet. There is no tag: a
/// flipped bit is not detected.
///
/// Both sides derive two keys with HKDF-SHA256 (seed, the 16 bytes as salt, info "packbin"); the
/// opener sends with the first and receives with the second, the waiter the other way round. Each
/// direction numbers its packets from 0, and packet n is XORed with the ChaCha20 (RFC 8439) stream
/// whose 12-byte nonce is n, little-endian, from block 0. The numbers are not sent: the receiver
/// unpacks the payloads in the order they were packed.
///
/// A `PackSession` is used by one task at a time. It is a class (two copies must never share a
/// stream) and is not `Sendable`: hand it from task to task, never use it from two at once.
///
/// Every refusal throws a ``PackbinError``; no input traps.
@available(tvOS 14.0, watchOS 7.0, *)
public final class PackSession {
    /// The length of the seed `load(_:)` takes.
    public static let seedSize = 32
    /// The length of the value the opener sends once and the waiter joins with.
    public static let nonceSize = 16

    /// The session's own copy of the seed until it opens; empty once open.
    private var seed: [UInt8]
    /// The keys of the two directions; empty until the session opens.
    private var send: [UInt8] = []
    private var recv: [UInt8] = []
    private var sendCount: UInt64 = 0
    private var recvCount: UInt64 = 0

    private init(seed: [UInt8]) {
        self.seed = seed
    }

    /// The seed of a session that never opened and the keys of one that did are zeroed when it goes.
    deinit {
        Self.wipe(&seed)
        Self.wipe(&send)
        Self.wipe(&recv)
    }

    /// A session that keeps a copy of the 32-byte seed until `start` or `join`. A seed of any other
    /// length makes no session and throws a `.badValue`. The caller's array is not changed.
    public static func load(_ seed: [UInt8]) throws -> PackSession {
        guard seed.count == seedSize else {
            throw sessionError("the seed is \(seed.count) bytes, not \(seedSize)")
        }
        // Storage of its own, so wiping it never writes to (or copies) the caller's buffer.
        return PackSession(seed: seed.withUnsafeBytes { [UInt8]($0) })
    }

    /// Opens the session as the opener with 16 bytes from the system's secure random generator and
    /// returns them: send them to the waiter once. A session that is already open throws a `.badValue`.
    public func start() throws -> [UInt8] {
        try requireClosed()
        var random = SystemRandomNumberGenerator()
        var nonce = [UInt8](repeating: 0, count: Self.nonceSize)
        for i in nonce.indices {
            nonce[i] = random.next()
        }
        try open(nonce, opener: true)
        return nonce
    }

    /// Opens the session as the opener with 16 bytes the caller already has, and returns them. A
    /// length other than 16 opens nothing, throws a `.badValue` and keeps the seed. The value must be
    /// fresh for every connection of one seed: two sessions that start with the same value share their
    /// key stream, and with no tag the XOR of two payloads is then the XOR of their packets.
    public func start(_ nonce: [UInt8]) throws -> [UInt8] {
        try open(nonce, opener: true)
        return nonce
    }

    /// Opens the session as the waiter with the 16 bytes the opener sent. A length other than 16 joins
    /// nothing, throws a `.badValue` and keeps the seed.
    public func join(_ nonce: [UInt8]) throws {
        try open(nonce, opener: false)
    }

    /// Packs a map row as `pack(_:_:)` does, then pads it with the next position of the send
    /// direction. Before `start` or `join` it throws a `.packError`; a refused row throws the error
    /// `pack` throws. A failed call returns no bytes and spends no position.
    public func pack(_ scheme: Scheme, _ row: [String: Any]) throws -> [UInt8] {
        try requireOpen()
        return try sealed(try Packbin.pack(scheme, row))
    }

    /// Packs a typed row (or a map row) as `pack(_:_:)` does, then pads it as the map form does.
    public func pack<Row>(_ scheme: Scheme, _ row: Row) throws -> [UInt8] {
        try requireOpen()
        return try sealed(try Packbin.pack(scheme, row))
    }

    /// Removes the pad of the next position of the receive direction from a copy of `payload` and
    /// unpacks it as `unpack(_:_:)` does, so a payload that cannot be read throws what clear unpack
    /// throws. Every call on an open session spends a position, whether or not the payload then reads
    /// (as TypeScript and C#). Before `join` or `start` it throws the `.short` of an empty buffer
    /// (needed 1, left 0).
    public func unpack(_ payload: [UInt8], _ schemes: Scheme...) throws -> Any {
        try unpack(payload, schemes)
    }

    /// `unpack` with the schemes as an array.
    public func unpack(_ payload: [UInt8], _ schemes: [Scheme]) throws -> Any {
        try Packbin.unpack(try opened(payload), schemes)
    }

    /// `unpack` with the row as a map keyed by field name, as `unpackMap(_:_:)` gives it.
    public func unpackMap(_ payload: [UInt8], _ schemes: Scheme...) throws -> [String: Any] {
        try unpackMap(payload, schemes)
    }

    /// `unpackMap` with the schemes as an array.
    public func unpackMap(_ payload: [UInt8], _ schemes: [Scheme]) throws -> [String: Any] {
        try Packbin.unpackMap(try opened(payload), schemes)
    }

    private func requireClosed() throws {
        guard send.isEmpty else { throw Self.sessionError("the session is already open") }
    }

    private func requireOpen() throws {
        guard !send.isEmpty else {
            throw PackbinError.pack(nil, "", "the session is not open: call start or join first")
        }
    }

    /// `plain` padded with the next send position, which is then spent.
    private func sealed(_ plain: [UInt8]) throws -> [UInt8] {
        var data = plain
        try Self.pad(&data, key: send, position: sendCount)
        sendCount += 1
        return data
    }

    /// A copy of `payload` with the next receive pad removed; the position is spent.
    private func opened(_ payload: [UInt8]) throws -> [UInt8] {
        guard !recv.isEmpty else { throw PackbinError.shortPacket(nil, "", needed: 1, left: 0) }
        var data = payload
        try Self.pad(&data, key: recv, position: recvCount)
        recvCount += 1
        return data
    }

    /// Derives both directions from the seed and the 16 bytes, then wipes the seed and the derived
    /// block.
    private func open(_ nonce: [UInt8], opener: Bool) throws {
        try requireClosed()
        guard nonce.count == Self.nonceSize else {
            throw Self.sessionError("the session value is \(nonce.count) bytes, not \(Self.nonceSize)")
        }
        var both = sessionKeys(seed: seed, nonce: nonce)
        guard both.count == 2 * Self.seedSize else {
            Self.wipe(&both)
            throw Self.sessionError("key derivation gave \(both.count) bytes, not \(2 * Self.seedSize)")
        }
        let first = Array(both[0..<Self.seedSize])
        let second = Array(both[Self.seedSize...])
        Self.wipe(&both)
        (send, recv) = opener ? (first, second) : (second, first)
        Self.wipe(&seed)
        seed = []
    }

    /// XORs `data` with the ChaCha20 stream of `key` for packet `position`: the 12-byte nonce is the
    /// position little-endian, the block counter starts at 0. The last position, 2^64 - 1, is refused
    /// rather than wrapped onto a stream already used.
    private static func pad(_ data: inout [UInt8], key: [UInt8], position: UInt64) throws {
        guard position < UInt64.max else { throw sessionError("every packet position of this session is used") }
        var nonce = [UInt8](repeating: 0, count: ChaCha20.nonceSize)
        for i in 0..<8 {
            nonce[i] = UInt8(truncatingIfNeeded: position &>> UInt64(i * 8))
        }
        try ChaCha20.xor(&data, key: key, nonce: nonce, counter: 0)
    }

    /// Zeroes the bytes in place. Swift gives no guarantee that a dead store survives the optimizer
    /// or that no copy was made earlier. The session holds each secret in one buffer of its own and
    /// wipes it when it is done: the seed when the session opens, the derived 64-byte block once it is
    /// split into the two keys, and the keys in `deinit`. CryptoKit zeroes its own key storage, and
    /// ChaCha20 zeroes its key words and its pad after each call.
    private static func wipe(_ bytes: inout [UInt8]) {
        for i in bytes.indices {
            bytes[i] = 0
        }
    }

    private static func sessionError(_ reason: String) -> PackbinError {
        PackbinError(.badValue, field: nil, reason: "session: " + reason)
    }
}
