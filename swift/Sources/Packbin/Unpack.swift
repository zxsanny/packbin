/// Unpacks `buffer` with the scheme its first byte names, out of `schemes`. The row is the bound row
/// type for a scheme whose fields are bound with `bind(get:set:)`, else a `[String: Any]` (see
/// `unpackMap`). A buffer that cannot be read throws a `PackbinError` (`.short`, `.trailing`,
/// `.unknownType`, `.badValue`) and gives no row; no input traps.
public func unpack(_ buffer: [UInt8], _ schemes: Scheme...) throws -> Any {
    try unpack(buffer, schemes)
}

/// `unpack` with the schemes as an array.
public func unpack(_ buffer: [UInt8], _ schemes: [Scheme]) throws -> Any {
    let (scheme, values, reached) = try dispatch(buffer, schemes, typed: true)
    guard let binding = scheme.binding else { return values }
    let box = binding.makeBox()
    fillRow(scheme.place, box, values, reached)
    return binding.unbox(box)
}

/// `unpack` with the row as a map keyed by field name, for every scheme. A value has the Swift type
/// of its field: `UInt8` to `UInt64`, `Int8` to `Int64`, `Float`, `Double`, `[UInt8]`, `String`, an
/// `[Any]` for a list, a `[String: Any]` for a dict, and `true` for a set bool or mark, a
/// `[String: Any]` of its members for a group that was read, a `[UInt8]` for
/// sized, bits and packed, a `UInt8` for a u2 slot, and for each name of a repeat or times round an
/// `[Any?]` with one entry a round (`nil` where the round skipped it). A field that was not read (a
/// clear bit, a when that did not match, a round of 0 rounds) has no key, so a row it returned packs
/// again to the same bytes.
public func unpackMap(_ buffer: [UInt8], _ schemes: Scheme...) throws -> [String: Any] {
    try unpackMap(buffer, schemes)
}

/// `unpackMap` with the schemes as an array.
public func unpackMap(_ buffer: [UInt8], _ schemes: [Scheme]) throws -> [String: Any] {
    try dispatch(buffer, schemes, typed: false).1
}

/// `typed`: the row is filled into the bound row type, so each item of a nested-row element keeps the
/// rounds it read.
private func dispatch(_ buffer: [UInt8], _ schemes: [Scheme], typed: Bool) throws
    -> (Scheme, [String: Any], Set<ObjectIdentifier>) {
    if schemes.isEmpty { throw PackbinError.scheme(nil, "", "unpack needs at least one scheme") }
    var seen = ByteSet()
    for s in schemes where !seen.insert(s.typeNumber) {
        throw PackbinError.scheme(nil, "", "duplicate type number \(s.typeNumber)")
    }
    guard let first = buffer.first else { throw PackbinError.shortPacket(nil, "", needed: 1, left: 0) }
    guard let scheme = schemes.first(where: { $0.typeNumber == Int(first) }) else {
        throw PackbinError(.unknownType, field: nil, actual: Int(first))
    }
    var r = Reader(buffer)
    r.typed = typed && scheme.binding != nil
    var values = [String: Any](minimumCapacity: scheme.place.members.count)
    try r.fields(scheme.fields, &values)
    if r.left > 0 { throw PackbinError(.trailing, field: nil, left: r.left) }
    return (scheme, values, r.reached)
}

/// Reads a buffer from its second byte. Every read goes through `take`, which checks the bytes left
/// first and throws `.short`, so no input reaches an index out of range.
struct Reader {
    let buf: [UInt8]
    /// The next byte to read; never above `buf.count`.
    var off = 1
    var flagBytes: [(tag: FlagTag, byte: UInt8)] = []
    /// The values of the scope read so far that a when or a count reads, by name, wherever they sit (a
    /// group shares the scope; a round is a scope of its own).
    var seen: [String: Any] = [:]
    /// The rounds read (with 0 rounds or more), for a typed row; an item of a nested-row element keeps
    /// its own.
    var reached = Set<ObjectIdentifier>()
    /// The row is filled into a bound row type: items of a nested-row element are `ElementItem`s.
    var typed = false

    init(_ buf: [UInt8]) { self.buf = buf }

    var left: Int { buf.count &- off }

    /// The index of the first of `size` bytes of `n`, which are then consumed.
    mutating func take(_ n: Node, _ size: Int) throws -> Int { try take(n.id, n.name, size) }

