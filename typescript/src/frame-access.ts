import type { FrameKeys } from "./frame-keys.ts"
import type { FrameSession } from "./frame-session.ts"
import type { MacKey } from "./mac-key.ts"

// Test access to state that the public classes keep in `#` fields (the derived keys, the count of HMAC computations).
// The classes fill this in when their module loads. Internal: index.ts does not export it and package.json `exports`
// names only the entry, so a consumer of the package cannot reach it.
export const access: {
  currentKeys?: (session: FrameSession) => FrameKeys
  keyArrays?: (session: FrameSession) => Uint8Array[]
  macComputations?: (session: FrameSession) => number
  macKeyBytes?: (key: MacKey) => Uint8Array
} = {}
