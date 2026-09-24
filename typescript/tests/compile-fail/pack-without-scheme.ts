import { pack } from "../../src/index.ts"

class MarkerRow {
  sid = 23
}

const row = new MarkerRow()
pack(row)
