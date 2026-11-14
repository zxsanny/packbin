/// The construction checks that look at the fields only, in TypeScript's order: a constructor's
/// refusal, the ids, the presence marks and the member names.

/// The deepest nesting a scheme may have (the contract scheme-depth): 256 containers on one path.
let maxSchemeDepth = 256

/// Refuses a scheme nested deeper than `maxSchemeDepth` containers, before any walk that recurses. A
/// `when`, `flags`, group, `repeat`, `times`, `list` and `dict` each count one level; a flag bit, a flag
/// byte and a u2 count none. It uses an explicit stack, so a scheme of any depth costs no call stack, and
/// it stops at the first path over the limit, so the stack holds at most the limit times the widest row. A node
/// that two parents share (the same `Field` used twice) is measured again only when it is reached deeper than
/// before, so a scheme that uses one field twice per level costs its size, not 2^depth steps.
func checkDepth(_ nodes: [Node]) throws {
    var pending: [(node: Node, depth: Int)] = nodes.reversed().map { ($0, 0) }
    var deepest: [ObjectIdentifier: Int] = [:]
    while let (node, above) = pending.popLast() {
        if let seen = deepest[ObjectIdentifier(node)], seen >= above { continue }
        deepest[ObjectIdentifier(node)] = above
        var depth = above
        switch node.kind {
        case .flags, .when, .group, .repeatRound, .timesRound, .list, .dict:
            depth += 1
            if depth > maxSchemeDepth {
                throw PackbinError.scheme(nil, "", "scheme nested too deep: more than \(maxSchemeDepth) levels; "
                    + "the limit is \(maxSchemeDepth)")
            }
        case .int, .float, .bytes, .bool, .flagByte, .flagBit, .sized, .u2, .slot, .bits, .packed, .utf8:
            break
        }
        for child in node.fields.reversed() { pending.append((child, depth)) }
    }
}

/// Reports a constructor's refusal at any depth. A node already looked at is not looked at again (it had no
/// refusal, or this would have thrown), so a node that two parents share costs one visit.
func checkNodes(_ nodes: [Node]) throws {
    var seen = Set<ObjectIdentifier>()
    try checkNodes(nodes, seen: &seen)
}

private func checkNodes(_ nodes: [Node], seen: inout Set<ObjectIdentifier>) throws {
    for n in nodes {
        guard seen.insert(ObjectIdentifier(n)).inserted else { continue }
        if let error = n.error {
            let at = n.kind == .flags && n.fields.count > flagBits ? n.fields[flagBits] : n
            throw PackbinError.scheme(at.errorID, at.declaredName, error)
        }
        try checkNodes(n.fields, seen: &seen)
    }
}

/// Every value id and anchor is the next id, from `next` on: a gap, a repeated id or a negative id is
/// refused, naming the id. An anchor takes no id of its own; an empty group's anchor is the next id
/// and the field after it takes the same id.
func checkFieldIDs(_ nodes: [Node], next: Int) throws -> Int {
    var next = next
    for n in nodes {
        switch n.kind {
        case .int, .float, .bytes, .bool, .sized, .slot, .bits, .packed, .utf8:
            try expectID(n, next)
            next += 1
        case .flagBit, .u2:
            next = try checkFieldIDs(n.fields, next: next)
        case .list, .dict:
            // An element numbers its fields from 0 in a scope of its own; a list or dict takes no id.
            _ = try checkFieldIDs(n.fields, next: 0)
        case .group where n.nested:
            // A nested row numbers its members from 0 and takes no id of the row around it.
            _ = try checkFieldIDs(n.fields, next: 0)
        case .flags, .when, .group, .repeatRound, .timesRound:
            try expectID(n, next)
            next = try checkFieldIDs(n.fields, next: next)
        case .flagByte:
            break
        }
    }
    return next
}

private func expectID(_ n: Node, _ next: Int) throws {
    guard let id = n.id, id == next else {
        throw PackbinError.scheme(n.id, n.name, "field id: expected \(next), got \(n.id.map { String($0) } ?? "none")")
    }
}

/// A bool or an empty group is a presence mark: it has no bytes, only a flag bit. It stands only as
/// the member of a flag bit or a direct member of `flags`; anywhere else (the top level, a group, a
/// when) it would always read as true.
func checkPresenceMarks(_ nodes: [Node], onFlagBit: Bool) throws {
    for n in nodes {
        if n.isMark && !onFlagBit {
            let mark = n.kind == .bool ? "bool" : "empty group"
            throw PackbinError.scheme(n.id, n.name,
                "\(mark) \(n.name): allowed only directly inside flags or a flag bit; move it into flags")
        }
        switch n.kind {
        case .flagBit, .flags:
            try checkPresenceMarks(n.fields, onFlagBit: true)
        case .group, .when, .repeatRound, .timesRound, .list, .dict:
            try checkPresenceMarks(n.fields, onFlagBit: false)
        case .int, .float, .bytes, .bool, .flagByte, .sized, .u2, .slot, .bits, .packed, .utf8:
            break
        }
    }
}

/// A row holds one value per name. An anchored group, `when`, `flags`, a flag bit, `u2`, `repeat` and
/// `times` share the place around them, and a group's own name belongs to that place too, so a name declared twice there is
/// refused, unless all but one of its declarations sit under a `when` (the branches of a chain may
/// share a member).
func checkMemberNames(_ nodes: [Node]) throws {
    var always: [String: Bool] = [:]

    func declare(_ n: Node, _ conditional: Bool) throws {
        guard let first = always[n.name] else {
            always[n.name] = !conditional
            return
        }
        if conditional { return }
        if first {
            throw PackbinError.scheme(n.id, n.name,
                "member \(n.name): declared twice in one scope; a row holds one value per name, so one would be lost")
        }
        always[n.name] = true
    }

    func walk(_ nodes: [Node], _ conditional: Bool) throws {
        for n in nodes {
            switch n.kind {
            case .int, .float, .bytes, .bool, .sized, .slot, .bits, .packed, .utf8:
                try declare(n, conditional)
            case .list, .dict:
                // An element is a row of its own, with the same rules.
                try declare(n, conditional)
                if let e = n.element { try checkMemberNames(elementScope(e)) }
            case .group where n.nested:
                // A nested row names its members in a scope of its own (as Go and C#).
                try declare(n, conditional)
                try checkMemberNames(n.fields)
            case .group:
                try declare(n, conditional)
                try walk(n.fields, conditional)
            case .when:
                try walk(n.fields, true)
            case .flags, .flagBit, .u2, .repeatRound, .timesRound:
                try walk(n.fields, conditional)
            case .flagByte:
                break
            }
        }
    }

    try walk(nodes, false)
}
