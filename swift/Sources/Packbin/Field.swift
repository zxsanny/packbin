/// The number of bits one flag byte holds.
public let flagBits = 8

enum NodeKind: Sendable {
    case int, float, bytes, bool, flags, flagByte, flagBit, when, group
    case repeatRound, timesRound, sized, u2, slot, bits, packed
}

/// The identity of one flag byte: a handle, or one read of it once a scheme is built.
final class FlagTag: Sendable {
    let name: String
    init(_ name: String) { self.name = name }
}

/// One field. Constructors make it and a scheme makes changed copies of it, never changing one, so a
/// `Field` can be shared by any number of schemes and tasks; walking a scheme copies no field.
final class Node: Sendable {
    let kind: NodeKind
    /// The value id; the anchor of flags, when, group, repeat and times; a u2's first slot's id; nil
    /// for a flag byte or bit.
    let id: Int?
    let name: String
    /// Bytes of an integer, a float or fixed bytes; bits per item of bits (1) and packed (1 or 2).
    let size: Int
    let signed: Bool
    let bigEndian: Bool
    /// Flags, when, group, repeat and times members; a u2's slots; a flag bit's one member; a built
    /// flags member: its byte and bits.
    let fields: [Node]
    /// Flag byte: this read; flag bit: the byte it belongs to.
    let tag: FlagTag?
    /// A flag byte made by `flags`: its bits are decided as their members are reached.
    let inOrder: Bool
    /// Flag bit: its number in the byte.
    let bit: Int
    let condition: Condition?
    /// The id of the field that holds the count of times, sized, bits and packed.
    let countID: Int?
    /// Packed: 0, or -1 for one item less than the count.
    let bias: Int
    /// When: the name `eq` resolves to; times, sized, bits, packed: the name of the count. Set when
    /// the scheme is built.
    let ref: String
    /// The groups from the scope's row to the count field, by name: where pack finds the count the row
    /// gives for a count that was not written.
    let refPath: [String]
    /// Repeat and times: the names of a round, worked out when the scheme is built.
    let shape: RoundShape?
    /// A value field whose name a when tests: pack keeps what it wrote for it.
    let referenced: Bool
    let accessor: Accessor?
    /// A constructor's refusal, reported by `Scheme.init`.
    let error: String?

    init(_ kind: NodeKind, id: Int?, name: String = "", size: Int = 0, signed: Bool = false,
         bigEndian: Bool = false, fields: [Node] = [], tag: FlagTag? = nil, inOrder: Bool = false,
         bit: Int = 0, condition: Condition? = nil, countID: Int? = nil, bias: Int = 0, ref: String = "",
         refPath: [String] = [], shape: RoundShape? = nil, referenced: Bool = false,
         accessor: Accessor? = nil, error: String? = nil) {
        self.kind = kind
        self.id = id
        self.name = name
        self.size = size
        self.signed = signed
        self.bigEndian = bigEndian
        self.fields = fields
        self.tag = tag
        self.inOrder = inOrder
        self.bit = bit
        self.condition = condition
        self.countID = countID
        self.bias = bias
        self.ref = ref
        self.refPath = refPath
        self.shape = shape
        self.referenced = referenced
        self.accessor = accessor
        self.error = error
    }

    /// A copy with the given properties changed; a nil argument keeps the property as it is.
    func with(bigEndian: Bool? = nil, fields: [Node]? = nil, tag: FlagTag? = nil, bit: Int? = nil,
              ref: String? = nil, refPath: [String]? = nil, shape: RoundShape? = nil, referenced: Bool? = nil,
              accessor: Accessor? = nil, error: String? = nil) -> Node {
        Node(kind, id: id, name: name, size: size, signed: signed, bigEndian: bigEndian ?? self.bigEndian,
             fields: fields ?? self.fields, tag: tag ?? self.tag, inOrder: inOrder, bit: bit ?? self.bit,
             condition: condition, countID: countID, bias: bias, ref: ref ?? self.ref,
             refPath: refPath ?? self.refPath, shape: shape ?? self.shape, referenced: referenced ?? self.referenced,
             accessor: accessor ?? self.accessor, error: error ?? self.error)
    }

