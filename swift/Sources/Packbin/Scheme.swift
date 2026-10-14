/// A built field list with its type number. It is immutable and `Sendable`, so one scheme can pack
/// and unpack from any number of tasks at once.
public struct Scheme: Sendable {
    /// The first byte of every packet of this scheme.
    public let typeNumber: Int
    let fields: [Node]
    /// The value fields at any depth (under flags, flag bits and when), in scheme order.
    let members: [Node]
    /// The bools whose name no other kind of field declares: a map row gives each of them a `Bool`.
    let marks: [Node]
    /// The row type the fields are bound to; nil for a scheme that packs only `[String: Any]`.
    let binding: Binding?

    /// Builds a scheme from its type number (0...255) and its fields, numbered by order from 0. A
    /// refused scheme throws a `PackbinError` of kind `.schemeError` naming the field id.
    public init(_ typeNumber: Int, _ fields: Field...) throws {
        try self.init(typeNumber, fields)
    }

    /// `init` with the fields as an array.
    public init(_ typeNumber: Int, _ fields: [Field]) throws {
        guard (0...255).contains(typeNumber) else {
            throw PackbinError.scheme(nil, "", "type number \(typeNumber): expected 0..255")
        }
        let nodes = fields.map(\.node)
        try checkNodes(nodes)
        var met: [ObjectIdentifier: Int] = [:]
        let flat = try bindFlagBits(flatten(nodes), seen: [:], met: &met)
        var scope: [Int: String] = [:]
        var refs = Set<String>()
        let bound = markReferenced(try bindReferences(flat, scope: &scope, refs: &refs), refs)
        var members: [Node] = []
        collectMembers(bound, into: &members)
        self.typeNumber = typeNumber
        self.fields = bound
        self.members = members
        self.marks = Scheme.marks(of: members)
        self.binding = try Scheme.binding(of: members)
    }

    private static func marks(of members: [Node]) -> [Node] {
        var others = Set<String>()
        for n in members where n.kind != .bool { others.insert(n.name) }
        return members.filter { $0.kind == .bool && !others.contains($0.name) }
    }

    /// The members are bound to one row type, or none is.
    private static func binding(of members: [Node]) throws -> Binding? {
        var first: Binding?
        var unbound: Node?
        for n in members {
            guard let acc = n.accessor else {
                if unbound == nil { unbound = n }
                continue
            }
            guard let firstBinding = first else {
                first = acc.binding
                continue
            }
            if acc.binding.rowType != firstBinding.rowType {
                throw PackbinError.scheme(n.id, n.name, "bound to row type \(acc.binding.rowTypeName), "
                    + "but an earlier field is bound to \(firstBinding.rowTypeName)")
            }
        }
        if let first, let unbound {
            throw PackbinError.scheme(unbound.id, unbound.name,
                "not bound to row type \(first.rowTypeName); bind every value field of a scheme, or none")
        }
        return first
    }
}

/// Reports a constructor's refusal at any depth.
private func checkNodes(_ nodes: [Node]) throws {
    for n in nodes {
        if let error = n.error {
            let at = n.kind == .flags && n.fields.count > flagBits ? n.fields[flagBits] : n
            throw PackbinError.scheme(at.errorID, at.declaredName, error)
        }
        try checkNodes(n.fields)
    }
}

/// Turns each flags into its flag byte and one flag bit per member. A member that is a flags of its
/// own becomes a flags whose fields are its own byte and bits.
private func flatten(_ nodes: [Node]) -> [Node] {
    var out: [Node] = []
    out.reserveCapacity(nodes.count)
    for n in nodes {
        switch n.kind {
        case .flags:
            out.append(contentsOf: flagsFlat(n))
        case .when, .flagBit:
            out.append(n.with(fields: flatten(n.fields)))
        case .int, .float, .bytes, .bool, .flagByte:
            out.append(n)
        }
    }
    return out
}

private func flagsFlat(_ n: Node) -> [Node] {
    let tag = FlagTag("")
    var out = [Node(.flagByte, id: n.id, tag: tag, inOrder: true)]
    for (bit, child) in n.fields.enumerated() {
        let member = child.kind == .flags ? [child.with(fields: flagsFlat(child))] : flatten([child])
        out.append(Node(.flagBit, id: nil, fields: member, tag: tag, bit: bit))
    }
    return out
}

