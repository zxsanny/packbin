import assert from "node:assert/strict"
import { readFileSync } from "node:fs"
import { describe, it } from "node:test"
import { Worker } from "node:worker_threads"
import { BinaryPacker, bits, bytes, eq, i32, list, repeat, scheme, u64, u8, when, type DispatchResult } from "../src/index.ts"
import { CONSTRUCT, type Outcome, type SessionOutcome } from "./support/hostile-cases.ts"
import { PACK } from "./support/hostile-pack.ts"

// A hang or an out-of-memory loop ends the worker, not the test run. The cases share one
// worker; the case that hangs is reported and the rest restart in a fresh worker.
const KILL_AFTER_MS = 5000

type Row = Record<string, unknown>

type Job = { key: string; id?: string; hex?: string; session?: boolean }
type Settled = Outcome | SessionOutcome | Error

function runBatch(jobs: Job[], done: Map<string, Settled>): Promise<void> {
  return new Promise((resolve) => {
    const worker = new Worker(new URL("./support/hostile-worker.ts", import.meta.url), {
      workerData: jobs,
      resourceLimits: { maxOldGenerationSizeMb: 256 },
    })
    let timer: NodeJS.Timeout
    const finish = (stuck?: string, reason?: unknown) => {
      clearTimeout(timer)
      void worker.terminate()
      if (stuck !== undefined) done.set(stuck, new Error(`${stuck}: ${String(reason)}`))
      resolve()
    }
    const arm = () => {
      clearTimeout(timer)
      const next = jobs.find((j) => !done.has(j.key))
      if (!next) return finish()
      timer = setTimeout(
        () => finish(next.key, `no result within ${KILL_AFTER_MS} ms (hang)`),
        KILL_AFTER_MS,
      )
    }
    worker.on("message", (m: { key: string; outcome: Outcome | SessionOutcome }) => {
      done.set(m.key, m.outcome)
      arm()
    })
    worker.once("error", (e) => {
      const next = jobs.find((j) => !done.has(j.key))
      finish(next?.key, e)
    })
    arm()
  })
}

async function runAll(jobs: Job[]): Promise<Map<string, Settled>> {
  const done = new Map<string, Settled>()
  while (jobs.some((j) => !done.has(j.key))) {
    await runBatch(jobs.filter((j) => !done.has(j.key)), done)
  }
  return done
}

const allCases = readFileSync(new URL("../../fixtures/hostile/cases.txt", import.meta.url), "utf8")
  .split("\n")
  .map((line) => line.trim())
  .filter((line) => line !== "" && !line.startsWith("#"))
  .map((line) => {
    const [id, stage, expected, hex] = line.split(/\s+/)
    return { id: id!, stage: stage!, expected: expected!.split("|"), hex: hex! }
  })
const cases = allCases.filter((c) => c.stage === "unpack")
const constructCases = allCases.filter((c) => c.stage === "construct")
const limitCases = allCases.filter((c) => c.stage === "limit")
const packCases = allCases.filter((c) => c.stage === "pack")

const SPEC: Record<string, string> = {
  row1_zero_progress_repeat: "010005",
  row2a_sized_negative: "01fd616263",
  row2b_bits_negative: "01fd",
  row2c_packed_negative: "01fd",
  row2c_times_negative: "01fd",
  row2d_packed_negative_bias: "0100",
  row3_invalid_utf8_string: "010310c328",
  row3_invalid_utf8_dict_key: "010100" + "0310c328" + "05",
  row4_sized_behind_clear_flag: "0100",
  row4_bits_behind_clear_flag: "0100",
  row4_packed_behind_clear_flag: "0100",
  row4_times_behind_clear_flag: "0100",
  row6_times_zero_width_oversize: "01ffffffff",
  row6_times_zero_width_small: "0103",
  row7_list_of_list_zero_width: "01ffffffff",
  row7_dict_zero_width_value: "01ffff021061",
  row7_dict_zero_width_value_one: "010100021061",
  row5_list_oversize: "01ffff0100",
  row5_utf8_oversize: "01ffff61",
  row5_times_oversize: "01ff0102",
  row5_sized_oversize: "01ff0102",
  row5_dict_oversize: "01ffff",
  row5_bits_oversize: "01ffffffff00",
  row5_packed_oversize: "01ffffffff00",
}

