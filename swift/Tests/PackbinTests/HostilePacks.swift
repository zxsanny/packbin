import Packbin

/// One pack case: the scheme and the map row its section names (fixtures/hostile/README.md). The case
/// file says whether bytes or a refusal comes out.
struct HostilePack: Sendable {
    let scheme: HostileBuild
    let row: @Sendable () -> [String: Any]

    init(_ scheme: @escaping HostileBuild, _ row: @escaping @Sendable () -> [String: Any]) {
        self.scheme = scheme
        self.row = row
    }
}

/// u8 a; times(a) { u8 x }
@Sendable private func timesX() throws -> Scheme { try Scheme(1, .u8(0, "a"), .times(1, count: 0, .u8(1, "x"))) }

/// Split-form flag byte first; u8 n after it; bit 0 { times(n) { u8 pt } }; `tail` adds bits after it.
private func splitCount(_ tail: @escaping @Sendable (FlagByte) -> [Field] = { _ in [] }) -> HostileBuild {
    {
        let fb = FlagByte("fb")
        return try Scheme(1, [.flagByte(fb), .u8(0, "n"), fb.bit(.times(1, count: 0, .u8(1, "pt")))] + tail(fb))
    }
}

/// u8 mode and a split-form flag byte, the mode before the byte when `modeFirst`; bit 0 holds `body`,
/// `tail` adds the bits after it.
private func splitWhen(modeFirst: Bool, _ body: @escaping @Sendable () -> Field,
                       _ tail: @escaping @Sendable (FlagByte) -> [Field] = { _ in [] }) -> HostileBuild {
    {
        let fb = FlagByte("fb")
        let head: [Field] = modeFirst ? [.u8(0, "mode"), .flagByte(fb)] : [.flagByte(fb), .u8(0, "mode")]
        return try Scheme(1, head + [fb.bit(body())] + tail(fb))
    }
}

/// u8 n; times(n) { u8 a }; repeat { u8 b }, maxSlots 3: each round of either container charges one slot.
@Sendable private func mixedRounds() throws -> Scheme {
    try Scheme(1, .u8(0, "n"), .times(1, count: 0, .u8(1, "a")), .repeat(2, .u8(2, "b"))).withLimits(maxSlots: 3)
}

/// repeat { flags { bool on; u8 v } }, maxSlots 4: a round holds the two names on and v.
@Sendable private func flagsRound() throws -> Scheme {
    try Scheme(1, .repeat(0, .flags(0, .bool(0, "on"), .u8(1, "v")))).withLimits(maxSlots: 4)
}

/// repeat { u8 w; flags { u8 v } }
@Sendable private func optionalRepeat() throws -> Scheme { try Scheme(1, .repeat(0, .u8(0, "w"), .flags(1, .u8(1, "v")))) }

/// u8 mode; when mode == 1 { u8 c }; then `member`, counted by c.
private func clearWhenCount(_ member: Field) -> HostileBuild {
    { try Scheme(1, .u8(0, "mode"), .when(1, .eq(0, 1), .u8(1, "c")), member) }
}

/// u8 mode; when mode == 1 { u8 c }; split-form flag byte; bit 0 { `member`, counted by c }.
private func novalueCount(_ member: Field) -> HostileBuild {
    {
        let fb = FlagByte("fb")
        return try Scheme(1, .u8(0, "mode"), .when(1, .eq(0, 1), .u8(1, "c")), .flagByte(fb), fb.bit(member))
    }
}

/// u8 mode; when mode == 1 { u16 a; u8 k }; when k == `value` { u8 b }: the source k sits inside a clear when.
private func skippedSourceWhen(_ value: Int) -> HostileBuild {
    {
        try Scheme(1, .u8(0, "mode"), .when(1, .eq(0, 1), .u16(1, "a"), .u8(2, "k")),
                   .when(3, .eq(2, value), .u8(3, "b")))
    }
}

private func skippedSourceRow(_ k: Int) -> @Sendable () -> [String: Any] {
    { ["mode": 0, "a": 7, "k": k, "b": 5] }
}

