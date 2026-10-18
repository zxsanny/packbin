import Foundation
import Packbin
import Testing

/// One row of fixtures/text/vectors.txt: `kind id rest...` (row syntax at the top of that file).
struct TextRow: CustomTestStringConvertible, Sendable {
    let kind: String
    let id: String
    let rest: [String]
    var testDescription: String { id }

    /// The text of an `enc` or `alt` row: the hex of its UTF-8 bytes, "-" for the empty text.
    var textBytes: [UInt8] { rest[0] == "-" ? [] : bytes(rest[0]) }
    var text: String { String(decoding: textBytes, as: UTF8.self) }
    /// The field of an `enc` or `alt` row, the buffer of a `bad` row (after its kind), or the packet of a `ref` row.
    var field: [UInt8] {
        switch kind {
        case "enc", "alt": return bytes(rest[1])
        case "bad": return rest.count > 1 ? bytes(rest[1]) : []
        default: return bytes(rest[0])
        }
    }
}

/// Every row of fixtures/text/vectors.txt of one kind, in file order.
func textRows(_ kind: String) throws -> [TextRow] {
    try repositoryFile("fixtures/text/vectors.txt").split(separator: "\n", omittingEmptySubsequences: true).compactMap { line in
        guard !line.hasPrefix("#") else { return nil }
        let f = line.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        guard f.count >= 2, f[0] == kind else { return nil }
        return TextRow(kind: f[0], id: f[1], rest: Array(f.dropFirst(2)))
    }
}

/// The scheme of a lone string field `s` followed by a `u8` `t`, for the bytes after the string.
@Sendable func stringThenByte() throws -> Scheme { try Scheme(1, .utf8(0, "s"), .u8(1, "t")) }
@Sendable func loneString() throws -> Scheme { try Scheme(1, .utf8(0, "s")) }

/// The refusal an unpack of `packet` gives, or nil when it returns.
func unpackRefusal(_ packet: [UInt8], _ scheme: Scheme) -> PackbinError? {
    packbinError { try unpackMap(packet, scheme) }
}

/// The ring packets of the `ref` rows: the scheme and the row each id packs (ADR-001: written by hand from
/// the ring driver, `.github/workflows/drivers/handoff-swift/Sources/handoff-swift/Kinds.swift`).
func refCase(_ id: String) throws -> (scheme: Scheme, row: [String: Any])? {
    switch id {
    case "ref.user":
        return (try userScheme(), userRow())
    case "ref.user_ua":
        return (try userScheme(), ["username": "Олександр", "roles": ["диспетчер", "Оператор"],
                                   "access": ["карта": ["читати", "правити"], "канал": ["читати"]]])
    case "ref.nested":
        return (try nestedRingScheme(), ["access": ["map": [["op": "gps_fix"]], "store": [["op": "read"], ["op": "write"]]]])
    case "ref.nested_mixed":
        return (try nestedRingScheme(), ["access": ["Карта": [["op": "gps_fix", "note": "увага 48.46, 35.04"]],
                                                   "store": [["op": "ЧИТАТИ"]]]])
    default:
        return nil
    }
}

/// The UTF-8 bytes of a value that is a `String`, for comparing without Swift's canonical equivalence.
func utf8Of(_ v: Any?) -> [UInt8]? { (v as? String).map { Array($0.utf8) } }

/// Whether two row values are equal, strings compared as UTF-8 bytes (not as Swift's canonical equivalence).
func sameValue(_ a: Any, _ b: Any) -> Bool {
    if let x = a as? String, let y = b as? String { return Array(x.utf8) == Array(y.utf8) }
    if let x = a as? [Any], let y = b as? [Any] { return x.count == y.count && zip(x, y).allSatisfy { sameValue($0, $1) } }
    if let x = a as? [String: Any], let y = b as? [String: Any] {
        return x.count == y.count && x.allSatisfy { key, v in y[key].map { sameValue(v, $0) } ?? false }
    }
    return false
}
