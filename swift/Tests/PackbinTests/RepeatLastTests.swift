import Packbin
import Testing

/// One round of the typed cases: `v` of the repeat, `w` of a second one.
struct LastRound: PackbinRow, Equatable {
    var v: UInt8 = 0
    var w: UInt8 = 0
}

/// The row of a nested row, of a list or dict item and of a times round: u8 mode; repeat { u8 v }.
struct LastInner: PackbinRow, Equatable {
    var mode: UInt8 = 0
    var rounds: [LastRound]?
}

/// A round that holds a nested row `m`.
struct LastOuter: PackbinRow, Equatable {
    var m: LastInner?
}

/// The top-level row of the typed cases; `ox` is `x` under a flag bit.
struct LastRow: PackbinRow, Equatable {
    var k: UInt8 = 0
    var x: UInt8 = 0
    var ox: UInt8?
    var on: Bool?
    var rounds: [LastRound]?
    var more: [LastRound]?
    var m: LastInner?
    var inners: [LastInner]?
    var outers: [LastOuter]?
    var items: [LastInner] = []
    var d: [String: LastInner] = [:]
}

/// The fields of the contract's cases in one of the two forms a Swift scheme has: map rows (the fields
/// as they are) or typed rows (every value field, group and round bound with `bind(get:set:)`).
struct LastForm: CustomTestStringConvertible, Sendable {
    let typed: Bool
    var testDescription: String { typed ? "typed rows" : "map rows" }

    static let both = [LastForm(typed: false), LastForm(typed: true)]

    func k(_ id: Int) -> Field {
        let f = Field.u8(id, "k")
        return typed ? f.bind(get: { (r: LastRow) in r.k }, set: { $0.k = $1 }) : f
    }

    func x(_ id: Int) -> Field {
        let f = Field.u8(id, "x")
        return typed ? f.bind(get: { (r: LastRow) in r.x }, set: { $0.x = $1 }) : f
    }

    /// `x` under a flag bit: an optional member.
    func optionalX(_ id: Int) -> Field {
        let f = Field.u8(id, "x")
        return typed ? f.bind(get: { (r: LastRow) in r.ox }, set: { $0.ox = $1 }) : f
    }

    func on(_ id: Int) -> Field {
        let f = Field.bool(id, "on")
        return typed ? f.bind(get: { (r: LastRow) in r.on }, set: { $0.on = $1 }) : f
    }

    /// u8 v, or u8 w, of a round.
    private func member(_ id: Int, _ name: String) -> Field {
        let f = Field.u8(id, name)
        guard typed else { return f }
        return name == "w" ? f.bind(get: { (r: LastRound) in r.w }, set: { $0.w = $1 })
            : f.bind(get: { (r: LastRound) in r.v }, set: { $0.v = $1 })
    }

    /// repeat { u8 v }, a member of the top-level row.
    func rounds(_ id: Int) -> Field {
        let f = Field.repeat(id, member(id, "v"))
        return typed ? f.bind(get: { (r: LastRow) in r.rounds }, set: { $0.rounds = $1 }) : f
    }

    /// repeat { u8 w }, a second repeat of the top-level row.
    func more(_ id: Int) -> Field {
        let f = Field.repeat(id, member(id, "w"))
        return typed ? f.bind(get: { (r: LastRow) in r.more }, set: { $0.more = $1 }) : f
    }

    /// times(count) { u8 v }, a member of the top-level row.
    func counted(_ id: Int, count: Int) -> Field {
        let f = Field.times(id, count: count, member(id, "v"))
        return typed ? f.bind(get: { (r: LastRow) in r.rounds }, set: { $0.rounds = $1 }) : f
    }

    /// repeat { u8 v }, a member of a nested row, of an item or of a times round.
    func innerRounds(_ id: Int) -> Field {
        let f = Field.repeat(id, member(id, "v"))
        return typed ? f.bind(get: { (r: LastInner) in r.rounds }, set: { $0.rounds = $1 }) : f
    }

    /// A group, anchored or a nested row, as the member `m`.
    func m(_ group: Field) -> Field {
        typed ? group.bind(get: { (r: LastRow) in r.m }, set: { $0.m = $1 }) : group
    }

