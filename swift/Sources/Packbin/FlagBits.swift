/// Whether a flag bit's member holds a value at any depth. A bool or an empty group is a mark with no
/// bytes of its own, and only `true` sets its bit. A group with members is on when it is given (its
/// values are a map of their own, so a member can be given only with it), or when a member is on with
/// no value given (a times whose count is above 0). A when is on when its condition holds on what pack
/// has written so far (`wrote`) and its body holds a value; a flags member when any of its members is
/// on; a u2 when any slot has a value; a times when its count is above 0 (a count that was not written
/// is no round; a count of 0 refuses a list of values); a repeat when a round holds a value. A member
/// that is on and cannot be written in full fails when it is packed.
func bitOn(_ n: Node, _ values: [String: Any], _ wrote: [String: Any]) throws -> Bool {
    switch n.kind {
    case .bool:
        return isTrue(values[n.name])
    case .group:
        if n.fields.isEmpty { return isTrue(values[n.name]) }
        if values[n.name] != nil { return true }
        return try anyOn(n.fields, [:], wrote)
    case .flags, .u2:
        return try anyOn(n.fields, values, wrote)
    case .flagBit:
        guard let member = n.member else { return false }
        return try bitOn(member, values, wrote)
    case .when:
        guard let condition = n.condition, sameValue(wrote[n.ref], condition.value) else { return false }
        return try anyOn(n.fields, values, wrote)
    case .timesRound:
        guard wrote[n.ref] != nil, let shape = n.shape else { return false }
        let count = try borrowedCount(n, wrote)
        if count == 0 {
            try refuseLongLists(shape, values, 0)
            try refuseLoneBuffers(shape, values)
        }
        return count > 0
    case .repeatRound:
        return n.shape.map { roundCount($0, values) > 0 } ?? false
    case .flagByte:
        return false
    case .int, .float, .bytes, .sized, .slot, .bits, .packed:
        return values[n.name] != nil
    }
}

private func anyOn(_ nodes: [Node], _ values: [String: Any], _ wrote: [String: Any]) throws -> Bool {
    for n in nodes where try bitOn(n, values, wrote) { return true }
    return false
}

func isTrue(_ v: Any?) -> Bool {
    guard let v, case .bool(true) = scalar(v) else { return false }
    return true
}

/// The first field under `n` that holds a value, at any depth; nil when none does. A round holds one
/// when it has a round, or a lone buffer that would reach every round.
func heldField(_ n: Node, _ values: [String: Any]) -> Node? {
    switch n.kind {
    case .bool:
        return isTrue(values[n.name]) ? n : nil
    case .group:
        guard let v = values[n.name] else { return nil }
        return !n.fields.isEmpty || isTrue(v) ? n : nil
    case .flags, .when, .u2:
        return firstHeld(n.fields, values)
    case .repeatRound, .timesRound:
        guard let shape = n.shape else { return nil }
        let lone = shape.buffers.contains { values[$0.name] != nil }
        return roundCount(shape, values) > 0 || lone ? firstHeld(n.fields, values) : nil
    case .flagBit:
        return n.member.flatMap { heldField($0, values) }
    case .flagByte:
        return nil
    case .int, .float, .bytes, .sized, .slot, .bits, .packed:
        return values[n.name] != nil ? n : nil
    }
}

private func firstHeld(_ nodes: [Node], _ values: [String: Any]) -> Node? {
    for n in nodes {
        if let held = heldField(n, values) { return held }
    }
    return nil
}

/// Whether a times in the scope of `n` (itself, or under groups, flags, flag bits and a when whose
/// condition holds) holds a value although its count was never written.
private func countNeverWritten(_ n: Node, _ values: [String: Any], _ wrote: [String: Any]) -> Bool {
    switch n.kind {
    case .timesRound:
        return wrote[n.ref] == nil && heldField(n, values) != nil
    case .when:
        guard let condition = n.condition, sameValue(wrote[n.ref], condition.value) else { return false }
        return n.fields.contains { countNeverWritten($0, values, wrote) }
    case .group:
        let inner = groupValues(values, n)
        return n.fields.contains { countNeverWritten($0, inner, wrote) }
    case .flags, .flagBit:
        return n.fields.contains { countNeverWritten($0, values, wrote) }
    case .int, .float, .bytes, .bool, .flagByte, .repeatRound, .sized, .u2, .slot, .bits, .packed:
        return false
    }
}

/// A flag byte decides a bit as it stands (a split byte where it is read). When the bit came out clear
/// but the member holds a value that a later look at what was written would write (its when condition
/// now holds, its times count is now known), or that waits for a count no field ever wrote, the value
/// would be dropped: returns the field that holds it, else nil. A when whose condition is false stays
/// a silent skip.
func droppedBody(_ n: Node, _ values: [String: Any], _ wrote: [String: Any]) throws -> Node? {
    guard let held = heldField(n, values) else { return nil }
    return try bitOn(n, values, wrote) || countNeverWritten(n, values, wrote) ? held : nil
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
        case .int, .float, .bytes, .bool, .flags, .flagByte, .repeatRound, .timesRound, .sized, .u2, .slot, .bits,
             .packed:
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
func flagValue(_ root: FlagRoot, _ tag: FlagTag, _ wrote: [String: Any]) throws -> UInt8 {
    var bits: [FlagBitRef] = []
    collectFlagBits(root.fields, tag, root.values, into: &bits)
    var flags: UInt8 = 0
    for b in bits where try bitOn(b.member, b.values, wrote) {
        flags |= UInt8(truncatingIfNeeded: 1 << b.bit)
    }
    return flags
}
