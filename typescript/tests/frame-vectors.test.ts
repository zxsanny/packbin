import assert from "node:assert/strict"
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { describe, it } from "node:test"
import { caseOf, FIXTURE, load, loadFixture, mismatches, opOf, run } from "./support/frame-vectors.ts"

// AZ-3295 AC-1: every row of fixtures/frame/vectors.txt through the public API, and copies of the file with one hex
// digit of an expected output changed fail on that row only.

describe("frame vectors (AZ-3295 AC-1)", () => {
  const rows = loadFixture()

  it("every row of the frame fixture matches: 157 of 157", () => {
    // Act
    const problems = mismatches(rows)
    const passing = rows.length - new Set(problems.map((p) => p.split(" ")[0])).size

    // Assert
    assert.deepEqual(problems, [])
    assert.equal(rows.length, 157)
    assert.equal(passing, 157)
    for (const op of ["keys", "seal", "open", "mac", "replay"]) assert.ok(rows.some((r) => opOf(r) === op), op)
  })

  for (const name of ["E1.seal", "E2.seal", "E3.seal", "E3.seal16", "E4.mac", "E5.mac", "E4.keys"]) {
    it(`the worked example ${name} is in the file and matches`, () => {
      // Arrange
      const row = rows.find((r) => caseOf(r) === name)
      assert.ok(row !== undefined, name)

      // Act
      const problems = mismatches([row])

      // Assert
      assert.deepEqual(problems, [])
    })
  }

  it("the largest epoch works and the next one is refused as BadValue", () => {
    // Arrange
    const maxEpoch = rows.filter((r) => opOf(r) === "keys" && r.get("epoch") === "16777215")
    const refused = rows.find((r) => caseOf(r) === "refuse.seal.epoch1000000")!

    // Act
    const problems = mismatches(maxEpoch)

    // Assert
    assert.equal(maxEpoch.length, 3)
    assert.deepEqual(problems, [])
    assert.equal(refused.get("result"), "BadValue")
    assert.equal(run(refused).get("result"), "BadValue")
  })

  const mutants: [op: string, field: string][] = [
    ["seal", "body"],
    ["open", "plain"],
    ["mac", "tag"],
    ["keys", "k_enc"],
    ["replay", "states"],
  ]
  for (const [op, field] of mutants) {
    it(`a fixture copy with one ${op} ${field} digit changed fails on that row only`, () => {
      // Arrange
      const dir = mkdtempSync(join(tmpdir(), "packbin-frame-"))
      try {
        const lines = readFileSync(FIXTURE, "utf8").split("\n")
        const at = lines.findIndex((l) => l.startsWith(`op=${op} `) && l.includes(` ${field}=`))
        assert.ok(at >= 0, "no row to change")
        const marker = ` ${field}=`
        const digit = lines[at]!.indexOf(marker) + marker.length
        const flipped = lines[at]![digit] === "0" ? "1" : "0"
        lines[at] = lines[at]!.slice(0, digit) + flipped + lines[at]!.slice(digit + 1)
        const path = join(dir, "vectors.txt")
        writeFileSync(path, lines.join("\n"))
        const changed = load(readFileSync(path, "utf8"))
        const name = changed.find((r) => opOf(r) === op && r.has(field))!.get("case")!

        // Act
        const problems = mismatches(changed)

        // Assert
        assert.equal(problems.length, 1)
        assert.ok(problems[0]!.startsWith(`${name} ${field}`), problems[0])
      } finally {
        rmSync(dir, { recursive: true, force: true })
      }
    })
  }
})