    /// times(count) { u8 v }, a member of a nested row.
    func innerTimes(_ id: Int, count: Int) -> Field {
        let f = Field.times(id, count: count, member(id, "v"))
        return typed ? f.bind(get: { (r: LastInner) in r.rounds }, set: { $0.rounds = $1 }) : f
    }

    /// u8 mode of a nested row or an item.
    func mode(_ id: Int) -> Field {
        let f = Field.u8(id, "mode")
        return typed ? f.bind(get: { (r: LastInner) in r.mode }, set: { $0.mode = $1 }) : f
    }

    /// The element row of R7 and R8: u8 mode; repeat { u8 v }.
    func element() -> Field { .group("item", mode(0), innerRounds(1)) }

    /// The nested row `m` of a round, with ids of its own.
    func roundRow(_ members: Field...) -> Field {
        let f = Field.group("m", members)
        return typed ? f.bind(get: { (r: LastOuter) in r.m }, set: { $0.m = $1 }) : f
    }

    /// A repeat or times whose round holds `roundRow`.
    func outers(_ round: Field) -> Field {
        typed ? round.bind(get: { (r: LastRow) in r.outers }, set: { $0.outers = $1 }) : round
    }

    func items(_ element: Field) -> Field {
        let f = Field.list("items", element)
        return typed ? f.bind(get: { (r: LastRow) in r.items }, set: { $0.items = $1 }) : f
    }

    func d(_ element: Field) -> Field {
        let f = Field.dict("d", element)
        return typed ? f.bind(get: { (r: LastRow) in r.d }, set: { $0.d = $1 }) : f
    }

    /// times(count) { repeat { u8 v } }: R9.
    func inners(_ id: Int, count: Int) -> Field {
        let f = Field.times(id, count: count, innerRounds(id))
        return typed ? f.bind(get: { (r: LastRow) in r.inners }, set: { $0.inners = $1 }) : f
    }
}

/// One scheme that must not build, and the whole text of its refusal.
struct LastRefusal: CustomTestStringConvertible, Sendable {
    let name: String
    let text: String
    let build: @Sendable (LastForm) throws -> Scheme
    var testDescription: String { name }

    init(_ name: String, _ text: String, _ build: @escaping @Sendable (LastForm) throws -> Scheme) {
        self.name = name
        self.text = text
        self.build = build
    }
}

/// One scheme that keeps building: its row in both forms, its packet and what `unpackMap` gives (in
/// `canon` form).
struct LastKept: CustomTestStringConvertible, Sendable {
    let name: String
    let packet: String
    let build: @Sendable (LastForm) throws -> Scheme
    let map: @Sendable () -> [String: Any]
    let want: String
    let typed: LastRow
    var testDescription: String { name }

    init(_ name: String, _ packet: String, map: @escaping @Sendable () -> [String: Any], want: [String: Any],
         typed: LastRow, _ build: @escaping @Sendable (LastForm) throws -> Scheme) {
        self.name = name
        self.packet = packet
        self.build = build
        self.map = map
        self.want = canon(want)
        self.typed = typed
    }
}

/// The two texts of the contract, whole: the error is at the repeat, which has no name.
private func followed(_ anchor: Int, _ field: String) -> String {
    "packbin: invalid scheme at field \(anchor): repeat \(anchor): \(field) follows it; "
        + "a repeat reads to the end of the packet, so nothing can follow it; use times"
}

private func inElement(_ anchor: Int) -> String {
    "packbin: invalid scheme at field \(anchor): repeat \(anchor) is inside a list or dict element; "
        + "a repeat reads to the end of the packet, so another element cannot follow it; use times"
}

/// The text of the nesting rule, which is older than the contract and runs before its check.
private func inRound(_ kind: String, _ anchor: Int) -> String {
    "packbin: invalid scheme at field \(anchor): \(kind) \(anchor) is inside a repeat or times round; "
        + "a round cannot hold another repeat or times"
}

/// repeat { u8 v }, with the id its place gives it.
private func repeatV(_ id: Int) -> Field { .repeat(id, .u8(id, "v")) }

private let mapRows = LastForm(typed: false)
private let twoRounds = [LastRound(v: 5), LastRound(v: 6)]