const jobs: Job[] = [
  ...Object.entries(SPEC).map(([id, hex]) => ({ key: id, id, hex })),
  ...cases.map((c) => ({ key: `vector:${c.id}`, id: c.id, hex: c.hex })),
  ...limitCases.map((c) => ({ key: `limit:${c.id}`, id: c.id, hex: c.hex })),
  { key: "session", session: true },
]

let results: Promise<Map<string, Settled>> | undefined

async function outcome(key: string): Promise<Outcome> {
  results ??= runAll(jobs)
  const got = (await results).get(key)
  if (got instanceof Error) throw got
  return got as Outcome
}

const run = (id: string) => outcome(id)

// Interim error mapping (until C15): trailing bytes, short packet, or a value that cannot be read.
// A scheme refused at construction is `scheme_error`.
function kindOf(out: Outcome): string {
  if (out.schemeError !== undefined) return "scheme_error"
  const result: DispatchResult | undefined = out.result
  if (!result || result.ok || !("field" in result)) return "other"
  if (result.field === "" && result.needed === 0) return "trailing_bytes"
  if (result.needed > 0) return "short_packet"
  return "bad_value"
}

function assertRejected(out: Outcome, ms = 1000): void {
  assert.equal(out.threw, undefined, `unpack threw: ${out.threw}`)
  assert.equal(out.called, false, "handler must not be called")
  assert.ok(out.result && out.result.ok === false, `expected ok:false, got ${JSON.stringify(out.result)}`)
  assert.ok(out.ms < ms, `unpack took ${out.ms} ms`)
}

function assertError(out: Outcome, field: string, left: number): void {
  assertRejected(out)
  assert.deepEqual(out.result, { ok: false, field, needed: 0, left })
}

