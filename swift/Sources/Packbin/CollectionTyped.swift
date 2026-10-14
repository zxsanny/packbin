/// A list or dict member of a typed row is an array `[E]` or a dictionary `[String: E]` (or an optional
/// of one), E being the element's Swift type: an integer, float, `[UInt8]` or `String` type for a
/// scalar element, a ``PackbinRow`` for a nested-row or flags element, or another array or dictionary.
/// These turn one into the `[Any?]` or `[String: Any]` the walker packs, and an unpacked one back.

/// An array a typed list member is bound to.
protocol ListMember {
    static var itemType: Any.Type { get }
    var listItems: [Any] { get }
    /// The array of `items`, each already a value of the item type; nil when one is not.
    static func makeList(_ items: [Any]) -> Any?
}

extension Array: ListMember {
    static var itemType: Any.Type { Element.self }
    var listItems: [Any] { map { $0 as Any } }
    static func makeList(_ items: [Any]) -> Any? {
        var out: [Element] = []
        out.reserveCapacity(items.count)
        for item in items {
            guard let e = item as? Element else { return nil }
            out.append(e)
        }
        return out
    }
}

/// A dictionary with `String` keys a typed dict member is bound to.
protocol DictMember {
    static var valueType: Any.Type { get }
    var dictItems: [(String, Any)] { get }
    /// The dictionary of `entries`, each already a value of the value type; nil when one is not.
    static func makeDict(_ entries: [String: Any]) -> Any?
}

extension Dictionary: DictMember where Key == String {
    static var valueType: Any.Type { Value.self }
    var dictItems: [(String, Any)] { map { ($0.key, $0.value as Any) } }
    static func makeDict(_ entries: [String: Any]) -> Any? {
        var out: [String: Value] = [:]
        out.reserveCapacity(entries.count)
        for (key, item) in entries {
            guard let e = item as? Value else { return nil }
            out[key] = e
        }
        return out
    }
}

/// A member type read through one optional.
func baseType(_ t: Any.Type) -> Any.Type { (t as? OptionalMember.Type)?.wrappedType ?? t }

/// Why a member of type `t` cannot hold every value of the list or dict `n`, or nil.
func collectionRefusal(_ n: Node, _ t: Any.Type) -> String? {
    let base = baseType(t)
    guard let e = n.element else { return nil }
    if n.kind == .list {
        guard let list = base as? ListMember.Type else {
            return "a \(String(describing: t)) member cannot hold list \(n.name); bind an array"
        }
        return elementRefusal(e, list.itemType)
    }
    guard let dict = base as? DictMember.Type else {
        return "a \(String(describing: t)) member cannot hold dict \(n.name); bind a [String: E]"
    }
    return elementRefusal(e, dict.valueType)
}

private func elementRefusal(_ e: Node, _ t: Any.Type) -> String? {
    switch e.kind {
    case .group:
        return childType(t) == nil ? "a \(String(describing: t)) item cannot hold a nested row; bind a PackbinRow" : nil
    case .list, .dict:
        return collectionRefusal(e, t)
    default:
        return memberRefusal(e, memberBase(t), String(describing: t))
    }
}

/// The row type of the nested row a chain of lists and dicts in a member of type `t` ends in; nil when
/// it ends in a scalar.
func leafChild(_ n: Node, _ t: Any.Type) -> ChildType? {
    var node = n
    var type = t
    while let e = node.element {
        let base = baseType(type)
        guard let next = (base as? ListMember.Type)?.itemType ?? (base as? DictMember.Type)?.valueType else { return nil }
        if e.kind == .group { return childType(next) }
        guard e.isCollection else { return nil }
        node = e
        type = next
    }
    return nil
}

/// A typed list or dict value as the walker packs it: an `[Any?]` or `[String: Any]` of items, a
/// nested-row item as a ``WalkedRow`` of the values its getters give. A `nil` item stays no value.
func walkedCollection(_ n: Node, _ v: Any) -> Any? {
    guard let e = n.element else { return nil }
    if n.kind == .list {
        guard let list = v as? ListMember else { return nil }
        return list.listItems.map { walkedItem(n, e, $0) } as [Any?]
    }
    guard let dict = v as? DictMember else { return nil }
    var out: [String: Any] = [:]
    for (key, item) in dict.dictItems { out[key] = walkedItem(n, e, item) as Any }
    return out
}

private func walkedItem(_ n: Node, _ e: Node, _ item: Any) -> Any? {
    guard let v = unboxed(item) else { return nil }
    switch e.kind {
    case .group:
        guard let place = n.rowPlace, let box = place.binding?.boxRow(v) else { return v }
        return WalkedRow(values: typedValues(place, box))
    case .list, .dict:
        return walkedCollection(e, v)
    default:
        return v
    }
}

/// The value of type `t` (a member's type) that holds what unpack read for the list or dict `n`; nil
/// when it cannot be made (construction has made sure it can).
func typedCollection(_ n: Node, _ v: Any, _ t: Any.Type) -> Any? {
    let base = baseType(t)
    guard let e = n.element else { return nil }
    if n.kind == .list {
        guard let type = base as? ListMember.Type, let items = v as? [Any] else { return nil }
        var out: [Any] = []
        out.reserveCapacity(items.count)
        for item in items {
            guard let x = typedItem(n, e, item, type.itemType) else { return nil }
            out.append(x)
        }
        return type.makeList(out)
    }
    guard let type = base as? DictMember.Type, let entries = v as? [String: Any] else { return nil }
    var out: [String: Any] = [:]
    out.reserveCapacity(entries.count)
    for (key, item) in entries {
        guard let x = typedItem(n, e, item, type.valueType) else { return nil }
        out[key] = x
    }
    return type.makeDict(out)
}

private func typedItem(_ n: Node, _ e: Node, _ v: Any, _ t: Any.Type) -> Any? {
    switch e.kind {
    case .group:
        guard let place = n.rowPlace, let binding = place.binding else { return nil }
        let box = binding.makeBox()
        if let item = v as? ElementItem {
            fillRow(place, box, item.values, item.reached)
        } else if let values = v as? [String: Any] {
            fillRow(place, box, values, [])
        }
        return binding.unbox(box)
    case .list, .dict:
        return typedCollection(e, v, t)
    default:
        return typedScalar(v, t)
    }
}

/// An unpacked scalar as a value of the item type `t`: as it is, or widened to its integer or float
/// type.
private func typedScalar(_ v: Any, _ t: Any.Type) -> Any? {
    if ObjectIdentifier(type(of: v)) == ObjectIdentifier(baseType(t)) { return v }
    switch (memberBase(t), scalar(v)) {
    case let (.int(type)?, .int(num)):
        return type.make(num)
    case let (.float(64)?, .float(x)):
        return x
    default:
        return v
    }
}
