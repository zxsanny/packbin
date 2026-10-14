/// Whether a flag bit's member holds a value at any depth. A bool is a mark with no bytes of its own,
/// and only `true` sets its bit. A when is on when its condition holds on what pack has written so far
/// (`wrote`) and its body holds a value; a flags member when any of its members is on. A member that
/// is on and cannot be written in full fails when it is packed.
func bitOn(_ n: Node, _ values: [String: Any], _ wrote: [String: Any]) -> Bool {
    switch n.kind {
    case .bool:
        return isTrue(values[n.name])
    case .flags:
        return n.fields.contains { bitOn($0, values, wrote) }
    case .flagBit:
        return n.member.map { bitOn($0, values, wrote) } ?? false
    case .when:
        guard let condition = n.condition, sameValue(wrote[n.ref], condition.value) else { return false }
        return n.fields.contains { bitOn($0, values, wrote) }
    case .flagByte:
        return false
    case .int, .float, .bytes:
        return values[n.name] != nil
    }
}

func isTrue(_ v: Any?) -> Bool {
    guard let v, case .bool(true) = scalar(v) else { return false }
    return true
}

/// The first field under `n` that holds a value, at any depth; nil when none does.
func heldField(_ n: Node, _ values: [String: Any]) -> Node? {
    switch n.kind {
    case .bool:
        return isTrue(values[n.name]) ? n : nil
    case .flags, .when:
        return firstHeld(n.fields, values)
    case .flagBit:
        return n.member.flatMap { heldField($0, values) }
    case .flagByte:
        return nil
    case .int, .float, .bytes:
        return values[n.name] != nil ? n : nil
    }
}

private func firstHeld(_ nodes: [Node], _ values: [String: Any]) -> Node? {
    for n in nodes {
        if let held = heldField(n, values) { return held }
    }
    return nil
}

/// A split flag byte decides its bits where it is read. When the bit came out clear but the member
/// holds a value that a later look at what was written would write (its when condition now holds),
/// the value would be dropped: returns the field that holds it, else nil. A when whose condition is
/// false stays a silent skip.
func droppedBody(_ n: Node, _ values: [String: Any], _ wrote: [String: Any]) -> Node? {
    guard let held = heldField(n, values) else { return nil }
    return bitOn(n, values, wrote) ? held : nil
}

/// The bits of the flag byte `tag` among `nodes`, at any depth of the scope.
private func collectFlagBits(_ nodes: [Node], _ tag: FlagTag, into out: inout [(bit: Int, member: Node)]) {
    for n in nodes {
        switch n.kind {
        case .flagBit:
            guard let member = n.member else { continue }
            if n.tag === tag { out.append((n.bit, member)) }
            collectFlagBits([member], tag, into: &out)
        case .when:
            collectFlagBits(n.fields, tag, into: &out)
        case .int, .float, .bytes, .bool, .flags, .flagByte:
            break
        }
    }
}

/// The byte a split flag byte writes: a bit for each member that is on where the byte sits.
func flagValue(_ root: [Node], _ tag: FlagTag, _ values: [String: Any], _ wrote: [String: Any]) -> UInt8 {
    var bits: [(bit: Int, member: Node)] = []
    collectFlagBits(root, tag, into: &bits)
    var flags: UInt8 = 0
    for b in bits where bitOn(b.member, values, wrote) {
        flags |= UInt8(truncatingIfNeeded: 1 << b.bit)
    }
    return flags
}