    /// The member a flag bit guards.
    var member: Node? { kind == .flagBit ? fields.first : nil }

    /// The name a field declares; a flag bit is named by its member.
    var declaredName: String { member?.declaredName ?? name }

    /// The id an error names: its value id or anchor; a flag bit's member's.
    var errorID: Int? { kind == .flagBit ? member?.errorID : id }

    var isValue: Bool {
        switch kind {
        case .int, .float, .bytes, .bool, .sized, .slot, .bits, .packed: return true
        case .flags, .flagByte, .flagBit, .when, .group, .repeatRound, .timesRound, .u2: return false
        }
    }

    var isRound: Bool { kind == .repeatRound || kind == .timesRound }

    /// Fields whose value is itself a run of bytes or items: one given for a round's name would reach
    /// every round.
    var isBuffer: Bool { kind == .bytes || kind == .sized || kind == .bits || kind == .packed }

    /// A bool or an empty group: a flag bit with no bytes of its own.
    var isMark: Bool { kind == .bool || (kind == .group && fields.isEmpty) }

    var label: String {
        switch kind {
        case .int: return "\(signed ? "i" : "u")\(size * 8)"
        case .float: return "f\(size * 8)"
        case .bytes: return "bytes(\(size))"
        case .bool: return "bool"
        case .flags: return "flags"
        case .flagByte: return "flag byte"
        case .flagBit: return "flag bit"
        case .when: return "when"
        case .group: return "group"
        case .repeatRound: return "repeat"
        case .timesRound: return "times"
        case .sized: return "sized"
        case .u2: return "u2"
        case .slot: return "slot"
        case .bits: return "bits"
        case .packed: return "packed"
        }
    }
}

/// One field of a scheme, made by the static constructors (`.u8(0, "n")`, `.flags(...)`, ...).
public struct Field: Sendable {
    let node: Node

    init(_ node: Node) { self.node = node }

    private static func int(_ id: Int, _ name: String, _ size: Int, _ signed: Bool) -> Field {
        Field(Node(.int, id: id, name: name, size: size, signed: signed))
    }

    /// An unsigned 8-bit integer.
    public static func u8(_ id: Int, _ name: String) -> Field { int(id, name, 1, false) }
    /// An unsigned 16-bit integer, little-endian.
    public static func u16(_ id: Int, _ name: String) -> Field { int(id, name, 2, false) }
    /// An unsigned 32-bit integer, little-endian.
    public static func u32(_ id: Int, _ name: String) -> Field { int(id, name, 4, false) }
    /// An unsigned 64-bit integer, little-endian.
    public static func u64(_ id: Int, _ name: String) -> Field { int(id, name, 8, false) }
    /// A signed 8-bit integer.
    public static func i8(_ id: Int, _ name: String) -> Field { int(id, name, 1, true) }
    /// A signed 16-bit integer, little-endian.
    public static func i16(_ id: Int, _ name: String) -> Field { int(id, name, 2, true) }
    /// A signed 32-bit integer, little-endian.
    public static func i32(_ id: Int, _ name: String) -> Field { int(id, name, 4, true) }
    /// A signed 64-bit integer, little-endian.
    public static func i64(_ id: Int, _ name: String) -> Field { int(id, name, 8, true) }

    /// An IEEE 754 single, little-endian. NaN and the infinities are written as given; a finite value
    /// too large for f32 is refused.
    public static func f32(_ id: Int, _ name: String) -> Field {
        Field(Node(.float, id: id, name: name, size: 4))
    }

    /// An IEEE 754 double, little-endian.
    public static func f64(_ id: Int, _ name: String) -> Field {
        Field(Node(.float, id: id, name: name, size: 8))
    }

    /// Exactly `size` raw bytes, with no length.
    public static func bytes(_ id: Int, _ name: String, size: Int) -> Field {
        let error = size < 0 ? "bytes size \(size): expected 0 or more" : nil
        return Field(Node(.bytes, id: id, name: name, size: size, error: error))
    }

    /// A flag bit with no payload, set only for `true`. It stands only directly under `flags` or a
    /// flag byte's `bit`.
    public static func bool(_ id: Int, _ name: String) -> Field { Field(Node(.bool, id: id, name: name)) }