/// AZ-4216, contract repeat-last 1.0.1: a repeat is the last thing a packet reads. A scheme that breaks
/// the rule is refused when it is built, with map rows and with typed rows; a repeat that is last
/// builds and packs the bytes it packed before. A value field after the repeat is named by its id and
/// name, as the count and eq refusals name a field.
@Suite struct RepeatLastTests {
    static let contractCases: [LastRefusal] = [
        LastRefusal("R1 a field after the repeat", followed(0, "field id 1 (x)")) { f in
            try Scheme(1, f.rounds(0), f.x(1))
        },
        LastRefusal("R2 a field after the when that holds the repeat", followed(1, "field id 2 (x)")) { f in
            try Scheme(1, f.k(0), .when(1, .eq(0, 1), f.rounds(1)), f.x(2))
        },
        LastRefusal("R3 a field after the flags that holds the repeat", followed(0, "field id 1 (x)")) { f in
            try Scheme(1, .flags(0, f.rounds(0)), f.x(1))
        },
        // A nested row numbers its members from 0, so `x` is id 0 of the row around it.
        LastRefusal("R4 a field after the nested row that holds the repeat", followed(0, "field id 0 (x)")) { f in
            try Scheme(1, f.m(.group("m", f.innerRounds(0))), f.x(0))
        },
        LastRefusal("R4 a field after the anchored group that holds the repeat", followed(0, "field id 1 (x)")) { f in
            try Scheme(1, f.m(.group(0, "m", f.innerRounds(0))), f.x(1))
        },
        LastRefusal("R5 a second repeat", followed(0, "repeat 1")) { f in try Scheme(1, f.rounds(0), f.more(1)) },
        LastRefusal("R6 a field under a when that cannot hold together with the repeat's when",
                    followed(1, "field id 2 (x)")) { f in
            try Scheme(1, f.k(0), .when(1, .eq(0, 1), f.rounds(1)), .when(2, .eq(0, 2), f.x(2)))
        },
        LastRefusal("R7 a repeat in a list element", inElement(1)) { f in try Scheme(1, f.items(f.element())) },
        LastRefusal("R8 a repeat in a dict element", inElement(1)) { f in try Scheme(1, f.d(f.element())) },
        LastRefusal("R9 a repeat in a times round keeps the text of the nesting rule", inRound("repeat", 1)) { f in
            try Scheme(1, f.k(0), f.inners(1, count: 0))
        },
    ]

    /// AC-1: the refused cases R1 to R9 of the contract, each with map rows and with typed rows.
    @Test(arguments: contractCases, LastForm.both)
    func scheme_refusedCaseOfTheContract_isRefusedWhenItIsBuilt(_ c: LastRefusal, _ form: LastForm) {
        // Arrange
        let build = { try c.build(form) }

        // Act
        let error = packbinError(build)

        // Assert
        #expect(error?.kind == .schemeError)
        #expect(error?.description == c.text)
    }

    static let nestedRowsOfRounds: [LastRefusal] = [
        LastRefusal("a repeat in a nested row of a repeat round", inRound("repeat", 0)) { f in
            try Scheme(1, f.outers(.repeat(0, f.roundRow(f.innerRounds(0)))))
        },
        LastRefusal("a repeat in a nested row of a times round", inRound("repeat", 0)) { f in
            try Scheme(1, f.k(0), f.outers(.times(1, count: 0, f.roundRow(f.innerRounds(0)))))
        },
        LastRefusal("a times in a nested row of a times round", inRound("times", 1)) { f in
            try Scheme(1, f.k(0), f.outers(.times(1, count: 0, f.roundRow(f.mode(0), f.innerTimes(1, count: 0)))))
        },
    ]

    /// Rule 3 of the contract: a nested row does not hide a round from the nesting rule, which refuses
    /// these with its own text, before the repeat-last check (a times in a nested row of a round too).
    @Test(arguments: nestedRowsOfRounds, LastForm.both)
    func scheme_roundInANestedRowOfARound_isRefusedByTheNestingRule(_ c: LastRefusal, _ form: LastForm) {
        // Arrange
        let build = { try c.build(form) }

        // Act
        let error = packbinError(build)

        // Assert
        #expect(error?.kind == .schemeError)
        #expect(error?.description == c.text)
    }

