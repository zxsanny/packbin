import {
  BinaryPacker, bits, bool, bytes, eq, flagByte, flags, group, list, packed, repeat, scheme, sized, times, u32, u64, u8, u16, utf8, when,
} from "../../src/index.ts"

type Row = Record<string, unknown>

// fixtures/hostile/cases.txt, pack stage: the scheme and row each case id names, written from
// fixtures/hostile/README.md. Each entry packs the row; the case file says whether bytes or a refusal is expected.
const timesScheme = () => scheme<Row>(1, u8(0, (x) => x.a), times(1, 0, [u8(1, (x) => x.x)]))

const splitWhenSource = () => {
  const fb = flagByte("fb")
  return scheme<Row>(
    1,
    fb,
    u8(0, (x) => x.mode),
    fb.bit(when(1, eq(0, 1), [u8(1, (x) => x.speed)])),
  )
}

const splitCountAfterByte = () => {
  const fb = flagByte("fb")
  return scheme<Row>(1, fb, u8(0, (x) => x.n), fb.bit(times(1, 0, [u8(1, (x) => x.pt)])))
}

const slotsScheme = () => scheme<Row>(
  1,
  u32(0, (x) => x.n),
  times(1, 0, [
    u8(1, (x) => x.m0), u8(2, (x) => x.m1), u8(3, (x) => x.m2), u8(4, (x) => x.m3), u8(5, (x) => x.m4),
    u8(6, (x) => x.m5), u8(7, (x) => x.m6), u8(8, (x) => x.m7), u8(9, (x) => x.m8), u8(10, (x) => x.m9),
    u8(11, (x) => x.m10), u8(12, (x) => x.m11), u8(13, (x) => x.m12), u8(14, (x) => x.m13),
    u8(15, (x) => x.m14), u8(16, (x) => x.m15), u8(17, (x) => x.m16), u8(18, (x) => x.m17),
    u8(19, (x) => x.m18), u8(20, (x) => x.m19), u8(21, (x) => x.m20), u8(22, (x) => x.m21),
    u8(23, (x) => x.m22), u8(24, (x) => x.m23), u8(25, (x) => x.m24), u8(26, (x) => x.m25),
    u8(27, (x) => x.m26), u8(28, (x) => x.m27), u8(29, (x) => x.m28), u8(30, (x) => x.m29),
    u8(31, (x) => x.m30), u8(32, (x) => x.m31), u8(33, (x) => x.m32), u8(34, (x) => x.m33),
    u8(35, (x) => x.m34), u8(36, (x) => x.m35), u8(37, (x) => x.m36), u8(38, (x) => x.m37),
    u8(39, (x) => x.m38), u8(40, (x) => x.m39), u8(41, (x) => x.m40), u8(42, (x) => x.m41),
    u8(43, (x) => x.m42), u8(44, (x) => x.m43), u8(45, (x) => x.m44), u8(46, (x) => x.m45),
    u8(47, (x) => x.m46), u8(48, (x) => x.m47), u8(49, (x) => x.m48), u8(50, (x) => x.m49),
    u8(51, (x) => x.m50), u8(52, (x) => x.m51), u8(53, (x) => x.m52), u8(54, (x) => x.m53),
    u8(55, (x) => x.m54), u8(56, (x) => x.m55), u8(57, (x) => x.m56), u8(58, (x) => x.m57),
    u8(59, (x) => x.m58), u8(60, (x) => x.m59), u8(61, (x) => x.m60), u8(62, (x) => x.m61),
    u8(63, (x) => x.m62), u8(64, (x) => x.m63), u8(65, (x) => x.m64),
  ]),
)

// repeat { u8 w; flags { u8 v } }
const optionalRepeat = () => scheme<Row>(1, repeat(0, [u8(0, (x) => x.w), flags(1, [u8(1, (x) => x.v)])]))

// repeat { flags { bool on; u8 v } }: a round holds the two names on and v, whatever the flags byte is.
const flagsRound = () => scheme<Row>(1, repeat(0, [flags(0, [bool(0, (x) => x.on), u8(1, (x) => x.v)])])).withLimits({ maxSlots: 4 })

// u8 n; times(n) { u8 a }; repeat { u8 b }: each round of either container charges one slot.
const mixedRounds = () => scheme<Row>(
  1,
  u8(0, (x) => x.n),
  times(1, 0, [u8(1, (x) => x.a)]),
  repeat(2, [u8(2, (x) => x.b)]),
).withLimits({ maxSlots: 3 })

// flag byte first; u8 n after it; bit 0 { times(n) { u8 pt } }; bit 1 { u16 heading }
const splitTimesBody = () => {
  const fb = flagByte("fb")
  return scheme<Row>(1, fb, u8(0, (x) => x.n), fb.bit(times(1, 0, [u8(1, (x) => x.pt)])), fb.bit(u16(2, (x) => x.heading)))
}

