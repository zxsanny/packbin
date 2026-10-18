/// The compact text format (contract `_docs/02_document/contracts/library/compact-text.md`, 1.0.0): the
/// tables of `TextTables.swift` turned into the lookups the encoder and the decoder use. Built once.
///
/// A symbol is addressed as `mode * 128 + index`; the index order is the contract's: the letters of the
/// language, the 32 shared characters, `SW` to each other mode, `CAP`, `LOCK`, `ESC` (the number mode:
/// the 15 number characters, `SW ua`, `SW ru`, `SW en`, `ESC`).
let textCodec = TextCodec()

/// What a symbol does when it is decoded.
enum TextSymbol {
    static let letter: UInt8 = 0
    static let character: UInt8 = 1
    static let switchMode: UInt8 = 2
    static let capital: UInt8 = 3
    static let lock: UInt8 = 4
    static let escape: UInt8 = 5
}

/// The first code point above every letter and character a text mode names (the Cyrillic block ends at
/// U+04FF); a character from here on has only the `ESC` edge.
let textTableRange = 0x500

/// The tables live for the whole process: the lookups are raw pointers to memory that is never freed, so the
/// hot loops of the encoder and the decoder index them without a bounds check or a retain.
struct TextCodec: @unchecked Sendable {
    /// Letters of the three text modes.
    let letters = [34, 33, 27]
    let length: UnsafePointer<UInt8>
    /// The canonical code of each symbol.
    let code: UnsafePointer<UInt32>
    let kind: UnsafePointer<UInt8>
    /// The code point of a letter (its small form) or a character, or the target mode of a `SW`.
    let argument: UnsafePointer<UInt32>
    /// The capital of a letter, or 0 when it has none (the apostrophe).
    let capital: UnsafePointer<UInt32>
    // Canonical decoding, per mode and code length 0...16: a 16-bit pattern below `limit[l]` (and not
    // below `limit[l - 1]`) is a code of length l, whose symbol is `sorted[offset[l] + (pattern >> (16 - l)) - first[l]]`.
    let limit: UnsafePointer<UInt32>
    let first: UnsafePointer<Int32>
    let offset: UnsafePointer<Int32>
    let sorted: UnsafePointer<UInt8>
    // Encoder lookups for the code points below `textTableRange`: the letter index of a small form and of a
    // capital in a text mode, the index of a shared character, the index of a number character (-1: none).
    let lowerLetter: [Int8]
    let upperLetter: [Int8]
    let sharedIndex: [Int8]
    let numberIndex: [Int8]
    /// The cheapest cost of the control edges (`SW`, `LOCK`) from state `s` to state `t`, where a state is
    /// `mode * 2 + lock`; entry s * 8 + t.
    let reach: UnsafePointer<Int32>

