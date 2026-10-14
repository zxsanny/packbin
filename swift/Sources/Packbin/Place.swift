/// One row of a scheme: the top level or a group with members. Its members are the value fields and
/// groups at any depth in it (under flags, flag bits and when) outside a group of its own, in scheme
/// order. In a map row a group's members are a `[String: Any]` under its name, both ways (owner
/// ruling 2026-10-14, Go-4 A); in a typed row a member of the group's own row type.
final class Place: Sendable {
    struct Member: Sendable {
        let node: Node
        /// The place of a group with members; nil for a value field or a mark.
        let inner: Place?
    }

    /// A name declared only inside a group of this place, with the groups from this place to it.
    struct Foreign: Sendable {
        let member: Node
        let path: [Node]
    }

    let members: [Member]
    /// The bools and empty groups whose name no other kind of field of the place declares: a map row
    /// gives each of them a `Bool`.
    let marks: [Node]
    /// The groups with members whose name no other kind of field of the place declares: a map row
    /// gives each of them a `[String: Any]`.
    let rows: [Member]
    let foreign: [Foreign]
    /// The row type the members are bound to (the first bound one); `checkBindings` refuses a mix.
    let binding: Binding?

    init(_ nodes: [Node]) {
        var members: [Member] = []
        Place.collect(nodes, into: &members)
        var classes: [String: Int] = [:]
        for m in members { classes[m.node.name, default: 0] |= Place.memberClass(m.node) }
        let single = members.filter { classes[$0.node.name] == Place.memberClass($0.node) }
        self.members = members
        self.marks = single.filter { $0.node.isMark }.map(\.node)
        self.rows = single.filter { $0.inner != nil }
        self.foreign = Place.foreignNames(members)
        self.binding = members.lazy.compactMap { $0.node.accessor?.binding }.first
    }

    private static func collect(_ nodes: [Node], into out: inout [Member]) {
        for n in nodes {
            switch n.kind {
            case .int, .float, .bytes, .bool:
                out.append(Member(node: n, inner: nil))
            case .group:
                out.append(Member(node: n, inner: n.fields.isEmpty ? nil : Place(n.fields)))
            case .flags, .flagBit, .when:
                collect(n.fields, into: &out)
            case .flagByte:
                break
            }
        }
    }

    private static func memberClass(_ n: Node) -> Int {
        if n.isMark { return 2 }
        return n.kind == .group ? 4 : 1
    }

    private static func foreignNames(_ members: [Member]) -> [Foreign] {
        let own = Set(members.map(\.node.name))
        var seen = Set<String>()
        var out: [Foreign] = []
        func walk(_ group: Member, _ path: [Node]) {
            guard let inner = group.inner else { return }
            let path = path + [group.node]
            for m in inner.members {
                if !own.contains(m.node.name) && seen.insert(m.node.name).inserted {
                    out.append(Foreign(member: m.node, path: path))
                }
                walk(m, path)
            }
        }
        for m in members { walk(m, []) }
        return out
    }
}