// u8 mode; when mode == 1 { u8 c }, then the counted member `after(1)` whose count is c.
const clearWhenCount = (after: (countId: number) => ReturnType<typeof bits>) =>
  scheme<Row>(1, u8(0, (x) => x.mode), when(1, eq(0, 1), [u8(1, (x) => x.c)]), after(1))

// id0 u8 mode; id1 when eq(0, 1) { id1 u8 c }; split-form flag byte; bit 0 { id2 <member>, count = id1 }, row without a value.
function novalueCount(member: (countId: number) => ReturnType<typeof bits>): () => Uint8Array {
  return () => {
    const fb = flagByte("fb")
    return BinaryPacker.pack(
      scheme<Row>(1, u8(0, (x) => x.mode), when(1, eq(0, 1), [u8(1, (x) => x.c)]), fb, fb.bit(member(1))),
      { mode: 0, c: 3 },
    )
  }
}

const novalueCountCases = (): Record<string, () => Uint8Array> => ({
  pack_novalue_count_clear_when_bits: novalueCount((c) => bits(2, (x) => x.v, c)),
  pack_novalue_count_clear_when_packed: novalueCount((c) => packed(1, 2, (x) => x.v, c)),
  pack_novalue_count_clear_when_sized: novalueCount((c) => sized(2, (x) => x.v, c)),
})

