// Probe of AZ-4291: what the package does with a scheme nested very deep. `schemedepthprobe <shape> <depth>`
// builds the scheme, packs one row and unpacks its own bytes, and prints one tab-separated line: package,
// shape-with-depth, build, pack, unpack. It asserts nothing: it prints what happens.
//
// Shapes: `when` (`u8 a` id 0, then `depth` nested `when(a == 1, ...)` anchored at id 1, the innermost
// holding `u8 b` id 1; values a = 1, b = 7; bytes 01 01 07) and `group` (`depth` nested rows, the innermost
// holding `u8 b`; b = 7; bytes 01 07).
//
// Form used for `group`: the nested row without an anchor, `.group(name, members)`: it numbers its members
// from 0 and takes no id of the row around it, so no id chain is needed. Rows are map rows
// (`[String: Any]`, read back with `unpackMap`), a nested row being a `[String: Any]` under its name, so the
// value is a dictionary nested `depth` deep. Every nested row is named `g`.
//
// The probe never recurses: the scheme and the values are built in a loop, innermost first, and the values
// that come back are compared by a loop. A deep `Field`, scheme or dictionary released by Swift recurses
// in its release, so the probe keeps every deep object in `keep` and leaves with `exit`, which releases
// nothing: the stack that overflows is then the package's own. The stack is the main thread's default.
// A trap or stack overflow kills the process; run.sh's `case.sh` prints that as a `crashed:` line.
import Foundation
import Packbin

/// Deep objects, never released.
nonisolated(unsafe) var keep: [Any] = []

func oneLine(_ text: String) -> String {
    String(text.split(whereSeparator: \.isWhitespace).joined(separator: " ").prefix(120))
}

/// Hex of the bytes; longer than 80 characters: the first 40, `...` and the byte count.
func hex(_ bytes: [UInt8]) -> String {
    let text = bytes.map { ($0 < 16 ? "0" : "") + String($0, radix: 16) }.joined()
    return text.count > 80 ? "\(text.prefix(40))...\(bytes.count) bytes" : text
}

/// A `PackbinError` is the package's own refusal; anything else is not.
func failure(_ error: any Error) -> String {
    if let refusal = error as? PackbinError { return "refused: \(oneLine(refusal.description))" }
    return "threw: \(oneLine(String(describing: error)))"
}

func finish(_ shape: String, _ build: String, _ pack: String = "-", _ unpack: String = "-") -> Never {
    print("swift\t\(shape)\t\(build)\t\(pack)\t\(unpack)")
    fflush(stdout)
    exit(0)
}

/// An integer of any width as an `Int`.
func number(_ value: Any?) -> Int? {
    (value as? any BinaryInteger).flatMap { Int(exactly: $0) }
}

/// True when `got` holds the row the shape was given: flat for `when`, `depth` rows named `g` holding `b`.
func same(_ shape: String, _ depth: Int, _ got: [String: Any]) -> Bool {
    if shape == "when" {
        return got.count == 2 && number(got["a"]) == 1 && number(got["b"]) == 7
    }
    var current = got
    for _ in 0..<depth {
        guard current.count == 1, let next = current["g"] as? [String: Any] else { return false }
        current = next
    }
    return current.count == 1 && number(current["b"]) == 7
}

func shown(_ got: [String: Any]) -> String { oneLine(String(describing: got.keys.sorted())) }

let args = Array(CommandLine.arguments.dropFirst())
guard args.count == 2, args[0] == "when" || args[0] == "group", let depth = Int(args[1]), depth > 0 else {
    FileHandle.standardError.write(Data("usage: schemedepthprobe <when|group> <depth>\n".utf8))
    exit(2)
}
let shape = args[0]
let label = "\(shape)-\(depth)"

var fields: [Field]
var row: [String: Any]
if shape == "when" {
    var inner: [Field] = [.u8(1, "b")]
    for _ in 0..<depth { inner = [.when(1, .eq(0, 1), inner)] }
    fields = [.u8(0, "a")] + inner
    row = ["a": 1, "b": 7]
} else {
    var inner: [Field] = [.u8(0, "b")]
    for _ in 0..<depth { inner = [.group("g", inner)] }
    fields = inner
    var nested: [String: Any] = ["b": 7]
    for _ in 0..<depth { nested = ["g": nested] }
    row = nested
}
keep.append(fields)
keep.append(row)

let scheme: Scheme
do {
    scheme = try Scheme(1, fields)
} catch {
    finish(label, failure(error))
}
keep.append(scheme)

let packed: [UInt8]
do {
    packed = try pack(scheme, row)
} catch {
    finish(label, "built", failure(error))
}

let unpacked: String
do {
    let got = try unpackMap(packed, scheme)
    keep.append(got)
    unpacked = same(shape, depth, got) ? "same" : "differs: keys \(shown(got))"
} catch {
    unpacked = failure(error)
}
finish(label, "built", hex(packed), unpacked)
