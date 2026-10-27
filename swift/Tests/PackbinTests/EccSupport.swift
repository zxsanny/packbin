import Packbin
import Testing

/// One row of fixtures/ecc/vectors.txt: `kind id args...` (row syntax at the top of that file).
struct EccRow: CustomTestStringConvertible, Sendable {
    let kind: String
    let id: String
    let args: [String]
    var testDescription: String { id }

    /// The argument `i` as a number.
    func number(_ i: Int) -> Int { Int(args[i]) ?? -1 }
    /// The argument `i` as bytes ("-" is none).
    func data(_ i: Int) -> [UInt8] { args[i] == "-" ? [] : bytes(args[i]) }
}

/// Every row of fixtures/ecc/vectors.txt of one kind, in file order.
func eccRows(_ kind: String) throws -> [EccRow] {
    try repositoryFile("fixtures/ecc/vectors.txt").split(separator: "\n", omittingEmptySubsequences: true).compactMap { line in
        guard !line.hasPrefix("#") else { return nil }
        let f = line.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
        guard f.count >= 2, f[0] == kind else { return nil }
        return EccRow(kind: f[0], id: f[1], args: Array(f.dropFirst(2)))
    }
}

/// The position fixture of `Helpers.swift` as a scheme that declares `parity` parity bytes.
func positionScheme(parity: Int) throws -> Scheme {
    try positionMapScheme().withLimits(parity: parity)
}

/// The typed form of the same scheme.
func positionTypedScheme(parity: Int) throws -> Scheme {
    try positionTypedScheme().withLimits(parity: parity)
}

/// The fields of a map row that differ from the AC-1 row (sid 1, lat 500000000, lon 300000000,
/// profile 1, no motion field).
func goldenFieldMismatches(_ row: [String: Any]) -> Int {
    var bad = 0
    if row["sid"] as? UInt16 != 1 { bad += 1 }
    if row["lat"] as? Int32 != 500_000_000 { bad += 1 }
    if row["lon"] as? Int32 != 300_000_000 { bad += 1 }
    if row["profile"] as? UInt8 != 1 { bad += 1 }
    return bad + ["heading", "speed", "altitude"].filter { row[$0] != nil }.count
}

/// A scheme that reads a clear message of any bytes as its type byte and a fixed run `b` of the rest, with
/// `parity` parity bytes, so the vector rows (which are raw bytes) go through the public calls.
func rawScheme(for clear: [UInt8], parity: Int) throws -> Scheme {
    let fields: [Field] = clear.count > 1 ? [.bytes(0, "b", size: clear.count - 1)] : []
    return try Scheme(Int(clear[0]), fields).withLimits(parity: parity)
}

/// The map row of a raw scheme for the bytes after the type byte.
func rawRow(_ clear: [UInt8]) -> [String: Any] {
    clear.count > 1 ? ["b": Array(clear.dropFirst())] : [:]
}

/// A copy of `message` with the byte at each position XORed by the matching value.
func corrupt(_ message: [UInt8], _ positions: [Int], _ values: [UInt8]) -> [UInt8] {
    var out = message
    for (p, v) in zip(positions, values) {
        out[p] ^= v
    }
    return out
}

/// `count` distinct positions below `size` and as many non-zero XOR values.
func pickWrong(_ random: inout SeededRandom, size: Int, count: Int) -> (positions: [Int], values: [UInt8]) {
    var positions: [Int] = []
    while positions.count < count {
        let p = Int.random(in: 0..<size, using: &random)
        if !positions.contains(p) { positions.append(p) }
    }
    return (positions, positions.map { _ in UInt8.random(in: 1...255, using: &random) })
}

/// The outcome of one repairing unpack of the position scheme with `parity` parity bytes.
enum PositionRead {
    case row([String: Any], repaired: Int)
    case refused(PackbinError)

    /// Whether the outcome is the golden row read with `count` bytes repaired.
    func isGolden(repaired count: Int) -> Bool {
        if case let .row(row, repaired) = self { return repaired == count && goldenFieldMismatches(row) == 0 }
        return false
    }

    var error: PackbinError? {
        if case let .refused(error) = self { return error }
        return nil
    }

    var rowCount: Int {
        if case .row = self { return 1 }
        return 0
    }
}

func readPosition(_ message: [UInt8], parity: Int, limit: Int) throws -> PositionRead {
    let scheme = try positionScheme(parity: parity)
    do {
        let got = try unpackMapRepair(message, limit: limit, scheme)
        return .row(got.row, repaired: got.repaired)
    } catch let error as PackbinError {
        return .refused(error)
    }
}
