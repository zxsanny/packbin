import Packbin

/// A scheme a hostile case builds; a builder may throw the scheme's refusal (`.schemeError`), which some
/// cases accept.
typealias HostileBuild = @Sendable () throws -> Scheme

/// fixtures/hostile/cases.txt, unpack stage: the scheme each case names (fixtures/hostile/README.md).
/// The fuzz run reads each case's packet with the same scheme (`fuzzKindSchemes`).
let hostileUnpackSchemes: [String: HostileBuild] = [
    "zero_progress_repeat_bool": { try Scheme(1, .repeat(0, .bool(0, "on"))) },
    "zero_progress_repeat_when": { try Scheme(1, .u8(0, "mode"), .repeat(1, .when(1, .eq(0, 1), .u8(1, "v")))) },
    "negative_count": { try Scheme(1, .i8(0, "n"), .sized(1, "payload", count: 0)) },
    "oversize_count": { try Scheme(1, .u32(0, "n"), .sized(1, "payload", count: 0)) },
    "oversize_count_times": { try Scheme(1, .u32(0, "n"), .times(1, count: 0, .u8(1, "v"))) },
    "oversize_list_count": { try Scheme(1, .list("xs", .u8(0, "x"))) },
    "invalid_utf8": { try Scheme(1, .utf8(0, "name")) },
    "invalid_utf8_dict_key": { try Scheme(1, .dict("m", .u8(0, "v"))) },
    "count_behind_clear_flag": { try Scheme(1, .flags(0, .u8(0, "n")), .sized(1, "payload", count: 0)) },
    "count_behind_clear_flag_bits": { try Scheme(1, .flags(0, .u8(0, "n")), .bits(1, "segs", count: 0)) },
]

/// fixtures/hostile/cases.txt, limit stage: the scheme each case names, at the default limits; the case
/// reads its packet with `hostileLimited` of it.
let hostileLimitSchemes: [String: HostileBuild] = [
    "repeat_rounds_over_limit": { try Scheme(1, .repeat(0, .u8(0, "v"))) },
    "times_rounds_over_limit": { try Scheme(1, .u8(0, "n"), .times(1, count: 0, .u8(1, "v"))) },
]

/// The low limit of the `limit` sections: `maxRounds` 3, the other limits at their defaults.
func hostileLimited(_ s: Scheme) throws -> Scheme { try s.withLimits(maxRounds: 3) }

private func nineU8() -> [Field] { (0..<9).map { Field.u8($0, "f\($0)") } }

private let emptyBody = "the body holds no member; a round of it would charge no slot and write nothing"

/// One construct case: the scheme, which must be refused, and the whole text of the refusal (the rule
/// and the field it names), so an error from a typo in the builder does not pass the case.
struct HostileConstruct: Sendable {
    let build: HostileBuild
    let rule: String
}

/// fixtures/hostile/cases.txt, construct stage. Each text is TypeScript's message after the field it
/// names (TypeScript at HEAD, probed for every case).
let hostileConstructs: [String: HostileConstruct] = [
    "nine_flag_bits": HostileConstruct(
        build: { try Scheme(1, .flags(0, nineU8())) },
        rule: "packbin: invalid scheme at field 8 (f8): flags: ninth bit (f8); a flag byte holds 8 bits"),
    "nine_flag_bits_split": HostileConstruct(
        build: {
            let fb = FlagByte("fb")
            return try Scheme(1, [Field.flagByte(fb)] + nineU8().map { fb.bit($0) })
        },
        rule: "packbin: invalid scheme at field 8 (f8): flag byte \"fb\": ninth bit (f8); a flag byte holds 8 bits"),
    "when_names_later_field": HostileConstruct(
        build: { try Scheme(1, .u8(0, "a"), .when(1, .eq(2, 1), .u8(1, "b")), .u8(2, "c")) },
        rule: "packbin: invalid scheme at field 1: when 1: eq names field id 2, which is not declared earlier in the same scope"),
    "count_names_later_field": HostileConstruct(
        build: { try Scheme(1, .sized(0, "payload", count: 1), .u16(1, "n")) },
        rule: "packbin: invalid scheme at field 0 (payload): sized 0: count names field id 1, which is not declared "
            + "earlier in the same scope"),
    "when_names_outer_field_in_repeat": HostileConstruct(
        build: { try Scheme(1, .u8(0, "mode"), .repeat(1, .when(1, .eq(0, 1), .u8(1, "v")))) },
        rule: "packbin: invalid scheme at field 1: when 1: eq names field id 0, which is not declared earlier in the same scope"),
    "bool_outside_flags": HostileConstruct(
        build: { try Scheme(1, .u8(0, "a"), .bool(1, "on")) },
        rule: "packbin: invalid scheme at field 1 (on): bool on: allowed only directly inside flags or a flag bit; "
            + "move it into flags"),
    "empty_group_outside_flags": HostileConstruct(
        build: { try Scheme(1, .u8(0, "a"), .group(1, "mark")) },
        rule: "packbin: invalid scheme at field 1 (mark): empty group mark: allowed only directly inside flags or a "
            + "flag bit; move it into flags"),
    "eq_bool_false": HostileConstruct(
        build: { try Scheme(1, .flags(0, .bool(0, "on")), .when(1, .eq(0, false), .u8(1, "v"))) },
        rule: "packbin: invalid scheme at field 1: when 1: eq names bool field id 0 (on) and accepts only true, not false"),
    "eq_out_of_range": HostileConstruct(
        build: { try Scheme(1, .u8(0, "a"), .when(1, .eq(0, 300), .u8(1, "v"))) },
        rule: "packbin: invalid scheme at field 1: when 1 tests u8 field 0 ('a') against 300; the value must be a whole "
            + "number from 0 to 255"),
    "construct_empty_times_body": HostileConstruct(
        build: { try Scheme(1, .u8(0, "n"), .times(1, count: 0, [])) },
        rule: "packbin: invalid scheme at field 1: times 1: \(emptyBody)"),
    "construct_empty_repeat_body": HostileConstruct(
        build: { try Scheme(1, .repeat(0, [])) },
        rule: "packbin: invalid scheme at field 0: repeat 0: \(emptyBody)"),
    "construct_empty_round_body_list_element": HostileConstruct(
        build: { try Scheme(1, .list("items", .group("item", .u32(0, "n"), .times(1, count: 0, [])))) },
        rule: "packbin: invalid scheme at field 1: times 1: \(emptyBody)"),
    "construct_empty_when_times_body": HostileConstruct(
        build: { try Scheme(1, .u8(0, "mode"), .u8(1, "c"), .times(2, count: 1, .when(2, .eq(0, 1), []))) },
        rule: "packbin: invalid scheme at field 2: times 2: \(emptyBody)"),
    "construct_empty_when_repeat_body": HostileConstruct(
        build: { try Scheme(1, .u8(0, "mode"), .repeat(1, .when(1, .eq(0, 1), []))) },
        rule: "packbin: invalid scheme at field 1: repeat 1: \(emptyBody)"),
    "construct_empty_nested_when_body": HostileConstruct(
        build: {
            try Scheme(1, .u8(0, "mode"), .u8(1, "c"), .times(2, count: 1, .when(2, .eq(0, 1), .when(2, .eq(0, 1), []))))
        },
        rule: "packbin: invalid scheme at field 2: times 2: \(emptyBody)"),
]
