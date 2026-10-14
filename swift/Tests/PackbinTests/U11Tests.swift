import Packbin
import Testing

private let u11Text = "v: the count c is 3 in the row, but no field wrote it (the when that holds it is clear), so the member reads nothing"
private let reads = "in the row, but no field wrote it (the when that holds it is clear), so its times reads no round"

/// One U11 kind: its member for an id and a count id, a value of 3 items and its bytes.
struct U11Kind: Sendable {
    let name: String
    let member: @Sendable (Int, Int) -> Field
    let value: @Sendable () -> Any
    let set: String
}

private let kinds: [U11Kind] = [
    U11Kind(name: "bits", member: { .bits($0, "v", count: $1) }, value: { [1, 0, 1] }, set: "05"),
    U11Kind(name: "packed", member: { .packed(1, $0, "v", count: $1) }, value: { [1, 0, 1] }, set: "05"),
    U11Kind(name: "sized", member: { .sized($0, "v", count: $1) }, value: { [UInt8(1), 2, 3] }, set: "010203"),
]

/// `inner` behind a split flag byte's bit, or as the one member of a combined flags at `id`.
private func behind(_ split: Bool, _ id: Int, _ inner: Field) -> [Field] {
    guard split else { return [.flags(id, inner)] }
    let fb = FlagByte("fb")
    return [.flagByte(fb), fb.bit(inner)]
}

/// Row 56 with ids from `b`: mode b, c b+1, the member b+2.
private func body(_ k: U11Kind, _ split: Bool, _ b: Int) -> [Field] {
    [.u8(b, "mode"), .when(b + 1, .eq(b, 1), .u8(b + 1, "c"))] + behind(split, b + 2, k.member(b + 2, b + 1))
}

/// One nested position of `loop23-novalue-nested`: the scheme, the rows refused, and the rows that
/// pack with their bytes.
private struct NestedPosition {
    let name: String
    let layout: (U11Kind, Bool) -> [Field]
    let refused: [[String: Any]]
    let packs: (U11Kind) -> [([String: Any], String)]
}

private func positions() -> [NestedPosition] {
    let inner = { (k: U11Kind) in ["010000", "010000", "01010300", "01010301" + k.set] }
    let outer = { (k: U11Kind) in ["01010000", "01010000", "0101010300", "0101010301" + k.set] }
    return [
        NestedPosition(name: "the body inside a group", layout: { k, s in [.group(0, "g", body(k, s, 0))] },
                 refused: [["g": ["mode": 0, "c": 3]]],
                 packs: { k in zip([["g": ["mode": 0, "c": 0]], ["g": ["mode": 0]], ["g": ["mode": 1, "c": 3]],
                                    ["g": ["mode": 1, "c": 3, "v": k.value()]]] as [[String: Any]], inner(k)).map { ($0, $1) } }),
        NestedPosition(name: "a bit holding a group holding the member", layout: { k, s in
            [.u8(0, "mode"), .when(1, .eq(0, 1), .u8(1, "c"))] + behind(s, 2, .group(2, "g", k.member(2, 1)))
        }, refused: [["mode": 0, "c": 3]], packs: { k in
            zip([["mode": 0, "c": 0], ["mode": 0], ["mode": 1, "c": 3], ["mode": 1, "c": 3, "g": ["v": k.value()]]]
                as [[String: Any]], inner(k)).map { ($0, $1) }
        }),
        NestedPosition(name: "the body inside an outer holding when", layout: { k, s in [.u8(0, "o"), .when(1, .eq(0, 1), body(k, s, 1))] },
                 refused: [["o": 1, "mode": 0, "c": 3]], packs: { k in
            zip([["o": 1, "mode": 0, "c": 0], ["o": 1, "mode": 0], ["o": 1, "mode": 1, "c": 3],
                 ["o": 1, "mode": 1, "c": 3, "v": k.value()]] as [[String: Any]], outer(k)).map { ($0, $1) }
        }),
        NestedPosition(name: "a bit holding a holding when around the member", layout: { k, s in
            [.u8(0, "o"), .u8(1, "mode"), .when(2, .eq(1, 1), .u8(2, "c"))] + behind(s, 3, .when(3, .eq(0, 1), k.member(3, 2)))
        }, refused: [["o": 1, "mode": 0, "c": 3]], packs: { k in
            zip([["o": 1, "mode": 0, "c": 0], ["o": 1, "mode": 0], ["o": 1, "mode": 1, "c": 3],
                 ["o": 1, "mode": 1, "c": 3, "v": k.value()]] as [[String: Any]], outer(k)).map { ($0, $1) }
        }),
        NestedPosition(name: "a times round body", layout: { k, s in [.u8(0, "n"), .times(1, count: 0, body(k, s, 1))] },
                 refused: [["n": 1, "mode": [0], "c": [3]], ["n": 2, "mode": [1, 0], "c": [0, 3]]], packs: { k in
            zip([["n": 2, "mode": [1, 0], "c": [0, 0]], ["n": 1, "mode": [0]], ["n": 1, "mode": [1], "c": [3]],
                 ["n": 1, "mode": [1], "c": [3], "v": [k.value()]]] as [[String: Any]],
                ["01020100000000", "01010000", "0101010300", "0101010301" + k.set]).map { ($0, $1) }
        }),
        NestedPosition(name: "a repeat round body", layout: { k, s in [.repeat(0, body(k, s, 0))] },
                 refused: [["mode": [0], "c": [3]], ["mode": [1, 0], "c": [0, 3]]], packs: { k in
            zip([["mode": [1, 0], "c": [0, 0]], ["mode": [0]], ["mode": [1], "c": [3]], ["mode": [1], "c": [3], "v": [k.value()]]]
                as [[String: Any]], ["010100000000", "010000", "01010300", "01010301" + k.set]).map { ($0, $1) }
        }),
    ]
}

