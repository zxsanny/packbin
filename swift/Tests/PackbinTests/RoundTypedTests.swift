import Packbin
import Testing

struct Point: PackbinRow, Equatable {
    var lat: Int32 = 0
    var lon: Int32 = 0
}

struct Route: PackbinRow, Equatable {
    var n: UInt8 = 0
    var points: [Point]?
    var tail: UInt8 = 0
}

struct Mark: PackbinRow, Equatable {
    var v: UInt8 = 0
}

struct Sample: PackbinRow, Equatable {
    var k: UInt8 = 0
    var on: Bool?
    var n: UInt8?
    var mark: Mark?
    var p: UInt8 = 0
    var q: Int = 0
}

struct Samples: PackbinRow, Equatable {
    var rounds: [Sample] = []
}

struct Counted: PackbinRow, Equatable {
    var n: UInt8 = 0
    var data: [UInt8] = []
    var segs: [UInt8] = []
    var legs: [UInt8] = []
    var a: Int = 0
    var b: UInt8 = 0
}

private let lat = Field.i32(1, "lat").bind(get: { (p: Point) in p.lat }, set: { $0.lat = $1 })
private let lon = Field.i32(2, "lon").bind(get: { (p: Point) in p.lon }, set: { $0.lon = $1 })
private let routeN = Field.u8(0, "n").bind(get: { (r: Route) in r.n }, set: { $0.n = $1 })

@Sendable func typedRouteScheme() throws -> Scheme {
    try Scheme(1, routeN,
               Field.times(1, count: 0, lat, lon).bind(get: { (r: Route) in r.points }, set: { $0.points = $1 }),
               Field.u8(3, "tail").bind(get: { (r: Route) in r.tail }, set: { $0.tail = $1 }))
}

/// repeat { u8 k; flags { bool on; u8 n; group mark { u8 v } }; u2 { p; q } }
@Sendable func samplesScheme() throws -> Scheme {
    let mark = Field.group(3, "mark", Field.u8(3, "v").bind(get: { (m: Mark) in m.v }, set: { $0.v = $1 }))
    return try Scheme(1, Field.repeat(0,
        Field.u8(0, "k").bind(get: { (s: Sample) in s.k }, set: { $0.k = $1 }),
        .flags(1, Field.bool(1, "on").bind(get: { (s: Sample) in s.on }, set: { $0.on = $1 }),
               Field.u8(2, "n").bind(get: { (s: Sample) in s.n }, set: { $0.n = $1 }),
               mark.bind(get: { (s: Sample) in s.mark }, set: { $0.mark = $1 })),
        .u2(Field.slot(4, "p").bind(get: { (s: Sample) in s.p }, set: { $0.p = $1 }),
            Field.slot(5, "q").bind(get: { (s: Sample) in s.q }, set: { $0.q = $1 })))
        .bind(get: { (r: Samples) in r.rounds }, set: { $0.rounds = $1 }))
}

/// AC-2 (SW-3, S8): a typed round binds an array of a ``PackbinRow``, one element a round (as Go, C#
/// and Rust; TypeScript rows are objects of per-name lists). The typed row and the map form give the
/// same bytes.
@Suite struct RoundTypedTests {
    @Test func packAndUnpack_typedTimesRoute_givesTheReadmeHexAndTheSameRow() throws {
        // Arrange
        let scheme = try typedRouteScheme()
        let row = Route(n: 2, points: [Point(lat: 10, lon: 20), Point(lat: 30, lon: 40)], tail: 7)
        let want = "01020a000000140000001e0000002800000007"

        // Act
        let wire = try packHex(scheme, row)
        let back = try unpack(bytes(want), scheme) as? Route
        let asMap = try packHex(scheme, ["n": 2, "lat": [10, 30], "lon": [20, 40], "tail": 7])

        // Assert
        #expect(wire == want && asMap == want)
        #expect(back == row)
    }

    @Test func packAndUnpack_typedRepeatWithOptionalMembersAGroupAndSlots_matchesTheMapForm() throws {
        // Arrange
        let scheme = try samplesScheme()
        let row = Samples(rounds: [Sample(k: 1, on: true, n: 9, p: 1, q: 2), Sample(k: 2, mark: Mark(v: 7), p: 3)])
        let asMap: [String: Any] = ["k": [1, 2], "on": [true, nil] as [Bool?], "n": [9, nil] as [Int?],
                                    "mark": [nil, ["v": 7]] as [[String: Any]?], "p": [1, 3], "q": [2, 0]]

        // Act
        let wire = try packHex(scheme, row)
        let mapWire = try packHex(scheme, asMap)
        let back = try unpack(bytes(wire), scheme) as? Samples

        // Assert
        #expect(wire == "010103090902040703")
        #expect(mapWire == wire)
        #expect(back == row)
    }

    /// SW-12: a `nil` array is no value and an empty array 0 rounds; both write no round. Unpack gives
    /// an empty array for a round read with 0 rounds, and `nil` for a round that was not read.
    @Test func packAndUnpack_typedRoundNilAndEmpty_writeNoRoundAndReadBackApart() throws {
        // Arrange
        struct Opt: PackbinRow, Equatable {
            var mode: UInt8 = 0
            var points: [Point]?
        }
        let scheme = try Scheme(1, Field.u8(0, "mode").bind(get: { (r: Opt) in r.mode }, set: { $0.mode = $1 }),
                                .flags(1, Field.repeat(1, lat, lon).bind(get: { (r: Opt) in r.points }, set: { $0.points = $1 })))
        let route = try typedRouteScheme()

        // Act
        let nilWire = try packHex(scheme, Opt(mode: 1))
        let emptyWire = try packHex(scheme, Opt(mode: 1, points: []))
        let clear = try unpack(bytes("010100"), scheme) as? Opt
        let zero = try unpack(bytes("010007"), route) as? Route

        // Assert
        #expect(nilWire == "010100" && emptyWire == "010100")
        #expect(clear?.points == nil)
        #expect(zero?.points == [])
    }

