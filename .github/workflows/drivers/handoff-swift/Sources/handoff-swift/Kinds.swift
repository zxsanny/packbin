import Packbin

/// One payload kind of the ring: the scheme, the row Swift packs, the row unpack must give (the Swift
/// types `unpackMap` uses), and whether the unpacked row must repack to the same bytes.
struct Kind {
    let scheme: Scheme
    let pack: [String: Any]
    let want: [String: Any]
    var repack = false
}

/// The kinds that also take unpack-<kind>-short: a packet cut short must be refused.
let shortKinds: Set<String> = ["listgroup", "dictgroup", "listflags"]

private func point(_ a: UInt8, _ b: UInt8) -> [String: Any] { ["a": a, "b": b] }

/// The kind `name`, its scheme built by hand as the README shows (ADR-001), or nil when there is none.
func kind(_ name: String) throws -> Kind? {
    switch name {
    case "user":
        let row: [String: Any] = [
            "username": "zxsanny",
            "roles": ["user", "dispatcher"],
            "access": ["channel": ["read"], "map": ["read", "gps_fix", "set", "edit"], "store": ["read", "write"]],
        ]
        return Kind(scheme: try Scheme(1, .utf8(0, "username"), .list("roles", .utf8(0, "role")),
                                       .dict("access", .list("actions", .utf8(0, "action")))),
                    pack: row, want: row)
    case "nested":
        let row: [String: Any] = ["access": ["map": [["op": "gps_fix"]], "store": [["op": "read"], ["op": "write"]]]]
        return Kind(scheme: try Scheme(1, .dict("access", .list("rows", .dict("row", .utf8(0, "op"))))),
                    pack: row, want: row)
    // flags { bool on }: the bit is set only for true.
    case "boolflag":
        return Kind(scheme: try Scheme(1, .flags(0, .bool(0, "on"))), pack: ["on": false], want: [:])
    case "booltrue":
        return Kind(scheme: try Scheme(1, .flags(0, .bool(0, "on"))), pack: ["on": true], want: ["on": true])
    // u8 k; split flag byte m; when(k == 1) { m.bit(u8 v) }: {k:0, v:5} sets the bit although the when is
    // not taken, and unpack never reads it.
    case "bitwhen":
        let m = FlagByte("m")
        return Kind(scheme: try Scheme(1, .u8(0, "k"), .flagByte(m), .when(1, .eq(0, 1), m.bit(.u8(1, "v")))),
                    pack: ["k": 0, "v": 5], want: ["k": UInt8(0)])
    // Aligned rounds: one entry per round; a clear bit and a when not taken leave the entry nil.
    case "roundflags":
        return Kind(scheme: try Scheme(1, .repeat(0, .flags(0, .bool(0, "on"), .u8(1, "n")))),
                    pack: ["on": [true, false, true], "n": [1, 2, 3]],
                    want: ["on": [true, nil, true] as [Any?], "n": [UInt8(1), UInt8(2), UInt8(3)]],
                    repack: true)
    case "roundwhen":
        return Kind(scheme: try Scheme(1, .repeat(0, .u8(0, "k"), .when(1, .eq(0, 1), .u8(1, "v")))),
                    pack: ["k": [1, 2], "v": [9]],
                    want: ["k": [UInt8(1), UInt8(2)], "v": [UInt8(9), nil] as [Any?]],
                    repack: true)
    case "listgroup":
        let row: [String: Any] = ["pts": [point(1, 2), point(3, 4)]]
        return Kind(scheme: try Scheme(1, .list("pts", .group("p", .u8(0, "a"), .u8(1, "b")))), pack: row, want: row)
    case "dictgroup":
        let row: [String: Any] = ["m": ["y": point(3, 4), "x": point(1, 2)]]
        return Kind(scheme: try Scheme(1, .dict("m", .group("p", .u8(0, "a"), .u8(1, "b")))), pack: row, want: row)
    // A missing value is a clear flag bit.
    case "listflags":
        let row: [String: Any] = ["pts": [["a": UInt8(1)], [String: Any](), ["b": UInt16(2)]] as [[String: Any]]]
        return Kind(scheme: try Scheme(1, .list("pts", .flags(0, .u8(0, "a"), .u16(1, "b")))), pack: row, want: row)
    default:
        return nil
    }
}