describe("hostile packets", () => {
  it("zero-progress repeat ends with trailing error", async () => {
    assertError(await run("row1_zero_progress_repeat"), "", 1)
  })

  it("negative sized count is an error", async () => {
    assertError(await run("row2a_sized_negative"), "p", 3)
  })

  it("negative bits count is an error", async () => {
    assertError(await run("row2b_bits_negative"), "b", 0)
  })

  it("negative packed/times count does not throw", async () => {
    assertError(await run("row2c_packed_negative"), "k", 0)
    assertError(await run("row2c_times_negative"), "v", 0)
    assertError(await run("row2d_packed_negative_bias"), "legs", 0)
  })

  it("invalid utf8 string is an error", async () => {
    assertError(await run("row3_invalid_utf8_string"), "s", 4)
  })

  it("invalid utf8 dictionary key is an error", async () => {
    assertError(await run("row3_invalid_utf8_dict_key"), "d", 5)
  })

  it("count behind a clear flag is an error", async () => {
    assertError(await run("row4_sized_behind_clear_flag"), "p", 0)
    assertError(await run("row4_bits_behind_clear_flag"), "b", 0)
    assertError(await run("row4_packed_behind_clear_flag"), "k", 0)
    assertError(await run("row4_times_behind_clear_flag"), "v", 0)
  })

  it("times round that reads nothing is an error", async () => {
    assertError(await run("row6_times_zero_width_oversize"), "v", 0)
    assertError(await run("row6_times_zero_width_small"), "v", 0)
  })

  it("zero_width_list_element_is_error", async () => {
    assertError(await run("row7_list_of_list_zero_width"), "inner", 0)
  })

  it("zero_width_dict_value_is_error", async () => {
    assertError(await run("row7_dict_zero_width_value"), "d", 0)
    assertError(await run("row7_dict_zero_width_value_one"), "d", 0)
  })

  // The element scope holds only the element, so a `when` there has nothing earlier to name.
  it("never_matching_when_element_is_error", () => {
    assert.throws(
      () => scheme<Row>(
        1,
        u8(0, (x) => x.mode),
        list((x) => x.xs, when(0, eq(0, 9), [u8(0, (x) => x.v)])),
      ),
      /^RangeError: when 0: eq names field id 0, which is not declared earlier in the same scope$/,
    )
  })

  it("empty_list_of_zero_width_still_unpacks", () => {
    type Row = { xs: unknown[] }
    const layout = scheme<Row>(1, list((r) => r.xs, bytes(0, (r) => r.e, 0)))
    let got: Row | undefined
    const result = BinaryPacker.unpack(Buffer.from("010000", "hex"), layout.on((row) => {
      got = row as Row
    }))
    assert.deepEqual(result, { ok: true })
    assert.deepEqual(got!.xs, [])
  })

  it("oversize counts stay short packets", async () => {
    for (const id of Object.keys(SPEC).filter((k) => k.startsWith("row5_"))) {
      const out = await run(id)
      assertRejected(out)
      assert.equal(kindOf(out), "short_packet", id)
    }
  })

  it("session unpack of hostile payload", async () => {
    const out = (await outcome("session")) as SessionOutcome
    assert.equal(out.threw, undefined, `session threw: ${out.threw}`)
    assert.ok(out.ms < 1000, `session unpack took ${out.ms} ms`)
    assert.deepEqual(out.first, { ok: false, field: "", needed: 0, left: 1 })
    // The receive counter advanced by one, so the next pad still matches.
    assert.deepEqual(out.second, { ok: true })
  })

  it("bits count from a u64 field still round trips", () => {
    type Row = { n: bigint; b: number[] }
    const layout = scheme<Row>(
      1,
      u64(0, (r) => r.n),
      bits(1, (r) => r.b, 0),
    )
    const wire = BinaryPacker.pack(layout, { n: 3n, b: [1, 0, 1] })
    assert.equal(Buffer.from(wire).toString("hex"), "01030000000000000005")
    let got: Row | undefined
    const result = BinaryPacker.unpack(wire, layout.on((row) => {
      got = row as Row
    }))
    assert.deepEqual(result, { ok: true })
    assert.deepEqual(got!.b, [1, 0, 1])
  })

  it("bits count above the safe integer range is an error", () => {
    type Row = { n: bigint; b: number[] }
    const layout = scheme<Row>(
      1,
      u64(0, (r) => r.n),
      bits(1, (r) => r.b, 0),
    )
    for (const hex of ["01ffffffffffffffff", "010000000000002000"]) {
      let ran = false
      const result = BinaryPacker.unpack(Buffer.from(hex, "hex"), layout.on(() => {
        ran = true
      }))
      assert.deepEqual(result, { ok: false, field: "b", needed: 0, left: 0 }, hex)
      assert.equal(ran, false)
    }
  })

  it("progressing repeat is unchanged", () => {
    type Points = { lat: number[]; lon: number[] }
    const points = scheme<Points>(
      1,
      repeat(0, [i32(0, (r) => r.lat), i32(1, (r) => r.lon)]),
    )
    const two = Uint8Array.from([1, 10, 0, 0, 0, 20, 0, 0, 0, 30, 0, 0, 0, 40, 0, 0, 0])
    let got: Points | undefined
    const ok = BinaryPacker.unpack(two, points.on((row) => {
      got = row as Points
    }))
    assert.equal(ok.ok, true)
    assert.deepEqual(got!.lat, [10, 30])
    assert.deepEqual(got!.lon, [20, 40])
    let ran = false
    const extra = BinaryPacker.unpack(Uint8Array.from([...two, 0]), points.on(() => {
      ran = true
    }))
    assert.equal(extra.ok, false)
    assert.equal(ran, false)
  })
})

