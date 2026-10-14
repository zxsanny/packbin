/// The values of a round's names in a map row and in a typed row, and the typed rows unpack makes of
/// the rounds it read.

/// Turns the value of each name of a round into a ``RoundList`` when it is an array, and checks its
/// entries (or the one value that goes to every round) for the round's bools, empty groups and groups.
func roundValues(_ shape: RoundShape, _ values: inout [String: Any]) throws {
    for n in shape.names {
        guard let v = values[n.name], let entries = roundEntries(v) else { continue }
        values[n.name] = RoundList(entries: entries, typed: false)
    }
    for mark in shape.place.marks {
        try eachEntry(&values, mark.name) { try checkedMark(mark, $0) }
    }
    for group in shape.place.rows {
        try eachEntry(&values, group.node.name) { try nestedRow(group, $0) }
    }
}

/// Applies `check` to every present entry of the list under `name`, or to its one value.
private func eachEntry(_ values: inout [String: Any], _ name: String, _ check: (Any) throws -> Any) throws {
    guard let v = values[name] else { return }
    guard let list = v as? RoundList else {
        values[name] = try check(v)
        return
    }
    var entries = list.entries
    for i in entries.indices {
        if let entry = entries[i] { entries[i] = try check(entry) }
    }
    values[name] = RoundList(entries: entries, typed: list.typed)
}

/// An array of a ``PackbinRow``, the member a typed repeat or times is bound to: one element a round.
protocol RoundRowArray {
    var rowElements: [Any] { get }
    static var rowType: Any.Type { get }
    static func makeRows(_ rows: [Any]) -> Any
}

extension Array: RoundRowArray where Element: PackbinRow {
    var rowElements: [Any] { map { $0 as Any } }
    static var rowType: Any.Type { Element.self }
    static func makeRows(_ rows: [Any]) -> Any { rows.compactMap { $0 as? Element } }
}

/// The member type `t` (read through one optional) as an array that holds the rounds of a repeat or
/// times, or nil when it is no array of a ``PackbinRow``.
func roundRows(_ t: Any.Type) -> RoundRowArray.Type? {
    ((t as? OptionalMember.Type)?.wrappedType ?? t) as? RoundRowArray.Type
}

/// A typed round's names as lists: one entry for each element of the bound array, so a times can
/// check its count against the rounds the row holds. A `nil` array is no value and an empty one 0
/// rounds; both give every name an empty list.
func typedRoundValues(_ m: Place.Member, _ box: AnyObject, _ values: inout [String: Any]) {
    guard let shape = m.node.shape, let inner = m.inner, let acc = m.node.accessor else { return }
    var rows: [[String: Any]?] = []
    if let v = acc.get(box), let elements = (v as? RoundRowArray)?.rowElements {
        rows = elements.map { element in inner.binding?.boxRow(element).map { typedValues(inner, $0) } }
    }
    for n in shape.names {
        values[n.name] = RoundList(entries: rows.map { $0?[n.name] ?? nil }, typed: true)
    }
}

/// Stores one element of the round's array for each round unpack read.
func fillRounds(_ m: Place.Member, _ box: AnyObject, _ values: [String: Any], _ reached: Set<ObjectIdentifier>) {
    guard let shape = m.node.shape, let inner = m.inner, let acc = m.node.accessor, let binding = inner.binding,
          let make = acc.makeRounds else { return }
    var lists: [(String, [Any?])] = []
    var count = 0
    for n in shape.names {
        guard let list = values[n.name] as? [Any?] else { continue }
        lists.append((n.name, list))
        count = max(count, list.count)
    }
    if count == 0 && !reached.contains(ObjectIdentifier(m.node)) { return }
    var rows: [Any] = []
    for i in 0..<count {
        var element: [String: Any] = [:]
        for (name, list) in lists where i < list.count {
            if let entry = list[i] { element[name] = entry }
        }
        let child = binding.makeBox()
        fillRow(inner, child, element, reached)
        rows.append(binding.unbox(child))
    }
    acc.set(box, make(rows))
}
