import Packbin
import Testing

/// A value as the round tests compare it: each integer with its Swift type, a `[UInt8]` as hex, an
/// array of rounds entry by entry (`nil` for a skipped round) and a map by its sorted keys.
func canon(_ v: Any?) -> String {
    guard let v else { return "nil" }
    if type(of: v) == [UInt8].self, let raw = v as? [UInt8] { return "0x" + hex(raw) }
    if let map = v as? [String: Any] {
        return "{" + map.keys.sorted().map { "\($0)=\(canon(map[$0]))" }.joined(separator: ",") + "}"
    }
    if let list = v as? [Any?] { return "[" + list.map { canon($0.flatMap(flattened)) }.joined(separator: ",") + "]" }
    return "\(type(of: v))(\(v))"
}

private func flattened(_ v: Any) -> Any? {
    if let optional = v as? OptionalBox { return optional.unwrapped }
    return v
}

private protocol OptionalBox { var unwrapped: Any? { get } }
extension Optional: OptionalBox {
    fileprivate var unwrapped: Any? { flatMap { $0 } }
}

/// One map row that packs to `wire` (TypeScript's hex at HEAD).
struct PackRow: CustomTestStringConvertible, Sendable {
    let name: String
    let scheme: @Sendable () throws -> Scheme
    let row: @Sendable () -> [String: Any]
    let wire: String
    var testDescription: String { name }

    init(_ name: String, _ scheme: @escaping @Sendable () throws -> Scheme, _ wire: String,
         _ row: @escaping @Sendable () -> [String: Any]) {
        self.name = name
        self.scheme = scheme
        self.row = row
        self.wire = wire
    }
}

/// One map row pack refuses, naming the field id and member; `reason` is a part of the reason.
struct RoundRefusal: CustomTestStringConvertible, Sendable {
    let name: String
    let scheme: @Sendable () throws -> Scheme
    let row: @Sendable () -> [String: Any]
    let field: Int?
    let member: String
    let reason: String
    var testDescription: String { name }

    init(_ name: String, _ scheme: @escaping @Sendable () throws -> Scheme, field: Int?, _ member: String,
         _ reason: String, _ row: @escaping @Sendable () -> [String: Any]) {
        self.name = name
        self.scheme = scheme
        self.row = row
        self.field = field
        self.member = member
        self.reason = reason
    }
}

/// One packet and the map unpack gives (in `canon` form); `row`, when given, packs to the packet.
struct UnpackRow: CustomTestStringConvertible, Sendable {
    let name: String
    let scheme: @Sendable () throws -> Scheme
    let wire: String
    let want: String
    let row: (@Sendable () -> [String: Any])?
    var testDescription: String { name }

    init(_ name: String, _ scheme: @escaping @Sendable () throws -> Scheme, _ wire: String, want: [String: Any],
         row: (@Sendable () -> [String: Any])? = nil) {
        self.name = name
        self.scheme = scheme
        self.wire = wire
        self.want = canon(want)
        self.row = row
    }
}

func expectPacks(_ c: PackRow) throws {
    let wire = try packHex(try c.scheme(), c.row())
    #expect(wire == c.wire, "\(c.name)")
}

/// Packs the row, unpacks the bytes as a map and packs that map again.
func repack(_ scheme: Scheme, _ row: [String: Any]) throws -> (String, [String: Any], String) {
    let wire = try pack(scheme, row)
    let back = try unpackMap(wire, scheme)
    return (hex(wire), back, try packHex(scheme, back))
}

func expectRefused(_ c: RoundRefusal) throws {
    let scheme = try c.scheme()
    let error = packbinError { try pack(scheme, c.row()) }
    #expect(error?.kind == .packError, "\(c.name)")
    #expect(error?.field == c.field && error?.name == c.member, "\(c.name): \(String(describing: error))")
    #expect(error?.reason.contains(c.reason) == true, "\(c.name): \(error?.reason ?? "")")
}

func expectUnpacks(_ c: UnpackRow) throws {
    let scheme = try c.scheme()
    let back = try unpackMap(bytes(c.wire), scheme)
    #expect(canon(back) == c.want, "\(c.name)")
    if let row = c.row { #expect(try packHex(scheme, row()) == c.wire, "\(c.name) packs") }
}

/// The short or unreadable-count error `body` throws: its member, bytes needed and bytes left.
func shortError(_ body: () throws -> Any) -> (String, Int, Int)? {
    guard let e = packbinError(body), e.kind == .short else { return nil }
    return (e.name, e.needed, e.left)
}

/// The seeded generator of the TypeScript round-roundtrip and when-on-written-values tests.
struct Mulberry32 {
    private var a: UInt32
    init(_ seed: UInt32) { a = seed }
    mutating func next() -> Double {
        a = a &+ 0x6d2b_79f5
        var t = (a ^ a >> 15) &* (1 | a)
        t = (t &+ (t ^ t >> 7) &* (61 | t)) ^ t
        return Double(t ^ t >> 14) / 4_294_967_296
    }
    mutating func pick(_ n: Int) -> Int { Int(next() * Double(n)) }
}

@Sendable func flagsRepeat() throws -> Scheme { try Scheme(1, .repeat(0, .flags(0, .bool(0, "on"), .u8(1, "n")))) }
@Sendable func flagsTimes() throws -> Scheme {
    try Scheme(1, .u8(0, "a"), .times(1, count: 0, .flags(1, .bool(1, "on"), .u8(2, "n"))))
}
@Sendable func whenRepeat() throws -> Scheme { try Scheme(1, .repeat(0, .u8(0, "k"), .when(1, .eq(0, 1), .u8(1, "v")))) }
@Sendable func whenTimes() throws -> Scheme {
    try Scheme(1, .u8(0, "a"), .times(1, count: 0, .u8(1, "k"), .when(2, .eq(1, 1), .u8(2, "v"))))
}
@Sendable func markRepeat() throws -> Scheme { try Scheme(1, .repeat(0, .flags(0, .group(0, "mark", .u8(0, "v"))))) }

func u8s(_ v: [UInt8?]) -> [Any?] { v.map { $0.map { $0 as Any } } }
