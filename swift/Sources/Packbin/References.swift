/// What an `eq` or count id can name: the name of an earlier value field of the scope, the kind of
/// value it holds, and the groups from the scope's row to it.
private struct Source {
    let id: Int
    let name: String
    let kind: SourceKind
    let path: [String]
}

private enum SourceKind {
    /// An integer of `size` bytes.
    case integer(size: Int, signed: Bool, label: String)
    /// A u2 slot: an integer from 0 to 3.
    case slot
    case bool
    /// A float, fixed bytes or a counted kind: no `eq` or count names one.
    case other
}

/// An `eq` id names an integer, slot or bool field read earlier in the same scope, and a count id of
/// times, sized, bits and packed an integer or slot; flags, flag bits, an anchored group, u2 and a when
/// share the scope around them, and a repeat or times body, a list or dict element and a group without
/// an anchor are scopes of their own, closed both ways. A
/// bool is compared only with `true` (a clear bit is absent, so `false` never matches), and an integer
/// only with a value it can hold. The scheme keeps a copy of each when and counted field with the name
/// filled in, so pack and unpack never look an id up; `refs` gets each name a when or count reads.
func bindReferences(_ nodes: [Node], refs: inout Set<String>) throws -> [Node] {
    var scope: [Int: Source] = [:]
    return try bindAll(nodes, path: [], scope: &scope, refs: &refs)
}

private func bindAll(_ nodes: [Node], path: [String], scope: inout [Int: Source],
                     refs: inout Set<String>) throws -> [Node] {
    var out: [Node] = []
    out.reserveCapacity(nodes.count)
    for n in nodes {
        switch n.kind {
        case .int:
            declare(n, .integer(size: n.size, signed: n.signed, label: n.label), path, &scope)
            out.append(n)
        case .slot:
            declare(n, .slot, path, &scope)
            out.append(n)
        case .bool:
            declare(n, .bool, path, &scope)
            out.append(n)
        case .float, .bytes, .utf8:
            declare(n, .other, path, &scope)
            out.append(n)
        case .list, .dict:
            // An element is a scope of its own, closed both ways; a list or dict declares no id.
            var own: [Int: Source] = [:]
            out.append(n.with(fields: try bindAll(n.fields, path: [], scope: &own, refs: &refs)))
        case .sized, .bits, .packed:
            let source = try resolveCount(n, scope)
            refs.insert(source.name)
            declare(n, .other, path, &scope)
            out.append(n.with(ref: source.name, refPath: source.path))
        case .timesRound:
            let source = try resolveCount(n, scope)
            refs.insert(source.name)
            var own: [Int: Source] = [:]
            let body = try bindAll(n.fields, path: [], scope: &own, refs: &refs)
            out.append(n.with(fields: body, ref: source.name, refPath: source.path))
        case .repeatRound:
            var own: [Int: Source] = [:]
            out.append(n.with(fields: try bindAll(n.fields, path: [], scope: &own, refs: &refs)))
        case .when:
            guard let condition = n.condition else {
                out.append(n)
                continue
            }
            let ref = try resolve(n, condition, scope)
            refs.insert(ref)
            out.append(n.with(fields: try bindAll(n.fields, path: path, scope: &scope, refs: &refs), ref: ref))
        case .group where n.nested:
            // A nested row has references of its own, read from its own map.
            var own: [Int: Source] = [:]
            out.append(n.with(fields: try bindAll(n.fields, path: [], scope: &own, refs: &refs)))
        case .group:
            out.append(n.with(fields: try bindAll(n.fields, path: path + [n.name], scope: &scope, refs: &refs)))
        case .flags, .flagBit, .u2:
            out.append(n.with(fields: try bindAll(n.fields, path: path, scope: &scope, refs: &refs)))
        case .flagByte:
            out.append(n)
        }
    }
    return out
}

private func declare(_ n: Node, _ kind: SourceKind, _ path: [String], _ scope: inout [Int: Source]) {
    guard let id = n.id else { return }
    scope[id] = Source(id: id, name: n.name, kind: kind, path: path)
}

/// The field a count id names: an integer or slot declared earlier in the same scope.
private func resolveCount(_ n: Node, _ scope: [Int: Source]) throws -> Source {
    let owner = n.id ?? -1
    let countID = n.countID ?? -1
    guard let source = scope[countID] else {
        throw PackbinError.scheme(n.id, n.isRound ? "" : n.name, "\(n.label) \(owner): count names field id \(countID), "
            + "which is not declared earlier in the same scope")
    }
    switch source.kind {
    case .integer, .slot:
        return source
    case .bool, .other:
        throw PackbinError.scheme(n.id, n.isRound ? "" : n.name, "\(n.label) \(owner): count names field id \(countID) "
            + "(\(source.name)), which is not an integer")
    }
}

/// The name the when's `eq` reads, or the refusal of its id or value.
private func resolve(_ n: Node, _ condition: Condition, _ scope: [Int: Source]) throws -> String {
    let anchor = n.id ?? -1
    guard let source = scope[condition.id] else {
        throw PackbinError.scheme(n.id, "", "when \(anchor): eq names field id \(condition.id), "
            + "which is not declared earlier in the same scope")
    }
    switch source.kind {
    case .other:
        throw PackbinError.scheme(n.id, "", "when \(anchor): eq names field id \(source.id) (\(source.name)), "
            + "which is not an integer or a bool")
    case .slot:
        if case let .int(num) = condition.value, !num.neg, num.mag <= 3 { break }
        throw PackbinError.scheme(n.id, "", "when \(anchor) tests u2 field \(source.id) ('\(source.name)') "
            + "against \(shown(condition.value)); the value must be a whole number from 0 to 3")
    case .bool:
        if condition.value != .bool(true) {
            throw PackbinError.scheme(n.id, "", "when \(anchor): eq names bool field id \(source.id) "
                + "(\(source.name)) and accepts only true, not \(shown(condition.value))")
        }
    case let .integer(size, signed, label):
        if case let .int(num) = condition.value, num.fits(size: size, signed: signed) { break }
        let shift = 64 &- size &* 8
        let (lo, hi) = signed ? (String(Int64.min >> shift), String(Int64.max >> shift)) : ("0", String(UInt64.max >> shift))
        throw PackbinError.scheme(n.id, "", "when \(anchor) tests \(label) field \(source.id) ('\(source.name)') "
            + "against \(shown(condition.value)); the value must be a whole number from \(lo) to \(hi)")
    }
    return source.name
}

/// An `eq` value as a refusal shows it.
private func shown(_ v: EqValue) -> String {
    switch v {
    case let .int(num): return "\(num.neg ? "-" : "")\(num.mag)"
    case let .bool(b): return String(b)
    case let .unrepresentable(text): return text
    }
}

/// Marks the value fields whose name a when tests, so pack and unpack keep only what a when reads.
func markReferenced(_ nodes: [Node], _ refs: Set<String>) -> [Node] {
    nodes.map { n in
        n.with(fields: markReferenced(n.fields, refs), referenced: n.isValue && refs.contains(n.name))
    }
}
