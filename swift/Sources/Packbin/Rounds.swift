/// A repeat or times round is addressed by index. In a map row each name a round holds takes an array,
/// entry i for round i; pack reads each array at the round's index, and a value that is not an array
/// goes to every round. Unpack gives every name a round can hold one entry a round, `nil` where the
/// round skipped it, so a repack gives the same bytes. A group in a round takes one `[String: Any]` a
/// round (owner ruling Go-4 A), where TypeScript takes its members as flat lists.

/// What a repeat or times asks of its values, worked out once when the scheme is built.
final class RoundShape: Sendable {
    /// The row of one round.
    let place: Place
    /// The members of the round's row, one per name, in scheme order: the names a round holds in the
    /// map form.
    let names: [Node]
    /// The names a flag bit can leave absent in a round: under flags or a flag bit (also through a when
    /// below them), and a group that holds such a name.
    let optional: [Node]
    /// The names whose value is itself a run of bytes or items: a lone one would reach every round.
    let buffers: [Node]
    /// The groups with members among the names, which can hold a buffer.
    let groups: [Place.Member]

    init(_ fields: [Node]) {
        place = Place(fields)
        var seen = Set<String>()
        var names: [Node] = []
        var groups: [Place.Member] = []
        for m in place.members where seen.insert(m.node.name).inserted {
            names.append(m.node)
            if m.inner != nil { groups.append(m) }
        }
        self.names = names
        self.groups = groups
        buffers = names.filter(\.isBuffer)
        var optionalSeen = Set<String>()
        var optional: [Node] = []
        collectOptional(fields, underFlag: false, &optionalSeen, &optional)
        self.optional = optional
    }
}

private func collectOptional(_ nodes: [Node], underFlag: Bool, _ seen: inout Set<String>, _ out: inout [Node]) {
    for n in nodes {
        switch n.kind {
        case .flagBit, .flags:
            collectOptional(n.fields, underFlag: true, &seen, &out)
        case .when, .u2:
            collectOptional(n.fields, underFlag: underFlag, &seen, &out)
        case .group:
            var inner = Set<String>()
            var held: [Node] = []
            collectOptional(n.fields, underFlag: false, &inner, &held)
            if (underFlag || !held.isEmpty) && seen.insert(n.name).inserted { out.append(n) }
        case .repeatRound, .timesRound, .flagByte:
            break
        case .int, .float, .bytes, .bool, .sized, .slot, .bits, .packed:
            if underFlag && seen.insert(n.name).inserted { out.append(n) }
        }
    }
}

/// Gives each repeat and times its shape.
func shapeRounds(_ nodes: [Node]) -> [Node] {
    nodes.map { n in
        let fields = shapeRounds(n.fields)
        return n.isRound ? n.with(fields: fields, shape: RoundShape(fields)) : n.with(fields: fields)
    }
}

/// The values of one name of a round as the walker reads them: one entry a round, `nil` where the
/// round leaves the name out. `typed`: made from the elements of a typed row's array, so a times can
/// check its count against them.
struct RoundList {
    let entries: [Any?]
    let typed: Bool
}

/// `v` as the entries of a round's name, each read through its optionals; nil for a value that is
/// not an array (it goes to every round). A `[UInt8]` is a byte run, not an array of rounds; the type
/// is compared exactly, as a cast would also turn an `[Any?]` of `UInt8`s into one.
func roundEntries(_ v: Any) -> [Any?]? {
    if type(of: v) == [UInt8].self { return nil }
    if let list = v as? [Any?] { return list.map { $0.flatMap(unboxed) } }
    if let list = v as? [Any] { return list.map(unboxed) }
    return nil
}

/// The longest list among the round's names; a value that is not a list is one round.
func roundCount(_ shape: RoundShape, _ values: [String: Any]) -> Int {
    var count = 0
    for n in shape.names {
        guard let v = values[n.name] else { continue }
        count = max(count, (v as? RoundList)?.entries.count ?? 1)
    }
    return count
}

