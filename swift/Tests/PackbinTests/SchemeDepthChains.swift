import Packbin

/// A scheme nested `levels` deep of one container kind, with a row that fills it and the bytes the row packs
/// to (nil when the bytes are only compared with a pack of the unpacked row). Every chain is written by a
/// loop, innermost first, so the helper itself never recurses.
struct DepthChain {
    let fields: [Field]
    let row: [String: Any]
    let wire: String?

    func scheme() throws -> Scheme { try Scheme(1, fields) }
}

/// The container kinds of the contract scheme-depth that a chain can nest.
enum DepthKind: String, CaseIterable, Sendable {
    case when, group, anchoredGroup, flags, listRows, dictRows, listAfterU8, repeatWhen, timesWhen

    /// A chain of exactly `levels` containers on its path (the row and wire of the chain are for the levels
    /// that pack: 256).
    func chain(_ levels: Int) -> DepthChain {
        switch self {
        case .when:
            var inner: [Field] = [.u8(1, "b")]
            for _ in 0..<levels { inner = [.when(1, .eq(0, 1), inner)] }
            return DepthChain(fields: [.u8(0, "a")] + inner, row: ["a": 1, "b": 7], wire: "010107")
        case .group:
            var inner: [Field] = [.u8(0, "b")]
            var row: [String: Any] = ["b": 7]
            for _ in 0..<levels {
                inner = [.group("g", inner)]
                row = ["g": row]
            }
            return DepthChain(fields: inner, row: row, wire: "0107")
        case .anchoredGroup:
            var inner: [Field] = [.u8(0, "b")]
            var row: [String: Any] = ["b": 7]
            for level in 0..<levels {
                inner = [.group(0, "g\(level)", inner)]
                row = ["g\(level)": row]
            }
            return DepthChain(fields: inner, row: row, wire: "0107")
        case .flags:
            var inner: [Field] = [.u8(0, "c")]
            for _ in 0..<levels { inner = [.flags(0, inner)] }
            return DepthChain(fields: inner, row: ["c": 9], wire: "01" + String(repeating: "01", count: levels) + "09")
        case .listRows, .dictRows:
            return collectionRows(levels, dict: self == .dictRows)
        case .listAfterU8:
            return listOverU8(levels)
        case .repeatWhen:
            var inner: [Field] = [.u8(1, "v")]
            for _ in 0..<max(levels - 1, 0) { inner = [.when(1, .eq(0, 1), inner)] }
            return DepthChain(fields: [.repeat(0, [.u8(0, "k")] + inner)], row: ["k": [1], "v": [7]], wire: "010107")
        case .timesWhen:
            var inner: [Field] = [.u8(2, "v")]
            for _ in 0..<max(levels - 1, 0) { inner = [.when(2, .eq(1, 1), inner)] }
            return DepthChain(fields: [.u8(0, "a"), .times(1, count: 0, [.u8(1, "k")] + inner)],
                              row: ["a": 1, "k": [1], "v": [7]], wire: "01010107")
        }
    }

    /// List (or dict) of rows, a row holding the next list: each pair is two levels (the list and its element
    /// row), so `levels` is even when the chain packs. The innermost level is the row `{v: 7}`.
    private func collectionRows(_ levels: Int, dict: Bool) -> DepthChain {
        var inner: [Field] = [.u8(0, "v")]
        var row: [String: Any] = ["v": 7]
        var field = Field.group("e", inner)
        for level in 0..<levels {
            if level % 2 == 0 {
                field = .group("e", inner)
            } else if dict {
                field = .dict("m", inner[0])
                row = ["m": ["k": row]]
            } else {
                field = .list("xs", inner[0])
                row = ["xs": [row]]
            }
            inner = [field]
        }
        return DepthChain(fields: inner, row: row, wire: nil)
    }

    /// A list whose element is a plain u8 counts one level; groups and lists above it count one each.
    private func listOverU8(_ levels: Int) -> DepthChain {
        var field = Field.list("xs", .u8(0, "x"))
        var row: [String: Any] = ["xs": [1, 2]]
        for level in 1..<max(levels, 2) {
            if level % 2 == 1 {
                field = .group("e", [field])
            } else {
                field = .list("xs", field)
                row = ["xs": [row]]
            }
        }
        if levels % 2 == 0 { row = ["e": row] }
        return DepthChain(fields: [field], row: row, wire: nil)
    }
}