    /// A typed times holds one element a round, so a count other than the elements is refused naming
    /// the member (as C# and Go); count 0 with a `nil` array packs.
    @Test func pack_typedTimesCountOtherThanTheElements_isRefusedNamingTheMember() throws {
        // Arrange
        let scheme = try typedRouteScheme()

        // Act
        let errors = [Route(n: 3, points: [Point(lat: 1, lon: 2), Point(lat: 3, lon: 4)]), Route(n: 2),
                      Route(n: 1, points: [Point(lat: 1, lon: 2), Point(lat: 3, lon: 4)])]
            .map { row in packbinError { try pack(scheme, row) } }
        let zero = try packHex(scheme, Route(n: 0, tail: 5))

        // Assert
        for e in errors {
            #expect(e?.kind == .packError && e?.field == 1 && e?.name == "lat" && e?.reason.contains("the times count") == true)
        }
        #expect(zero == "010005")
    }

    @Test func packAndUnpack_typedCountedKinds_bindByteArraysAndSlotIntegers() throws {
        // Arrange
        let scheme = try Scheme(1,
            Field.u8(0, "n").bind(get: { (r: Counted) in r.n }, set: { $0.n = $1 }),
            Field.sized(1, "data", count: 0).bind(get: { (r: Counted) in r.data }, set: { $0.data = $1 }),
            Field.bits(2, "segs", count: 0).bind(get: { (r: Counted) in r.segs }, set: { $0.segs = $1 }),
            Field.packed(2, 3, "legs", count: 0, bias: -1).bind(get: { (r: Counted) in r.legs }, set: { $0.legs = $1 }),
            .u2(Field.slot(4, "a").bind(get: { (r: Counted) in r.a }, set: { $0.a = $1 }),
                Field.slot(5, "b").bind(get: { (r: Counted) in r.b }, set: { $0.b = $1 })))
        let row = Counted(n: 3, data: Array("uav".utf8), segs: [1, 0, 1], legs: [3, 2], a: 2, b: 3)

        // Act
        let wire = try packHex(scheme, row)
        let asMap = try packHex(scheme, ["n": 3, "data": Array("uav".utf8), "segs": [1, 0, 1], "legs": [3, 2], "a": 2, "b": 3])
        let back = try unpack(bytes(wire), scheme) as? Counted

        // Assert
        #expect(wire == "0103756176050b0e" && asMap == wire)
        #expect(back == row)
    }

    static let bindings: [RefusedScheme] = [
        RefusedScheme("not an array", field: 1, "", "a Point member cannot hold the rounds of times 1; bind an array of a PackbinRow") {
            try Scheme(1, routeN, Field.times(1, count: 0, lat).bind(get: { (_: Route) in Point() }, set: { _, _ in }))
        },
        RefusedScheme("an array of numbers", field: 1, "", "a Array<Int> member cannot hold the rounds of times 1; "
                      + "bind an array of a PackbinRow") {
            try Scheme(1, routeN, Field.times(1, count: 0, lat).bind(get: { (_: Route) in [Int]() }, set: { _, _ in }))
        },
        RefusedScheme("members unbound", field: 1, "lat", "not bound to row type Point (the row of times 1); "
                      + "bind every value field of a scheme, or none") {
            try Scheme(1, routeN, Field.times(1, count: 0, .i32(1, "lat")).bind(get: { (r: Route) in r.points },
                                                                               set: { $0.points = $1 }))
        },
        RefusedScheme("members bound to another row type", field: 1, "v", "bound to row type Mark, but its times 1 is bound to Point") {
            try Scheme(1, routeN, Field.times(1, count: 0, Field.u8(1, "v").bind(get: { (m: Mark) in m.v }, set: { $0.v = $1 }))
                .bind(get: { (r: Route) in r.points }, set: { $0.points = $1 }))
        },
        RefusedScheme("round unbound in a typed scheme", field: 1, "", "not bound to row type Route; bind every value field "
                      + "of a scheme, or none") {
            try Scheme(1, routeN, .times(1, count: 0, lat))
        },
        RefusedScheme("round members bound, round not", field: 0, "lat", "bound to row type Point, but its repeat 0 is not bound") {
            try Scheme(1, .repeat(0, Field.i32(0, "lat").bind(get: { (p: Point) in p.lat }, set: { $0.lat = $1 })))
        },
        RefusedScheme("a u2 is not bound itself", field: 0, "a", "bind takes a value field, not u2") {
            try Scheme(1, Field.u2(.slot(0, "a")).bind(get: { (r: Mark) in r.v }, set: { $0.v = $1 }))
        },
        RefusedScheme("sized bound to an integer", field: 1, "data", "a UInt8 member cannot hold sized; bind a [UInt8]") {
            try Scheme(1, Field.u8(0, "n").bind(get: { (r: Counted) in r.n }, set: { $0.n = $1 }),
                       Field.sized(1, "data", count: 0).bind(get: { (r: Counted) in r.n }, set: { $0.n = $1 }))
        },
    ]

    @Test(arguments: bindings)
    func scheme_roundOrCountedKindBoundToAMemberThatCannotHoldIt_isRefused(_ c: RefusedScheme) { expectRefused(c) }
}
