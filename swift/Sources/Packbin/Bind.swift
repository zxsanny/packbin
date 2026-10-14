#if compiler(>=6.2)
/// A typed row: a type whose members are bound to fields with `Field.bind(get:set:)`. Unpack starts
/// from `init()` and stores each value it read; a member whose field was not read keeps its initial
/// value. (Every concrete type meets `SendableMetatype`; it lets the scheme keep the row's type.)
public protocol PackbinRow: SendableMetatype {
    init()
}
#else
/// A typed row: a type whose members are bound to fields with `Field.bind(get:set:)`. Unpack starts
/// from `init()` and stores each value it read; a member whose field was not read keeps its initial
/// value.
public protocol PackbinRow {
    init()
}
#endif

/// A typed row held by reference for the length of one call, so the accessors read and write it in
/// place.
final class RowBox<Row> {
    var row: Row
    init(_ row: Row) { self.row = row }
}

/// The type-erased row operations of the row type a scheme is bound to.
final class Binding: Sendable {
    let rowType: ObjectIdentifier
    let rowTypeName: String
    let makeBox: @Sendable () -> AnyObject
    /// A row given to pack, held in a box, or nil when it is not of the bound type.
    let boxRow: @Sendable (Any) -> AnyObject?
    let unbox: @Sendable (AnyObject) -> Any

    init(rowType: ObjectIdentifier, rowTypeName: String, makeBox: @escaping @Sendable () -> AnyObject,
         boxRow: @escaping @Sendable (Any) -> AnyObject?, unbox: @escaping @Sendable (AnyObject) -> Any) {
        self.rowType = rowType
        self.rowTypeName = rowTypeName
        self.makeBox = makeBox
        self.boxRow = boxRow
        self.unbox = unbox
    }
}

/// The base type of a member of a typed row (read through one optional).
enum MemberBase: Sendable {
    case int(IntType)
    case float(bits: Int)
    case bool
    case bytes
}

/// The Swift integer types a member can be.
enum IntType: Sendable {
    case int, int8, int16, int32, int64, uint, uint8, uint16, uint32, uint64

    var bits: Int {
        switch self {
        case .int8, .uint8: return 8
        case .int16, .uint16: return 16
        case .int32, .uint32: return 32
        case .int, .uint: return Int.bitWidth
        case .int64, .uint64: return 64
        }
    }

    var signed: Bool {
        switch self {
        case .int, .int8, .int16, .int32, .int64: return true
        case .uint, .uint8, .uint16, .uint32, .uint64: return false
        }
    }

    /// `num` as this type, or nil when this type cannot hold it.
    func make(_ num: Num) -> Any? {
        switch self {
        case .int: return num.exact(Int.self)
        case .int8: return num.exact(Int8.self)
        case .int16: return num.exact(Int16.self)
        case .int32: return num.exact(Int32.self)
        case .int64: return num.exact(Int64.self)
        case .uint: return num.exact(UInt.self)
        case .uint8: return num.exact(UInt8.self)
        case .uint16: return num.exact(UInt16.self)
        case .uint32: return num.exact(UInt32.self)
        case .uint64: return num.exact(UInt64.self)
        }
    }
}

/// Binds a value field to a member of `Row` through a getter and a setter.
final class Accessor: Sendable {
    let binding: Binding
    /// The member's value for pack, read through its optional; nil is no value.
    let get: @Sendable (AnyObject) -> Any?
    /// Stores a value unpack read (the Swift type of its field) into the member.
    let set: @Sendable (AnyObject, Any) -> Void

    init(binding: Binding, get: @escaping @Sendable (AnyObject) -> Any?,
         set: @escaping @Sendable (AnyObject, Any) -> Void) {
        self.binding = binding
        self.get = get
        self.set = set
    }
}

protocol OptionalMember {
    static var wrappedType: Any.Type { get }
}

extension Optional: OptionalMember {
    static var wrappedType: Any.Type { Wrapped.self }
}

