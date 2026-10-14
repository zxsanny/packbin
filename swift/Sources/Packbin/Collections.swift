/// Strings, lists, dicts and nested rows, and the construction checks that belong to them.
extension Field {
    /// A string: a u16 byte count (at most 65 535), then its UTF-8 bytes. Its value is a `String`;
    /// unpack refuses bytes that are not valid UTF-8 (a short packet with `needed` 0).
    public static func utf8(_ id: Int, _ name: String) -> Field { Field(Node(.utf8, id: id, name: name)) }

    /// A u16 item count (at most 65 535), then the items. The element is one field, a scope of its own
    /// with ids from 0: an integer, a float, fixed bytes, `utf8`, another list or dict, a group without
    /// an anchor, or `flags` (whose item is then a row, as a group's). An element with no name of its
    /// own is named by the list in refusals. A list has no id. In a map row the value is any array but
    /// a `[UInt8]` (a byte run, never a list), a group or flags item a `[String: Any]`; unpack gives an
    /// `[Any]`. In a typed row it is bound to an array (`[UInt8]` too) of the element's Swift type.
    public static func list(_ name: String, _ element: Field) -> Field {
        collection(.list, name, element, refusal: "list element must be one field")
    }

    /// A u16 pair count (at most 65 535), then the pairs: a key (as `utf8`) and an element as for
    /// `list`. Keys are written in unsigned UTF-8 byte order, so a dictionary packs to the same bytes
    /// whatever its order; a key is never a member of the row. In a map row the value is any
    /// dictionary with `String` keys; unpack gives a `[String: Any]` and refuses a packet whose keys are
    /// equal as Swift strings (also when their bytes differ, as NFC and NFD forms do: "dict key given
    /// twice"). In a typed row it is bound to a `[String: E]`.
    public static func dict(_ name: String, _ element: Field) -> Field {
        collection(.dict, name, element, refusal: "repeat is not a dictionary element")
    }

    /// A nested row under `name`: its members are numbered from 0 and have references and names of
    /// their own, so they may repeat a name of the row around it, and it takes no id of that row. In a
    /// map row it is a `[String: Any]` under `name`, both ways; a typed row binds it to a member whose
    /// type is a ``PackbinRow``. Under `flags` or a flag bit its bit is set when it is given; with no
    /// members it is a mark, as `bool`. It is also the element of a list or dict.
    public static func group(_ name: String, _ members: Field...) -> Field { group(name, members) }

    /// `group(_:_:)` with its members as an array.
    public static func group(_ name: String, _ members: [Field]) -> Field {
        Field(Node(.group, id: nil, name: name, fields: members.map(\.node), nested: true))
    }

    private static func collection(_ kind: NodeKind, _ name: String, _ element: Field, refusal: String) -> Field {
        var e = element.node
        if e.kind == .flags {
            // A flags element is a flag byte and its bits, not one field: it is held as a nested row of
            // its own, so an item is one row.
            e = Node(.group, id: nil, fields: [e], nested: true)
        } else if e.name.isEmpty && [.int, .float, .bytes, .utf8].contains(e.kind) {
            e = e.with(name: name)
        }
        let error = e.kind == .repeatRound ? refusal : nil
        return Field(Node(kind, id: nil, name: name, fields: [e], error: error))
    }
}

/// The fields of an element's scope: a nested row's members, else the element itself.
func elementScope(_ e: Node) -> [Node] { e.kind == .group && e.nested ? e.fields : [e] }

/// The place of the nested row a chain of lists and dicts ends in; nil when it ends in a scalar.
func leafPlace(_ n: Node) -> Place? {
    var cur = n
    while let e = cur.element {
        if e.kind == .group { return cur.rowPlace }
        guard e.isCollection else { return nil }
        cur = e
    }
    return nil
}

/// Refuses an element a list or dict cannot hold, at any depth, as TypeScript's last check: an
/// anchored group (its members would read the row around it), and a kind that is no value of its own
/// (a `u2`, a flag byte; TypeScript builds these, Go refuses them, loop 25 D2 A). An element is bound
/// through its list or dict, never on its own.
func checkElements(_ nodes: [Node]) throws {
    for n in nodes {
        if let e = n.element {
            try checkElementKind(n, e)
        }
        try checkElements(n.fields)
    }
}

private func checkElementKind(_ c: Node, _ e: Node) throws {
    switch e.kind {
    case .int, .float, .bytes, .utf8, .list, .dict:
        break
    case .group where e.nested:
        break
    case .group:
        throw PackbinError.scheme(nil, c.name,
            "\(c.label) \(c.name): element is an anchored group (\(e.name)); use a group without an anchor")
    default:
        throw PackbinError.scheme(nil, c.name, "\(c.label) \(c.name): a \(e.label) cannot be an element; use an "
            + "integer, float, bytes, utf8, list, dict, flags or a group without an anchor")
    }
    if e.accessor != nil {
        throw PackbinError.scheme(nil, c.name, "\(c.label) \(c.name): the element is bound; bind the \(c.label) "
            + "to an array or dictionary of the element's type instead")
    }
}
