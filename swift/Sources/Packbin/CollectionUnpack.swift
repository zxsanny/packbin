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

    /// A u16 byte count and that many bytes of valid UTF-8. A string that is not valid is refused with
    /// the shape of an unreadable count (as TypeScript's fatal decoder): the field, nothing more needed,
    /// the bytes left where the string starts. Valid bytes are kept as they are, a byte order mark too.
    mutating func readString(_ id: Int?, _ name: String) throws -> String {
        let leftAtStart = left
        let count = try readLength(id, name)
        let start = try take(id, name, count)
        let raw = buf[start..<(start + count)]
        guard isValidUTF8(raw) else { throw PackbinError.shortPacket(id, name, needed: 0, left: leftAtStart) }
        return String(decoding: raw, as: UTF8.self)
    }

    /// A list (`[Any]`) or dict (`[String: Any]`): a u16 count, then the items, each after its key for a
    /// dict. An item that reads no byte is refused, so a count of 65 535 cannot be walked for no input.
    /// A key given twice is refused as TypeScript refuses it (a short packet with `needed` 0 and `left`
    /// 0), and so are two keys that are equal as Swift strings although their bytes differ (NFC and
    /// NFD), which one `[String: Any]` cannot hold apart (owner ruling 2026-10-14).
    mutating func collection(_ n: Node) throws -> Any {
        guard let element = n.element else { return [Any]() }
        let count = try readLength(nil, n.name)
        if n.kind == .list {
            var items: [Any] = []
            for _ in 0..<count { items.append(try item(n, element)) }
            return items
        }
        var entries: [String: Any] = [:]
        for _ in 0..<count {
            let key = try readString(nil, n.name)
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

/// Whether `raw` is well-formed UTF-8: no stray or missing continuation byte, no overlong form, no
/// surrogate and nothing above U+10FFFF.
private func isValidUTF8(_ raw: ArraySlice<UInt8>) -> Bool {
    var it = raw.makeIterator()
    var decoder = UTF8()
    while true {
        switch decoder.decode(&it) {
        case .scalarValue: continue
        case .emptyInput: return true
        case .error: return false
        }
    }
}