/// The members of each place are bound to one row type, or none is; a bound group's members are bound
/// to the row type of the group's member, and an unbound group's members are not bound.
func checkBindings(_ place: Place) throws {
    var unbound: Node?
    for m in place.members {
        guard let acc = m.node.accessor else {
            if unbound == nil { unbound = m.node }
            continue
        }
        guard let first = place.binding, acc.binding.rowType != first.rowType else { continue }
        throw PackbinError.scheme(m.node.errorID, m.node.name, "bound to row type \(acc.binding.rowTypeName), "
            + "but an earlier field is bound to \(first.rowTypeName)")
    }
    if let first = place.binding, let unbound {
        throw PackbinError.scheme(unbound.errorID, unbound.name,
            "not bound to row type \(first.rowTypeName); bind every value field of a scheme, or none")
    }
    for m in place.members {
        guard let inner = m.inner else { continue }
        let child = m.node.accessor?.child
        let bound = inner.members.first { $0.node.accessor != nil }?.node ?? inner.members.first?.node
        switch (child, inner.binding) {
        case let (nil, innerBinding?):
            throw PackbinError.scheme(bound?.id, bound?.name ?? "", "bound to row type \(innerBinding.rowTypeName), "
                + "but its group \(m.node.name) is not bound")
        case let (child?, nil):
            guard let first = inner.members.first?.node else { break }
            throw PackbinError.scheme(first.id, first.name, "not bound to row type \(child.typeName) (the row of "
                + "group \(m.node.name)); bind every value field of a scheme, or none")
        case let (child?, innerBinding?) where child.type != innerBinding.rowType:
            throw PackbinError.scheme(bound?.id, bound?.name ?? "", "bound to row type \(innerBinding.rowTypeName), "
                + "but its group \(m.node.name) is bound to \(child.typeName)")
        default:
            break
        }
        try checkBindings(inner)
    }
}

/// A map row as the walker reads it: each given value read through its optionals, a mark's value a
/// `Bool`, a group's value a map of its own read the same way. A name declared only inside a group,
/// given in the row around it while the group is not given, is refused (owner ruling Go-4 A:
/// TypeScript packs it from the flat key).
func mapValues(_ place: Place, _ row: [String: Any]) throws -> [String: Any] {
    var values = presentValues(row)
    for mark in place.marks {
        guard let v = values[mark.name] else { continue }
        if case .bool = scalar(v) { continue }
        throw PackbinError.pack(mark.id, mark.name, "expected a Bool for \(mark.label) \(mark.name), got \(typeName(v))")
    }
    for group in place.rows {
        let g = group.node
        guard let v = values[g.name], let inner = group.inner else { continue }
        guard let nested = v as? [String: Any] else {
            throw PackbinError.pack(g.id, g.name, "expected a [String: Any] for group \(g.name), got \(typeName(v))")
        }
        values[g.name] = try mapValues(inner, nested)
    }
    for f in place.foreign where values[f.member.name] != nil {
        guard let absent = absentGroup(values, f.path) else { continue }
        throw PackbinError.pack(f.member.id, f.member.name, "\(f.member.name) is a member of group \(absent.name), "
            + "which is not given; give the value in the group's [String: Any], not in the row around it")
    }
    return values
}

/// The first group on `path` the row does not give, or nil.
private func absentGroup(_ values: [String: Any], _ path: [Node]) -> Node? {
    var map = values
    for g in path {
        guard let v = map[g.name] else { return g }
        guard let nested = v as? [String: Any] else { return nil }
        map = nested
    }
    return nil
}

/// A typed row (held in a box of the place's row type) as the walker reads it: each value its getter
/// gives, by field name; a group's values as a map of their own.
func typedValues(_ place: Place, _ box: AnyObject) -> [String: Any] {
    var values = [String: Any](minimumCapacity: place.members.count)
    for m in place.members {
        guard let acc = m.node.accessor, let v = acc.get(box) else { continue }
        guard let inner = m.inner else {
            values[m.node.name] = v
            continue
        }
        if let childBox = inner.binding?.boxRow(v) { values[m.node.name] = typedValues(inner, childBox) }
    }
    return values
}

/// Stores the values unpack read into a typed row of the place (held in a box); a group's values
/// into a new row of the group's type.
func fillRow(_ place: Place, _ box: AnyObject, _ values: [String: Any]) {
    for m in place.members {
        guard let acc = m.node.accessor, let v = values[m.node.name] else { continue }
        guard let inner = m.inner else {
            acc.set(box, v)
            continue
        }
        guard let nested = v as? [String: Any], let binding = inner.binding else { continue }
        let childBox = binding.makeBox()
        fillRow(inner, childBox, nested)
        acc.set(box, binding.unbox(childBox))
    }
}