    /// The index of the first of `size` bytes of the field `id` (`name`), which are then consumed.
    mutating func take(_ id: Int?, _ name: String, _ size: Int) throws -> Int {
        guard size <= left else { throw PackbinError.shortPacket(id, name, needed: size, left: left) }
        let start = off
        off += size
        return start
    }

    /// Reads `nodes` into `values`, the row they belong to (inside a group, the group's own map).
    mutating func fields(_ nodes: [Node], _ values: inout [String: Any]) throws {
        for n in nodes {
            switch n.kind {
            case .int, .float, .bytes, .utf8:
                store(n, try value(n), &values)
            case .list, .dict:
                store(n, try collection(n), &values)
            case .bool:
                // Reached only through a set flag bit.
                store(n, true, &values)
            case .flagByte:
                guard let tag = n.tag else { continue }
                let byte = buf[try take(n, 1)]
                if let i = flagBytes.firstIndex(where: { $0.tag === tag }) {
                    flagBytes[i].byte = byte
                } else {
                    flagBytes.append((tag, byte))
                }
            case .flagBit:
                let byte = flagBytes.first(where: { $0.tag === n.tag })?.byte ?? 0
                if byte & UInt8(truncatingIfNeeded: 1 << n.bit) != 0 {
                    try fields(n.fields, &values)
                }
            case .when:
                if let condition = n.condition, sameValue(seen[n.ref], condition.value) {
                    try fields(n.fields, &values)
                }
            case .flags:
                try fields(n.fields, &values)
            case .group:
                // A mark is reached only through a set flag bit; a group with members is a map of its own.
                if n.fields.isEmpty {
                    values[n.name] = true
                } else if n.nested {
                    values[n.name] = try nestedRow(n.fields)
                } else {
                    var inner: [String: Any] = [:]
                    try fields(n.fields, &inner)
                    values[n.name] = inner
                }
            case .sized, .u2, .bits, .packed, .repeatRound, .timesRound:
                try counted(n, &values)
            case .slot:
                // A slot is read by its u2.
                break
            }
        }
    }

    /// The value of an integer, float, fixed bytes or utf8 field.
    mutating func value(_ n: Node) throws -> Any {
        switch n.kind {
        case .float:
            let x = readUInt(try take(n, n.size), n.size, n.bigEndian)
            return n.size == 4 ? Float(bitPattern: UInt32(truncatingIfNeeded: x)) as Any : Double(bitPattern: x)
        case .bytes:
            let start = try take(n, n.size)
            return Array(buf[start..<(start + n.size)])
        case .utf8:
            return try readString(n.id, n.name)
        default:
            return integer(readUInt(try take(n, n.size), n.size, n.bigEndian), n.size, n.signed)
        }
    }

    mutating func store(_ n: Node, _ v: Any, _ values: inout [String: Any]) {
        values[n.name] = v
        if n.referenced { seen[n.name] = v }
    }

    func readUInt(_ start: Int, _ size: Int, _ bigEndian: Bool) -> UInt64 {
        var x: UInt64 = 0
        for i in 0..<size {
            let shift = UInt64(bigEndian ? size &- 1 &- i : i) &* 8
            x |= UInt64(buf[start &+ i]) << shift
        }
        return x
    }
}

/// The integer in `x` as the Swift type of its field.
private func integer(_ x: UInt64, _ size: Int, _ signed: Bool) -> Any {
    switch (size, signed) {
    case (1, false): return UInt8(truncatingIfNeeded: x)
    case (1, true): return Int8(truncatingIfNeeded: x)
    case (2, false): return UInt16(truncatingIfNeeded: x)
    case (2, true): return Int16(truncatingIfNeeded: x)
    case (4, false): return UInt32(truncatingIfNeeded: x)
    case (4, true): return Int32(truncatingIfNeeded: x)
    case (_, false): return x
    case (_, true): return Int64(truncatingIfNeeded: x)
    }
}

/// A set of type numbers (0...255) with no allocation.
private struct ByteSet {
    private var words: (UInt64, UInt64, UInt64, UInt64) = (0, 0, 0, 0)

    /// Inserts `n`; false when it was already in the set.
    mutating func insert(_ n: Int) -> Bool {
        let bit = UInt64(1) << UInt64(n & 63)
        let old: UInt64
        switch n >> 6 {
        case 0: old = words.0; words.0 |= bit
        case 1: old = words.1; words.1 |= bit
        case 2: old = words.2; words.2 |= bit
        default: old = words.3; words.3 |= bit
        }
        return old & bit == 0
    }
}
