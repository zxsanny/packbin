// Probe of AZ-4251: a `flags` that is a direct member of a `flags`. It builds scheme S of
// ../../../README.md with the public API, packs each shape's values and unpacks its own bytes. One
// line per shape: package, shape, build, pack, unpack (tab separated). It asserts nothing: it prints
// what happens.
//
// Rows are map rows (`[String: Any]`, read back with `unpackMap`); a shape leaves a value out by
// leaving its key out. Ids: both `.flags` and `x` are 0, `b` is 1.
//
// `flagsprobe` prints every shape; `flagsprobe <shape>...` prints the ones named. `run.sh` starts one
// process per shape, so a trap in one shape is its own line.
import Foundation
import Packbin

/// Written at once: a line that a trap cuts short still holds the cells before it.
func emit(_ text: String) { FileHandle.standardOutput.write(Data(text.utf8)) }

func oneLine(_ text: String) -> String {
    text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
}

func hex(_ bytes: [UInt8]) -> String {
    bytes.map { ($0 < 16 ? "0" : "") + String($0, radix: 16) }.joined()
}

/// Keys in sorted order and every integer type as its number, so two rows that hold the same values
/// print the same text.
func shown(_ row: [String: Any]) -> String {
    "{" + row.keys.sorted().map { "\"\($0)\":\(scalar(row[$0]!))" }.joined(separator: ",") + "}"
}

func scalar(_ value: Any) -> String {
    if let number = value as? any BinaryInteger { return "\(number)" }
    return "\(value)"
}

/// The row two rows are compared by: `b = false` leaves the bit clear as an absent `b` does (README
/// §Bool), so it is left out.
func present(_ row: [String: Any]) -> String {
    shown(row.filter { !($0.key == "b" && ($0.value as? Bool) == false) })
}

/// A `PackbinError` is the package's own refusal; anything else is not.
func failure(_ error: any Error) -> String {
    if let refusal = error as? PackbinError { return "refused: \(oneLine(refusal.description))" }
    return "threw: \(oneLine(String(describing: error)))"
}

func probe(_ shape: String, _ values: [String: Any]) {
    emit("swift\t\(shape)\t")
    let scheme: Scheme
    do {
        // S: flags(flags(u8 x), bool b).
        scheme = try Scheme(1, .flags(0, .flags(0, .u8(0, "x")), .bool(1, "b")))
    } catch {
        emit("\(failure(error))\t-\t-\n")
        return
    }
    emit("built\t")
    let packed: [UInt8]
    do {
        packed = try pack(scheme, values)
    } catch {
        emit("\(failure(error))\t-\n")
        return
    }
    emit("\(hex(packed))\t")
    do {
        let got = try unpackMap(packed, scheme)
        emit(present(got) == present(values) ? "same\n" : "differs: \(oneLine(shown(got)))\n")
    } catch {
        emit("\(failure(error))\n")
    }
}

let shapes: [(String, [String: Any])] = [
    ("both", ["x": UInt8(9), "b": true]),
    ("x-only", ["x": UInt8(9)]),
    ("b-only", ["b": true]),
    ("none", [:]),
]

let named = Array(CommandLine.arguments.dropFirst())
for name in named.isEmpty ? shapes.map(\.0) : named {
    guard let shape = shapes.first(where: { $0.0 == name }) else {
        let known = shapes.map(\.0).joined(separator: " ")
        FileHandle.standardError.write(Data("flagsprobe: no shape \(name); shapes: \(known)\n".utf8))
        exit(2)
    }
    probe(shape.0, shape.1)
}
