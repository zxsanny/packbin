/// What a typed unpack reads for one item of a nested-row element: its values, and the rounds the item
/// read, so a round read with 0 rounds in one item and not read in another fill their rows apart.
struct ElementItem {
    let values: [String: Any]
    let reached: Set<ObjectIdentifier>
}

/// Unpack of utf8, lists, dicts and nested rows. A u16 length or count is read before anything it
/// sizes, and no storage is reserved from it: every item reads at least one byte, so the items held
/// never outnumber the bytes read.
extension Reader {
    /// A u16 length or count of the field `id` (`name`).
    mutating func readLength(_ id: Int?, _ name: String) throws -> Int {
        let start = try take(id, name, 2)
        return Int(buf[start]) | Int(buf[start + 1]) << 8
    }

    /// A string field of the compact text format: a LEB128 byte count (1 to 3 bytes) and that many payload
    /// bytes (``TextCodec``). A buffer that ends inside the count or the payload is short, with the field
    /// and the bytes it needed. A payload that breaks a rule of the format (a bad count, start mode, pad,
    /// code, capital, escape, UTF-8 or length) is refused with the shape of an unreadable count (as
    /// TypeScript's fatal decoder): the field, nothing more needed, the bytes left where the string starts.
    mutating func readString(_ id: Int?, _ name: String) throws -> String {
        let leftAtStart = left
        var count = 0
        var k = 0
        while true {
            guard k < 3 else { throw PackbinError.shortPacket(id, name, needed: 0, left: leftAtStart) }
            guard k < leftAtStart else { throw PackbinError.shortPacket(id, name, needed: k + 1, left: leftAtStart) }
            let b = Int(buf[off + k])
            count |= (b & 0x7F) << (7 * k)
            k += 1
            if b & 0x80 == 0 {
                guard k == 1 || b != 0 else { throw PackbinError.shortPacket(id, name, needed: 0, left: leftAtStart) }
                break
            }
        }
        off += k
        if count == 0 { return "" }
        let start = try take(id, name, count)
        guard let text = buf.withUnsafeBufferPointer({ textCodec.decode($0, start, count) }) else {
            throw PackbinError.shortPacket(id, name, needed: 0, left: leftAtStart)
        }
        return text
    }

    /// A dict key: a string as `readString` reads it, refused with the same shape when it is not in
    /// stream-safe form (``isStreamSafe(_:)``), before it is hashed or compared.
    mutating func readKey(_ name: String) throws -> String {
        let leftAtStart = left
        let key = try readString(nil, name)
        guard isStreamSafe(key.unicodeScalars) else { throw PackbinError.shortPacket(nil, name, needed: 0, left: leftAtStart) }
        return key
    }

    /// A list (`[Any]`) or dict (`[String: Any]`): a u16 count, then the items, each after its key for a
    /// dict. An item that reads no byte is refused, so a count of 65 535 cannot be walked for no input.
    /// A key that is not strictly greater than the key before it, by UTF-8 bytes (AZ-2713), is refused
    /// as TypeScript refuses a key given twice (a short packet with `needed` 0 and `left` 0). So are
    /// two keys that are equal as Swift strings although their bytes differ (NFC and
    /// NFD), which one `[String: Any]` cannot hold apart (owner ruling 2026-10-14). A key that is not in
    /// stream-safe form is refused before it reaches the dictionary.
    mutating func collection(_ n: Node) throws -> Any {
        guard let element = n.element else { return [Any]() }
        let count = try readLength(nil, n.name)
        if n.kind == .list {
            var items: [Any] = []
            for _ in 0..<count { items.append(try item(n, element)) }
            return items
        }
        var entries: [String: Any] = [:]
        var previous: String?
        for _ in 0..<count {
            let key = try readKey(n.name)
            // Strictly ascending by UTF-8 bytes (not by Swift's canonical-equivalence order): an equal
            // key is a repeated one, a smaller one is out of order, and both are refused as one error.
            if let previous, !previous.utf8.lexicographicallyPrecedes(key.utf8) {
                throw PackbinError(.short, field: nil, name: n.name, reason: "dict key given twice")
            }
            previous = key
            let v = try item(n, element)
            guard entries[key] == nil else {
                throw PackbinError(.short, field: nil, name: n.name, reason: "dict key given twice")
            }
            entries[key] = v
        }
        return entries
    }

    private mutating func item(_ n: Node, _ e: Node) throws -> Any {
        let before = off
        let v: Any
        switch e.kind {
        case .group:
            v = try elementRow(e.fields)
        case .list, .dict:
            v = try collection(e)
        default:
            v = try value(e)
        }
        if off == before { throw PackbinError.shortPacket(nil, n.name, needed: 0, left: left) }
        return v
    }

    /// One item of a nested-row element: a row and a scope of its own, with the rounds it read.
    private mutating func elementRow(_ fields: [Node]) throws -> Any {
        let savedReached = reached
        reached = []
        defer { reached = savedReached }
        let values = try nestedRow(fields)
        return typed ? ElementItem(values: values, reached: reached) : values
    }

    /// The members of a nested row, read into a map of their own with references of their own.
    mutating func nestedRow(_ fields: [Node]) throws -> [String: Any] {
        let saved = seen
        seen = [:]
        defer { seen = saved }
        var values: [String: Any] = [:]
        try self.fields(fields, &values)
        return values
    }
}

/// The most scalars with a nonzero canonical combining class a dict key may hold in a row: the limit of
/// Unicode's stream-safe text format (UAX #15).
let maxNonStarters = 30

/// Whether `scalars` are in stream-safe form: no run of more than ``maxNonStarters`` scalars whose
/// canonical combining class is not 0. Swift hashes and compares a `String` in NFC, and sorts each such
/// run by combining class in time quadratic in its length; a scalar of class 0 ends the run. One linear
/// pass, before the key is hashed (F47 of the loop 26 security audit). No scalar below U+0300 has a
/// combining class, so those skip the property lookup.
func isStreamSafe(_ scalars: some Sequence<Unicode.Scalar>) -> Bool {
    var run = 0
    for s in scalars {
        run = s.value < 0x300 || s.properties.canonicalCombiningClass == .notReordered ? 0 : run + 1
        if run > maxNonStarters { return false }
    }
    return true
}