    /// AC-1: the array form of `Scheme.init` runs the same check.
    @Test func scheme_refusedCaseBuiltFromAnArrayOfFields_isRefusedAsTheVariadicInit() {
        // Arrange
        let followedFields: [Field] = [repeatV(0), .u8(1, "x")]
        let elementFields: [Field] = [mapRows.items(mapRows.element())]

        // Act
        let afterRepeat = packbinError { try Scheme(1, followedFields) }
        let inItem = packbinError { try Scheme(1, elementFields) }

        // Assert
        #expect(afterRepeat?.kind == .schemeError && afterRepeat?.description == followed(0, "field id 1 (x)"))
        #expect(inItem?.kind == .schemeError && inItem?.description == inElement(1))
    }

    static let followers: [LastRefusal] = [
        LastRefusal("a later field of the when that holds the repeat, before the field after the when",
                    followed(1, "field id 2 (y)")) { _ in
            try Scheme(1, .u8(0, "k"), .when(1, .eq(0, 1), repeatV(1), .u8(2, "y")), .u8(3, "x"))
        },
        LastRefusal("a field two places out: after the when that holds the flags that holds the repeat",
                    followed(1, "field id 2 (x)")) { _ in
            try Scheme(1, .u8(0, "k"), .when(1, .eq(0, 1), .flags(1, repeatV(1))), .u8(2, "x"))
        },
        LastRefusal("a later member of the flags that holds the repeat", followed(0, "field id 1 (x)")) { _ in
            try Scheme(1, .flags(0, repeatV(0), .u8(1, "x")))
        },
        LastRefusal("a later member of the flags around the flags that holds the repeat",
                    followed(0, "field id 1 (x)")) { _ in
            try Scheme(1, .flags(0, .flags(0, repeatV(0)), .u8(1, "x")))
        },
        LastRefusal("a later split flag bit", followed(0, "field id 1 (x)")) { _ in
            let fb = FlagByte("fb")
            return try Scheme(1, .flagByte(fb), fb.bit(repeatV(0)), fb.bit(.u8(1, "x")))
        },
        LastRefusal("a field under an anchored group, not the group", followed(0, "field id 1 (x)")) { _ in
            try Scheme(1, repeatV(0), .group(1, "g", .u8(1, "x")))
        },
        LastRefusal("a field of a nested row, not the row", followed(0, "field id 0 (x)")) { _ in
            try Scheme(1, repeatV(0), .group("g", .u8(0, "x")))
        },
        LastRefusal("a times, by its anchor", followed(1, "times 2")) { _ in
            try Scheme(1, .u8(0, "n"), repeatV(1), .times(2, count: 0, .u8(2, "w")))
        },
        LastRefusal("a repeat whose body cannot write a byte is passed over for the field after it",
                    followed(0, "field id 2 (x)")) { _ in
            try Scheme(1, repeatV(0), .repeat(1, .bytes(1, "z", size: 0)), .u8(2, "x"))
        },
        LastRefusal("a list, by its name", followed(0, "list items")) { _ in
            try Scheme(1, repeatV(0), .list("items", .u8(0, "e")))
        },
        LastRefusal("a dict, by its name", followed(0, "dict d")) { _ in
            try Scheme(1, repeatV(0), .dict("d", .u8(0, "e")))
        },
        LastRefusal("a flags, by its anchor", followed(0, "flags 1")) { _ in
            try Scheme(1, repeatV(0), .flags(1, .u8(1, "x")))
        },
        LastRefusal("a flags under a later split bit, by its anchor", followed(0, "flags 1")) { _ in
            let fb = FlagByte("fb")
            return try Scheme(1, .flagByte(fb), fb.bit(repeatV(0)), fb.bit(.flags(1, .u8(1, "x"))))
        },
        LastRefusal("a split flag byte, by its name", followed(0, "flag byte \"fb\"")) { _ in
            let fb = FlagByte("fb")
            return try Scheme(1, repeatV(0), .flagByte(fb), fb.bit(.u8(1, "x")))
        },
        LastRefusal("a u2, by its first slot", followed(0, "field id 1 (a)")) { _ in
            try Scheme(1, repeatV(0), .u2(.slot(1, "a"), .slot(2, "b")))
        },
        LastRefusal("a zero-width bytes is passed over for the field after it", followed(0, "field id 2 (x)")) { _ in
            try Scheme(1, repeatV(0), .bytes(1, "z", size: 0), .bytes(2, "x", size: 1))
        },
        LastRefusal("a float", followed(0, "field id 1 (f)")) { _ in try Scheme(1, repeatV(0), .f32(1, "f")) },
        LastRefusal("a utf8", followed(0, "field id 1 (s)")) { _ in try Scheme(1, repeatV(0), .utf8(1, "s")) },
        LastRefusal("a sized", followed(1, "field id 2 (p)")) { _ in
            try Scheme(1, .u8(0, "n"), repeatV(1), .sized(2, "p", count: 0))
        },
        LastRefusal("a bits", followed(1, "field id 2 (b)")) { _ in
            try Scheme(1, .u8(0, "n"), repeatV(1), .bits(2, "b", count: 0))
        },
        LastRefusal("a packed", followed(1, "field id 2 (p)")) { _ in
            try Scheme(1, .u8(0, "n"), repeatV(1), .packed(2, 2, "p", count: 0))
        },
    ]

