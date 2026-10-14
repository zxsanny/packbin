import Packbin
import Testing

/// AC-2 (SW-3), TypeScript `round-values`: round values are addressed by round index. A group in a
/// round takes one `[String: Any]` a round (owner ruling Go-4 A, as Go), where TypeScript takes its
/// members as flat lists; the hex is TypeScript's for its flat form (probed at HEAD).
@Suite struct RoundValueTests {
    static let packs: [PackRow] = [
        PackRow("repeat flags by index", flagsRepeat, "01030102020303") { ["on": [true, false, true], "n": [1, 2, 3]] },
        PackRow("times flags by index", flagsTimes, "0103030102020303") {
            ["a": 3, "on": [true, false, true], "n": [1, 2, 3]]
        },
        PackRow("repeat only where the when holds", whenRepeat, "01010902") { ["k": [1, 2], "v": [9]] },
        PackRow("times only where the when holds", whenTimes, "0102010902") { ["a": 2, "k": [1, 2], "v": [9]] },
        PackRow("scalars make one round", whenRepeat, "010109") { ["k": 1, "v": 9] },
        PackRow("scalar beside a list", { try Scheme(1, .repeat(0, .u8(0, "k"), .u8(1, "v"))) }, "0101090209") {
            ["k": [1, 2], "v": 9]
        },
        PackRow("absent entry in the middle", { try Scheme(1, .repeat(0, .u8(0, "x"), .flags(1, .u8(1, "n")))) },
                "010101050200") { ["x": [1, 2], "n": [5, nil] as [Int?]] },
        PackRow("longest list sets the count", { try Scheme(1, .repeat(0, .flags(0, .u8(0, "a"), .u8(1, "b")))) },
                "010301050206") { ["a": [1, nil] as [Int?], "b": [5, 6]] },
        PackRow("group under flags per round", markRepeat, "010107000109") {
            ["mark": [["v": 7], nil, ["v": 9]] as [[String: Any]?]]
        },
        PackRow("group read at the round's index", markRepeat, "01010700") {
            ["mark": [["v": 7], nil] as [[String: Any]?]]
        },
        PackRow("times group at the round's index",
                { try Scheme(1, .u8(0, "a"), .times(1, count: 0, .flags(1, .group(1, "mark", .u8(1, "v"))))) },
                "0102010700") { ["a": 2, "mark": [["v": 7], nil] as [[String: Any]?]] },
        PackRow("empty group under flags per round",
                { try Scheme(1, .repeat(0, .flags(0, .group(0, "mark"), .u8(0, "n")))) }, "01030102020303") {
            ["mark": [true, false, true], "n": [1, 2, 3]]
        },
        PackRow("anchored group by round index",
                { try Scheme(1, .repeat(0, .u8(0, "k"), .group(1, "mark", .u8(1, "v")))) }, "0101070208") {
            ["k": [1, 2], "mark": [["v": 7], ["v": 8]]]
        },
        PackRow("a lone group map goes to every round",
                { try Scheme(1, .repeat(0, .u8(0, "k"), .group(1, "mark", .u8(1, "v")))) }, "0101070207") {
            ["k": [1, 2], "mark": ["v": 7]]
        },
        PackRow("u2 slots by round index", { try Scheme(1, .repeat(0, .u8(0, "k"), .u2(.slot(1, "p"), .slot(2, "q")))) },
                "01010d0202") { ["k": [1, 2], "p": [1, 2], "q": [3, 0]] },
        PackRow("count read inside a round", { try Scheme(1, .repeat(0, .u8(0, "n"), .sized(1, "p", count: 0))) },
                "0102aabb01cc") { ["n": [2, 1], "p": [[0xaa, 0xbb] as [UInt8], [0xcc] as [UInt8]]] },
    ]

    @Test(arguments: packs)
    func pack_roundRow_givesTypeScriptHexAndRepacks(_ c: PackRow) throws {
        // Act
        let (wire, _, again) = try repack(try c.scheme(), c.row())

        // Assert
        #expect(wire == c.wire, "\(c.name)")
        #expect(again == c.wire, "\(c.name) repack")
    }