/// `count` items, each `item`.
private func items(_ count: Int, _ item: [String: Any]) -> [String: Any] {
    ["items": [Any](repeating: item, count: count)]
}

private let clearWhenRow: @Sendable () -> [String: Any] = { ["mode": 0, "c": 3, "v": [1, 0, 1]] }
private let novalueRow: @Sendable () -> [String: Any] = { ["mode": 0, "c": 3] }

/// fixtures/hostile/cases.txt, pack stage: every row in the map form, a list as an `[Any]` (`[Any?]`
/// where an entry is absent), a group's members in a nested map under its name.
let hostilePacks: [String: HostilePack] = [
    "pack_out_of_range_integer": HostilePack({ try Scheme(1, .u8(0, "a")) }, { ["a": 300] }),
    "pack_missing_required_value": HostilePack({ try Scheme(1, .u8(0, "a"), .u8(1, "b")) }, { ["a": 1] }),
    "pack_times_list_too_long": HostilePack(timesX, { ["a": 2, "x": [1, 2, 3]] }),
    "pack_times_list_too_short": HostilePack(timesX, { ["a": 2, "x": [1]] }),
    "pack_aligned_round_row": HostilePack(
        { try Scheme(1, .repeat(0, .flags(0, .bool(0, "on"), .u8(1, "n")))) },
        { ["on": [true, false, true], "n": [1, 2, 3]] }),
    "pack_times_count_over_limit": HostilePack(
        { try Scheme(1, .u32(0, "n"), .times(1, count: 0, .u8(1, "x"))) }, { ["n": 65_536, "x": 7] }),
    "pack_times_zero_with_values": HostilePack(timesX, { ["a": 0, "x": [5]] }),
    "pack_split_when_source_after_byte": HostilePack(
        splitWhen(modeFirst: false, { .when(1, .eq(0, 1), .u8(1, "speed")) }), { ["mode": 1, "speed": 7] }),
    "pack_split_times_count_after_byte": HostilePack(splitCount(), { ["n": 2, "pt": [5, 6]] }),
    "pack_split_times_count_skipped": HostilePack(
        {
            let fb = FlagByte("fb")
            return try Scheme(1, .u8(0, "sel"), .flagByte(fb), .when(1, .eq(0, 1), .u8(1, "n")),
                              fb.bit(.times(2, count: 1, .u8(2, "pt"))))
        },
        { ["sel": 0, "pt": [5]] }),
    "pack_lone_bytes_in_round": HostilePack(
        { try Scheme(1, .u8(0, "n"), .times(1, count: 0, .bytes(1, "d", size: 2))) }, { ["n": 2, "d": [UInt8(1), 2]] }),
    "pack_split_false_condition_silent": HostilePack(
        splitWhen(modeFirst: true, { .when(1, .eq(0, 1), .u8(1, "speed")) }, { [$0.bit(.u16(2, "heading"))] }),
        { ["mode": 0, "speed": 7, "heading": 90] }),
    "pack_lone_utf8_under_times_over_budget": HostilePack(
        { try Scheme(1, .u32(0, "n"), .times(1, count: 0, .utf8(1, "s"))) },
        { ["n": 65_535, "s": String(repeating: "q", count: 65_535)] }),
    "pack_element_times_over_budget": HostilePack(
        { try Scheme(1, .list("items", .group("item", .u32(0, "n"), .times(1, count: 0, .u64(1, "k"))))) },
        { items(40, ["n": 65_535, "k": 5]) }),
    "pack_slots_over_limit": HostilePack({ try wideRound().0 }, {
        var row: [String: Any] = ["n": 65_535]
        for i in 0..<65 { row["m\(i)"] = 1 }
        return row
    }),
    "pack_repeat_over_limit": HostilePack(repeatK, { ["k": rounds(65_536, 7)] }),
    "pack_split_count_zero_after_byte_list": HostilePack(splitCount(), { ["n": 0, "pt": [5, 6]] }),
    "pack_split_count_zero_after_byte_scalar": HostilePack(splitCount(), { ["n": 0, "pt": 5] }),
    "pack_flags_skipped_count_with_values": HostilePack(
        { try Scheme(1, .flags(0, .u8(0, "n"), .times(1, count: 0, .u8(1, "pt")))) }, { ["pt": [5, 6]] }),
    "pack_round_slots_at_limit": HostilePack(mixedRounds, { ["n": 1, "a": [1], "b": [2, 3]] }),
    "pack_round_slots_over_limit": HostilePack(mixedRounds, { ["n": 1, "a": [1], "b": [2, 3, 4]] }),
    "pack_round_slots_flags_at_limit": HostilePack(flagsRound, { ["on": [true, true], "v": [5, 6]] }),
    "pack_round_slots_flags_over_limit": HostilePack(flagsRound, { ["on": [true, true, true], "v": [5, 6, 7]] }),
    "pack_flags_short_list": HostilePack(optionalRepeat, { ["w": [1, 2], "v": [5]] }),
    "pack_flags_short_list_filled": HostilePack(optionalRepeat, { ["w": [1, 2], "v": [5, nil] as [Any?]] }),
    "pack_split_times_absent_body": HostilePack(splitCount { [$0.bit(.u16(2, "heading"))] }, { ["n": 2, "heading": 90] }),
    "pack_late_when_in_bit_body": HostilePack(
        splitWhen(modeFirst: false, {
            .group(1, "g", .u8(1, "d"), .when(2, .eq(0, 1), .u8(2, "a")), .when(3, .eq(0, 2), .u8(3, "b")))
        }),
        { ["mode": 1, "g": ["d": 5, "a": 9] as [String: Any]] }),
    "pack_count_one_clear_when": HostilePack(
        {
            let fb = FlagByte("fb")
            return try Scheme(1, .u8(0, "mode"), .when(1, .eq(0, 1), .u8(1, "c")), .flagByte(fb),
                              fb.bit(.times(2, count: 1, .u8(2, "pt"))), fb.bit(.u16(3, "heading")))
        },
        { ["mode": 0, "c": 1, "heading": 90] }),
    "pack_bits_count_clear_when": HostilePack(clearWhenCount(.bits(2, "v", count: 1)), clearWhenRow),
    "pack_packed_count_clear_when": HostilePack(clearWhenCount(.packed(1, 2, "v", count: 1)), clearWhenRow),
    "pack_sized_count_clear_when": HostilePack(
        clearWhenCount(.sized(2, "v", count: 1)), { ["mode": 0, "c": 3, "v": [UInt8(1), 2, 3]] }),
    "pack_novalue_count_clear_when_bits": HostilePack(novalueCount(.bits(2, "v", count: 1)), novalueRow),
    "pack_novalue_count_clear_when_packed": HostilePack(novalueCount(.packed(1, 2, "v", count: 1)), novalueRow),
    "pack_novalue_count_clear_when_sized": HostilePack(novalueCount(.sized(2, "v", count: 1)), novalueRow),
    "pack_repeat_unequal_lists_lone": HostilePack(
        { try Scheme(1, .repeat(0, .u8(0, "a"), .u8(1, "b"))) }, { ["a": [1, 2], "b": 7] }),
    "pack_repeat_unequal_lists_when": HostilePack(
        { try Scheme(1, .repeat(0, .u8(0, "k"), .when(1, .eq(0, 1), .u8(1, "v")))) }, { ["k": [1, 2], "v": [9]] }),
    "pack_times_short_list_flags": HostilePack(
        { try Scheme(1, .u8(0, "c"), .times(1, count: 0, .flags(1, .u8(1, "v")))) }, { ["c": 2, "v": [5]] }),
    "pack_element_times_over_bytes_budget": HostilePack(
        { try Scheme(1, .list("items", .group("item", .u32(0, "n"), .times(1, count: 0, .utf8(1, "s"))))) },
        { items(16, ["n": 65_535, "s": String(repeating: "q", count: 16)]) }),
    "pack_when_of_skipped_source": HostilePack(skippedSourceWhen(2), skippedSourceRow(2)),
    "pack_when_of_skipped_source_zero": HostilePack(skippedSourceWhen(0), skippedSourceRow(0)),
]
