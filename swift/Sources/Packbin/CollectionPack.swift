/// The most items a list or dict, and the most bytes a string, can hold: a u16.
let maxCollection = 65_535

/// A nested row a typed row has already turned into the values the walker reads.
struct WalkedRow {
    let values: [String: Any]
}

/// Pack of utf8, lists, dicts and nested rows.
extension Packer {
    /// Packs the members of a nested row from `sub`, in a scope of its own: its references read what it
    /// writes, a flag byte read in it finds its bits in it, and a count it gives is read from it.
    mutating func nestedRow(_ fields: [Node], _ sub: [String: Any]) throws {
        let saved = scope
        defer { scope = saved }
        scope = sub
        var wrote: [String: Any] = [:]
        try self.fields(fields, root: FlagRoot(fields: fields, values: sub), sub, &wrote)
    }

    /// A u16 byte count and the UTF-8 bytes of `text`.
    mutating func writeString(_ id: Int?, _ name: String, _ text: String) throws {
        let count = text.utf8.count
        guard count <= maxCollection else { throw PackbinError.pack(id, name, "\(name): utf-8 length \(count)") }
        appendCount(count)
        out.append(contentsOf: text.utf8)
    }

    /// A list or dict `n` from its value: a u16 count, then the items (a dict's in unsigned UTF-8 byte
    /// order of their keys, each after its key).
    mutating func collection(_ n: Node, _ v: Any?) throws {
        guard let element = n.element else { return }
        if n.kind == .list {
            guard let v, let items = roundEntries(v) else {
                throw PackbinError.pack(nil, n.name, "\(n.name): expected a list, got \(shownValue(v))")
            }
            try writeCount(n, items.count)
            for item in items { try packItem(n, element, item) }
            return
        }
        guard let v, let entries = try dictEntries(n, v) else {
            throw PackbinError.pack(nil, n.name, "\(n.name): expected a dictionary, got \(shownValue(v))")
        }
        let keys = entries.keys.sorted { $0.utf8.lexicographicallyPrecedes($1.utf8) }
        try writeCount(n, keys.count)
        for key in keys {
            try writeString(nil, n.name, key)
            try packItem(n, element, entries[key] ?? nil)
        }
    }

    private mutating func writeCount(_ n: Node, _ count: Int) throws {
        guard count <= maxCollection else { throw PackbinError.pack(nil, n.name, "\(n.name): length \(count)") }
        appendCount(count)
    }

    private mutating func appendCount(_ count: Int) {
        out.append(UInt8(truncatingIfNeeded: count))
        out.append(UInt8(truncatingIfNeeded: count >> 8))
    }

    /// One item of the list or dict `n`, whose element is `e`.
    private mutating func packItem(_ n: Node, _ e: Node, _ item: Any?) throws {
        let v = item.flatMap(unboxed)
        switch e.kind {
        case .group:
            try nestedRow(e.fields, try itemRow(n, v))
        case .list, .dict:
            try collection(e, v)
        default:
            guard let v else { throw PackbinError.pack(e.id, e.name, "missing \(e.name)") }
            var unused: [String: Any] = [:]
            try write(e, v, &unused)
        }
    }

    /// The values of one item of a nested-row element: a map the row gave, read as a group's map is,
    /// or the values a typed row made.
    private func itemRow(_ n: Node, _ v: Any?) throws -> [String: Any] {
        if let walked = v as? WalkedRow { return walked.values }
        guard let v, let map = v as? [String: Any] else {
            throw PackbinError.pack(nil, n.name, "\(n.name): expected a [String: Any] for each item, got \(shownValue(v))")
        }
        guard let place = n.rowPlace else { return presentValues(map) }
        return try mapValues(place, map)
    }
}

/// A dict value as its entries: any dictionary with `String` keys, else nil. A Foundation dictionary
/// that holds two keys equal as Swift strings (NFC and NFD forms) would lose one of them, so it is
/// refused.
private func dictEntries(_ n: Node, _ v: Any) throws -> [String: Any]? {
    guard let entries = v as? [String: Any] else { return nil }
    if foreignKeysMerged(v, entries.count) {
        throw PackbinError.pack(nil, n.name, "\(n.name): dict key given twice: two keys are equal as Swift strings, "
            + "though their UTF-8 bytes differ")
    }
    return entries
}

/// A utf8 value: a `String` (a Foundation string too).
func stringValue(_ v: Any) -> String? { v as? String }

/// A value as a refusal names it, or "no value".
private func shownValue(_ v: Any?) -> String { v.map { described(scalar($0), $0) } ?? "no value" }