    /// That integer or float, big-endian; any other field is returned as it is.
    public static func be(_ field: Field) -> Field {
        let n = field.node
        switch n.kind {
        case .int, .float:
            return Field(n.with(bigEndian: true))
        case .flagBit:
            guard let member = n.member else { return field }
            return Field(n.with(fields: [be(Field(member)).node]))
        case .bytes, .bool, .flags, .flagByte, .when, .group, .repeatRound, .timesRound, .sized, .u2, .slot,
             .bits, .packed:
            return field
        }
    }

    /// One byte in front of its members: bit i is member i, a set bit writes that member, a clear bit
    /// skips it. At most 8 members. The anchor is the next id and is not written.
    public static func flags(_ anchor: Int, _ members: Field...) -> Field { flags(anchor, members) }

    /// `flags` with its members as an array.
    public static func flags(_ anchor: Int, _ members: [Field]) -> Field {
        let nodes = members.map(\.node)
        let error = nodes.count > flagBits
            ? "flags: ninth bit (\(nodes[flagBits].declaredName)); a flag byte holds \(flagBits) bits" : nil
        return Field(Node(.flags, id: anchor, fields: nodes, error: error))
    }

    /// The place the split-form flag byte `handle` is read; its `bit`s follow it.
    public static func flagByte(_ handle: FlagByte) -> Field {
        Field(Node(.flagByte, id: nil, name: handle.name, tag: handle.tag))
    }

    /// The members only when an earlier field of the same scope equals the condition's value (what
    /// was written when packing, what was read when unpacking). The anchor is the next id and is not
    /// written.
    public static func when(_ anchor: Int, _ condition: Condition, _ members: Field...) -> Field {
        when(anchor, condition, members)
    }

    /// `when` with its members as an array.
    public static func when(_ anchor: Int, _ condition: Condition, _ members: [Field]) -> Field {
        Field(Node(.when, id: anchor, fields: members.map(\.node), condition: condition))
    }

    /// The members under one name. They share the ids and the scope of the fields around the group:
    /// the anchor is the next id and is not written. In a map row the members are a `[String: Any]`
    /// under `name`, on pack and on unpack; in a typed row the group is bound to a member whose type
    /// is a ``PackbinRow`` the members are bound to. Under `flags` or a flag bit the group's bit is set
    /// when it is given. With no members it is a mark, as `bool`: a flag bit with no payload, set only
    /// for `true`, that stands only directly under `flags` or a flag byte's `bit`.
    public static func group(_ anchor: Int, _ name: String, _ members: Field...) -> Field {
        group(anchor, name, members)
    }

    /// `group` with its members as an array.
    public static func group(_ anchor: Int, _ name: String, _ members: [Field]) -> Field {
        Field(Node(.group, id: anchor, name: name, fields: members.map(\.node)))
    }
}

/// A split-form flag byte: `.flagByte(handle)` is where the byte is read, and `bit` puts a member
/// under its next bit. A handle can be read more than once and shared by schemes.
public struct FlagByte: Sendable {
    let tag: FlagTag

    public init(_ name: String) { tag = FlagTag(name) }

    public var name: String { tag.name }

    /// `member` under the next bit of the flag byte read before it in the same scope. The scheme
    /// numbers the bits when it is built.
    public func bit(_ member: Field) -> Field {
        Field(Node(.flagBit, id: nil, fields: [member.node], tag: tag))
    }
}

/// The condition of `when`, made by `eq`.
public struct Condition: Sendable {
    let id: Int
    let value: EqValue

    /// True when the field `id`, read earlier in the same scope, equals `value`.
    public static func eq<I: BinaryInteger>(_ id: Int, _ value: I) -> Condition {
        Condition(id: id, value: Num(exactly: value).map(EqValue.int) ?? .unrepresentable(String(value)))
    }

    /// True when the bool field `id`, read earlier in the same scope, equals `value`.
    public static func eq(_ id: Int, _ value: Bool) -> Condition { Condition(id: id, value: .bool(value)) }
}

enum EqValue: Sendable, Equatable {
    case int(Num)
    case bool(Bool)
    /// An integer wider than 64 bits: no field holds it, so it never matches.
    case unrepresentable(String)
}
