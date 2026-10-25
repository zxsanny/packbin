/// The direction of a frame: the byte `d` of the key schedule and of the nonce (contract
/// `_docs/02_document/contracts/library/pack-session.md` 2.0.0, Frame mode).
public enum FrameDirection: UInt8, Sendable, CaseIterable {
    case up = 1
    case down = 2
    case group = 3

    /// The direction numbered `number` (1 up, 2 down, 3 group); any other number throws a `.badValue`.
    public init(number: Int) throws {
        guard (1...3).contains(number), let direction = FrameDirection(rawValue: UInt8(number)) else {
            throw PackbinError.frame(.badValue, "the direction is \(number), not 1, 2 or 3")
        }
        self = direction
    }

    /// 0 for up, 1 for down, 2 for group: the position in the per-direction key tables.
    var index: Int { Int(rawValue) - 1 }
}

/// The directions a session loads keys for.
public struct FrameDirections: OptionSet, Sendable, Equatable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
        self.rawValue = rawValue & 7
    }

    public static let up = FrameDirections(rawValue: 1)
    public static let down = FrameDirections(rawValue: 2)
    public static let group = FrameDirections(rawValue: 4)
    public static let all: FrameDirections = [.up, .down, .group]

    /// Whether `direction` is in the set.
    public func contains(direction: FrameDirection) -> Bool {
        rawValue & (1 &<< (direction.rawValue &- 1)) != 0
    }
}

/// What a frame session is loaded with besides the key and the epoch.
public struct FrameConfig: Sendable, Equatable {
    /// The tag bytes: 4, 8 or 16, fixed for the lifetime of the loaded key. Any other value is refused at load
    /// with a `.badValue`.
    public var tagLength: Int
    /// The directions the session derives keys for; a call in another direction throws a `.badValue`.
    public var directions: FrameDirections

    public init(tagLength: Int, directions: FrameDirections = .all) {
        self.tagLength = tagLength
        self.directions = directions
    }
}

/// What the caller supplies per message besides the bytes: the 8-byte `msgID` and the 4-bit `kind`. Both go
/// into the nonce and, through it, into the tag. Neither is checked when the value is made: `seal` and `open`
/// throw a `.badValue` for a `msgID` that is not 8 bytes and for a `kind` above 15.
///
/// **The uniqueness rule (the caller's duty): for one (key, epoch, direction), a `msgID` is never sealed twice
/// with different contents.** Reuse breaks the confidentiality of both messages, and the library cannot check it
/// (it keeps no state). A new epoch derives new keys and nonces. Example: meshbell builds `msgID` as source
/// (2 bytes), id field (2 bytes) and creation wave (4 bytes); sequences restart every wave, waves never repeat
/// and source ids are never reissued, so it is unique by construction.
public struct MessageContext: Sendable, Equatable {
    public var msgID: [UInt8]
    public var kind: UInt8

    public init(msgID: [UInt8], kind: UInt8) {
        self.msgID = msgID
        self.kind = kind
    }
}

/// Which loaded key opened a frame.
public enum FrameSlot: Sendable, Equatable {
    case current
    case previous
}

/// What an opened frame reports: the key that opened it, the length of its clear part and the length of the
/// plaintext written to the caller's buffer.
public struct FrameOpened: Sendable, Equatable {
    public let slot: FrameSlot
    public let clearLength: Int
    public let plainLength: Int

    public init(slot: FrameSlot, clearLength: Int, plainLength: Int) {
        self.slot = slot
        self.clearLength = clearLength
        self.plainLength = plainLength
    }
}

/// The replay window of one sender, owned by the caller: the highest committed counter (`top`) and a bit per
/// counter up to 63 below it (`bits`: bit i set means `top - i` was committed). `bits == 0` is an empty window,
/// where every counter is fresh. `check` never changes the state; `commit` records a counter, and `open` calls
/// it only after a frame opened.
///
/// The counter is the caller's: a value that increases with every message of one sender. **It must come from
/// bytes the tag covers** (for example the `msgID` or the associated data), never from an unauthenticated field
/// of the wire: the counter is an argument of `open` and is not part of the tag, so a captured frame replayed
/// under a counter the attacker chooses would open and could move the window. A window serves one sender and
/// one key lifetime. One restored from stored `(top, bits)` with `bits == 0` is empty (replay protection is off
/// until the next commit), so a caller that restores a window checks that bit 0 is set when `bits` is not 0.
public struct ReplayWindow: Sendable, Equatable {
    /// What the window says about a counter.
    public enum Freshness: Sendable, Equatable {
        /// Not seen, and not older than the window.
        case fresh
        /// Already committed.
        case duplicate
        /// 64 or more behind the highest committed counter.
        case tooOld
    }

    public private(set) var top: UInt64
    public private(set) var bits: UInt64

    /// An empty window.
    public init() {
        top = 0
        bits = 0
    }

    /// A window restored from stored parts.
    public init(top: UInt64, bits: UInt64) {
        self.top = top
        self.bits = bits
    }

    /// What the window says about `counter`. Never changes the state.
    public func check(_ counter: UInt64) -> Freshness {
        if bits == 0 || counter > top { return .fresh }
        let behind = top - counter
        if behind >= 64 { return .tooOld }
        return (bits >> behind) & 1 == 1 ? .duplicate : .fresh
    }

    /// Records `counter`; a counter 64 or more behind the highest is ignored.
    public mutating func commit(_ counter: UInt64) {
        if bits == 0 {
            top = counter
            bits = 1
        } else if counter > top {
            bits = (bits << (counter - top)) | 1
            top = counter
        } else {
            let behind = top - counter
            if behind < 64 { bits |= 1 << behind }
        }
    }
}

extension PackbinError {
    /// A frame-mode refusal. `needed` and `left` are set for a `.short`.
    static func frame(_ kind: Kind, _ reason: String, needed: Int = 0, left: Int = 0) -> PackbinError {
        PackbinError(kind, field: nil, needed: needed, left: left, reason: "frame: " + reason)
    }
}
