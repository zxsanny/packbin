/// Every error the package throws. `pack`, `unpack` and `Scheme.init` throw only this type and never
/// trap on any input.
public struct PackbinError: Error, Equatable, Sendable, CustomStringConvertible {
    /// What went wrong. The raw value is a stable error kind: pack/unpack kinds match the shared
    /// hostile vectors (`fixtures/hostile/README.md`); frame-mode kinds match `fixtures/frame/`.
    /// A case is never renamed, later versions only add cases.
    public enum Kind: String, Sendable, CaseIterable {
        /// The buffer ends inside a field: `field`, `name`, `needed` and `left` are set.
        case short = "short_packet"
        /// Bytes are left after the scheme's last field: `left` is their count.
        case trailing = "trailing_bytes"
        /// The first byte names no scheme of the call: `actual` is that byte.
        case unknownType = "type_mismatch"
        /// Unpack read a value it cannot use.
        case badValue = "bad_value"
        /// Unpack refuses a round past a limit of the scheme.
        case tooMany = "too_many"
        /// A scheme, a field or an unpack call's scheme list is refused.
        case schemeError = "scheme_error"
        /// Pack cannot write the row; it returns no bytes.
        case packError = "pack_error"
        /// A protected message has more wrong bytes than the correction limit repairs: no field is named
        /// and no row is given (see `unpackRepair(_:limit:_:)`).
        case uncorrectable = "uncorrectable"
        /// A protected message of more than 254 bytes: no field is named, `left` is its length and `reason`
        /// names the length and the limit.
        case tooLong = "too_long"
        /// Frame mode: the tag of a received frame matches neither the current nor the previous key.
        case tagMismatch = "tag_mismatch"
        /// Frame mode: the replay window has already committed the counter of the frame.
        case duplicate = "duplicate"
        /// Frame mode: the counter of the frame is 64 or more behind the highest the replay window committed.
        case tooOld = "too_old"
        /// Frame mode: the caller's output buffer is shorter than the bytes the call would write.
        case bufferFull = "buffer_full"
    }

    public let kind: Kind
    /// The field id (the anchor of `flags` and `when`), or `nil` for an error that belongs to no
    /// field: trailing bytes, an unknown type number, an empty buffer, a split flag byte.
    public let field: Int?
    /// The field's name, or "".
    public let name: String
    /// The bytes a short field needed.
    public let needed: Int
    /// The bytes left where a short field started, or the count of trailing bytes.
    public let left: Int
    /// The first byte of a packet whose type number no scheme has.
    public let actual: Int?
    /// Why a value, a row or a scheme is refused.
    public let reason: String

    init(_ kind: Kind, field: Int?, name: String = "", needed: Int = 0, left: Int = 0,
         actual: Int? = nil, reason: String = "") {
        self.kind = kind
        self.field = field
        self.name = name
        self.needed = needed
        self.left = left
        self.actual = actual
        self.reason = reason
    }

    public var description: String {
        let at = whereText
        switch kind {
        case .short: return "packbin: short packet\(at): needed \(needed), left \(left)"
        case .trailing: return "packbin: \(left) trailing bytes"
        case .unknownType: return "packbin: unknown type number \(actual ?? -1)"
        case .badValue: return "packbin: bad value\(at): \(reason)"
        case .tooMany: return "packbin: too many\(at): \(reason)"
        case .schemeError: return "packbin: invalid scheme\(at): \(reason)"
        case .packError: return "packbin: pack refused\(at): \(reason)"
        case .uncorrectable: return "packbin: uncorrectable message: more wrong bytes than the correction limit repairs"
        case .tooLong: return "packbin: too long: \(reason)"
        case .tagMismatch: return "packbin: tag mismatch: \(reason)"
        case .duplicate: return "packbin: duplicate frame: \(reason)"
        case .tooOld: return "packbin: frame too old: \(reason)"
        case .bufferFull: return "packbin: buffer full: \(reason)"
        }
    }

    private var whereText: String {
        switch (field, name.isEmpty) {
        case let (id?, false): return " at field \(id) (\(name))"
        case let (id?, true): return " at field \(id)"
        case (nil, false): return " at \(name)"
        case (nil, true): return ""
        }
    }

    static func scheme(_ id: Int?, _ name: String, _ reason: String) -> PackbinError {
        PackbinError(.schemeError, field: id, name: name, reason: reason)
    }

    static func pack(_ id: Int?, _ name: String, _ reason: String) -> PackbinError {
        PackbinError(.packError, field: id, name: name, reason: reason)
    }

    static let uncorrectable = PackbinError(.uncorrectable, field: nil)

    static func shortPacket(_ id: Int?, _ name: String, needed: Int, left: Int) -> PackbinError {
        PackbinError(.short, field: id, name: name, needed: needed, left: left)
    }
}