    init() {
        let lengthTables = [textLengthsUa, textLengthsRu, textLengthsEn, textLengthsNum]
        let alphabets = [textUa, textRu, textEn]
        let capitals = [textUaUpper, textRuUpper, textEnUpper]
        var length = [UInt8](repeating: 0, count: 512)
        var code = [UInt32](repeating: 0, count: 512)
        var kind = [UInt8](repeating: 0, count: 512)
        var argument = [UInt32](repeating: 0, count: 512)
        var capital = [UInt32](repeating: 0, count: 512)
        var limit = [UInt32](repeating: 0, count: 4 * 17)
        var first = [Int32](repeating: 0, count: 4 * 17)
        var offset = [Int32](repeating: 0, count: 4 * 17)
        var sorted = [UInt8](repeating: 0, count: 512)

        for m in 0..<4 {
            var at = m * 128
            if m < 3 {
                for i in 0..<alphabets[m].count {
                    kind[at] = TextSymbol.letter
                    argument[at] = alphabets[m][i]
                    capital[at] = capitals[m][i]
                    at += 1
                }
                for c in textShared {
                    kind[at] = TextSymbol.character
                    argument[at] = c
                    at += 1
                }
            } else {
                for c in textNumset {
                    kind[at] = TextSymbol.character
                    argument[at] = c
                    at += 1
                }
            }
            for t in 0..<(m < 3 ? 4 : 3) where t != m {
                kind[at] = TextSymbol.switchMode
                argument[at] = UInt32(t)
                at += 1
            }
            if m < 3 {
                kind[at] = TextSymbol.capital
                kind[at + 1] = TextSymbol.lock
                at += 2
            }
            kind[at] = TextSymbol.escape
            let size = at + 1 - m * 128
            let lengths = lengthTables[m]
            for i in 0..<size { length[m * 128 + i] = lengths[i] }

            // Canonical Huffman: symbols by (length, index); the first gets the all-zero code.
            let order = (0..<size).sorted { (lengths[$0], $0) < (lengths[$1], $1) }
            var next: UInt32 = 0
            var previous = 0
            for i in order {
                next <<= UInt32(Int(lengths[i]) - previous)
                code[m * 128 + i] = next
                next += 1
                previous = Int(lengths[i])
            }
            for (rank, i) in order.enumerated() { sorted[m * 128 + rank] = UInt8(i) }
            var count = [Int](repeating: 0, count: 18)
            for l in lengths { count[Int(l)] += 1 }
            var firstCode = 0
            var passed = 0
            for l in 1...16 {
                firstCode = (firstCode + count[l - 1]) << 1
                first[m * 17 + l] = Int32(firstCode)
                offset[m * 17 + l] = Int32(passed)
                limit[m * 17 + l] = UInt32((firstCode + count[l]) << (16 - l))
                passed += count[l]
            }
        }
        self.length = immortal(length)
        self.code = immortal(code)
        self.kind = immortal(kind)
        self.argument = immortal(argument)
        self.capital = immortal(capital)
        self.limit = immortal(limit)
        self.first = immortal(first)
        self.offset = immortal(offset)
        self.sorted = immortal(sorted)

        var lower = [Int8](repeating: -1, count: 3 * textTableRange)
        var upper = [Int8](repeating: -1, count: 3 * textTableRange)
        for m in 0..<3 {
            for i in 0..<alphabets[m].count {
                lower[m * textTableRange + Int(alphabets[m][i])] = Int8(i)
                if capitals[m][i] != 0 { upper[m * textTableRange + Int(capitals[m][i])] = Int8(i) }
            }
        }
        var shared = [Int8](repeating: -1, count: textTableRange)
        for (j, c) in textShared.enumerated() { shared[Int(c)] = Int8(j) }
        var number = [Int8](repeating: -1, count: textTableRange)
        for (j, c) in textNumset.enumerated() { number[Int(c)] = Int8(j) }
        lowerLetter = lower
        upperLetter = upper
        sharedIndex = shared
        numberIndex = number

        // Shortest paths over the control edges (Floyd-Warshall on the 8 states).
        let far: Int32 = 1 << 28
        var d = [[Int32]](repeating: [Int32](repeating: far, count: 8), count: 8)
        for s in 0..<8 {
            d[s][s] = 0
            let m = s >> 1
            let k = s & 1
            for t in 0..<4 where t != m {
                let sym = TextCodec.switchSymbol(m, t)
                d[s][t * 2 + k] = Int32(length[m * 128 + sym])
            }
            if m < 3 { d[s][m * 2 + 1 - k] = Int32(length[m * 128 + TextCodec.lockSymbol(m)]) }
        }
        for via in 0..<8 { for a in 0..<8 { for b in 0..<8 where d[a][via] + d[via][b] < d[a][b] { d[a][b] = d[a][via] + d[via][b] } } }
        reach = immortal(d.flatMap { $0 })
    }

    /// The index of `SW target` in the table of `mode`.
    static func switchSymbol(_ mode: Int, _ target: Int) -> Int {
        mode == 3 ? 15 + target : (mode == 0 ? 34 : mode == 1 ? 33 : 27) + 32 + (target < mode ? target : target - 1)
    }

    static func capitalSymbol(_ mode: Int) -> Int { (mode == 0 ? 34 : mode == 1 ? 33 : 27) + 35 }
    static func lockSymbol(_ mode: Int) -> Int { capitalSymbol(mode) + 1 }
    static func escapeSymbol(_ mode: Int) -> Int { mode == 3 ? 18 : capitalSymbol(mode) + 2 }
}

/// A copy of `values` in memory that is never freed.
func immortal<T>(_ values: [T]) -> UnsafePointer<T> {
    let p = UnsafeMutablePointer<T>.allocate(capacity: max(values.count, 1))
    p.initialize(from: values, count: values.count)
    return UnsafePointer(p)
}