    /// AC-1: "after" is the repeat's own place and every place around it; the refusal names the first
    /// field there that can write a byte.
    @Test(arguments: followers)
    func scheme_fieldAfterARepeat_isRefusedNamingTheFirstFieldThatCanWriteAByte(_ c: LastRefusal) {
        // Arrange
        let build = { try c.build(mapRows) }

        // Act
        let error = packbinError(build)

        // Assert
        #expect(error?.kind == .schemeError)
        #expect(error?.description == c.text)
    }

    static let inElements: [LastRefusal] = [
        LastRefusal("under a when of the element", inElement(1)) { _ in
            try Scheme(1, .list("items", .group("item", .u8(0, "mode"), .when(1, .eq(0, 1), repeatV(1)))))
        },
        LastRefusal("under a flags of the element", inElement(0)) { _ in
            try Scheme(1, .dict("d", .group("item", .flags(0, repeatV(0)))))
        },
        LastRefusal("in a flags element", inElement(0)) { _ in try Scheme(1, .list("items", .flags(0, repeatV(0)))) },
        LastRefusal("under a nested row of the element", inElement(0)) { _ in
            try Scheme(1, .list("items", .group("item", .group("g", repeatV(0)))))
        },
        LastRefusal("under an anchored group of the element", inElement(0)) { _ in
            try Scheme(1, .list("items", .group("item", .group(0, "g", repeatV(0)))))
        },
        LastRefusal("in the element of a list inside a list element", inElement(0)) { _ in
            try Scheme(1, .list("outer", .list("inner", .group("item", repeatV(0)))))
        },
        LastRefusal("in the element of a list inside a times round", inElement(0)) { _ in
            try Scheme(1, .u8(0, "n"), .times(1, count: 0, .list("rows", .group("row", repeatV(0)))))
        },
        LastRefusal("with a field after it in the element: the element text, not the follower text", inElement(0)) { _ in
            try Scheme(1, .list("items", .group("item", repeatV(0), .u8(1, "x"))))
        },
    ]

    /// AC-1: rule 2 of the contract, a repeat directly in an element row or under a when, flags, group
    /// or nested row of it.
    @Test(arguments: inElements)
    func scheme_repeatInsideAListOrDictElement_isRefusedWithTheElementText(_ c: LastRefusal) {
        // Arrange
        let build = { try c.build(mapRows) }

        // Act
        let error = packbinError(build)

        // Assert
        #expect(error?.kind == .schemeError)
        #expect(error?.description == c.text)
    }