/// One read of a flag byte while a scheme is built: its own tag, and the bits taken so far.
private final class FlagRead {
    let tag: FlagTag
    var taken = 0
    init(_ name: String) { tag = FlagTag(name) }
}

/// Gives each read of a flag byte an identity of its own and numbers its bits by their place after it.
/// A bit reads the flag byte of its own scope, read before it: the top level or a when body (which
/// also sees the bytes read before it around it); each flags member sees the scope too.
private func bindFlagBits(_ nodes: [Node], seen: [ObjectIdentifier: FlagRead],
                          met: inout [ObjectIdentifier: Int]) throws -> [Node] {
    var seen = seen
    var out: [Node] = []
    out.reserveCapacity(nodes.count)
    for n in nodes {
        out.append(try bindBits(n, seen: &seen, met: &met))
    }
    return out
}

private func bindBits(_ n: Node, seen: inout [ObjectIdentifier: FlagRead],
                      met: inout [ObjectIdentifier: Int]) throws -> Node {
    switch n.kind {
    case .flagByte:
        guard let tag = n.tag else { return n }
        let read = FlagRead(tag.name)
        seen[ObjectIdentifier(tag)] = read
        return n.with(tag: read.tag)
    case .flagBit:
        guard let tag = n.tag else { return n }
        let key = ObjectIdentifier(tag)
        let before = met[key] ?? 0
        met[key] = before &+ 1
        guard let read = seen[key] else {
            throw PackbinError.scheme(n.errorID, n.declaredName,
                "flag bit \(before) (\(n.declaredName)): its flag byte is not read earlier in the same scope")
        }
        if read.taken >= flagBits {
            throw PackbinError.scheme(n.errorID, n.declaredName,
                "flag byte \"\(tag.name)\": ninth bit (\(n.declaredName)); a flag byte holds \(flagBits) bits")
        }
        let bit = read.taken
        read.taken += 1
        return n.with(fields: try bindFlagBits(n.fields, seen: seen, met: &met), tag: read.tag, bit: bit)
    case .flags, .when:
        // A when body, or a built flags member (its own byte and bits): a scope that sees the bytes read
        // around it, and whose bytes are not seen after it.
        return n.with(fields: try bindFlagBits(n.fields, seen: seen, met: &met))
    case .int, .float, .bytes, .bool:
        return n
    }
}

/// An `eq` id names a value field read earlier in the same scope; flags, flag bits and a when share
/// the scope around them. The scheme keeps a copy of each when with the name filled in, so pack and
/// unpack never look an id up.
private func bindReferences(_ nodes: [Node], scope: inout [Int: String],
                            refs: inout Set<String>) throws -> [Node] {
    var out: [Node] = []
    out.reserveCapacity(nodes.count)
    for n in nodes {
        switch n.kind {
        case .int, .float, .bytes, .bool:
            if let id = n.id { scope[id] = n.name }
            out.append(n)
        case .when:
            guard let condition = n.condition else {
                out.append(n)
                continue
            }
            guard let ref = scope[condition.id] else {
                throw PackbinError.scheme(n.id, "", "when \(n.id ?? -1): eq names field id \(condition.id), "
                    + "which is not declared earlier in the same scope")
            }
            refs.insert(ref)
            out.append(n.with(fields: try bindReferences(n.fields, scope: &scope, refs: &refs), ref: ref))
        case .flags, .flagBit:
            out.append(n.with(fields: try bindReferences(n.fields, scope: &scope, refs: &refs)))
        case .flagByte:
            out.append(n)
        }
    }
    return out
}

/// Marks the value fields whose name a when tests, so pack keeps only what a when reads.
private func markReferenced(_ nodes: [Node], _ refs: Set<String>) -> [Node] {
    nodes.map { n in
        n.with(fields: markReferenced(n.fields, refs), referenced: n.isValue && refs.contains(n.name))
    }
}

private func collectMembers(_ nodes: [Node], into out: inout [Node]) {
    for n in nodes {
        if n.isValue {
            out.append(n)
        } else {
            collectMembers(n.fields, into: &out)
        }
    }
}
