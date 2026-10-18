/// Packs a map row: the type number, then the fields in order. A value is read by its field's name;
/// a missing key or a nil value is no value (only a flag bit can leave one out), a stored 0 is a
/// value. An integer field takes any Swift integer type whose value fits, a float field any integer
/// or float, fixed bytes a `[UInt8]` of exactly its size, a bool or an empty group a `Bool`, a
/// group with members a `[String: Any]` its members are read from, utf8 a `String`, a list any array
/// but a `[UInt8]` and a dict any dictionary with `String` keys; a Foundation `NSNumber` is read as
/// the `Bool`, integer or float it was made from. Any other value (a `Bool` or a `Double` for an
/// integer, an integer for a bool, a group member given outside its group) is refused. A refused row
/// throws a `PackbinError` of kind `.packError` naming the field id, and no bytes are returned.
public func pack(_ scheme: Scheme, _ row: [String: Any]) throws -> [UInt8] {
    try packValues(scheme, try mapValues(scheme.place, row))
}

/// Packs a typed row, a value of the type the scheme's fields are bound to with `bind(get:set:)`. A
/// `[String: Any]` (or any `[String: V]`) is packed as a map row.
public func pack<Row>(_ scheme: Scheme, _ row: Row) throws -> [UInt8] {
    let box = scheme.binding?.boxRow(row)
    if box == nil, let map = row as? [String: Any] { return try pack(scheme, map) }
    let first = scheme.place.members.first?.node
    guard let binding = scheme.binding else {
        throw PackbinError.pack(first?.errorID, first?.name ?? "",
            "a \(typeName(row)) row needs fields bound with bind(get:set:); this scheme packs a [String: Any]")
    }
    guard let box else {
        throw PackbinError.pack(first?.errorID, first?.name ?? "",
            "the row is a \(typeName(row)); this scheme is bound to \(binding.rowTypeName)")
    }
    return try packValues(scheme, typedValues(scheme.place, box))
}

private func packValues(_ scheme: Scheme, _ values: [String: Any]) throws -> [UInt8] {
    var p = Packer(scope: values, limits: scheme)
    p.out.reserveCapacity(min(32, scheme.maxBytes))
    p.out.append(UInt8(truncatingIfNeeded: scheme.typeNumber))
    var wrote: [String: Any] = [:]
    try p.fields(scheme.fields, root: FlagRoot(fields: scheme.fields, values: values), values, &wrote)
    return p.out
}

/// A flag byte pack has written: where it sits, the bits set so far, and whether its bits are decided
/// one by one as their members are reached (a combined `flags`).
struct PackedFlagByte {
    let tag: FlagTag
    let at: Int
    var flags: UInt8
    let inOrder: Bool
}

struct Packer {
    var out: [UInt8] = []
    var flagBytes: [PackedFlagByte] = []
    /// The row of the scope being packed: the top-level row, or the row of one round. A count the row
    /// gives for a field that was not written is read from it.
    var scope: [String: Any]
    /// The scheme's limits; `slots` is what every round of this call has charged so far against
    /// `maxSlots`, one counter for every repeat and times at any depth, as unpack charges them.
    let maxRounds: Int
    let maxSlots: Int
    let maxBytes: Int
    var slots = 0
    /// The last long text written and its field, for the same text packed again in the next round.
    var textMemo: (text: String, field: [UInt8])?

    init(scope: [String: Any], limits: Scheme) {
        self.scope = scope
        maxRounds = limits.maxRounds
        maxSlots = limits.maxSlots
        maxBytes = limits.maxBytes
    }

    /// Packs `nodes` from `values`, the row they read (inside a group, the group's own values). `wrote`
    /// is what the scope has written so far, by name, for a when to test; `root` is where a split flag
    /// byte looks for its bits.
    mutating func fields(_ nodes: [Node], root: FlagRoot, _ values: [String: Any],
                         _ wrote: inout [String: Any]) throws {
        for n in nodes {
            switch n.kind {
            case .int, .float, .bytes, .utf8:
                guard let v = values[n.name] else { throw PackbinError.pack(n.id, n.name, "missing \(n.name)") }
                try write(n, v, &wrote)
            case .list, .dict:
                try collection(n, values[n.name])
            case .bool:
                // Reached only through a set flag bit: the bit is the value, nothing follows it.
                if n.referenced { wrote[n.name] = true }
            case .flagByte:
                guard let tag = n.tag else { continue }
                let flags = n.inOrder ? 0 : try flagValue(root, tag, wrote)
                try room(1, n.id, n.name.isEmpty ? firstBitName(nodes, tag) : n.name)
                let record = PackedFlagByte(tag: tag, at: out.count, flags: flags, inOrder: n.inOrder)
                if let i = flagBytes.firstIndex(where: { $0.tag === tag }) {
                    flagBytes[i] = record
                } else {
                    flagBytes.append(record)
                }
                out.append(flags)
            case .flagBit:
                try flagBit(n, root: root, values, &wrote)
            case .when:
                if let condition = n.condition, sameValue(wrote[n.ref], condition.value) {
                    try fields(n.fields, root: root, values, &wrote)
                }
            case .flags:
                // A flags member: its own byte and bits, looked up among the fields made with it.
                try fields(n.fields, root: FlagRoot(fields: n.fields, values: values), values, &wrote)
            case .group:
                // A mark is reached only through a set flag bit: the bit is its value, nothing follows it.
                if n.fields.isEmpty { continue }
                if n.nested {
                    try nestedRow(n.fields, groupValues(values, n))
                } else {
                    try fields(n.fields, root: root, groupValues(values, n), &wrote)
                }
            case .sized, .u2, .bits, .packed, .repeatRound, .timesRound:
                try counted(n, values, &wrote)
            case .slot:
                // A slot is written by its u2.
                break
            }
        }
    }

