/// The round and counted kinds: `repeat`, `times`, `sized`, `u2` slots, `bits` and `packed`, and the
/// construction checks that belong to them.
extension Field {
    /// Its members once a round until the buffer ends; there is no count, so nothing may follow it.
    /// The anchor is the next id and is not written. In a map row each name a round holds takes one
    /// array, entry i for round i (`nil` where the round leaves the name out; a value that is not an
    /// array goes to every round, and a `[UInt8]` is a byte run, not an array of rounds); a group in a
    /// round takes one `[String: Any]` a round. Bound with `bind(get:set:)` it takes an array of a
    /// ``PackbinRow``, one element a round. Unpack gives each name one entry a round, `nil` where the
    /// round skipped it. The body is a scope of its own.
    public static func `repeat`(_ anchor: Int, _ members: Field...) -> Field { `repeat`(anchor, members) }

    /// `repeat` with its members as an array.
    public static func `repeat`(_ anchor: Int, _ members: [Field]) -> Field {
        Field(Node(.repeatRound, id: anchor, fields: members.map(\.node)))
    }

    /// Its members exactly `count` times, `count` being the value of the integer field `countID`
    /// written earlier in the same scope; the next field follows. The rounds are given as for
    /// `repeat`. The anchor is the next id and is not written.
    public static func times(_ anchor: Int, count countID: Int, _ members: Field...) -> Field {
        times(anchor, count: countID, members)
    }

    /// `times` with its members as an array.
    public static func times(_ anchor: Int, count countID: Int, _ members: [Field]) -> Field {
        Field(Node(.timesRound, id: anchor, fields: members.map(\.node), countID: countID))
    }

    /// Raw bytes whose length is the integer field `countID`, written earlier in the same scope; no
    /// length of its own. Its value is a `[UInt8]`.
    public static func sized(_ id: Int, _ name: String, count countID: Int) -> Field {
        Field(Node(.sized, id: id, name: name, countID: countID))
    }

    /// Its slots two bits each, four to a byte, low bits first; unused bits are 0.
    public static func u2(_ slots: Field...) -> Field { u2(slots) }

    /// `u2` with its slots as an array.
    public static func u2(_ slots: [Field]) -> Field {
        let nodes = slots.map(\.node)
        var error: String?
        if nodes.isEmpty {
            error = "u2 needs at least one slot"
        } else if let other = nodes.first(where: { $0.kind != .slot }) {
            error = "u2 takes slot fields, not \(other.label)"
        }
        return Field(Node(.u2, id: nodes.first?.id, name: nodes.first?.name ?? "", fields: nodes, error: error))
    }

    /// One 2-bit value (0...3) of `u2`; it stands only directly in `u2`. Unpack gives it as a `UInt8`.
    public static func slot(_ id: Int, _ name: String) -> Field { Field(Node(.slot, id: id, name: name)) }

    /// A list of 0 and 1, one bit an item, low bits first; the item count is the integer field
    /// `countID`, written earlier in the same scope. Its value is an array of integers (a `[UInt8]`
    /// too); unpack gives a `[UInt8]`.
    public static func bits(_ id: Int, _ name: String, count countID: Int) -> Field {
        Field(Node(.bits, id: id, name: name, size: 1, countID: countID))
    }

    /// A list of small integers, `width` (1 or 2) bits an item, low bits first; the item count is the
    /// integer field `countID` plus `bias` (0 or -1). Its value is an array of integers; unpack gives a
    /// `[UInt8]`.
    public static func packed(_ width: Int, _ id: Int, _ name: String, count countID: Int, bias: Int = 0) -> Field {
        var error: String?
        if width != 1 && width != 2 {
            error = "packed width must be 1 or 2"
        } else if bias != 0 && bias != -1 {
            error = "packed bias must be 0 or -1"
        }
        return Field(Node(.packed, id: id, name: name, size: width, countID: countID, bias: bias, error: error))
    }
}

/// A slot stands only directly in `u2`: anywhere else it has no byte to live in.
func checkSlots(_ nodes: [Node], inU2: Bool) throws {
    for n in nodes {
        if n.kind == .slot && !inU2 {
            throw PackbinError.scheme(n.id, n.name, "slot \(n.name): allowed only directly inside u2")
        }
        try checkSlots(n.fields, inU2: n.kind == .u2)
    }
}

/// A round packs entry i of each list, so a repeat or times inside it would read every inner round
/// from the same entry. Refused wherever it sits in the round: directly, or under when, flags, flag
/// bits and groups.
func checkRoundNesting(_ nodes: [Node], inRound: Bool) throws {
    for n in nodes {
        switch n.kind {
        case .repeatRound, .timesRound:
            if inRound {
                throw PackbinError.scheme(n.id, "", "\(n.label) \(n.id ?? -1) is inside a repeat or times round; "
                    + "a round cannot hold another repeat or times")
            }
            try checkRoundNesting(n.fields, inRound: true)
        case .when, .flags, .group, .flagBit:
            try checkRoundNesting(n.fields, inRound: inRound)
        case .list, .dict:
            // A list or dict element is a row of its own and starts outside any round.
            try checkRoundNesting(n.fields, inRound: false)
        case .int, .float, .bytes, .bool, .flagByte, .sized, .u2, .slot, .bits, .packed, .utf8:
            break
        }
    }
}

/// A round of a body with no member writes no byte, so a large count would loop for no output.
/// Refused wherever the repeat or times stands. A member is any field but a when or group that holds
/// none; a flag byte, a flags with no member and a zero-width bytes are members.
func checkRoundBodies(_ nodes: [Node]) throws {
    for n in nodes {
        switch n.kind {
        case .repeatRound, .timesRound:
            if !holdsMember(n.fields) {
                throw PackbinError.scheme(n.id, "", "\(n.label) \(n.id ?? -1): the body holds no member; "
                    + "a round of it would charge no slot and write nothing")
            }
            try checkRoundBodies(n.fields)
        case .when, .flags, .group, .flagBit, .list, .dict:
            try checkRoundBodies(n.fields)
        case .int, .float, .bytes, .bool, .flagByte, .sized, .u2, .slot, .bits, .packed, .utf8:
            break
        }
    }
}

private func holdsMember(_ nodes: [Node]) -> Bool {
    nodes.contains { n in
        switch n.kind {
        case .when, .group, .repeatRound, .timesRound, .flagBit:
            return holdsMember(n.fields)
        case .int, .float, .bytes, .bool, .flags, .flagByte, .sized, .u2, .slot, .bits, .packed, .utf8, .list, .dict:
            return true
        }
    }
}