    static let unpacks: [UnpackRow] = [
        UnpackRow("bool is true or absent", flagsRepeat, "01030102020303",
                  want: ["on": [true, nil, true] as [Any?], "n": u8s([1, 2, 3])]),
        UnpackRow("times bool is true or absent", flagsTimes, "0103030102020303",
                  want: ["a": UInt8(3), "on": [true, nil, true] as [Any?], "n": u8s([1, 2, 3])]),
        UnpackRow("skipped round keeps its place", whenRepeat, "01020109", want: ["k": u8s([2, 1]), "v": u8s([nil, 9])]),
        UnpackRow("no round set the value", whenRepeat, "010202", want: ["k": u8s([2, 2]), "v": u8s([nil, nil])]),
        UnpackRow("times skipped round keeps its place", whenTimes, "0102020109",
                  want: ["a": UInt8(2), "k": u8s([2, 1]), "v": u8s([nil, 9])]),
        UnpackRow("group per round", markRepeat, "010107000109",
                  want: ["mark": [["v": UInt8(7)], nil, ["v": UInt8(9)]] as [Any?]]),
        UnpackRow("times when values per round",
                  { try Scheme(1, .u8(0, "a"), .times(1, count: 0, .u8(1, "b"), .when(2, .eq(1, 1), .u8(2, "c")))) },
                  "01030107000109", want: ["a": UInt8(3), "b": u8s([1, 0, 1]), "c": u8s([7, nil, 9])]),
        UnpackRow("u2 slots per round", { try Scheme(1, .repeat(0, .u8(0, "k"), .u2(.slot(1, "p"), .slot(2, "q")))) },
                  "01010d0202", want: ["k": u8s([1, 2]), "p": u8s([1, 2]), "q": u8s([3, 0])]),
        UnpackRow("sized per round", { try Scheme(1, .repeat(0, .u8(0, "n"), .sized(1, "p", count: 0))) },
                  "0102aabb01cc", want: ["n": u8s([2, 1]), "p": [[UInt8(0xaa), 0xbb], [UInt8(0xcc)]] as [Any?]]),
        UnpackRow("empty group per round", { try Scheme(1, .repeat(0, .flags(0, .group(0, "mark"), .u8(0, "n")))) },
                  "01030102020303", want: ["mark": [true, nil, true] as [Any?], "n": u8s([1, 2, 3])]),
        UnpackRow("repeat with no round", whenRepeat, "01", want: [:]),
        UnpackRow("times count zero", whenTimes, "0100", want: ["a": UInt8(0)]),
    ]

    @Test(arguments: unpacks)
    func unpackMap_roundPacket_givesOneEntryARoundAndRepacks(_ c: UnpackRow) throws {
        // Arrange
        let scheme = try c.scheme()

        // Act
        let back = try unpackMap(bytes(c.wire), scheme)
        let again = try packHex(scheme, back)

        // Assert
        #expect(canon(back) == c.want, "\(c.name)")
        #expect(again == c.wire, "\(c.name) repack")
    }

    @Test func unpackMap_nonCanonicalRounds_keepOneEntryARound() throws {
        // Arrange
        let twice = try Scheme(1, .repeat(0, .u8(0, "k"), .when(1, .eq(0, 1), .u8(1, "v")), .when(2, .eq(0, 1), .u8(2, "v"))))
        let empty = try Scheme(1, .repeat(0, .bytes(0, "v", size: 0)), .u8(1, "tail"))

        // Act
        let named = try unpackMap(bytes("0101090a02"), twice)
        let ended = try unpackMap(bytes("0105"), empty)

        // Assert
        #expect(canon(named) == canon(["k": u8s([1, 2]), "v": u8s([10, nil])]))
        #expect(canon(ended) == canon(["v": [[UInt8]()] as [Any?], "tail": UInt8(5)]))
    }

    static let refusals: [RoundRefusal] = [
        RoundRefusal("times count from the field, not the lists",
                     { try Scheme(1, .u8(0, "a"), .times(1, count: 0, .u8(1, "x"))) }, field: 1, "x", "missing x") {
            ["a": 3, "x": [1]]
        },
        RoundRefusal("a given group with its member missing", markRepeat, field: 0, "v", "missing v") {
            ["mark": [[String: Any]()]]
        },
        RoundRefusal("a group given a bool", markRepeat, field: 0, "mark", "expected a [String: Any] for group mark") {
            ["mark": [true]]
        },
        RoundRefusal("Go-4: a member list given flat beside no group", markRepeat, field: 0, "v", "member of group mark") {
            ["v": [7]]
        },
        RoundRefusal("a mark given an integer", { try Scheme(1, .repeat(0, .flags(0, .group(0, "mark"), .u8(0, "n")))) },
                     field: 0, "mark", "expected a Bool") { ["mark": [1], "n": [1]] },
    ]

    @Test(arguments: refusals)
    func pack_roundRowTypeScriptRefuses_isRefusedNamingTheMember(_ c: RoundRefusal) throws {
        try expectRefused(c)
    }

    @Test func scheme_roundMemberNamedLikeAnEarlierScalar_isRefused() {
        // Act
        let error = packbinError { try Scheme(1, .u8(0, "x"), .repeat(1, .u8(1, "x"))) }

        // Assert
        #expect(error?.kind == .schemeError && error?.field == 1 && error?.name == "x")
        #expect(error?.reason.contains("declared twice") == true)
    }

    /// A when in a round reads only the round's own value, not a same-named one outside it; the
    /// round's list of that name joins the value outside, as in TypeScript.
    @Test func unpackMap_whenInARound_readsTheRoundsOwnValue() throws {
        // Arrange
        let scheme = try Scheme(1, .u8(0, "k"),
                                .repeat(1, .u8(1, "j"), .when(2, .eq(1, 1), .u8(2, "k")), .when(3, .eq(2, 7), .u8(3, "w"))))

        // Act
        let row = try unpackMap(bytes("0107000a"), scheme)

        // Assert
        #expect(canon(row) == canon(["k": u8s([7, nil, nil]), "j": u8s([0, 10]), "w": u8s([nil, nil])]))
    }
}