    private mutating func flagBit(_ n: Node, root: FlagRoot, _ values: [String: Any],
                                  _ wrote: inout [String: Any]) throws {
        guard let member = n.member, let i = flagBytes.firstIndex(where: { $0.tag === n.tag }) else { return }
        let mask = UInt8(truncatingIfNeeded: 1 << n.bit)
        if flagBytes[i].inOrder {
            guard try bitOn(member, values, wrote) else {
                // A times whose count was not written (skipped, or under a clear bit) writes no round, so
                // the values given for it would be dropped without a word.
                if let held = try droppedBody(member, values, wrote) {
                    throw PackbinError.pack(held.id, held.name, "\(held.name): a value is given, but the count of "
                        + "its times is not written, so its bit is clear; write the count before the times")
                }
                try refuseUnwrittenCount(member, values, wrote)
                return
            }
            flagBytes[i].flags |= mask
            out[flagBytes[i].at] = flagBytes[i].flags
        } else if flagBytes[i].flags & mask == 0 {
            // The bit was decided where the byte sits. A body whose condition or count is not written by
            // then would be dropped without a word, and its own unpack reads no bit for it.
            if let held = try droppedBody(member, values, wrote) {
                throw PackbinError.pack(held.id, held.name, "\(held.name): a value is given, but the condition "
                    + "or count of its when or times is not written before the flag byte, so its bit is clear; "
                    + "write that field before the flag byte")
            }
            try refuseUnwrittenCount(member, values, wrote)
            return
        }
        try fields([member], root: root, values, &wrote)
    }

    mutating func write(_ n: Node, _ v: Any, _ wrote: inout [String: Any]) throws {
        if n.kind == .utf8 {
            guard let text = stringValue(v) else {
                throw PackbinError.pack(n.id, n.name, "\(n.name): expected a String for utf8, got \(described(scalar(v), v))")
            }
            try writeString(n.id, n.name, text)
            if n.referenced { wrote[n.name] = text }
            return
        }
        switch (n.kind, scalar(v)) {
        case let (.int, .int(num)):
            guard num.fits(size: n.size, signed: n.signed) else {
                throw PackbinError.pack(n.id, n.name, "\(num.neg ? "-" : "")\(num.mag) does not fit in \(n.label)")
            }
            try room(n.size, n.id, n.name)
            append(num.bits, size: n.size, bigEndian: n.bigEndian)
            if n.referenced { wrote[n.name] = v }
        case (.int, let other):
            throw PackbinError.pack(n.id, n.name, "expected an integer for \(n.label), got \(described(other, v))")
        case let (.float, .int(num)):
            try writeFloat(n, num.double, &wrote)
        case let (.float, .float(x)):
            try writeFloat(n, x, &wrote)
        case (.float, let other):
            throw PackbinError.pack(n.id, n.name, "expected a number for \(n.label), got \(described(other, v))")
        case let (.bytes, .bytes(raw)):
            guard raw.count == n.size else {
                throw PackbinError.pack(n.id, n.name, "expected \(n.size) bytes, got \(raw.count)")
            }
            try room(n.size, n.id, n.name)
            out.append(contentsOf: raw)
            if n.referenced { wrote[n.name] = raw }
        case (.bytes, let other):
            throw PackbinError.pack(n.id, n.name, "expected [UInt8] for \(n.label), got \(described(other, v))")
        default:
            throw PackbinError.pack(n.id, n.name, "\(n.label) takes no value")
        }
    }

    /// NaN and the infinities are written as given; a finite value is refused only where f32 would
    /// turn it into an infinity. A reader sees an f32 as it was rounded to 32 bits.
    private mutating func writeFloat(_ n: Node, _ x: Double, _ wrote: inout [String: Any]) throws {
        if n.size == 4 {
            let single = Float(x)
            if x.isFinite && !single.isFinite {
                throw PackbinError.pack(n.id, n.name, "\(x) does not fit in f32")
            }
            try room(4, n.id, n.name)
            append(UInt64(single.bitPattern), size: 4, bigEndian: n.bigEndian)
            if n.referenced { wrote[n.name] = single }
        } else {
            try room(8, n.id, n.name)
            append(x.bitPattern, size: 8, bigEndian: n.bigEndian)
            if n.referenced { wrote[n.name] = x }
        }
    }

    mutating func append(_ x: UInt64, size: Int, bigEndian: Bool) {
        for i in 0..<size {
            let shift = UInt64(bigEndian ? size &- 1 &- i : i) &* 8
            out.append(UInt8(truncatingIfNeeded: x >> shift))
        }
    }
}

/// A value's type as a refusal names it: a Foundation number by what it holds.
func described(_ s: Scalar, _ v: Any) -> String {
    switch s {
    case .int: return "an integer (\(typeName(v)))"
    case .float: return "a float (\(typeName(v)))"
    case .bool: return "a Bool (\(typeName(v)))"
    case .bytes: return "[UInt8]"
    case let .other(name): return name
    }
}
