import {
  BinaryPacker,
  PackSession,
  bits,
  bool,
  bytes,
  dict,
  eq,
  flagByte,
  flags,
  group,
  i8,
  list,
  packed,
  repeat,
  scheme,
  sized,
  times,
  u16,
  u32,
  u8,
  utf8,
  when,
  type DispatchResult,
  type Scheme,
} from "../../src/index.ts"

type Row = Record<string, unknown>

export type Outcome = {
  result?: DispatchResult
  called: boolean
  threw?: string
  // Set when building the scheme threw RangeError: the `scheme_error` outcome.
  schemeError?: string
  ms: number
}

// Count 0 is the first value of the scheme; flag-guarded counts hide it behind a clear bit.
const clearFlag = () => flags(0, [u8(0, (x: Row) => x.n)])

const dictZeroWidthValue = () => scheme<Row>(1, dict((x) => x.d, bytes(0, (x) => x.v, 0)))

// A `when` names only a field read earlier in its own round, so a round that reads nothing is a
// zero-width field and a `when` on it that never matches. Ids 1 and 2 follow one field before it.
const emptyRound = () => [
  bytes(1, (x: Row) => x.v, 0),
  when(2, eq(1, 9), [u8(2, (x: Row) => x.w)]),
]

const nineU8 = () => [
  u8(0, (x: Row) => x.f0),
  u8(1, (x: Row) => x.f1),
  u8(2, (x: Row) => x.f2),
  u8(3, (x: Row) => x.f3),
  u8(4, (x: Row) => x.f4),
  u8(5, (x: Row) => x.f5),
  u8(6, (x: Row) => x.f6),
  u8(7, (x: Row) => x.f7),
  u8(8, (x: Row) => x.f8),
]

// fixtures/hostile/cases.txt, construct stage: each builder must throw RangeError whose
// message matches `rule`, so an error from a typo in the builder does not pass the case.
export const CONSTRUCT: Record<string, { build: () => unknown; rule: RegExp }> = {
  nine_flag_bits: {
    build: () => scheme<Row>(1, flags(0, nineU8())),
    rule: /^flags: ninth bit \(f8\); a flag byte holds 8 bits$/,
  },
  nine_flag_bits_split: {
    build: () => {
      const fb = flagByte("fb")
      return scheme<Row>(1, fb, ...nineU8().map((f) => fb.bit(f)))
    },
    rule: /^flag byte "fb": ninth bit \(f8\); a flag byte holds 8 bits$/,
  },
  when_names_later_field: {
    build: () => scheme<Row>(
      1,
      u8(0, (x) => x.a),
      when(1, eq(2, 1), [u8(1, (x) => x.b)]),
      u8(2, (x) => x.c),
    ),
    rule: /^when 1: eq names field id 2, which is not declared earlier in the same scope$/,
  },
  count_names_later_field: {
    build: () => scheme<Row>(1, sized(0, (x) => x.payload, 1), u16(1, (x) => x.n)),
    rule: /^sized 0: count names field id 1, which is not declared earlier in the same scope$/,
  },
  when_names_outer_field_in_repeat: {
    build: () => scheme<Row>(
      1,
      u8(0, (x) => x.mode),
      repeat(1, [when(1, eq(0, 1), [u8(1, (x) => x.v)])]),
    ),
    rule: /^when 1: eq names field id 0, which is not declared earlier in the same scope$/,
  },
  bool_outside_flags: {
    build: () => scheme<Row>(1, u8(0, (x) => x.a), bool(1, (x) => x.on)),
    rule: /^bool on: allowed only directly inside flags or a flag bit/,
  },
  empty_group_outside_flags: {
    build: () => scheme<Row>(1, u8(0, (x) => x.a), group((x) => x.mark, [])),
    rule: /^empty group mark: allowed only directly inside flags or a flag bit/,
  },
}

