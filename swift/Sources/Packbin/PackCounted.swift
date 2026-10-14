/// Pack of the counted kinds and rounds: sized, bits, packed, u2, repeat and times.
extension Packer {
    mutating func counted(_ n: Node, _ values: [String: Any], _ wrote: inout [String: Any]) throws {
        switch n.kind {
        case .sized:
            try sized(n, values, wrote)
        case .bits, .packed:
            try items(n, values, wrote)
        case .u2:
            try u2(n, values, &wrote)
        case .repeatRound:
            guard let shape = n.shape else { return }
            let count = roundCount(shape, values)
            try refuseShortOptional(shape, values, count)
            try refuseLoneBuffers(shape, values)
            try rounds(n, shape, count, values)
        case .timesRound:
            guard let shape = n.shape else { return }
            let count = try borrowedCount(n, wrote)
            try refuseTypedCount(n, shape, values, count)
            try refuseLongLists(shape, values, count)
            try refuseLoneBuffers(shape, values)
            try rounds(n, shape, count, values)
        case .int, .float, .bytes, .bool, .flags, .flagByte, .flagBit, .when, .group, .slot:
            break
        }
    }

    /// Packs `count` rounds of `n`, each from its own row and with its own scope.
    private mutating func rounds(_ n: Node, _ shape: RoundShape, _ count: Int, _ values: [String: Any]) throws {
        let saved = scope
        defer { scope = saved }
        for i in 0..<count {
            let view = sliceRound(shape, values, i)
            scope = view
            var wrote: [String: Any] = [:]
            try fields(n.fields, root: FlagRoot(fields: n.fields, values: view), view, &wrote)
        }
    }

    private mutating func sized(_ n: Node, _ values: [String: Any], _ wrote: [String: Any]) throws {
        let count = try writtenCount(n, wrote)
        let v = values[n.name]
        guard let v, case let .bytes(raw) = scalar(v) else {
            let got = v.map { described(scalar($0), $0) } ?? "no value"
            throw PackbinError.pack(n.id, n.name, "\(n.name): expected [UInt8] for sized, got \(got)")
        }
        guard !count.neg && count.mag == UInt64(raw.count) else {
            throw PackbinError.pack(n.id, n.name, "\(n.name): expected \(shown(count, bias: 0)) bytes, got \(raw.count)")
        }
        out.append(contentsOf: raw)
    }

    /// A bits or packed list: `count` items, `size` bits each, low bits first.
    private mutating func items(_ n: Node, _ values: [String: Any], _ wrote: [String: Any]) throws {
        let count: Int
        let label: String
        if n.kind == .bits {
            let num = try writtenCount(n, wrote)
            count = countOf(num, 0) ?? -1
            label = shown(num, bias: 0)
        } else {
            count = try borrowedCount(n, wrote)
            label = String(count)
        }
        let v = values[n.name]
        guard let v, let list = itemList(v), list.count == count else {
            let got = v.map { itemList($0).map { "\($0.count) items" } ?? described(scalar($0), $0) } ?? "no value"
            throw PackbinError.pack(n.id, n.name, "\(n.name): expected a list of \(label) items for \(n.label), got \(got)")
        }
        let width = n.size
        let top = UInt64(1) << UInt64(width) - 1
        var packed = [UInt8](repeating: 0, count: itemBytes(width, count))
        for (i, item) in list.enumerated() {
            guard let item, case let .int(num) = scalar(item), !num.neg, num.mag <= top else {
                let got = item.map { described(scalar($0), $0) } ?? "no value"
                throw PackbinError.pack(n.id, n.name, "\(n.name): item \(i) is \(got); expected 0..\(top)")
            }
            let bit = i &* width
            packed[bit >> 3] |= UInt8(truncatingIfNeeded: num.mag) << UInt8(bit & 7)
        }
        out.append(contentsOf: packed)
    }

    private mutating func u2(_ n: Node, _ values: [String: Any], _ wrote: inout [String: Any]) throws {
        var packed = [UInt8](repeating: 0, count: (n.fields.count + 3) >> 2)
        for (i, slot) in n.fields.enumerated() {
            let v = values[slot.name]
            guard let v, case let .int(num) = scalar(v), !num.neg, num.mag <= 3 else {
                let got = v.map { described(scalar($0), $0) } ?? "no value"
                throw PackbinError.pack(slot.id, slot.name, "\(slot.name): expected a 2-bit integer 0..3, got \(got)")
            }
            packed[i >> 2] |= UInt8(truncatingIfNeeded: num.mag) << UInt8((i & 3) * 2)
            if slot.referenced { wrote[slot.name] = v }
        }
        out.append(contentsOf: packed)
    }

