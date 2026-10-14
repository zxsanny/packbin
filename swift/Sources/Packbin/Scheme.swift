/// A built field list with its type number. It is immutable and `Sendable`, so one scheme can pack
/// and unpack from any number of tasks at once.
public struct Scheme: Sendable {
    /// The first byte of every packet of this scheme.
    public let typeNumber: Int
    let fields: [Node]
    /// The row of the top level: its value fields and groups, outside a group.
    let place: Place
    /// The row type the fields are bound to; nil for a scheme that packs only `[String: Any]`.
    var binding: Binding? { place.binding }

    /// Builds a scheme from its type number (0...255) and its fields, numbered by order from 0. A
    /// refused scheme throws a `PackbinError` of kind `.schemeError` naming the field id.
    public init(_ typeNumber: Int, _ fields: Field...) throws {
        try self.init(typeNumber, fields)
    }

    /// `init` with the fields as an array. The checks run in TypeScript's order.
    public init(_ typeNumber: Int, _ fields: [Field]) throws {
        guard (0...255).contains(typeNumber) else {
            throw PackbinError.scheme(nil, "", "type number \(typeNumber): expected 0..255")
        }
        let nodes = fields.map(\.node)
        try checkNodes(nodes)
        try checkSlots(nodes, inU2: false)
        _ = try checkFieldIDs(nodes, next: 0)
        var met: [ObjectIdentifier: Int] = [:]
        let flat = try bindFlagBits(flatten(nodes), seen: [:], met: &met)
        try checkPresenceMarks(flat, onFlagBit: false)
        try checkMemberNames(flat)
        try checkRoundNesting(flat, inRound: false)
        try checkRoundBodies(flat)
        var refs = Set<String>()
        let bound = shapeRounds(markReferenced(try bindReferences(flat, refs: &refs), refs))
        try checkElements(bound)
        let place = Place(bound)
        try checkBindings(place)
        self.typeNumber = typeNumber
        self.fields = bound
        self.place = place
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
        case .flagBit:
            // A split bit's member that is a flags stays one member: its own byte and bits.
            out.append(n.with(fields: n.fields.flatMap(flagMember)))
        case .when, .group, .repeatRound, .timesRound, .list, .dict:
            out.append(n.with(fields: flatten(n.fields)))
        case .int, .float, .bytes, .bool, .flagByte, .sized, .u2, .slot, .bits, .packed, .utf8:
            out.append(n)
        }
    }
    return out
}

private func flagsFlat(_ n: Node) -> [Node] {
    let tag = FlagTag("")
    var out = [Node(.flagByte, id: n.id, tag: tag, inOrder: true)]
    for (bit, child) in n.fields.enumerated() {
        out.append(Node(.flagBit, id: nil, fields: flagMember(child), tag: tag, bit: bit))
    }
    return out
}

/// The member of a flag bit: a flags keeps its own byte and bits as its fields.
private func flagMember(_ child: Node) -> [Node] {
    child.kind == .flags ? [child.with(fields: flagsFlat(child))] : flatten([child])
}

/// One read of a flag byte while a scheme is built: its own tag, and the bits taken so far.
private final class FlagRead {
    let tag: FlagTag
    var taken = 0
    init(_ name: String) { tag = FlagTag(name) }
}

/// Gives each read of a flag byte an identity of its own and numbers its bits by their place after it.
/// A bit reads the flag byte of its own scope, read before it: the top level, a repeat or times round,
/// or a when body (which also sees the bytes read before it around it); each flags member sees the
/// scope too, and a group shares the scope around it.
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
    case .group:
        // A group is transparent: it sees the bytes read before it, and a byte read in it is seen after it.
        var fields: [Node] = []
        fields.reserveCapacity(n.fields.count)
        for child in n.fields { fields.append(try bindBits(child, seen: &seen, met: &met)) }
        return n.with(fields: fields)
    case .repeatRound, .timesRound, .list, .dict:
        // A round and a list or dict element are scopes of their own: they see no byte read around them.
        return n.with(fields: try bindFlagBits(n.fields, seen: [:], met: &met))
    case .int, .float, .bytes, .bool, .sized, .u2, .slot, .bits, .packed, .utf8:
        return n
    }
}