// Built per case, so a scheme a package refuses is reported for that case alone.
export const SCHEMES: Record<string, () => Scheme<Row>> = {
  // fixtures/hostile/cases.txt, unpack stage
  zero_progress_repeat_bool: () => scheme<Row>(1, repeat(0, [bool(0, (x) => x.on)])),
  zero_progress_repeat_when: () => scheme<Row>(
    1,
    u8(0, (x) => x.mode),
    repeat(1, [when(1, eq(0, 1), [u8(1, (x) => x.v)])]),
  ),
  negative_count: () => scheme<Row>(
    1,
    i8(0, (x) => x.n),
    sized(1, (x) => x.payload, 0),
  ),
  oversize_count: () => scheme<Row>(
    1,
    u32(0, (x) => x.n),
    sized(1, (x) => x.payload, 0),
  ),
  oversize_count_times: () => scheme<Row>(
    1,
    u32(0, (x) => x.n),
    times(1, 0, [u8(1, (x) => x.v)]),
  ),
  oversize_list_count: () => scheme<Row>(1, list((x) => x.xs, u8(0, (x) => x.x))),
  invalid_utf8: () => scheme<Row>(1, utf8(0, (x) => x.name)),
  invalid_utf8_dict_key: () => scheme<Row>(1, dict((x) => x.m, u8(0, (x) => x.v))),
  count_behind_clear_flag: () => scheme<Row>(1, clearFlag(), sized(1, (x) => x.payload, 0)),
  count_behind_clear_flag_bits: () => scheme<Row>(1, clearFlag(), bits(1, (x) => x.segs, 0)),

  // fixtures/hostile/cases.txt, limit stage: maxRounds 3, the default maxSlots.
  repeat_rounds_over_limit: () => scheme<Row>(1, repeat(0, [u8(0, (x) => x.v)])).withLimits({ maxRounds: 3 }),
  times_rounds_over_limit: () => scheme<Row>(
    1,
    u8(0, (x) => x.n),
    times(1, 0, [u8(1, (x) => x.v)]),
  ).withLimits({ maxRounds: 3 }),

  // AZ-2072 problem table
  row1_zero_progress_repeat: () => scheme<Row>(1, u8(0, (x) => x.k), repeat(1, emptyRound())),
  row2a_sized_negative: () => scheme<Row>(
    1,
    i8(0, (x) => x.n),
    sized(1, (x) => x.p, 0),
  ),
  row2b_bits_negative: () => scheme<Row>(
    1,
    i8(0, (x) => x.n),
    bits(1, (x) => x.b, 0),
  ),
  row2c_packed_negative: () => scheme<Row>(
    1,
    i8(0, (x) => x.n),
    packed(2, 1, (x) => x.k, 0),
  ),
  row2c_times_negative: () => scheme<Row>(
    1,
    i8(0, (x) => x.n),
    times(1, 0, [u8(1, (x) => x.v)]),
  ),
  row2d_packed_negative_bias: () => scheme<Row>(
    1,
    u8(0, (x) => x.n),
    packed(1, 1, (x) => x.legs, 0, -1),
  ),
  row3_invalid_utf8_string: () => scheme<Row>(1, utf8(0, (x) => x.s)),
  row3_invalid_utf8_dict_key: () => scheme<Row>(1, dict((x) => x.d, u8(0, (x) => x.v))),
  row4_sized_behind_clear_flag: () => scheme<Row>(1, clearFlag(), sized(1, (x) => x.p, 0)),
  row4_bits_behind_clear_flag: () => scheme<Row>(1, clearFlag(), bits(1, (x) => x.b, 0)),
  row4_packed_behind_clear_flag: () => scheme<Row>(1, clearFlag(), packed(2, 1, (x) => x.k, 0)),
  row4_times_behind_clear_flag: () => scheme<Row>(
    1,
    clearFlag(),
    times(1, 0, [u8(1, (x) => x.v)]),
  ),
  row5_list_oversize: () => scheme<Row>(1, list((x) => x.xs, u8(0, (x) => x.x))),
  row5_utf8_oversize: () => scheme<Row>(1, utf8(0, (x) => x.s)),
  row5_times_oversize: () => scheme<Row>(
    1,
    u8(0, (x) => x.n),
    times(1, 0, [u8(1, (x) => x.v)]),
  ),
  row5_sized_oversize: () => scheme<Row>(
    1,
    u8(0, (x) => x.n),
    sized(1, (x) => x.p, 0),
  ),
  row6_times_zero_width_oversize: () => scheme<Row>(1, u32(0, (x) => x.n), times(1, 0, emptyRound())),
  row6_times_zero_width_small: () => scheme<Row>(1, u8(0, (x) => x.n), times(1, 0, emptyRound())),
  row7_list_of_list_zero_width: () => scheme<Row>(
    1,
    list(
      (x) => x.outer,
      list((x) => x.inner, bytes(0, (x) => x.e, 0)),
    ),
  ),
  row7_dict_zero_width_value: dictZeroWidthValue,
  row7_dict_zero_width_value_one: dictZeroWidthValue,
  row5_bits_oversize: () => scheme<Row>(
    1,
    u32(0, (x) => x.n),
    bits(1, (x) => x.b, 0),
  ),
  row5_packed_oversize: () => scheme<Row>(
    1,
    u32(0, (x) => x.n),
    packed(2, 1, (x) => x.k, 0),
  ),
  row5_dict_oversize: () => scheme<Row>(1, dict((x) => x.d, u8(0, (x) => x.v))),
}

export function runCase(id: string, hex: string): Outcome {
  const build = SCHEMES[id]
  if (!build) throw new Error(`no scheme declared for hostile case ${id}`)
  const out: Outcome = { called: false, ms: 0 }
  let layout: Scheme<Row>
  try {
    layout = build()
  } catch (e) {
    if (e instanceof RangeError) out.schemeError = e.message
    else out.threw = `construction: ${String(e)}`
    return out
  }
  const start = performance.now()
  try {
    out.result = BinaryPacker.unpack(
      Buffer.from(hex, "hex"),
      layout.on(() => {
        out.called = true
      }),
    )
  } catch (e) {
    out.threw = String(e)
  }
  out.ms = performance.now() - start
  return out
}

export type SessionOutcome = { first?: DispatchResult; second?: DispatchResult; threw?: string; ms: number }

const sessionSeed = () => Uint8Array.from({ length: 32 }, (_, i) => i + 1)
const sessionNonce = Uint8Array.from({ length: 16 }, (_, i) => i + 1)

// Clear bytes 01 00 05 (type 1, k = 0, trailing 05), then a valid type-2 message.
export function runSession(): SessionOutcome {
  const opener = PackSession.load(sessionSeed())!
  const waiter = PackSession.load(sessionSeed())!
  opener.start(sessionNonce)
  waiter.join(sessionNonce)
  const sender = scheme<Row>(
    1,
    u8(0, (x) => x.k),
    u8(1, (x) => x.extra),
  )
  const receiver = scheme<Row>(1, u8(0, (x) => x.k), repeat(1, emptyRound()))
  const next = scheme<Row>(2, u8(0, (x) => x.k))
  const out: SessionOutcome = { ms: 0 }
  const start = performance.now()
  try {
    const hostile = opener.pack(sender, { k: 0, extra: 5 })!
    out.first = waiter.unpack(hostile, receiver.on(() => {}))
    const fine = opener.pack(next, { k: 7 })!
    out.second = waiter.unpack(fine, next.on(() => {}))
  } catch (e) {
    out.threw = String(e)
  }
  out.ms = performance.now() - start
  return out
}
