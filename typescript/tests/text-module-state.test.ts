import assert from "node:assert/strict"
import { copyFileSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs"
import { tmpdir } from "node:os"
import { join } from "node:path"
import { after, describe, it } from "node:test"
import { fileURLToPath, pathToFileURL } from "node:url"
import v8 from "node:v8"
import vm from "node:vm"
import { hexOf } from "./support/text-vectors.ts"
import { encodeText } from "../src/text.ts"

// AZ-2733 (CS-D1, HD-1): once a pack call has returned, no module-level variable of text.ts keeps the
// field it wrote or the code points and costs of its text.

// A collection on demand without a runner flag: the flag is switched on in this process, then `gc` is
// taken from a fresh context.
const gc: () => void =
  (globalThis as { gc?: () => void }).gc ?? (v8.setFlagsFromString("--expose-gc"), vm.runInNewContext("gc") as () => void)

function weakField(text: string): WeakRef<Uint8Array> {
  return new WeakRef(encodeText(text, "s"))
}

async function collected(ref: WeakRef<object>): Promise<boolean> {
  for (let attempt = 0; attempt < 5; attempt++) {
    // The target of a WeakRef is kept to the end of the job that made it.
    await new Promise((resolve) => setImmediate(resolve))
    gc()
    if (ref.deref() === undefined) return true
  }
  return false
}

const cases: [string, string][] = [
  ["65,535 characters, compact", "q".repeat(65535)],
  ["4,000 Ukrainian characters, compact", "Привіт, як справи ".repeat(300).slice(0, 4000)],
  ["20,000 CJK characters, raw", Array.from({ length: 20000 }, (_, i) => String.fromCodePoint(0x4e00 + ((i * 7919) % 20000))).join("")],
  ["a short Ukrainian text", "привіт"],
]

describe("AZ-2733: the encoder keeps no field after a call", () => {
  for (const [name, text] of cases) {
    it(`the field of ${name} is collectable once the caller drops it`, async () => {
      // Arrange
      const ref = weakField(text)
      assert.ok(ref.deref() !== undefined)

      // Act
      const gone = await collected(ref)

      // Assert
      assert.ok(gone, "a module-level variable of text.ts still references the returned field")
    })
  }
})

// The scratch arrays of text.ts are module constants, so a test cannot reach them through the package. This
// loads a copy of the very source with one line appended that exports them, and reads them after each call.
describe("AZ-2733: the encoder scratch arrays are zero after a call", () => {
  const srcDir = fileURLToPath(new URL("../src/", import.meta.url))
  const copyDir = mkdtempSync(join(tmpdir(), "packbin-text-"))
  after(() => rmSync(copyDir, { recursive: true, force: true }))

  type Copy = { encodeText: typeof encodeText; scratch: { points: Int32Array; costs: Int32Array } }
  let loads = 0
  // A new query string gives a new module instance, so each test starts from fresh scratch arrays.
  async function loadCopy(): Promise<Copy> {
    copyFileSync(join(srcDir, "text-tables.ts"), join(copyDir, "text-tables.ts"))
    const source = readFileSync(join(srcDir, "text.ts"), "utf8")
    writeFileSync(join(copyDir, "text.ts"), `${source}\nexport const scratch = { points: scratchPoints, costs: scratchCosts }\n`)
    return (await import(`${pathToFileURL(join(copyDir, "text.ts")).href}?copy=${++loads}`)) as Copy
  }

  const allZero = (a: Int32Array): boolean => a.every((x) => x === 0)

  for (const [name, text] of cases) {
    it(`after ${name}`, async () => {
      // Arrange
      const copy = await loadCopy()

      // Act
      const field = copy.encodeText(text, "s")

      // Assert
      assert.equal(hexOf(field), hexOf(encodeText(text, "s")))
      assert.equal(allZero(copy.scratch.points), true, "scratchPoints still holds code points")
      assert.equal(allZero(copy.scratch.costs), true, "scratchCosts still holds costs")
    })
  }

  it("after a run of calls of different lengths", async () => {
    // Arrange
    const copy = await loadCopy()

    // Act
    for (const [, text] of cases) copy.encodeText(text, "s")
    copy.encodeText("Привіт".repeat(683).slice(0, 4096), "s")
    copy.encodeText("q", "s")

    // Assert
    assert.equal(allZero(copy.scratch.points), true)
    assert.equal(allZero(copy.scratch.costs), true)
  })
})
