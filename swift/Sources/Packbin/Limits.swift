/// The limits of a scheme, which keep the cost of one call from being set by its input. Unpack refuses
/// a repeat or times field past `maxRounds` rounds, and rounds that together would hold more than
/// `maxSlots` slots, when the round would start, before its bytes are read (kind `.tooMany`, `needed`
/// 0, `left` the bytes left there). Pack refuses the same rounds and slots (a times count or a repeat
/// list above `maxRounds` before any round is written), and a packet longer than `maxBytes`.
extension Scheme {
    /// The default of `maxRounds`, the same in every package of this repository.
    public static let defaultMaxRounds = 65_535
    /// The default of `maxSlots`.
    public static let defaultMaxSlots = 1_048_576
    /// The default of `maxBytes` (16 MiB).
    public static let defaultMaxBytes = 16_777_216

    /// A copy of this scheme with the given limits; this scheme is unchanged. A limit left out takes
    /// its default, not this scheme's value. A limit below 1 throws a `PackbinError` of kind
    /// `.schemeError` naming the limit. `parity` is the count of parity bytes of message error
    /// correction (0...32); left out it keeps this scheme's count, so setting a limit never drops
    /// protection; another count throws a `.schemeError` naming `parity`, the count and 32.
    public func withLimits(maxRounds: Int? = nil, maxSlots: Int? = nil, maxBytes: Int? = nil,
                           parity: Int? = nil) throws -> Scheme {
        let n = parity ?? self.parity
        try Ecc.checkParity(n)
        return Scheme(self, maxRounds: try checkedLimit("maxRounds", maxRounds, Scheme.defaultMaxRounds),
                      maxSlots: try checkedLimit("maxSlots", maxSlots, Scheme.defaultMaxSlots),
                      maxBytes: try checkedLimit("maxBytes", maxBytes, Scheme.defaultMaxBytes),
                      parity: n)
    }
}

private func checkedLimit(_ name: String, _ value: Int?, _ fallback: Int) throws -> Int {
    guard let value else { return fallback }
    guard value >= 1 else {
        throw PackbinError.scheme(nil, name, "\(name): expected a positive integer, got \(value)")
    }
    return value
}

/// The slots one round of `fields` charges against `maxSlots`: the distinct names it can hold, as every
/// package counts them. One slot each for a value field (a bool too), a sized, bits or packed name, a
/// list or dict name (however many items), each slot of a u2 and an empty group's own name; and one for
/// each name inside a when (whether its condition holds or not), flags, flag bit or group, at any depth.
/// A non-empty group's own name, a flag byte and the anchors of when, repeat and times are no slot, and
/// a name declared twice is one slot. A nested row is a scope of its own, so it charges the width of
/// its own members, apart from the names around it (as Go; assessment 24 D3, kept).
func roundWidth(_ fields: [Node]) -> Int {
    var names = Set<String>()
    let nested = nameSlots(fields, &names)
    return nested + names.count
}

/// Collects the names of `fields` into `names` and returns the slots of the nested rows among them.
private func nameSlots(_ fields: [Node], _ names: inout Set<String>) -> Int {
    var nested = 0
    for n in fields {
        switch n.kind {
        case .repeatRound, .timesRound, .flagByte:
            break
        case .when, .flags, .flagBit, .u2:
            nested += nameSlots(n.fields, &names)
        case .group where n.fields.isEmpty:
            names.insert(n.name)
        case .group where n.nested:
            nested += roundWidth(n.fields)
        case .group:
            nested += nameSlots(n.fields, &names)
        case .int, .float, .bytes, .bool, .sized, .slot, .bits, .packed, .utf8, .list, .dict:
            names.insert(n.name)
        }
    }
    return nested
}

/// The member a round limit names: the first name the round holds, else the round itself.
func roundLabel(_ r: Node) -> (Int?, String) {
    let (id, name) = roundMember(r)
    return (id, name.isEmpty ? "\(r.label) \(r.id ?? -1)" : name)
}