/// The base type of a member type `t` (read through one optional), or nil for a type no field takes.
func memberBase(_ t: Any.Type) -> MemberBase? {
    let base = (t as? OptionalMember.Type)?.wrappedType ?? t
    switch ObjectIdentifier(base) {
    case ObjectIdentifier(Int.self): return .int(.int)
    case ObjectIdentifier(Int8.self): return .int(.int8)
    case ObjectIdentifier(Int16.self): return .int(.int16)
    case ObjectIdentifier(Int32.self): return .int(.int32)
    case ObjectIdentifier(Int64.self): return .int(.int64)
    case ObjectIdentifier(UInt.self): return .int(.uint)
    case ObjectIdentifier(UInt8.self): return .int(.uint8)
    case ObjectIdentifier(UInt16.self): return .int(.uint16)
    case ObjectIdentifier(UInt32.self): return .int(.uint32)
    case ObjectIdentifier(UInt64.self): return .int(.uint64)
    case ObjectIdentifier(Float.self): return .float(bits: 32)
    case ObjectIdentifier(Double.self): return .float(bits: 64)
    case ObjectIdentifier(Bool.self): return .bool
    case ObjectIdentifier([UInt8].self): return .bytes
    default: return nil
    }
}

/// Why a member of `typeName` with base `base` cannot hold every value of `node`, or nil.
func memberRefusal(_ node: Node, _ base: MemberBase?, _ typeName: String) -> String? {
    let holds: Bool
    switch (node.kind, base) {
    case let (.int, .int(type)?):
        let (bits, signed, fieldBits) = (type.bits, type.signed, node.size * 8)
        if node.signed {
            holds = signed && bits >= fieldBits
        } else {
            holds = signed ? bits > fieldBits : bits >= fieldBits
        }
    case let (.float, .float(bits)?):
        holds = bits == 64 || node.size == 4
    case (.bool, .bool?):
        holds = true
    case (.bytes, .bytes?):
        return nil
    case (.bytes, _):
        return "a \(typeName) member cannot hold \(node.label); bind a [UInt8]"
    default:
        holds = false
    }
    return holds ? nil : "a \(typeName) member cannot hold every \(node.label) value"
}

extension Field {
    /// Binds this value field (an integer, float, fixed bytes or bool) to a member of the typed row
    /// `Row`: `get` reads it for pack, `set` stores it after unpack. `Member` holds every value of
    /// the field: an integer type that holds the field's range, `Float` (f32 only) or `Double`,
    /// `[UInt8]` for bytes, `Bool` for bool, or an optional of one. A nil optional is no value; a
    /// stored 0 is a value. Every value field of a scheme is bound to the same `Row`, or none is.
    public func bind<Row: PackbinRow, Member>(
        get: @escaping @Sendable (Row) -> Member,
        set: @escaping @Sendable (inout Row, Member) -> Void
    ) -> Field {
        let n = node
        let memberName = String(describing: Member.self)
        let base = memberBase(Member.self)
        let optional = Member.self is OptionalMember.Type
        let error: String?
        if !n.isValue {
            error = "bind takes a value field, not \(n.label)"
        } else if n.accessor != nil {
            error = "the field is already bound"
        } else {
            error = memberRefusal(n, base, memberName)
        }
        let binding = Binding(
            rowType: ObjectIdentifier(Row.self),
            rowTypeName: String(describing: Row.self),
            makeBox: { RowBox(Row()) },
            boxRow: { row in (row as? Row).map { RowBox($0) } },
            unbox: { box in (box as? RowBox<Row>)?.row as Any })
        let accessor = Accessor(
            binding: binding,
            get: { box in
                guard let row = (box as? RowBox<Row>)?.row else { return nil }
                return optional ? unboxed(get(row)) : get(row)
            },
            set: { box, value in
                guard let box = box as? RowBox<Row>, let member = memberValue(value, base, Member.self) else {
                    return
                }
                set(&box.row, member)
            })
        return Field(n.with(accessor: accessor, error: error))
    }
}

/// An unpacked value (the Swift type of its field) as a `Member`: as it is, or widened to the
/// member's integer or float type. Construction has made sure the member holds it.
private func memberValue<Member>(_ value: Any, _ base: MemberBase?, _: Member.Type) -> Member? {
    if let member = value as? Member { return member }
    switch (base, scalar(value)) {
    case let (.int(type)?, .int(num)):
        return type.make(num).flatMap { $0 as? Member }
    case let (.float(64)?, .float(x)):
        return x as? Member
    default:
        return nil
    }
}
