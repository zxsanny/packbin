import assert from "node:assert/strict"
import { describe, it } from "node:test"
import { repair } from "../src/ecc.ts"
import { bytesOf } from "./support/ecc.ts"

// Received words found by a seeded search (seed 2695) for which the locator and the error values are
// computed and applied to the bytes, yet the result is not a code word: only the check that the repaired
// bytes have zero syndromes refuses them.
const notRepairable: [n: number, t: number, hex: string][] = [
  [4, 1, "80332535593733fca1739e2267"],
  [4, 1, "2b8db83aa9aa0591c26c"],
  [4, 2, "a442946cbcc2c6ed20a7b2"],
  [4, 2, "e63fe2b98f6e7b39"],
  [6, 2, "69b32100cbe1bb78fbac03493cfe025039a7"],
  [6, 3, "09ddf2505e56add4bfdf"],
  [8, 3, "0c2313f4e775b4b5a60e5edbebb7c8cab2db"],
]

describe("message ECC post-repair re-verify", () => {
  for (const [n, t, hex] of notRepairable) {
    it(`EC-6 n = ${n}, t = ${t}: ${hex.length / 2} received bytes whose repair is not a code word are refused`, () => {
      // Arrange
      const received = bytesOf(hex)
      const before = Uint8Array.from(received)

      // Act
      const got = repair(received, n, t)

      // Assert
      assert.deepEqual(got, { ok: false, kind: "uncorrectable" })
      assert.deepEqual(received, before)
    })
  }
})