/// `a + b` as text, exact for any two counts.
func sumText(_ a: Int, _ b: Int) -> String { String(UInt(max(a, 0)) + UInt(max(b, 0))) }

extension Packer {
    /// Refuses, naming the member, a write of `size` bytes that would make the packet longer than
    /// `maxBytes`; checked before every write, so nothing of a refused write is made.
    func room(_ size: Int, _ id: Int?, _ name: String) throws {
        guard size > maxBytes - out.count else { return }
        throw PackbinError.pack(id, name, "\(name): the packet would be \(sumText(out.count, size)) bytes, "
            + "above the limit of \(maxBytes) bytes")
    }

    /// Charges the round of `r` that starts next against `maxSlots`, before any of its bytes, as unpack
    /// charges it, so pack refuses at the round where the same scheme's unpack would.
    mutating func chargeRound(_ r: Node, _ shape: RoundShape) throws {
        if shape.width > maxSlots - slots {
            let (id, name) = roundLabel(r)
            throw PackbinError.pack(id, name, "\(name): the rounds would hold \(sumText(slots, shape.width)) slots, "
                + "above the limit of \(maxSlots) slots")
        }
        slots += shape.width
    }

    /// A times writes `count` rounds and a lone value goes to every round, so a count past
    /// `maxRounds` is refused before any round.
    func refuseRoundsOverLimit(_ r: Node, _ count: Int) throws {
        guard count > maxRounds else { return }
        let (id, name) = roundLabel(r)
        throw PackbinError.pack(id, name, "\(name): the times count is \(count), above the limit of \(maxRounds) rounds")
    }

    /// A repeat writes a round per entry of its longest list, so the first list among the round's
    /// names with more entries than `maxRounds` is refused before any round, named by its own member.
    func refuseRepeatOverLimit(_ shape: RoundShape, _ values: [String: Any]) throws {
        for n in shape.names {
            guard let list = values[n.name] as? RoundList, list.entries.count > maxRounds else { continue }
            throw PackbinError.pack(n.id, n.name, "\(n.name): the repeat count is \(list.entries.count), "
                + "above the limit of \(maxRounds) rounds")
        }
    }
}

extension Reader {
    /// Charges round `index` (from 0) of `r`, which starts next: a round past `maxRounds`, or one that
    /// would take the slots of the call past `maxSlots`, is refused with the bytes left where it would
    /// start, before anything is made for it.
    mutating func chargeRound(_ r: Node, _ shape: RoundShape, _ index: Int) throws {
        if index >= maxRounds {
            let (id, name) = roundLabel(r)
            throw PackbinError(.tooMany, field: id, name: name, left: left,
                               reason: "round \(sumText(index, 1)) is above the limit of \(maxRounds) rounds")
        }
        if shape.width > maxSlots - slots {
            let (id, name) = roundLabel(r)
            throw PackbinError(.tooMany, field: id, name: name, left: left,
                               reason: "the rounds would hold \(sumText(slots, shape.width)) slots, above the limit of "
                                   + "\(maxSlots) slots")
        }
        slots += shape.width
    }
}

/// A combined flags' byte has no name of its own: it is named by the first name its members declare,
/// among `nodes`, the fields it is packed with.
func firstBitName(_ nodes: [Node], _ tag: FlagTag) -> String {
    guard let bit = nodes.first(where: { $0.kind == .flagBit && $0.tag === tag }) else { return "" }
    return firstDeclaredName(bit)
}

/// The first name `n` declares, looking into a flag bit's member, a when, a round and a flags.
private func firstDeclaredName(_ n: Node) -> String {
    if n.kind == .flagBit { return n.member.map(firstDeclaredName) ?? "" }
    if !n.name.isEmpty { return n.name }
    for child in n.fields {
        let name = firstDeclaredName(child)
        if !name.isEmpty { return name }
    }
    return ""
}