describe("shared hostile vectors (fixtures/hostile/cases.txt)", () => {
  it("reads at least one unpack vector", () => {
    assert.ok(cases.length > 0)
  })

  for (const c of cases) {
    it(`${c.id} returns an error value`, async () => {
      const out = await run(`vector:${c.id}`)
      if (out.schemeError === undefined) assertRejected(out)
      const kind = kindOf(out)
      assert.ok(
        c.expected.includes(kind),
        `${c.id}: returned ${kind} ${JSON.stringify(out.result)}, vector accepts ${c.expected.join("|")}`,
      )
    })
  }
})

describe("shared limit vectors (fixtures/hostile/cases.txt)", () => {
  it("reads at least one limit vector", () => {
    assert.ok(limitCases.length > 0)
  })

  for (const c of limitCases) {
    it(`${c.id} is refused by the round limit`, async () => {
      const out = await run(`limit:${c.id}`)
      assertRejected(out)
      assert.ok(c.expected.includes(kindOf(out)), `${c.id}: returned ${kindOf(out)}, vector accepts ${c.expected.join("|")}`)
      // The refusal comes when a round would start: no bytes needed, the byte of that round left.
      // A short read of a field would have needed > 0.
      const result = out.result as { needed: number; left: number }
      assert.equal(result.needed, 0, `${c.id}: ${JSON.stringify(out.result)}`)
      assert.equal(result.left, 1, `${c.id}: ${JSON.stringify(out.result)}`)
    })
  }
})

type ConstructEntry = { build: () => unknown; rule: RegExp }
type VectorCase = (typeof allCases)[number]

// Builds the scheme of a construct case and checks the refusal names `entry.rule`.
function checkConstruct(c: VectorCase, entry: ConstructEntry | undefined): void {
  assert.ok(entry, `no TypeScript scheme for construct case ${c.id}`)
  assert.ok(c.expected.includes("scheme_error"), `${c.id}: vector expects ${c.expected.join("|")}`)
  const start = performance.now()
  assert.throws(entry.build, (e: unknown) => {
    assert.ok(e instanceof RangeError, `${c.id}: expected RangeError, got ${String(e)}`)
    assert.match(e.message, entry.rule, `${c.id}: wrong rule fired`)
    return true
  })
  // The refusal comes at build, before any item or round exists (construct_empty_round_body_list_element).
  assert.ok(performance.now() - start < 1000, `${c.id}: construction took ${performance.now() - start} ms`)
}

describe("shared construct vectors (fixtures/hostile/cases.txt)", () => {
  for (const c of constructCases) {
    it(`${c.id} is refused at construction`, () => {
      checkConstruct(c, CONSTRUCT[c.id])
    })
  }

  // AZ-2418 AC-1: a rule table with one wrong entry cannot pass. The wrong entry is built here; nothing on disk changes.
  it("a construct case with a wrong rule entry fails naming that case", () => {
    // Arrange
    const c = constructCases.find((x) => x.id === "construct_empty_times_body")!
    const wrong: ConstructEntry = { ...CONSTRUCT[c.id]!, rule: /^repeat 0: the body holds no member/ }

    // Act and assert
    assert.throws(() => checkConstruct(c, wrong), (e: unknown) => {
      assert.ok(e instanceof assert.AssertionError, String(e))
      assert.match(e.message, /^construct_empty_times_body: wrong rule fired/)
      return true
    })
  })
})

const NOVALUE_COUNT =
  /^v: the count c is 3 in the row, but no field wrote it \(the when that holds it is clear\), so the member reads nothing; give the count 0, leave it out, or make the when hold$/

