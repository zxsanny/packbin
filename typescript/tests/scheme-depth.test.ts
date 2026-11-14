import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { BinaryPacker, bool, flags, group, list, scheme, Scheme, u8, when, eq, type Field } from "../src/index.ts"
import { validateSchemeDepth } from "../src/scheme-depth.ts"
import { CHAINS, DEPTH_REFUSAL, whenChain, type Row } from "./support/scheme-depth.ts"
import { assertWithinMs, bound } from "./support/timing.ts"

// Contract scheme-depth 1.0.0 (AZ-4295, owner decision D18): a scheme nested deeper than 256 levels is refused when it
// is built, with the package's scheme error (RangeError) and the contract's text, before any walk that recurses.

const refused = (e: unknown): boolean => {
  assert.ok(e instanceof RangeError, `expected RangeError, got ${String(e)}`)
  assert.equal(e.message, DEPTH_REFUSAL)
  return true
}

describe("scheme depth limit of 256 levels", () => {
  for (const chain of CHAINS) {
    it(`AC-2: ${chain.name}: 256 levels build, pack the same bytes and unpack to the same value`, () => {
      // Arrange
      const s = chain.build(256)
      const row = chain.row(256)

      // Act
      const packet = BinaryPacker.pack(s, row)
      let got: unknown
      const result = BinaryPacker.unpack(packet, s.on((r) => { got = r }))

      // Assert
      assert.equal(Buffer.from(packet).toString("hex"), chain.hex)
      assert.deepEqual(result, { ok: true })
      assert.deepEqual(got, row)
    })

    it(`AC-1: ${chain.name}: 257 levels are refused when the scheme is built`, () => {
      // Arrange and act and assert
      assert.throws(() => chain.build(257), refused)
    })

    for (const depth of [1_000, 50_000]) {
      it(`AC-1: ${chain.name}: ${depth} levels are refused with no stack error, within 5 s`, () => {
        // Arrange
        const limit = bound(5)
        const start = performance.now()

        // Act and assert
        assert.throws(() => chain.build(depth), refused)
        assertWithinMs(performance.now() - start, limit, `${chain.name} ${depth}`)
      })
    }
  }

  it("AC-1: the depth is refused first, before the field id walk that would refuse the scheme too", () => {
    // Arrange: id 5 is wrong at the top of a 257 deep chain, so any walk that ran before the depth check would name it
    const deep: Field[] = [u8(5, (r: Row) => r.b)]
    let inner = deep
    for (let i = 0; i < 257; i++) inner = [when(0, eq(0, 1), inner)]

    // Act and assert
    assert.throws(() => scheme<Row>(1, ...inner), refused)
  })

  it("AC-1: new Scheme refuses what scheme() refuses, and a scheme at the limit survives withLimits", () => {
    // Arrange
    const ok = whenChain(256)

    // Act
    const again = ok.withLimits({ maxRounds: 10 })

    // Assert
    assert.equal(again.maxRounds, 10)
    assert.throws(() => new Scheme<Row>(1, [when(0, eq(0, 1), whenChain(256).fields)]), refused)
  })

  it("AC-1: a list or dict element counts as a level, wherever it stands", () => {
    // Arrange: 255 whens then a list is 256 levels; one more when is 257
    const build = (whens: number): Scheme<Row> => {
      let inner: Field[] = [list((r: Row) => r.xs, u8(0, (r: Row) => r.v))]
      for (let i = 0; i < whens; i++) inner = [when(1, eq(0, 1), inner)]
      return scheme<Row>(1, u8(0, (r: Row) => r.a), ...inner)
    }

    // Act and assert
    assert.doesNotThrow(() => build(255))
    assert.throws(() => build(256), refused)
  })

  it("AC-1: a flag bit is its field, not a level of its own", () => {
    // Arrange: 256 flags hold a bool, a flag byte and its bit add no level
    let inner: Field = bool(0, (r: Row) => r.on)
    for (let i = 0; i < 256; i++) inner = flags(0, [inner])

    // Act and assert
    assert.doesNotThrow(() => scheme<Row>(1, inner))
    assert.throws(() => scheme<Row>(1, flags(0, [inner])), refused)
  })

  it("AC-1: two sibling chains of 200 groups are not summed: only one path counts", () => {
    // Arrange
    const chain = (prefix: string): Field => {
      let inner: Field[] = [u8(0, new Function("r", `return r.${prefix}b`) as (r: Row) => unknown)]
      for (let i = 0; i < 200; i++) inner = [group(new Function("r", `return r.${prefix}${i}`) as (r: Row) => unknown, inner)]
      return inner[0]!
    }

    // Act
    const s = scheme<Row>(1, chain("p"), chain("q"))

    // Assert
    assert.equal(s.fields.length, 2)
  })

  // AZ-4306: a field held by two parents (the same object) is measured once, so a diamond costs its size, not 2^depth.
  const diamond = (levels: number): Field[] => {
    let inner: Field[] = [u8(1, (r: Row) => r.b)]
    for (let i = 0; i < levels; i++) inner = [when(1, eq(0, 1), [...inner, ...inner])]
    return inner
  }

  it("AZ-4306 AC-1: a diamond of 60 levels is answered within one second, never a hang", () => {
    // Arrange
    const top = diamond(60)
    const limit = bound(1)
    const start = performance.now()

    // Act: the depth walk alone, then the whole build (the field id rule refuses the repeated u8)
    validateSchemeDepth(top)
    assert.throws(() => scheme<Row>(1, u8(0, (r: Row) => r.a), ...top), RangeError)

    // Assert
    assertWithinMs(performance.now() - start, limit, "diamond of 60 levels")
  })

  it("AZ-4306 AC-1: a diamond of 300 levels is still refused as too deep, within one second", () => {
    // Arrange
    const top = diamond(300)
    const limit = bound(1)
    const start = performance.now()

    // Act and assert
    assert.throws(() => validateSchemeDepth(top), refused)
    assertWithinMs(performance.now() - start, limit, "diamond of 300 levels")
  })

  for (const sharedFirst of [true, false]) {
    it(`AZ-4306 AC-3: a field reached shallow and again deeper is measured at its deepest (shared ${sharedFirst ? "first" : "last"})`, () => {
      // Arrange: a group held at the top and again at the bottom of a chain of whens
      const build = (whens: number): Field[] => {
        const shared = group((r: Row) => r.s, [u8(0, (r: Row) => r.v)])
        let inner: Field[] = [shared]
        for (let i = 0; i < whens; i++) inner = [when(0, eq(0, 1), inner)]
        return sharedFirst ? [shared, ...inner] : [...inner, shared]
      }

      // Act and assert: 255 whens and the group make 256 levels, 256 whens make 257
      assert.doesNotThrow(() => validateSchemeDepth(build(255)))
      assert.throws(() => validateSchemeDepth(build(256)), refused)
    })
  }

  it("AZ-4307: a chain of 256 nested lists builds, the 257th list() is refused when it is called", () => {
    // Arrange
    let element: Field = u8(0, (r: Row) => r.v)
    for (let i = 0; i < 256; i++) element = list((r: Row) => r.xs, element)

    // Act and assert
    assert.throws(() => list((r: Row) => r.xs, element), refused)
  })
})
