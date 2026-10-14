/// Whether a flag bit's member holds a value at any depth. A bool or an empty group is a mark with no
/// bytes of its own, and only `true` sets its bit. A group with members is on when it is given (its
/// values are a map of their own, so a member can be given only with it). A when is on when its
/// condition holds on what pack has written so far (`wrote`) and its body holds a value; a flags
/// member when any of its members is on. A member that is on and cannot be written in full fails when
/// it is packed.
func bitOn(_ n: Node, _ values: [String: Any], _ wrote: [String: Any]) -> Bool {
    switch n.kind {
    case .bool:
        return isTrue(values[n.name])
    case .group:
        if n.fields.isEmpty { return isTrue(values[n.name]) }
        return values[n.name] != nil
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
    case .group:
        guard let v = values[n.name] else { return nil }
        return !n.fields.isEmpty || isTrue(v) ? n : nil
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

/// The map a group's members read: its value in `values`, empty when the group is not given.
func groupValues(_ values: [String: Any], _ group: Node) -> [String: Any] {
    values[group.name] as? [String: Any] ?? [:]
}

/// One bit of a split flag byte: its member, and the values of the row the member reads (inside a
/// group, the group's own values).
private struct FlagBitRef {
    let bit: Int
    let member: Node
    let values: [String: Any]
}

/// The bits of the flag byte `tag` among `nodes`, at any depth of the scope.
private func collectFlagBits(_ nodes: [Node], _ tag: FlagTag, _ values: [String: Any], into out: inout [FlagBitRef]) {
    for n in nodes {
        switch n.kind {
        case .flagBit:
            guard let member = n.member else { continue }
            if n.tag === tag { out.append(FlagBitRef(bit: n.bit, member: member, values: values)) }
            collectFlagBits([member], tag, values, into: &out)
        case .when:
            collectFlagBits(n.fields, tag, values, into: &out)
        case .group:
            collectFlagBits(n.fields, tag, groupValues(values, n), into: &out)
        case .int, .float, .bytes, .bool, .flags, .flagByte:
            break
        }
    }
}

/// The fields a split flag byte looks for its bits in, with the values of their row: the top level, or
/// a flags member and the values around it.
struct FlagRoot {
    let fields: [Node]
    let values: [String: Any]
}

/// The byte a split flag byte writes: a bit for each member that is on where the byte sits.
func flagValue(_ root: FlagRoot, _ tag: FlagTag, _ wrote: [String: Any]) -> UInt8 {
    var bits: [FlagBitRef] = []
    collectFlagBits(root.fields, tag, root.values, into: &bits)
    var flags: UInt8 = 0
    for b in bits where bitOn(b.member, b.values, wrote) {
        flags |= UInt8(truncatingIfNeeded: 1 << b.bit)
    }
    return flags
}