// The rule each loop 20 refusal must name, so a refusal by some other rule does not pass.
const PACK_REFUSAL: Record<string, RegExp> = {
  pack_lone_utf8_under_times_over_budget: /^s: the packet would be 16779269 bytes, above the limit of 16777216 bytes$/,
  // The 40 items of 65 535 rounds are 2 621 400 slots: since loop 22 (maxSlots 1 048 576) the slots refuse it
  // (item 17), before the 16 MiB bytes budget it was written to reach. pack-output-budget.test.ts keeps the
  // bytes-budget element route with a scheme that fits the slots.
  pack_element_times_over_budget: /^k: the rounds would hold 1048577 slots, above the limit of 1048576 slots$/,
  pack_slots_over_limit: /^m0: the rounds would hold 1048580 slots, above the limit of 1048576 slots$/,
  pack_repeat_over_limit: /^k: the repeat count is 65536, above the limit of 65535 rounds$/,
  pack_split_count_zero_after_byte_list: /^pt: 2 items, times count 0$/,
  pack_flags_skipped_count_with_values: /^pt: a value is given, but the count of its times is not written/,
  pack_round_slots_over_limit: /^b: the rounds would hold 4 slots, above the limit of 3 slots$/,
  pack_round_slots_flags_over_limit: /^on: the rounds would hold 6 slots, above the limit of 4 slots$/,
  pack_flags_short_list: /^v: 1 items, repeat count 2; give one entry per round, undefined where the member is absent$/,
  pack_count_one_clear_when:
    /^pt: the count c is 1 in the row, but no field wrote it \(the when that holds it is clear\), so its times reads no round; give the count 0, leave it out, or make the when hold$/,
  pack_bits_count_clear_when: /^v: count c was not written$/,
  pack_packed_count_clear_when: /^v: count c was not written$/,
  pack_sized_count_clear_when: /^v: count c was not written$/,
  pack_novalue_count_clear_when_bits: NOVALUE_COUNT,
  pack_novalue_count_clear_when_packed: NOVALUE_COUNT,
  pack_novalue_count_clear_when_sized: NOVALUE_COUNT,
  pack_element_times_over_bytes_budget: /^s: the packet would be 16777231 bytes, above the limit of 16777216 bytes$/,
}

// Packs the case row and checks the bytes, or the refusal and the rule it names (`rules` is PACK_REFUSAL).
function checkPack(c: VectorCase, pack: (() => Uint8Array) | undefined, rules: Record<string, RegExp>): void {
  assert.ok(pack, `no TypeScript scheme for pack case ${c.id}`)
  if (c.expected[0] === "bytes") {
    assert.equal(Buffer.from(pack()).toString("hex"), c.hex)
    return
  }
  assert.deepEqual(c.expected, ["pack_error"])
  assert.throws(pack, (e: unknown) => {
    assert.ok(e instanceof RangeError, `${c.id}: expected RangeError, got ${String(e)}`)
    const rule = rules[c.id]
    if (rule) assert.match(e.message, rule, `${c.id}: refused by another rule`)
    return true
  })
}

describe("shared pack vectors (fixtures/hostile/cases.txt)", () => {
  it("has a TypeScript scheme for every pack vector and no other", () => {
    assert.ok(packCases.length > 0)
    assert.deepEqual(packCases.map((c) => c.id).sort(), Object.keys(PACK).sort())
  })

  for (const c of packCases) {
    it(`${c.id} packs ${c.expected[0] === "bytes" ? "the bytes" : "nothing: pack refuses the row"}`, () => {
      checkPack(c, PACK[c.id], PACK_REFUSAL)
    })
  }

  // AZ-2418 AC-1: a rule table with one wrong entry cannot pass. The wrong entry is built here; nothing on disk changes.
  it("a pack case with a wrong rule entry fails naming that case", () => {
    // Arrange
    const c = packCases.find((x) => x.id === "pack_slots_over_limit")!
    const wrong = { ...PACK_REFUSAL, [c.id]: PACK_REFUSAL.pack_repeat_over_limit! }

    // Act and assert
    assert.throws(() => checkPack(c, PACK[c.id], wrong), (e: unknown) => {
      assert.ok(e instanceof assert.AssertionError, String(e))
      assert.match(e.message, /^pack_slots_over_limit: refused by another rule/)
      return true
    })
  })
})