    /// Refuses a times, bits, packed or sized in the scope of `n` (itself, or under groups, flags, flag
    /// bits and a when whose condition holds) whose count the row gives above 0 although no field
    /// wrote it, which is what a clear when that holds the count leaves: the bit is clear and nothing
    /// is read, so the count the row gives would mean nothing (U6, U11).
    func refuseUnwrittenCount(_ n: Node, _ values: [String: Any], _ wrote: [String: Any]) throws {
        switch n.kind {
        case .timesRound, .sized, .bits, .packed:
            guard wrote[n.ref] == nil, let count = rowCountAbove0(rowCount(n), n.kind == .packed ? n.bias : 0) else {
                return
            }
            let given = "the count \(n.ref) is \(count) in the row, but no field wrote it (the when that holds it is clear)"
            let fix = "give the count 0, leave it out, or make the when hold"
            if n.isRound {
                let (id, name) = roundMember(n)
                throw PackbinError.pack(id, name, "\(name): \(given), so its times reads no round; \(fix)")
            }
            throw PackbinError.pack(n.id, n.name, "\(n.name): \(given), so the member reads nothing; \(fix)")
        case .when:
            guard let condition = n.condition, sameValue(wrote[n.ref], condition.value) else { return }
            for child in n.fields { try refuseUnwrittenCount(child, values, wrote) }
        case .group:
            let inner = groupValues(values, n)
            for child in n.fields { try refuseUnwrittenCount(child, inner, wrote) }
        case .flags, .flagBit:
            for child in n.fields { try refuseUnwrittenCount(child, values, wrote) }
        case .int, .float, .bytes, .bool, .flagByte, .repeatRound, .u2, .slot:
            return
        }
    }

    /// The count the row gives for `n`'s count field, read from the scope's row along the groups that
    /// hold it; nil when the row gives none.
    private func rowCount(_ n: Node) -> Any? {
        var map = scope
        for g in n.refPath {
            guard let nested = map[g] as? [String: Any] else { return nil }
            map = nested
        }
        return map[n.ref]
    }
}

/// A count the row gives as a whole number above 0 after `bias` (an integer, or a whole float), as
/// text before the bias; nil otherwise. A count too large to read is still a count above 0 (U23).
private func rowCountAbove0(_ raw: Any?, _ bias: Int) -> String? {
    guard let raw else { return nil }
    switch scalar(raw) {
    case let .int(num):
        if num.neg { return nil }
        guard let count = Int(exactly: num.mag) else { return String(num.mag) }
        return count &+ bias > 0 ? String(num.mag) : nil
    case let .float(x):
        guard x.rounded(.towardZero) == x, x + Double(bias) > 0 else { return nil }
        return x < 0x1p63 ? String(Int64(x)) : String(x)
    case .bool, .bytes, .other:
        return nil
    }
}

/// The bytes `count` items of `width` bits take, without overflow for any count.
func itemBytes(_ width: Int, _ count: Int) -> Int {
    let c = max(count, 0)
    return c / 8 * width + (c % 8 * width + 7) / 8
}

/// A bits or packed value as its items, each read through its optionals: any array, a `[UInt8]` too.
private func itemList(_ v: Any) -> [Any?]? {
    if let raw = v as? [UInt8] { return raw.map { $0 } }
    return roundEntries(v)
}

/// The count pack wrote in the scope for `n`; a count field that was skipped or absent was not
/// written, and unpack would not read it either.
func writtenCount(_ n: Node, _ wrote: [String: Any]) throws -> Num {
    let (id, name) = n.isRound ? roundMember(n) : (n.id, n.name)
    let label = n.isRound ? "times" : n.name
    guard let raw = wrote[n.ref] else {
        throw PackbinError.pack(id, name, "\(label): count \(n.ref) was not written")
    }
    guard case let .int(num) = scalar(raw) else {
        throw PackbinError.pack(id, name, "\(label): count \(n.ref) is not an integer")
    }
    return num
}

/// The written count plus the bias of packed, refused when it is negative or too large for an `Int`.
func borrowedCount(_ n: Node, _ wrote: [String: Any]) throws -> Int {
    let num = try writtenCount(n, wrote)
    let bias = n.kind == .packed ? n.bias : 0
    if let count = countOf(num, bias) { return count }
    let (id, name) = n.isRound ? roundMember(n) : (n.id, n.name)
    throw PackbinError.pack(id, name, "\(n.isRound ? "times" : n.name): item count \(shown(num, bias: bias))")
}

/// A count plus `bias` (0 or -1) as an `Int`; nil when it is negative or above `Int.max`.
func countOf(_ num: Num, _ bias: Int) -> Int? {
    guard !num.neg, let count = Int(exactly: num.mag) else { return nil }
    let (sum, overflow) = count.addingReportingOverflow(bias)
    return !overflow && sum >= 0 ? sum : nil
}

/// `num + bias` (bias 0 or -1) as text, exact for every 64-bit value.
func shown(_ num: Num, bias: Int) -> String {
    switch (bias, num.neg, num.mag) {
    case (0, true, let mag): return "-\(mag)"
    case (0, false, let mag): return "\(mag)"
    case (_, true, let mag): return mag == UInt64.max ? "-18446744073709551616" : "-\(mag + 1)"
    case (_, false, 0): return "-1"
    case (_, false, let mag): return "\(mag - 1)"
    }
}