export const PACK: Record<string, () => Uint8Array> = {
  pack_lone_utf8_under_times_over_budget: () => BinaryPacker.pack(
    scheme<Row>(1, u32(0, (x) => x.n), times(1, 0, [utf8(1, (x) => x.s)])),
    { n: 65535, s: "a".repeat(65535) },
  ),
  pack_element_times_over_budget: () => BinaryPacker.pack(
    scheme<Row>(
      1,
      list((x) => x.items, group((x) => x.item, [u32(0, (x) => x.n), times(1, 0, [u64(1, (x) => x.k)])])),
    ),
    { items: Array.from({ length: 40 }, () => ({ n: 65535, k: 5n })) },
  ),
  pack_slots_over_limit: () => BinaryPacker.pack(
    slotsScheme(),
    { n: 65535, ...Object.fromEntries(Array.from({ length: 65 }, (_, i) => [`m${i}`, 1])) },
  ),
  pack_repeat_over_limit: () => BinaryPacker.pack(
    scheme<Row>(1, repeat(0, [u8(0, (x) => x.k)])),
    { k: new Array<number>(65536).fill(7) },
  ),
  pack_split_count_zero_after_byte_list: () => BinaryPacker.pack(splitCountAfterByte(), { n: 0, pt: [5, 6] }),
  pack_split_count_zero_after_byte_scalar: () => BinaryPacker.pack(splitCountAfterByte(), { n: 0, pt: 5 }),
  pack_flags_skipped_count_with_values: () => BinaryPacker.pack(
    scheme<Row>(1, flags(0, [u8(0, (x) => x.n), times(1, 0, [u8(1, (x) => x.pt)])])),
    { pt: [5, 6] },
  ),
  pack_out_of_range_integer: () => BinaryPacker.pack(scheme<Row>(1, u8(0, (x) => x.a)), { a: 300 }),
  pack_missing_required_value: () => BinaryPacker.pack(
    scheme<Row>(1, u8(0, (x) => x.a), u8(1, (x) => x.b)),
    { a: 1 },
  ),
  pack_times_list_too_long: () => BinaryPacker.pack(timesScheme(), { a: 2, x: [1, 2, 3] }),
  pack_times_list_too_short: () => BinaryPacker.pack(timesScheme(), { a: 2, x: [1] }),
  pack_aligned_round_row: () => BinaryPacker.pack(
    scheme<Row>(1, repeat(0, [flags(0, [bool(0, (x) => x.on), u8(1, (x) => x.n)])])),
    { on: [true, false, true], n: [1, 2, 3] },
  ),
  pack_times_count_over_limit: () => BinaryPacker.pack(
    scheme<Row>(1, u32(0, (x) => x.n), times(1, 0, [u8(1, (x) => x.x)])),
    { n: 65536, x: 7 },
  ),
  pack_times_zero_with_values: () => BinaryPacker.pack(timesScheme(), { a: 0, x: [5] }),
  pack_split_when_source_after_byte: () => BinaryPacker.pack(splitWhenSource(), { mode: 1, speed: 7 }),
  pack_split_times_count_after_byte: () => {
    const fb = flagByte("fb")
    return BinaryPacker.pack(
      scheme<Row>(1, fb, u8(0, (x) => x.n), fb.bit(times(1, 0, [u8(1, (x) => x.pt)]))),
      { n: 2, pt: [5, 6] },
    )
  },
  pack_split_times_count_skipped: () => {
    const fb = flagByte("fb")
    return BinaryPacker.pack(
      scheme<Row>(
        1,
        u8(0, (x) => x.sel),
        fb,
        when(1, eq(0, 1), [u8(1, (x) => x.n)]),
        fb.bit(times(2, 1, [u8(2, (x) => x.pt)])),
      ),
      { sel: 0, pt: [5] },
    )
  },
  pack_lone_bytes_in_round: () => BinaryPacker.pack(
    scheme<Row>(1, u8(0, (x) => x.n), times(1, 0, [bytes(1, (x) => x.d, 2)])),
    { n: 2, d: Uint8Array.from([1, 2]) },
  ),
  pack_split_false_condition_silent: () => {
    const fb = flagByte("fb")
    return BinaryPacker.pack(
      scheme<Row>(
        1,
        u8(0, (x) => x.mode),
        fb,
        fb.bit(when(1, eq(0, 1), [u8(1, (x) => x.speed)])),
        fb.bit(u16(2, (x) => x.heading)),
      ),
      { mode: 0, speed: 7, heading: 90 },
    )
  },
  pack_round_slots_at_limit: () => BinaryPacker.pack(mixedRounds(), { n: 1, a: [1], b: [2, 3] }),
  pack_round_slots_over_limit: () => BinaryPacker.pack(mixedRounds(), { n: 1, a: [1], b: [2, 3, 4] }),
  pack_round_slots_flags_at_limit: () => BinaryPacker.pack(flagsRound(), { on: [true, true], v: [5, 6] }),
  pack_round_slots_flags_over_limit: () => BinaryPacker.pack(flagsRound(), { on: [true, true, true], v: [5, 6, 7] }),
  pack_flags_short_list: () => BinaryPacker.pack(optionalRepeat(), { w: [1, 2], v: [5] }),
  pack_flags_short_list_filled: () => BinaryPacker.pack(optionalRepeat(), { w: [1, 2], v: [5, undefined] }),
  pack_split_times_absent_body: () => BinaryPacker.pack(splitTimesBody(), { n: 2, heading: 90 }),
  pack_late_when_in_bit_body: () => {
    const fb = flagByte("fb")
    return BinaryPacker.pack(
      scheme<Row>(
        1,
        fb,
        u8(0, (x) => x.mode),
        fb.bit(group(1, (x) => x.g, [
          u8(1, (x) => x.d),
          when(2, eq(0, 1), [u8(2, (x) => x.a)]),
          when(3, eq(0, 2), [u8(3, (x) => x.b)]),
        ])),
      ),
      { mode: 1, d: 5, a: 9 },
    )
  },
  pack_count_one_clear_when: () => {
    const fb = flagByte("fb")
    return BinaryPacker.pack(
      scheme<Row>(
        1,
        u8(0, (x) => x.mode),
        when(1, eq(0, 1), [u8(1, (x) => x.c)]),
        fb,
        fb.bit(times(2, 1, [u8(2, (x) => x.pt)])),
        fb.bit(u16(3, (x) => x.heading)),
      ),
      { mode: 0, c: 1, heading: 90 },
    )
  },
  pack_bits_count_clear_when: () => BinaryPacker.pack(
    clearWhenCount((c) => bits(2, (x) => x.v, c)),
    { mode: 0, c: 3, v: [1, 0, 1] },
  ),
  pack_packed_count_clear_when: () => BinaryPacker.pack(
    clearWhenCount((c) => packed(1, 2, (x) => x.v, c)),
    { mode: 0, c: 3, v: [1, 0, 1] },
  ),
  pack_sized_count_clear_when: () => BinaryPacker.pack(
    clearWhenCount((c) => sized(2, (x) => x.v, c)),
    { mode: 0, c: 3, v: Uint8Array.from([1, 2, 3]) },
  ),
  ...novalueCountCases(),
  pack_repeat_unequal_lists_lone: () => BinaryPacker.pack(
    scheme<Row>(1, repeat(0, [u8(0, (x) => x.a), u8(1, (x) => x.b)])),
    { a: [1, 2], b: 7 },
  ),
  pack_repeat_unequal_lists_when: () => BinaryPacker.pack(
    scheme<Row>(1, repeat(0, [u8(0, (x) => x.k), when(1, eq(0, 1), [u8(1, (x) => x.v)])])),
    { k: [1, 2], v: [9] },
  ),
  pack_times_short_list_flags: () => BinaryPacker.pack(
    scheme<Row>(1, u8(0, (x) => x.c), times(1, 0, [flags(1, [u8(1, (x) => x.v)])])),
    { c: 2, v: [5] },
  ),
  pack_element_times_over_bytes_budget: () => BinaryPacker.pack(
    scheme<Row>(
      1,
      list((x) => x.items, group((x) => x.item, [u32(0, (x) => x.n), times(1, 0, [utf8(1, (x) => x.s)])])),
    ),
    { items: Array.from({ length: 16 }, () => ({ n: 65535, s: "a".repeat(16) })) },
  ),
}
