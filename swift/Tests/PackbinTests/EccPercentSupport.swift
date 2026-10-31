import Packbin

/// One row of fixtures/ecc/percent-vectors.txt: `kind id args...` (row syntax at the top of that file).
func percentRows(_ kind: String) throws -> [EccRow] {
    try repositoryFile("fixtures/ecc/percent-vectors.txt").split(separator: "\n", omittingEmptySubsequences: true)
        .compactMap { line in
            guard !line.hasPrefix("#") else { return nil }
            let f = line.split(separator: " ", omittingEmptySubsequences: false).map(String.init)
            guard f.count >= 2, f[0] == kind else { return nil }
            return EccRow(kind: f[0], id: f[1], args: Array(f.dropFirst(2)))
        }
}

/// `rawScheme(for:parity:)` with a parity percentage.
func rawScheme(for clear: [UInt8], percent: Int) throws -> Scheme {
    try rawScheme(for: clear, parity: 0).withLimits(parityPercent: percent)
}

/// The parity count of a clear message of `length` bytes under `percent`, by the contract's integer formula.
func expectedCount(_ percent: Int, _ length: Int) -> Int {
    min(32, (percent * length + 99) / 100)
}

/// The largest clear length under `percent` 1...100, by search: the sent length stays within 254.
func expectedLargest(_ percent: Int) -> Int {
    (0...254).last { $0 + expectedCount(percent, $0) <= 254 } ?? 0
}

/// A clear message of `length` bytes (at least 1) whose bytes depend on `seed`.
func patternClear(_ length: Int, seed: Int) -> [UInt8] {
    (0..<length).map { UInt8(truncatingIfNeeded: $0 &* 29 &+ seed &* 7 &+ 3) }
}
