// AZ-2666 loop 41 security audit probe: Swift compact-text decoder and message ECC unpack path.
//
// Public API only (`import Packbin`). A trap (overflow, index out of range, force unwrap) kills the
// process, so a run that prints "result=..." had 0 traps.
//
// Files (one executable target): main.swift (this entry point), Support.swift (shared helpers),
// TextFuzz.swift, EccFuzz.swift, Edge.swift, Timing.swift, and the manifest Package.swift.txt.
//
// Build it as its own package next to a copy of the sources, never in the repository root (SwiftPM
// locks `.build`). `build_swift.sh <repo> <empty dir> release|debug|asan` (next to this directory)
// lays the package out and builds it; by hand:
//
//   D=<empty work dir>; REPO=<checkout>
//   git -C "$REPO" archive HEAD swift/Sources/Packbin | tar -x -C "$D"
//   mkdir -p "$D/Sources/Probe" && cp *.swift "$D/Sources/Probe/"
//   cp Package.swift.txt "$D/Package.swift"      # the manifest next to this file
//   swift build -c release --package-path "$D" --scratch-path "$D/.build-release"
//   swift build -c debug   --package-path "$D" --scratch-path "$D/.build-debug"
//   # optional: AddressSanitizer (the decoder reads through unsafe pointers)
//   swift build -c debug -Xswiftc -sanitize=address --package-path "$D" --scratch-path "$D/.build-asan"
//
// Run (FIX is "$REPO/fixtures"; every mode ends on its own):
//   Probe text-fuzz FIX <seed> <seconds>   random + mutated string fields through unpack
//   Probe ecc-fuzz  FIX <seed> <seconds>   random + mutated protected messages through unpack
//   Probe edge      FIX                    the AC edge cases (exits 1 on any failed expectation)
//   Probe ecc-worst <iterations>           254-byte buffers at n = 32: slowest and median per call
//   Probe text-amp                         largest accepted text, many max texts in one packet
//   Probe text-long                        a 2,097,151-byte payload that decodes to no text
//   Probe dictkey <shape> <keys> <bytes>   dict keys of one shape (F47 and its fix): time per unpack
// Each mode prints key=value lines and a final "result=PASS" or "result=FAIL".

import Foundation
import Packbin

// ---------------------------------------------------------------- main

let args = CommandLine.arguments
func usage() -> Never {
    FileHandle.standardError.write("usage: see the header comment\n".data(using: .utf8)!)
    exit(2)
}
guard args.count >= 2 else { usage() }
let code: Int32
switch (args[1], args.count) {
case ("text-fuzz", 5): code = try textFuzz(args[2], UInt64(args[3]) ?? 1, Double(args[4]) ?? 10)
case ("ecc-fuzz", 5): code = try eccFuzz(args[2], UInt64(args[3]) ?? 1, Double(args[4]) ?? 10)
case ("edge", 3): code = try edge(args[2])
case ("ecc-worst", 3): code = try eccWorst(Int(args[2]) ?? 1000)
case ("text-amp", 2): code = try textAmp()
case ("text-long", 2): code = try textLong()
case ("dictkey", 5): code = try dictKey(args[2], Int(args[3]) ?? 1, Int(args[4]) ?? 1000)
default: usage()
}
exit(code)
