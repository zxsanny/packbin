/// What an `eq` id can name: the name of an earlier value field of the scope and the kind of value
/// it holds.
private struct Source {
    let id: Int
    let name: String
    let kind: SourceKind
}

private enum SourceKind {
    /// An integer of `size` bytes.
    case integer(size: Int, signed: Bool, label: String)
    case bool
    /// A float or fixed bytes: no `eq` names one.
    case other
}

/// An `eq` id names an integer or bool field read earlier in the same scope; flags, flag bits, an
/// anchored group and a when share the scope around them. A bool is compared only with `true` (a
/// clear bit is absent, so `false` never matches), and an integer only with a value it can hold. The
/// scheme keeps a copy of each when with the name filled in, so pack and unpack never look an id up.
func bindReferences(_ nodes: [Node], refs: inout Set<String>) throws -> [Node] {
    var scope: [Int: Source] = [:]
    return try bindAll(nodes, scope: &scope, refs: &refs)
}

private func bindAll(_ nodes: [Node], scope: inout [Int: Source], refs: inout Set<String>) throws -> [Node] {
    var out: [Node] = []
    out.reserveCapacity(nodes.count)
    for n in nodes {
        switch n.kind {
        case .int:
            declare(n, .integer(size: n.size, signed: n.signed, label: n.label), &scope)
            out.append(n)
        case .bool:
            declare(n, .bool, &scope)
            out.append(n)
        case .float, .bytes:
            declare(n, .other, &scope)
            out.append(n)
        case .when:
            guard let condition = n.condition else {
                out.append(n)
                continue
            }
            let ref = try resolve(n, condition, scope)
            refs.insert(ref)
            out.append(n.with(fields: try bindAll(n.fields, scope: &scope, refs: &refs), ref: ref))
        case .flags, .flagBit, .group:
            out.append(n.with(fields: try bindAll(n.fields, scope: &scope, refs: &refs)))
        case .flagByte:
            out.append(n)
        }
    }
    return out
}

private func declare(_ n: Node, _ kind: SourceKind, _ scope: inout [Int: Source]) {
    guard let id = n.id else { return }
    scope[id] = Source(id: id, name: n.name, kind: kind)
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