/// The row of round `i`: each list read at `i` (an absent entry leaves the name out), a value that is
/// not a list as it is.
func sliceRound(_ shape: RoundShape, _ values: [String: Any], _ i: Int) -> [String: Any] {
    var view = [String: Any](minimumCapacity: shape.names.count)
    for n in shape.names {
        guard let v = values[n.name] else { continue }
        guard let list = v as? RoundList else {
            view[n.name] = v
            continue
        }
        if i < list.entries.count, let entry = list.entries[i] { view[n.name] = entry }
    }
    return view
}

/// The member a refusal about a whole round names: the first name its round holds, else the round.
func roundMember(_ r: Node) -> (Int?, String) {
    guard let first = r.shape?.names.first else { return (r.id, "") }
    return (first.id, first.name)
}

/// A repeat writes a round per entry of its longest list, and a flag bit leaves a member absent in a
/// round only by a `nil` entry, so a non-empty list shorter than the rounds under a member a flag bit
/// can leave absent does not say which rounds it belongs to.
func refuseShortOptional(_ shape: RoundShape, _ values: [String: Any], _ count: Int) throws {
    for n in shape.optional {
        guard let list = values[n.name] as? RoundList, !list.entries.isEmpty, list.entries.count < count else {
            continue
        }
        throw PackbinError.pack(n.id, n.name, "\(n.name): \(list.entries.count) items, repeat count \(count); "
            + "give one entry per round, nil where the member is absent")
    }
}

/// A times writes exactly `count` rounds, so a list that holds more would lose its tail.
func refuseLongLists(_ shape: RoundShape, _ values: [String: Any], _ count: Int) throws {
    for n in shape.names {
        guard let list = values[n.name] as? RoundList, list.entries.count > count else { continue }
        throw PackbinError.pack(n.id, n.name, "\(n.name): \(list.entries.count) items, times count \(count)")
    }
}

/// A typed times holds one element a round, so a count other than the elements is refused (as C# and
/// Go), naming the member.
func refuseTypedCount(_ r: Node, _ shape: RoundShape, _ values: [String: Any], _ count: Int) throws {
    for n in shape.names {
        guard let list = values[n.name] as? RoundList, list.typed else { continue }
        if list.entries.count == count { return }
        let (id, name) = roundMember(r)
        throw PackbinError.pack(id, name, "\(name): the times count is \(count), but the row holds "
            + "\(list.entries.count) rounds")
    }
}

/// One byte run or item list given for a name of a round (also inside a group map given once for every
/// round) would reach every round, so it is refused: one per round goes in a list.
func refuseLoneBuffers(_ shape: RoundShape, _ values: [String: Any]) throws {
    for n in shape.buffers where values[n.name] != nil && !(values[n.name] is RoundList) {
        throw loneBuffer(n)
    }
    for g in shape.groups {
        guard let inner = g.inner, let nested = values[g.node.name] as? [String: Any] else { continue }
        try refuseBuffersIn(inner, nested)
    }
}

private func refuseBuffersIn(_ place: Place, _ values: [String: Any]) throws {
    for m in place.members {
        if m.node.isBuffer && values[m.node.name] != nil { throw loneBuffer(m.node) }
        if let inner = m.inner, let nested = values[m.node.name] as? [String: Any] {
            try refuseBuffersIn(inner, nested)
        }
    }
}

private func loneBuffer(_ n: Node) -> PackbinError {
    PackbinError.pack(n.id, n.name, "\(n.name): a byte buffer in a repeat or times round needs a list with one "
        + "buffer per round")
}

/// The list a repeat built joins what the scope already holds under that name.
func appendList(_ into: inout [String: Any], _ name: String, _ list: [Any?]) {
    switch into[name] {
    case nil:
        into[name] = list
    case let prev as [Any?]:
        into[name] = prev + list
    case let prev?:
        into[name] = [prev] + list
    }
}
