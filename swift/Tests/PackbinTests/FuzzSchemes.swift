import Packbin

/// The schemes the fuzz run reads every input with, each under its own type number so one call can
/// dispatch among all of them: the ring kinds of .github/workflows/language-pair.sh, the golden
/// position, and one scheme for each kind of field a hostile packet can aim at (rounds with and without
/// low limits, counted fields, groups, flags, nested rows, list and dict elements). As Go's
/// `fuzzSchemes`, with three Swift shapes added (19 to 21).
@Sendable func fuzzSchemes() throws -> [Scheme] {
    let fb = FlagByte("m")
    let wide = (0..<40).map { Field.u8($0 + 1, "w\($0)") }
    let low = { (s: Scheme) in try s.withLimits(maxRounds: 3, maxSlots: 8) }
    return [
        try Scheme(1, .utf8(0, "username"), .list("roles", .utf8(0, "role")), .dict("access", .list("ops", .utf8(0, "op")))),
        try Scheme(2, .dict("access", .list("rows", .dict("row", .utf8(0, "v"))))),
        try Scheme(3, .flags(0, .bool(0, "on"))),
        try Scheme(4, .u8(0, "k"), .flagByte(fb), .when(1, .eq(0, 1), fb.bit(.u8(1, "v")))),
        try Scheme(5, .repeat(0, .flags(0, .bool(0, "on"), .u8(1, "n")))),
        try Scheme(6, .repeat(0, .u8(0, "k"), .when(1, .eq(0, 1), .u8(1, "v")))),
        try Scheme(7, .list("pts", .group("p", .u8(0, "a"), .u8(1, "b")))),
        try Scheme(8, .dict("m", .group("p", .u8(0, "a"), .u8(1, "b")))),
        try Scheme(9, .list("pts", .flags(0, .u8(0, "a"), .u16(1, "b")))),
        try Scheme(10, .u8(0, "n"), .times(1, count: 0, .u8(1, "v"), .utf8(2, "s"))),
        try low(Scheme(11, .u8(0, "n"), .times(1, count: 0, .u8(1, "v"), .utf8(2, "s")))),
        try Scheme(12, .u8(0, "n"), .sized(1, "raw", count: 0), .u8(2, "c"), .bits(3, "b", count: 2), .u8(4, "d"),
                   .packed(2, 5, "p", count: 4, bias: -1), .u2(.slot(6, "s0"), .slot(7, "s1"))),
        try Scheme(13, .repeat(0, .u8(0, "k"), .list("xs", .u8(0, "e")))),
        try low(Scheme(14, .repeat(0, .u8(0, "k")))),
        try Scheme(15, .repeat(0, [.u8(0, "k"), .when(1, .eq(0, 1), wide)])),
        try Scheme(16, .u8(0, "a"), .flags(1, .group(1, "g", .u8(1, "x"), .u8(2, "y")), .u8(3, "z"))),
        try Scheme(17, .u32(0, "n"), .times(1, count: 0, .u8(1, "v"))),
        try Scheme(18, .list("items", .group("item", .u8(0, "n"), .times(1, count: 0, .u16(1, "k"))))),
        // A nested row in a round, a count from an i64, and a dict of nested rows that hold a split bit.
        try Scheme(19, .repeat(0, .u8(0, "a"), .group("g", .u8(0, "a"), .when(1, .eq(0, 1), .u8(1, "y"))))),
        try Scheme(20, .i64(0, "n"), .bits(1, "b", count: 0), .times(2, count: 0, .flags(2, .bool(2, "on"), .u16(3, "v")))),
        try Scheme(21, .dict("d", .group("row", .flagByte(fb), .u8(0, "k"), fb.bit(.sized(1, "s", count: 0))))),
        try positionMapScheme(),
    ]
}

/// The bound schemes, read one at a time with the typed `unpack` (each fills its row type).
@Sendable func fuzzTypedSchemes() throws -> [Scheme] {
    [try positionTypedScheme(), try typedRouteScheme(), try samplesScheme()]
}

/// The scheme of each corpus kind (fixtures/hostile/fuzz/README.md): the ring kinds, the golden
/// position, and each hostile `unpack` and `limit` case of fixtures/hostile/README.md. A `limit` case
/// is read with its limit and with the defaults. A case whose scheme Swift refuses at construction
/// (a bool outside flags, a when naming a field outside its repeat) has none: its input is read with the
/// fuzz schemes only.
@Sendable func fuzzKindSchemes() throws -> [String: [Scheme]] {
    let fb = FlagByte("m")
    var kinds: [String: [Scheme]] = [
        "user": [try userScheme()],
        "nested": [try nestedRingScheme()],
        "boolflag": [try Scheme(1, .flags(0, .bool(0, "on")))],
        "booltrue": [try Scheme(1, .flags(0, .bool(0, "on")))],
        "bitwhen": [try Scheme(1, .u8(0, "k"), .flagByte(fb), .when(1, .eq(0, 1), fb.bit(.u8(1, "v"))))],
        "roundflags": [try Scheme(1, .repeat(0, .flags(0, .bool(0, "on"), .u8(1, "n"))))],
        "roundwhen": [try Scheme(1, .repeat(0, .u8(0, "k"), .when(1, .eq(0, 1), .u8(1, "v"))))],
        "listgroup": [try pairList()],
        "dictgroup": [try pairDict()],
        "listflags": [try flagsList()],
        "position": [try positionMapScheme(), try positionTypedScheme()],
        "any": [],
    ]
    for (kind, build) in hostileLimitSchemes {
        let s = try build()
        kinds[kind] = [s, try hostileLimited(s)]
    }
    for (kind, build) in hostileUnpackSchemes {
        do {
            kinds[kind] = [try build()]
        } catch let error as PackbinError where error.kind == .schemeError {
            kinds[kind] = []
        }
    }
    return kinds
}
