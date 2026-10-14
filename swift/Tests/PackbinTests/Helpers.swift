import Foundation
import Packbin
import Testing

let expectedHex = "4001000065cd1d00a3e1110100"

/// The repository root, found from this file's path (swift/Tests/PackbinTests/Helpers.swift).
let repositoryRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

func repositoryFile(_ path: String) throws -> String {
    try String(contentsOf: repositoryRoot.appendingPathComponent(path), encoding: .utf8)
}

func goldenHex() throws -> String {
    try repositoryFile("fixtures/golden.hex").trimmingCharacters(in: .whitespacesAndNewlines)
}

func hex(_ bytes: [UInt8]) -> String {
    bytes.map { String(format: "%02x", $0) }.joined()
}

func bytes(_ hex: String) -> [UInt8] {
    let digits = Array(hex.replacingOccurrences(of: " ", with: "").utf8)
    var out: [UInt8] = []
    var i = 0
    while i + 1 < digits.count {
        out.append(UInt8(String(decoding: digits[i...i + 1], as: UTF8.self), radix: 16) ?? 0)
        i += 2
    }
    return out
}

func mismatchedBytes(_ a: [UInt8], _ b: [UInt8]) -> Int {
    (0..<max(a.count, b.count)).filter { $0 >= a.count || $0 >= b.count || a[$0] != b[$0] }.count
}

struct Position: PackbinRow, Equatable {
    var sid: UInt16 = 0
    var lat: Int32 = 0
    var lon: Int32 = 0
    var profile: UInt8 = 0
    var heading: UInt16?
    var speed: UInt8?
    var altitude: Int16?
}

func goldenRow() -> Position {
    Position(sid: 1, lat: 500_000_000, lon: 300_000_000, profile: 1)
}

func goldenMap() -> [String: Any] {
    ["sid": 1, "lat": 500_000_000, "lon": 300_000_000, "profile": 1]
}

func positionMapScheme() throws -> Scheme {
    try Scheme(0x40,
               .u16(0, "sid"),
               .i32(1, "lat"),
               .i32(2, "lon"),
               .u8(3, "profile"),
               .flags(4, .u16(4, "heading"), .u8(5, "speed"), .i16(6, "altitude")))
}

func positionTypedScheme() throws -> Scheme {
    try Scheme(0x40,
               .u16(0, "sid").bind(get: { (r: Position) in r.sid }, set: { $0.sid = $1 }),
               .i32(1, "lat").bind(get: { (r: Position) in r.lat }, set: { $0.lat = $1 }),
               .i32(2, "lon").bind(get: { (r: Position) in r.lon }, set: { $0.lon = $1 }),
               .u8(3, "profile").bind(get: { (r: Position) in r.profile }, set: { $0.profile = $1 }),
               .flags(4,
                      .u16(4, "heading").bind(get: { (r: Position) in r.heading }, set: { $0.heading = $1 }),
                      .u8(5, "speed").bind(get: { (r: Position) in r.speed }, set: { $0.speed = $1 }),
                      .i16(6, "altitude").bind(get: { (r: Position) in r.altitude }, set: { $0.altitude = $1 })))
}

func packHex(_ scheme: Scheme, _ row: [String: Any]) throws -> String {
    hex(try pack(scheme, row))
}

func packHex<Row>(_ scheme: Scheme, _ row: Row) throws -> String {
    hex(try pack(scheme, row))
}

/// The error `body` throws, which must be a `PackbinError`.
func packbinError(_ body: () throws -> Any) -> PackbinError? {
    do {
        _ = try body()
        return nil
    } catch let error as PackbinError {
        return error
    } catch {
        Issue.record("not a PackbinError: \(error)")
        return nil
    }
}

/// A map compared by its keys and the type and value of each entry; a nested map (a group) as
/// `key={...}`.
func describeMap(_ map: [String: Any]) -> String {
    map.keys.sorted().map { key in
        let v = map[key] ?? "none"
        if let nested = v as? [String: Any] { return "\(key)={\(describeMap(nested))}" }
        let shown = (v as? [UInt8]).map(hex) ?? "\(v)"
        return "\(key)=\(type(of: v)):\(shown)"
    }.joined(separator: ",")
}

/// A map compared by its keys and the value of each entry, whatever its type (`5` as an `Int` and as
/// a `UInt8` are the same); a nested map as `key={...}`.
func describeValues(_ map: [String: Any]) -> String {
    map.keys.sorted().map { key in
        let v = map[key] ?? "none"
        if let nested = v as? [String: Any] { return "\(key)={\(describeValues(nested))}" }
        return "\(key)=\((v as? [UInt8]).map(hex) ?? "\(v)")"
    }.joined(separator: ",")
}

/// One scheme the construction checks refuse: the id and name the error names, and its reason (the
/// whole reason, or its start when it ends in "...").
struct RefusedScheme: CustomTestStringConvertible, Sendable {
    let name: String
    let build: @Sendable () throws -> Scheme
    let field: Int?
    let member: String
    let reason: String
    var testDescription: String { name }

    init(_ name: String, field: Int?, _ member: String, _ reason: String,
         _ build: @escaping @Sendable () throws -> Scheme) {
        self.name = name
        self.build = build
        self.field = field
        self.member = member
        self.reason = reason
    }
}

/// Whether `build` throws the scheme error `c` describes.
func expectRefused(_ c: RefusedScheme) {
    let error = packbinError { try c.build() }
    let prefix = c.reason.hasSuffix("...") ? String(c.reason.dropLast(3)) : nil
    let reason = error?.reason ?? ""
    #expect(error?.kind == .schemeError)
    #expect(error?.field == c.field && error?.name == c.member)
    #expect(prefix.map { reason.hasPrefix($0) } ?? (reason == c.reason), "reason: \(reason)")
}
