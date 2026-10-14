/// An exact integer of any Swift integer type up to 64 bits: -mag when neg, else mag. Zero is never neg.
struct Num: Equatable, Sendable {
    let neg: Bool
    let mag: UInt64

    init?<I: BinaryInteger>(exactly x: I) {
        guard let mag = UInt64(exactly: x.magnitude) else { return nil }
        self.neg = x < 0
        self.mag = mag
    }

    /// Whether the value is in the range of an integer of `size` bytes.
    func fits(size: Int, signed: Bool) -> Bool {
        let bits = UInt64(size) &* 8
        if !signed { return !neg && (bits >= 64 || mag < UInt64(1) << bits) }
        let limit = UInt64(1) << (bits &- 1)
        return neg ? mag <= limit : mag < limit
    }

    /// The value as two's complement, 64 bits wide.
    var bits: UInt64 { neg ? 0 &- mag : mag }

    var double: Double { neg ? -Double(mag) : Double(mag) }

    /// The value as a `T`, or nil when `T` cannot hold it.
    func exact<T: FixedWidthInteger>(_: T.Type) -> T? {
        guard neg else { return T(exactly: mag) }
        guard T.isSigned, mag <= UInt64(1) << 63 else { return nil }
        return T(exactly: mag == UInt64(1) << 63 ? Int64.min : -Int64(mag))
    }
}

/// A value given for a field, as pack reads it.
enum Scalar {
    case int(Num)
    case float(Double)
    case bool(Bool)
    case bytes([UInt8])
    /// Any other value; the field that reads it refuses it, naming this type.
    case other(String)
}

protocol AnyOptional {
    var packbinWrapped: Any? { get }
}

extension Optional: AnyOptional {
    var packbinWrapped: Any? { map { $0 } }
}

/// How many optionals `unboxed` reads through; a value nested deeper is kept as it is, and the field
/// that reads it refuses it.
private let maxHops = 8

/// The value `v` holds: an optional is read through (nil is no value); anything else as it is.
func unboxed(_ v: Any) -> Any? {
    var cur = v
    for _ in 0..<maxHops {
        guard let optional = cur as? AnyOptional else { return cur }
        guard let wrapped = optional.packbinWrapped else { return nil }
        cur = wrapped
    }
    return cur
}

func typeName(_ v: Any) -> String { String(describing: type(of: v)) }

/// `v` as pack reads it. A class instance (a Foundation `NSNumber`) is classified on its own, before
/// the casts below, which would bridge it to both `Bool` and `Int`.
func scalar(_ v: Any) -> Scalar {
    let type = type(of: v)
    if type is AnyObject.Type { return foreignScalar(v) ?? .other(typeName(v)) }
    // One metatype comparison picks the type, so one cast reads the value.
    switch ObjectIdentifier(type) {
    case ObjectIdentifier(Int.self): return integer(v as? Int)
    case ObjectIdentifier(UInt8.self): return integer(v as? UInt8)
    case ObjectIdentifier(UInt16.self): return integer(v as? UInt16)
    case ObjectIdentifier(UInt32.self): return integer(v as? UInt32)
    case ObjectIdentifier(UInt64.self): return integer(v as? UInt64)
    case ObjectIdentifier(Int8.self): return integer(v as? Int8)
    case ObjectIdentifier(Int16.self): return integer(v as? Int16)
    case ObjectIdentifier(Int32.self): return integer(v as? Int32)
    case ObjectIdentifier(Int64.self): return integer(v as? Int64)
    case ObjectIdentifier(UInt.self): return integer(v as? UInt)
    case ObjectIdentifier(Double.self): return (v as? Double).map(Scalar.float) ?? .other(typeName(v))
    case ObjectIdentifier(Float.self): return (v as? Float).map { .float(Double($0)) } ?? .other(typeName(v))
    case ObjectIdentifier(Bool.self): return (v as? Bool).map(Scalar.bool) ?? .other(typeName(v))
    case ObjectIdentifier([UInt8].self): return (v as? [UInt8]).map(Scalar.bytes) ?? .other(typeName(v))
    default: return .other(typeName(v))
    }
}

private func integer<I: FixedWidthInteger>(_ x: I?) -> Scalar {
    x.flatMap { Num(exactly: $0) }.map(Scalar.int) ?? .other(String(describing: I.self))
}

/// The `eq` comparison: two integers compare exactly, an integer and a float by value, a bool only
/// with a bool; an absent value never matches.
func sameValue(_ seen: Any?, _ want: EqValue) -> Bool {
    guard let seen else { return false }
    switch (scalar(seen), want) {
    case let (.int(a), .int(b)): return a == b
    case let (.float(a), .int(b)): return a == b.double
    case let (.bool(a), .bool(b)): return a == b
    default: return false
    }
}

/// The row as the walker reads it: every given value read through its optionals, absent ones left out.
func presentValues(_ row: [String: Any]) -> [String: Any] {
    var values = [String: Any](minimumCapacity: row.count)
    for (key, raw) in row {
        if let v = unboxed(raw) { values[key] = v }
    }
    return values
}
