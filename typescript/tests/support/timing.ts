import assert from "node:assert/strict"

// Load-aware wall-clock bounds (AZ-2723). A timing check keeps its nominal bound, written for an idle host, and
// multiplies it by the load factor: the mean of five runs of a fixed CPU-bound reference loop in this process,
// taken right before the timed code, over the time that loop takes on an idle host. The factor is never below 1
// and is capped at MAX_FACTOR, so a slowdown larger than the cap still fails.

// The best of 100 runs of the loop below after a warm-up (Node 22, arm64 Mac) was 0.0283 s while other sessions
// loaded the host; a busy host only adds time, so an idle one is not faster by more than the noise.
export const REFERENCE_SECONDS = 0.028
export const MAX_FACTOR = 8
const REFERENCE_ITERATIONS = 30_000_000

function referenceLoop(): number {
  let acc = 0
  for (let i = 0; i < REFERENCE_ITERATIONS; i++) acc = (Math.imul(acc, 31) + i) | 0
  return acc
}

let warm = false
// A factor measured less than this long ago answers again (a test file of many short checks pays the loop once).
const FRESH_MS = 500
let last = { at: -Infinity, factor: 1 }

function referenceSeconds(): number {
  if (!warm) {
    // One run lets the JIT compile the loop before it is timed, in this thread or worker.
    referenceLoop()
    warm = true
  }
  const runs = 5
  let total = 0
  for (let run = 0; run < runs; run++) {
    const started = performance.now()
    referenceLoop()
    total += (performance.now() - started) / 1000
  }
  return total / runs
}

/**
 * How much slower than an idle host this process runs now, in [1, MAX_FACTOR]. The mean of five runs, not the best
 * of three: on a host loaded many times over its cores the best of a few short runs catches a free time slice and
 * reads 1.0 while a one-second section is slowed 1.5 to 3 times; the mean sees the slices that were lost. On an idle
 * host both are the same.
 */
export function loadFactor(): number {
  if (performance.now() - last.at < FRESH_MS) return last.factor
  const factor = Math.min(MAX_FACTOR, Math.max(1, referenceSeconds() / REFERENCE_SECONDS))
  last = { at: performance.now(), factor }
  return factor
}

export type Bound = { nominalSeconds: number; factor: number; seconds: number }

/** nominal * load factor, measured now: call it right before the timed section. */
export function bound(nominalSeconds: number): Bound {
  const factor = loadFactor()
  return { nominalSeconds, factor, seconds: nominalSeconds * factor }
}

export function assertWithin(elapsedSeconds: number, limit: Bound, what = ""): void {
  const label = what === "" ? "" : `${what}: `
  assert.ok(
    elapsedSeconds <= limit.seconds,
    `${label}elapsed ${elapsedSeconds.toFixed(3)} s, nominal bound ${limit.nominalSeconds.toFixed(3)} s, ` +
      `load factor ${limit.factor.toFixed(2)}, scaled bound ${limit.seconds.toFixed(3)} s`,
  )
}

export function assertWithinMs(elapsedMs: number, limit: Bound, what = ""): void {
  assertWithin(elapsedMs / 1000, limit, what)
}
