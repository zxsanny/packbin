// Probe of AZ-4206: a repeat that is not the last thing a packet reads. It builds each shape of
// ../../../README.md with the public API, packs the values given there and unpacks its own bytes. One
// line per shape: package, shape, build, pack, unpack (tab separated). It asserts nothing: it prints
// what happens.
//
// Rows are map rows (`[String: Any]`, read back with `unpackMap`): the form that writes every shape
// without a row type. The rounds of a repeat are one array per name (entry i is round i); a nested row
// and a list or dict item are a `[String: Any]` of their own.
//
// `repeatprobe` prints every shape; `repeatprobe <shape>...` prints the ones named. `run.sh` starts
// one process per shape, so a trap in one shape is its own line.
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

private protocol OptionalValue { var inner: Any? { get } }
extension Optional: OptionalValue {
    fileprivate var inner: Any? { map { $0 as Any } }
}

/// Keys in sorted order, an absent entry as null and every integer type as its number, so two rows that
/// hold the same values print the same text.
func shown(_ value: Any?) -> String {
    guard let value else { return "null" }
    if let optional = value as? OptionalValue { return optional.inner.map { shown($0) } ?? "null" }
    if let map = value as? [String: Any] {
        return "{" + map.keys.sorted().map { "\"\($0)\":\(shown(map[$0]))" }.joined(separator: ",") + "}"
    }
    if let list = value as? [Any?] { return "[" + list.map { shown($0) }.joined(separator: ",") + "]" }
    if let number = value as? any BinaryInteger { return "\(number)" }
    if let text = value as? String { return "\"\(text)\"" }
    return "\(value)"
}

/// The names the repeats of the shapes hold.
func isRoundName(_ name: String) -> Bool { name == "v" || name == "w" }

/// `value` without the names of a repeat that hold no round, at any depth. Unpack gives a repeat that
/// read no round no key (`UnpackCounted.swift`: `if rows.isEmpty { return }`), so a row packed with
/// `v: []` reads back without `v`: for the rounds of a repeat an empty array and an absent key are the
/// same value. Only the comparison uses this: what is packed and what `differs:` prints are as given.
func withoutEmptyRounds(_ value: Any) -> Any {
    if let map = value as? [String: Any] {
        var out: [String: Any] = [:]
        for (name, member) in map {
            if isRoundName(name), let rounds = member as? [Any?], rounds.isEmpty { continue }
            out[name] = withoutEmptyRounds(member)
        }
        return out
    }
    if let list = value as? [Any?] { return list.map { $0.map { withoutEmptyRounds($0) } } }
    return value
}

/// A `PackbinError` is the package's own refusal; anything else is not.
func failure(_ error: any Error) -> String {
    if let refusal = error as? PackbinError { return "refused: \(oneLine(refusal.description))" }
    return "threw: \(oneLine(String(describing: error)))"
}

func probe(_ shape: String, _ values: [String: Any], _ build: () throws -> Scheme) {
    emit("swift\t\(shape)\t")
    let scheme: Scheme
    do {
        scheme = try build()
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
        let same = shown(withoutEmptyRounds(got)) == shown(withoutEmptyRounds(values))
        emit(same ? "same\n" : "differs: \(oneLine(shown(got)))\n")
    } catch {
        emit("\(failure(error))\n")
    }
}

/// The element row of shapes b and c: a nested row (a group without an anchor) with ids of its own.
func elementRow() -> Field { .group("item", .u8(0, "mode"), .repeat(1, .u8(1, "v"))) }

func elementValues(_ mode: Int, _ v: [Int]) -> [String: Any] { ["mode": mode, "v": v] }

let shapes = ["control", "a", "b", "c", "d", "e-when", "e-flags", "f"]

/// False for a name that is no shape.
func run(_ shape: String) -> Bool {
    switch shape {
    case "control":
        // The repeat is the last thing read.
        probe(shape, ["x": 9, "v": [5, 6]]) { try Scheme(1, .u8(0, "x"), .repeat(1, .u8(1, "v"))) }
    case "a":
        // A field after a repeat, top level.
        probe(shape, ["v": [5, 6], "x": 9]) { try Scheme(1, .repeat(0, .u8(0, "v")), .u8(1, "x")) }
    case "b":
        // A repeat inside a list element row, two items.
        probe(shape, ["items": [elementValues(1, [5]), elementValues(2, [])]]) {
            try Scheme(1, .list("items", elementRow()))
        }
    case "c":
        // A repeat inside a dict element row, two entries.
        probe(shape, ["d": ["a": elementValues(1, [5]), "b": elementValues(2, [])]]) {
            try Scheme(1, .dict("d", elementRow()))
        }
    case "d":
        // A repeat inside a nested row (`.group(name, ...)`, no anchor), then a field. The nested row is
        // a `[String: Any]` under its name and numbers its members from 0, so `x` is id 0 of the top level.
        probe(shape, ["m": ["v": [5, 6]], "x": 9]) {
            try Scheme(1, .group("m", .repeat(0, .u8(0, "v"))), .u8(0, "x"))
        }
    case "e-when":
        // A repeat under a when that is taken, then a field.
        probe(shape, ["k": 1, "v": [5, 6], "x": 9]) {
            try Scheme(1, .u8(0, "k"), .when(1, .eq(0, 1), .repeat(1, .u8(1, "v"))), .u8(2, "x"))
        }
    case "e-flags":
        // A repeat under flags, then a field.
        probe(shape, ["v": [5, 6], "x": 9]) { try Scheme(1, .flags(0, .repeat(0, .u8(0, "v"))), .u8(1, "x")) }
    case "f":
        // A repeat after a repeat, one round each. A name that unpack gives no value has no key in the
        // row, so it is absent from the text of `differs:`.
        probe(shape, ["v": [5], "w": [6]]) { try Scheme(1, .repeat(0, .u8(0, "v")), .repeat(1, .u8(1, "w"))) }
    default:
        return false
    }
    return true
}

let named = Array(CommandLine.arguments.dropFirst())
for shape in named.isEmpty ? shapes : named {
    if run(shape) { continue }
    let known = shapes.joined(separator: " ")
    FileHandle.standardError.write(Data("repeatprobe: no shape \(shape); shapes: \(known)\n".utf8))
    exit(2)
}