    static let kept: [LastKept] = [
        LastKept("K1 a repeat after a field", "01090506", map: { ["x": 9, "v": [5, 6]] },
                 want: ["x": UInt8(9), "v": u8s([5, 6])], typed: LastRow(x: 9, rounds: twoRounds)) { f in
            try Scheme(1, f.x(0), f.rounds(1))
        },
        LastKept("K2 a repeat that is the last thing in a when that nothing follows", "01010506",
                 map: { ["k": 1, "v": [5, 6]] }, want: ["k": UInt8(1), "v": u8s([5, 6])],
                 typed: LastRow(k: 1, rounds: twoRounds)) { f in
            try Scheme(1, f.k(0), .when(1, .eq(0, 1), f.rounds(1)))
        },
        LastKept("K3 a repeat that is the last member of a flags that nothing follows", "0103090506",
                 map: { ["x": 9, "v": [5, 6]] }, want: ["x": UInt8(9), "v": u8s([5, 6])],
                 typed: LastRow(ox: 9, rounds: twoRounds)) { f in
            try Scheme(1, .flags(0, f.optionalX(0), f.rounds(1)))
        },
        LastKept("K4 a times with a field after it", "0102050609", map: { ["k": 2, "v": [5, 6], "x": 9] },
                 want: ["k": UInt8(2), "v": u8s([5, 6]), "x": UInt8(9)],
                 typed: LastRow(k: 2, x: 9, rounds: twoRounds)) { f in
            try Scheme(1, f.k(0), f.counted(1, count: 0), f.x(2))
        },
        LastKept("K5 a bool bit of an earlier flag byte after the repeat (split form)", "0103090506",
                 map: { ["x": 9, "v": [5, 6], "on": true] }, want: ["x": UInt8(9), "v": u8s([5, 6]), "on": true],
                 typed: LastRow(ox: 9, on: true, rounds: twoRounds)) { f in
            let fb = FlagByte("fb")
            return try Scheme(1, .flagByte(fb), fb.bit(f.optionalX(0)), f.rounds(1), fb.bit(f.on(2)))
        },
    ]

    /// AC-2: the cases K1 to K5 of the contract, each with map rows and with typed rows.
    @Test(arguments: kept, LastForm.both)
    func packAndUnpack_repeatThatIsLast_givesTheContractPacketAndTheValues(_ c: LastKept, _ form: LastForm) throws {
        // Arrange
        let scheme = try c.build(form)
        let want = form.typed ? String(describing: Optional(c.typed)) : c.want

        // Act
        let wire = try form.typed ? packHex(scheme, c.typed) : packHex(scheme, c.map())
        let back = try form.typed ? String(describing: unpack(bytes(c.packet), scheme) as? LastRow)
            : canon(unpackMap(bytes(c.packet), scheme))

        // Assert
        #expect(wire == c.packet)
        #expect(back == want)
    }

    static let noByteAfter: [UnpackRow] = [
        UnpackRow("a bool member of the flags after the repeat", {
            try Scheme(1, .flags(0, .u8(0, "x"), repeatV(1), .bool(2, "on")))
        }, "0107090506", want: ["x": UInt8(9), "v": u8s([5, 6]), "on": true], row: { ["x": 9, "v": [5, 6], "on": true] }),
        UnpackRow("an empty group under a later bit of the flag byte", {
            let fb = FlagByte("fb")
            return try Scheme(1, .flagByte(fb), fb.bit(.u8(0, "x")), repeatV(1), fb.bit(.group(2, "mark")))
        }, "0103090506", want: ["x": UInt8(9), "v": u8s([5, 6]), "mark": true],
                  row: { ["x": 9, "v": [5, 6], "mark": true] }),
        UnpackRow("a zero-width bytes", { try Scheme(1, repeatV(0), .bytes(1, "z", size: 0)) }, "010506",
                  want: ["v": u8s([5, 6]), "z": [UInt8]()], row: { ["v": [5, 6], "z": [UInt8]()] }),
        UnpackRow("a when that holds only a zero-width bytes", {
            try Scheme(1, .u8(0, "k"), repeatV(1), .when(2, .eq(0, 1), .bytes(2, "z", size: 0)))
        }, "01010506", want: ["k": UInt8(1), "v": u8s([5, 6]), "z": [UInt8]()],
                  row: { ["k": 1, "v": [5, 6], "z": [UInt8]()] }),
        UnpackRow("a times whose body holds only a zero-width bytes, with no round", {
            try Scheme(1, .u8(0, "n"), repeatV(1), .times(2, count: 0, .bytes(2, "z", size: 0)))
        }, "01000506", want: ["n": UInt8(0), "v": u8s([5, 6])], row: { ["n": 0, "v": [5, 6]] }),
    ]

    /// AC-1 (unit row 2): a field after the repeat that cannot write a byte does not refuse the scheme.
    @Test(arguments: noByteAfter)
    func packAndUnpack_fieldAfterARepeatThatCannotWriteAByte_buildsAndKeepsItsBytes(_ c: UnpackRow) throws {
        // Arrange
        let scheme = try c.scheme()

        // Act
        let back = try unpackMap(bytes(c.wire), scheme)
        let wire = try c.row.map { try packHex(scheme, $0()) }

        // Assert
        #expect(canon(back) == c.want)
        #expect(wire == c.wire)
    }
}
