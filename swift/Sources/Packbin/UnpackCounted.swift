/// Unpack of the counted kinds and rounds: sized, bits, packed, u2, repeat and times. A count read from
/// the wire is checked before it sizes anything: a count that is absent, negative or above `Int.max`
/// cannot be read, and the bytes a count asks for are taken (checked against the bytes left) before
/// any storage is made for them.
extension Reader {
    mutating func counted(_ n: Node, _ values: inout [String: Any]) throws {
        switch n.kind {
        case .sized:
            guard let count = readCount(n, bias: 0) else { throw unreadable(n.id, n.name) }
            let start = try take(n, count)
            store(n, Array(buf[start..<(start + count)]), &values)
        case .bits, .packed:
            guard let count = readCount(n, bias: n.kind == .packed ? n.bias : 0) else { throw unreadable(n.id, n.name) }
            let width = n.size
            let start = try take(n, itemBytes(width, count))
            let mask = UInt8(1) << UInt8(width) - 1
            // `count` is at most 8 items for each byte just taken.
            var items: [UInt8] = []
            items.reserveCapacity(count)
            for i in 0..<count {
                let bit = i * width
                items.append(buf[start + (bit >> 3)] >> UInt8(bit & 7) & mask)
            }
            store(n, items, &values)
        case .u2:
            let start = try take(n, (n.fields.count + 3) >> 2)
            for (i, slot) in n.fields.enumerated() {
                store(slot, buf[start + (i >> 2)] >> UInt8((i & 3) * 2) & 3, &values)
            }
        case .repeatRound:
            try rounds(n, count: nil, &values)
        case .timesRound:
            guard let count = readCount(n, bias: 0) else {
                let (id, name) = roundMember(n)
                throw unreadable(id, name)
            }
            try rounds(n, count: count, &values)
        case .int, .float, .bytes, .bool, .flags, .flagByte, .flagBit, .when, .group, .slot, .utf8, .list, .dict:
            break
        }
    }

    /// The error of a count that is absent, negative or too large to read: the counted field, nothing
    /// more needed, the bytes left where it starts.
    private func unreadable(_ id: Int?, _ name: String) -> PackbinError {
        PackbinError.shortPacket(id, name, needed: 0, left: left)
    }

    /// The count `n` reads from the scope plus `bias`; nil when the count field was not read (a clear
    /// bit, a false when) or the count is negative or above `Int.max`.
    private func readCount(_ n: Node, bias: Int) -> Int? {
        guard let raw = seen[n.ref], case let .int(num) = scalar(raw) else { return nil }
        return countOf(num, bias)
    }

    /// Reads the rounds of `n`: `count` of them, or for a repeat (nil) until the buffer ends. Each
    /// round is read into a row and a scope of its own; then every name a round can hold gets one entry
    /// a round, `nil` where the round skipped it (no key when there was no round). A repeat's lists join
    /// what the scope already holds under the name.
    private mutating func rounds(_ n: Node, count: Int?, _ values: inout [String: Any]) throws {
        guard let shape = n.shape else { return }
        reached.insert(ObjectIdentifier(n))
        let saved = seen
        defer { seen = saved }
        var rows: [[String: Any]] = []
        while count.map({ rows.count < $0 }) ?? (left > 0) {
            let before = off
            seen = [:]
            var one: [String: Any] = [:]
            try fields(n.fields, &one)
            if off == before {
                // A times round that reads nothing would repeat up to `count` times for no input; a
                // repeat round that reads nothing ends the repeat, and the bytes left are trailing.
                if count != nil {
                    let (id, name) = roundMember(n)
                    throw unreadable(id, name)
                }
                rows.append(one)
                break
            }
            rows.append(one)
        }
        if rows.isEmpty { return }
        for m in shape.names {
            let list: [Any?] = rows.map { $0[m.name] }
            if count == nil {
                appendList(&values, m.name, list)
            } else {
                values[m.name] = list
            }
        }
    }
}
