import Packbin
import Testing

/// One counted kind for count 3: its member, its bytes, its value in a row and what unpack gives.
struct CountedKind: CustomTestStringConvertible, Sendable {
    let name: String
    let member: @Sendable () -> Field
    let body: String
    let field: String
    let row: @Sendable () -> [String: Any]
    let want: String
    var testDescription: String { name }
}

private let countedKinds: [CountedKind] = [
    CountedKind(name: "sized", member: { .sized(1, "p", count: 0) }, body: "616263", field: "p",
                row: { ["p": Array("abc".utf8)] }, want: canon(Array("abc".utf8))),
    CountedKind(name: "packed", member: { .packed(2, 1, "p", count: 0) }, body: "24", field: "p",
                row: { ["p": [0, 1, 2]] }, want: canon([UInt8(0), 1, 2])),
    CountedKind(name: "times", member: { .times(1, count: 0, .u8(1, "x")) }, body: "010203", field: "x",
                row: { ["x": [1, 2, 3]] }, want: canon(u8s([1, 2, 3]))),
]

private func withCount(_ row: [String: Any], _ n: Any) -> [String: Any] { row.merging(["n": n]) { a, _ in a } }

/// AC-2 (SW-3), TypeScript `u64-count` and `when-on-written-values`: counts are wire integers up to
/// u64 and never trap; counts and whens read what pack wrote in their scope.
@Suite struct CountTests {
    @Test(arguments: countedKinds)
    func packAndUnpack_u64Count_readsAndWritesAndRefusesWhatNoBufferHolds(_ k: CountedKind) throws {
        // Arrange
        let scheme = try Scheme(1, .u64(0, "n"), k.member())
        let wire = "010300000000000000" + k.body

        // Act
        let back = try unpackMap(bytes(wire), scheme)
        let again = try packHex(scheme, back)
        let fromRow = try packHex(scheme, withCount(k.row(), UInt64(3)))
        let max = shortError { try unpackMap(bytes("01ffffffffffffffff" + k.body), scheme) }
        let refused = packbinError { try pack(scheme, withCount(k.row(), UInt64(1) << 53)) }

        // Assert
        #expect(canon(back["n"]) == canon(UInt64(3)) && canon(back[k.field]) == k.want)
        #expect(again == wire && fromRow == wire)
        #expect(max?.0 == k.field && max?.1 == 0 && max?.2 == k.body.count / 2, "2^64-1 cannot be read")
        #expect(refused?.kind == .packError && refused?.name == k.field)
    }

    /// 2^53 is a count in Swift as in C#, Python, Rust, Java and Go (TypeScript cannot read it exactly
    /// and reports it with needed 0): the sized and packed rows name the member and the bytes they lack.
    @Test func unpack_u64CountOf2Pow53_isACountThatTheBufferCannotHold() throws {
        // Arrange
        let sized = try Scheme(1, .u64(0, "n"), .sized(1, "p", count: 0))
        let times = try Scheme(1, .u64(0, "n"), .times(1, count: 0, .u8(1, "x")))

        // Act
        let shortSized = shortError { try unpackMap(bytes("010000000000002000616263"), sized) }
        let shortTimes = shortError { try unpackMap(bytes("010000000000002000010203"), times) }
        let largest = shortError { try unpackMap(bytes("01ffffffffffff1f0061"), sized) }

        // Assert
        #expect(shortSized?.0 == "p" && shortSized?.1 == 1 << 53 && shortSized?.2 == 3)
        #expect(shortTimes?.0 == "x" && shortTimes?.1 == 1 && shortTimes?.2 == 0)
        #expect(largest?.0 == "p" && largest?.1 == (1 << 53) - 1 && largest?.2 == 1)
    }

