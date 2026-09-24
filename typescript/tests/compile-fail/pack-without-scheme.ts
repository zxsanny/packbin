import { BinaryPacker } from "../../src/index.ts"

class MarkerRow {
  sid = 23
}

const row = new MarkerRow()
BinaryPacker.pack(row)