/// AC-3 (SW-12, U11): a bits, packed or sized member whose count the row gives above 0 behind a clear
/// when is refused, naming the member and the count, at the top level (`loop22-novalue-count`) and in
/// the six nested positions (`loop23-novalue-nested`); U6 (`loop21-parity-probes`): a times as well.
/// A `nil` array is no value; an empty array is 0 items (count 0 written).
@Suite struct U11Tests {
    @Test(arguments: ["bits", "packed", "sized"], [true, false])
    func pack_countBehindAClearWhenAtTheTopLevel_isRefusedNamingMemberAndCount(kind: String, split: Bool) throws {
        // Arrange
        let k = try #require(kinds.first { $0.name == kind })
        let scheme = try Scheme(1, body(k, split, 0))
        let refused: [([String: Any], String)] = [
            (["mode": 0, "c": 3], u11Text), (["mode": 0, "c": UInt64(3)], u11Text),
            (["mode": 0, "c": 3, "v": [Int]?.none as Any], u11Text), (["mode": 0, "c": 3.0], u11Text),
            (["mode": 0, "c": 3, "v": k.value()], "v: count c was not written"),
        ]
        let packs: [([String: Any], String)] = [
            (["mode": 0, "c": 0], "010000"), (["mode": 0], "010000"), (["mode": 1, "c": 3], "01010300"),
            (["mode": 1, "c": 3, "v": k.value()], "01010301" + k.set),
        ]

        // Act and Assert
        for (row, reason) in refused {
            let error = packbinError { try pack(scheme, row) }
            #expect(error?.field == 2 && error?.name == "v" && error?.reason.hasPrefix(reason) == true, "\(row): \(error?.reason ?? "")")
        }
        for (row, wire) in packs { #expect(try packHex(scheme, row) == wire, "\(row)") }
    }

    @Test(arguments: ["bits", "packed", "sized"])
    func pack_plainMemberWithItsCountBehindAClearWhen_isRefused(kind: String) throws {
        // Arrange
        let k = try #require(kinds.first { $0.name == kind })
        let scheme = try Scheme(1, .u8(0, "mode"), .when(1, .eq(0, 1), .u8(1, "c")), k.member(2, 1))

        // Act
        let none = packbinError { try pack(scheme, ["mode": 0, "c": 3]) }
        let value = packbinError { try pack(scheme, ["mode": 0, "c": 3, "v": k.value()]) }
        let held = try packHex(scheme, ["mode": 1, "c": 3, "v": k.value()])

        // Assert
        for e in [none, value] { #expect(e?.name == "v" && e?.reason == "v: count c was not written") }
        #expect(held == "010103" + k.set)
    }

    @Test func pack_packedBiasMinus1BehindAClearWhen_looksAtTheCountAfterTheBias() throws {
        // Arrange
        let fb = FlagByte("fb")
        let scheme = try Scheme(1, .u8(0, "mode"), .when(1, .eq(0, 1), .u8(1, "c")), .flagByte(fb),
                                fb.bit(.packed(1, 2, "v", count: 1, bias: -1)))

        // Act
        let one = try packHex(scheme, ["mode": 0, "c": 1])
        let three = packbinError { try pack(scheme, ["mode": 0, "c": 3]) }

        // Assert
        #expect(one == "010000")
        #expect(three?.reason.hasPrefix(u11Text) == true)
    }

    @Test(arguments: 0..<6, [true, false])
    func pack_countBehindAClearWhenInANestedPosition_isRefused(position: Int, split: Bool) throws {
        let pos = positions()[position]
        for k in kinds {
            // Arrange
            let scheme = try Scheme(1, pos.layout(k, split))

            // Act and Assert
            for row in pos.refused {
                let error = packbinError { try pack(scheme, row) }
                #expect(error?.name == "v" && error?.reason.hasPrefix(u11Text) == true, "\(pos.name) \(k.name) \(row)")
            }
            for (row, wire) in pos.packs(k) {
                #expect(try packHex(scheme, row) == wire, "\(pos.name) \(k.name) \(row)")
            }
        }
    }

    @Test(arguments: [true, false])
    func pack_memberInsideTheClearWhenItself_isASilentSkip(split: Bool) throws {
        for k in kinds {
            // Arrange
            let inner: [Field] = [.u8(2, "c")] + behind(split, 3, k.member(3, 2))
            let scheme = try Scheme(1, .u8(0, "o"), .when(1, .eq(0, 1), [.u8(1, "mode"), .when(2, .eq(1, 1), inner)]))

            // Act
            let wire = try packHex(scheme, ["o": 1, "mode": 0, "c": 3])

            // Assert
            #expect(wire == "010100", "\(k.name)")
        }
    }

    static let u6: [RoundRefusal] = [
        RoundRefusal("count 1, body absent", u6Split, field: 2, "pt", "pt: the count c is 1 " + reads) {
            ["mode": 0, "c": 1, "heading": 90]
        },
        RoundRefusal("count 1, body empty", u6Split, field: 2, "pt", "the count c is 1 " + reads) {
            ["mode": 0, "c": 1, "pt": [Int](), "heading": 90]
        },
        RoundRefusal("count 2, combined flags", {
            try Scheme(1, .u8(0, "mode"), .when(1, .eq(0, 1), .u8(1, "c")),
                       .flags(2, .times(2, count: 1, .u8(2, "pt")), .u16(3, "heading")))
        }, field: 2, "pt", "the count c is 2 " + reads) { ["mode": 0, "c": 2, "heading": 90] },
        RoundRefusal("a UInt64 count", u6Split, field: 2, "pt", "the count c is 3 " + reads) {
            ["mode": 0, "c": UInt64(3), "heading": 90]
        },
        RoundRefusal("a count above Int64.max", u6Split, field: 2, "pt", "the count c is 18446744073709551615 " + reads) {
            ["mode": 0, "c": UInt64.max, "heading": 90]
        },
        RoundRefusal("values given keep their own error", u6Split, field: 2, "pt",
                     "is not written before the flag byte, so its bit is clear") {
            ["mode": 0, "c": 2, "pt": [5, 6], "heading": 90]
        },
        RoundRefusal("plain times, count 1", u6Plain, field: 2, "pt", "times: count c was not written") {
            ["mode": 0, "c": 1, "heading": 90]
        },
        RoundRefusal("plain times, count 0", u6Plain, field: 2, "pt", "times: count c was not written") {
            ["mode": 0, "c": 0, "heading": 90]
        },
    ]

    @Test(arguments: u6)
    func pack_timesCountBehindAClearWhen_isRefusedNamingTheMember(_ c: RoundRefusal) throws { try expectRefused(c) }

    static let u6Packs: [PackRow] = [
        PackRow("count 0", u6Split, "0100025a00") { ["mode": 0, "c": 0, "heading": 90] },
        PackRow("count left out", u6Split, "0100025a00") { ["mode": 0, "heading": 90] },
        PackRow("a holding when", u6Split, "01010103055a00") { ["mode": 1, "c": 1, "pt": [5], "heading": 90] },
    ]

    @Test(arguments: u6Packs)
    func pack_timesCountThatIsZeroOrWritten_givesTypeScriptHex(_ c: PackRow) throws { try expectPacks(c) }

    /// SW-12 with a count: an empty array is a value of 0 items (the bit is set and count 0 written), a
    /// `nil` array is no value (the bit is clear).
    @Test func pack_emptyArrayIsZeroItemsNilIsNoValue() throws {
        // Arrange
        let scheme = try Scheme(1, .u8(0, "n"), .flags(1, .bits(1, "v", count: 0), .sized(2, "p", count: 0)))

        // Act
        let empty = try packHex(scheme, ["n": 0, "v": [Int](), "p": [UInt8]()])
        let none = try packHex(scheme, ["n": 0, "v": [Int]?.none as Any, "p": [UInt8]?.none as Any])
        let absent = try packHex(scheme, ["n": 0])

        // Assert
        #expect(empty == "010003")
        #expect(none == "010000" && absent == "010000")
    }
}

@Sendable private func u6Split() throws -> Scheme {
    let fb = FlagByte("fb")
    return try Scheme(1, .u8(0, "mode"), .when(1, .eq(0, 1), .u8(1, "c")), .flagByte(fb),
                      fb.bit(.times(2, count: 1, .u8(2, "pt"))), fb.bit(.u16(3, "heading")))
}

@Sendable private func u6Plain() throws -> Scheme {
    try Scheme(1, .u8(0, "mode"), .when(1, .eq(0, 1), .u8(1, "c")), .times(2, count: 1, .u8(2, "pt")), .u16(3, "heading"))
}