    @Test(arguments: countedKinds)
    func packAndUnpack_i64CountNegativeOrHuge_isRefusedNamingTheMember(_ k: CountedKind) throws {
        // Arrange
        let scheme = try Scheme(1, .i64(0, "n"), k.member())
        let counts: [(String, Int64)] = [("ffffffffffffffff", -1), ("0000000000000080", Int64.min),
                                        ("ffffffffffffff7f", Int64.max)]

        for (wire, value) in counts {
            // Act
            let read = packbinError { try unpackMap(bytes("01" + wire + k.body), scheme) }
            let written = packbinError { try pack(scheme, withCount(k.row(), value)) }

            // Assert
            #expect(read?.kind == .short && read?.name == k.field, "\(k.name) \(value)")
            if value < 0 { #expect(read?.needed == 0 && read?.left == k.body.count / 2, "\(k.name) \(value) unreadable") }
            #expect(written?.kind == .packError && written?.field != nil, "\(k.name) \(value) pack")
        }
    }

    static let skipped: [RoundRefusal] = [
        RoundRefusal("sized count skipped", { try skipN(.sized(2, "data", count: 1)) }, field: 2, "data",
                     "data: count n was not written") { ["p": 1, "n": 2, "data": [UInt8(1), 2]] },
        RoundRefusal("bits count skipped", { try skipN(.bits(2, "data", count: 1)) }, field: 2, "data",
                     "data: count n was not written") { ["p": 1, "n": 2, "data": [1, 0]] },
        RoundRefusal("packed count skipped", { try skipN(.packed(2, 2, "data", count: 1)) }, field: 2, "data",
                     "data: count n was not written") { ["p": 1, "n": 2, "data": [1, 2]] },
        RoundRefusal("times count skipped", { try skipN(.times(2, count: 1, .u8(2, "x"))) }, field: 2, "x",
                     "times: count n was not written") { ["p": 1, "n": 2, "x": [1, 2]] },
        RoundRefusal("count skipped in a round", {
            try Scheme(1, .repeat(0, .u8(0, "k"), .when(1, .eq(0, 1), .u8(1, "n")), .packed(2, 2, "data", count: 1)))
        }, field: 2, "data", "data: count n was not written") { ["k": [0], "n": [3], "data": [[1, 2, 3]]] },
        RoundRefusal("bits list of the wrong length", { try Scheme(1, .u8(0, "n"), .bits(1, "v", count: 0)) }, field: 1, "v",
                     "v: expected a list of 3 items for bits, got 2 items") { ["n": 3, "v": [1, 0]] },
        RoundRefusal("bits item above 1", { try Scheme(1, .u8(0, "n"), .bits(1, "v", count: 0)) }, field: 1, "v",
                     "v: item 1 is an integer (Int); expected 0..1") { ["n": 2, "v": [1, 2]] },
        RoundRefusal("packed item a Bool", { try Scheme(1, .u8(0, "n"), .packed(2, 1, "v", count: 0)) }, field: 1, "v",
                     "v: item 0 is a Bool (Bool); expected 0..3") { ["n": 1, "v": [true]] },
        RoundRefusal("sized bytes of the wrong length", { try Scheme(1, .u8(0, "n"), .sized(1, "v", count: 0)) }, field: 1,
                     "v", "v: expected 2 bytes, got 1") { ["n": 2, "v": [UInt8(1)]] },
        RoundRefusal("sized with no value", { try Scheme(1, .u8(0, "n"), .sized(1, "v", count: 0)) }, field: 1, "v",
                     "v: expected [UInt8] for sized, got no value") { ["n": 0] },
        RoundRefusal("packed bias -1 of a count of 0", { try Scheme(1, .u8(0, "n"), .packed(1, 1, "v", count: 0, bias: -1)) },
                     field: 1, "v", "v: item count -1") { ["n": 0, "v": [Int]()] },
        RoundRefusal("u2 slot above 3", { try Scheme(1, .u2(.slot(0, "a"), .slot(1, "b"))) }, field: 1, "b",
                     "b: expected a 2-bit integer 0..3, got an integer (Int)") { ["a": 0, "b": 4] },
        RoundRefusal("u2 slot missing", { try Scheme(1, .u2(.slot(0, "a"), .slot(1, "b"))) }, field: 1, "b",
                     "b: expected a 2-bit integer 0..3, got no value") { ["a": 0] },
    ]

    @Test(arguments: skipped)
    func pack_countedRowTheSchemeCannotWrite_isRefusedNamingTheMember(_ c: RoundRefusal) throws { try expectRefused(c) }

    static let written: [PackRow] = [
        PackRow("sized count written", { try skipN(.sized(2, "data", count: 1)) }, "0100020708") {
            ["p": 0, "n": 2, "data": [UInt8(7), 8]]
        },
        PackRow("bits count written", { try skipN(.bits(2, "data", count: 1)) }, "01000201") { ["p": 0, "n": 2, "data": [1, 0]] },
        PackRow("packed count written", { try skipN(.packed(2, 2, "data", count: 1)) }, "01000209") {
            ["p": 0, "n": 2, "data": [1, 2]]
        },
        PackRow("times count written", { try skipN(.times(2, count: 1, .u8(2, "x"))) }, "0100020506") {
            ["p": 0, "n": 2, "x": [5, 6]]
        },
        PackRow("bits given a [UInt8]", { try Scheme(1, .u8(0, "n"), .bits(1, "v", count: 0)) }, "010305") {
            ["n": 3, "v": [UInt8(1), 0, 1]]
        },
        PackRow("count from a u2 slot", { try Scheme(1, .u2(.slot(0, "c")), .bits(1, "v", count: 0)) }, "010305") {
            ["c": 3, "v": [1, 0, 1]]
        },
    ]

    @Test(arguments: written)
    func pack_countWrittenInTheScope_givesTypeScriptHex(_ c: PackRow) throws { try expectPacks(c) }

    static let whens: [UnpackRow] = [
        UnpackRow("a when on a field skipped in the round", {
            try Scheme(1, .repeat(0, .u8(0, "k"), .when(1, .eq(0, 1), .u8(1, "a")), .when(2, .eq(1, 5), .u8(2, "b"))))
        }, "0100", want: ["k": u8s([0]), "a": u8s([nil]), "b": u8s([nil])], row: { ["k": [0], "a": [5], "b": [3]] }),
        UnpackRow("a when on a field another when skipped", { try skipN(.when(2, .eq(1, 0), .u8(2, "v"))) }, "0101",
                  want: ["p": UInt8(1)], row: { ["p": 1, "n": 0, "v": 4] }),
    ]

    @Test(arguments: whens)
    func packAndUnpack_whenOnAFieldThatWasNotWritten_doesNotMatch(_ c: UnpackRow) throws { try expectUnpacks(c) }

    /// `when-on-written-values` AC-2: a seeded chain of whens in a round reads back what was written.
    @Test func packAndUnpack_seededWhenChainInARound_readsBackWhatWasWritten() throws {
        var rng = Mulberry32(2198)
        for _ in 0..<500 {
            // Arrange
            let scheme = try Scheme(1, .repeat(0, .u8(0, "a"), .when(1, .eq(0, rng.pick(3)), .u8(1, "b")),
                                               .when(2, .eq(rng.pick(2), rng.pick(3)), .u8(2, "c"))))
            for _ in 0..<20 {
                let rounds = 1 + rng.pick(3)
                let list = { (rng: inout Mulberry32) in (0..<rounds).map { _ in rng.pick(3) } }
                let row: [String: Any] = ["a": list(&rng), "b": list(&rng), "c": list(&rng)]

                // Act
                let wire = try pack(scheme, row)
                let again = try pack(scheme, try unpackMap(wire, scheme))

                // Assert
                #expect(again == wire, "\(row)")
            }
        }
    }
}

/// `when-on-written-values`: a count or condition `n` that a when on `p` skips when `p` is 1.
@Sendable func skipN(_ member: Field) throws -> Scheme {
    try Scheme(1, .u8(0, "p"), .when(1, .eq(0, 0), .u8(1, "n")), member)
}
