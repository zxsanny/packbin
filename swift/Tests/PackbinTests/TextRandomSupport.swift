import Dispatch
import Foundation

/// Random Unicode texts and count headers for the text tests that draw from a seed (AZ-2735, AZ-2736). Every
/// generator takes a `SeededRandom` (NoTrapTests.swift), so a failure replays from its seed.

private func scalars(_ text: String) -> [Unicode.Scalar] { Array(text.unicodeScalars) }

/// The pools a random text draws its runs from. Indexes 0 to 5 are the small and capital letters of the
/// Ukrainian, Russian and English alphabets, 6 the number characters, 7 the shared characters, 8 emoji (a
/// flag and a joined family among them), 9 other scripts and accented letters, 10 combining marks, 11 the code
/// points at the edges (controls, zero-width, noncharacters, the first and last of the planes).
private let textPools: [[Unicode.Scalar]] = [
    scalars("абвгґдеєжзиіїйклмнопрстуфхцчшщьюя'"),
    scalars("АБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯ"),
    scalars("абвгдеёжзийклмнопрстуфхцчшщъыьэюя"),
    scalars("АБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ"),
    scalars("abcdefghijklmnopqrstuvwxyz'"),
    scalars("ABCDEFGHIJKLMNOPQRSTUVWXYZ"),
    scalars("0123456789.,-: "),
    scalars(" 0123456789,.-:!?;()\"%/@+=*#&_$\n"),
    scalars("😀😂🎉🚀🔥👍🇺🇦👨\u{200D}👩\u{200D}👧❤\u{FE0F}🐱🌍"),
    scalars("中文日本語한국어العربيةעבריתहिन्दीไทยΕλληνικάÉßżłñü€£"),
    scalars("\u{300}\u{301}\u{302}\u{308}\u{323}\u{327}\u{35C}\u{20D7}\u{1AB0}\u{1DC0}"),
    ([0x0000, 0x0001, 0x007F, 0x0080, 0x200B, 0x200D, 0xFE0F, 0xFEFF, 0xFFFD, 0xFFFF, 0xD7FF, 0xE000,
      0x10000, 0x10FFFF] as [UInt32]).compactMap(Unicode.Scalar.init),
]

/// The index of the pool that draws any code point, surrogates excluded.
private let anyPool = textPools.count

private func pick(_ pool: Int, _ random: inout SeededRandom) -> Unicode.Scalar {
    if pool == anyPool {
        while true {
            if let scalar = Unicode.Scalar(UInt32(random.next() % 0x11_0000)) { return scalar }
        }
    }
    return textPools[pool][Int(random.next() % UInt64(textPools[pool].count))]
}

/// A random text of at most `longest` code points: runs of 1 to 8 characters, each from a random pool, or
/// (one text in three) words of one alphabet in small letters, with a capital first letter, in capitals or mixed,
/// which reaches the capital lock and the shift codes of the format.
func randomUnicodeText(_ random: inout SeededRandom, longest: Int = 60) -> String {
    random.next() % 3 == 0 ? randomWords(&random, longest: longest) : randomRuns(&random, longest: longest)
}

private func randomRuns(_ random: inout SeededRandom, longest: Int) -> String {
    var text = String.UnicodeScalarView()
    var left = Int(random.next() % UInt64(longest + 1))
    while left > 0 {
        let pool = Int(random.next() % UInt64(textPools.count + 1))
        let run = min(left, 1 + Int(random.next() % 8))
        for _ in 0..<run { text.append(pick(pool, &random)) }
        left -= run
    }
    return String(text)
}

private func randomWords(_ random: inout SeededRandom, longest: Int) -> String {
    let language = Int(random.next() % 3) * 2
    var text = String.UnicodeScalarView()
    let target = Int(random.next() % UInt64(longest + 1))
    while text.count < target {
        let style = random.next() % 4
        for i in 0..<(1 + Int(random.next() % 8)) {
            let capital = style == 2 || (style == 1 && i == 0) || (style == 3 && random.next() % 2 == 0)
            text.append(pick(language + (capital ? 1 : 0), &random))
        }
        text.append(pick(random.next() % 8 == 0 ? 6 : 7, &random))
    }
    return String(text)
}

/// A text of exactly `bytes` UTF-8 bytes: whole characters from `next` while they fit, then `a` for the rest.
func filledText(bytes: Int, _ next: () -> String) -> String {
    var text = ""
    var size = 0
    while true {
        let piece = next()
        let width = piece.utf8.count
        if width == 0 { continue }
        if size + width > bytes { break }
        text += piece
        size += width
    }
    return text + String(repeating: "a", count: bytes - size)
}

/// The LEB128 count header of a payload of `n` bytes (compact-text.md, Field).
func textCountHeader(_ n: Int) -> [UInt8] {
    var header: [UInt8] = []
    var rest = n
    while rest >= 0x80 {
        header.append(UInt8(rest & 0x7F) | 0x80)
        rest >>= 7
    }
    return header + [UInt8(rest)]
}

/// The payload length and header length of the field at the start of `field` when the count is a minimal
/// varint of 1 to 3 bytes, or nil.
func textCountOf(_ field: [UInt8]) -> (payload: Int, header: Int)? {
    var count = 0
    for k in 0..<min(3, field.count) {
        count |= Int(field[k] & 0x7F) << (7 * k)
        if field[k] & 0x80 == 0 { return k == 0 || field[k] != 0 ? (count, k + 1) : nil }
    }
    return nil
}

private final class Slot<T: Sendable>: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: T?

    func set(_ value: T) {
        lock.lock()
        stored = value
        lock.unlock()
    }

    var value: T? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }
}

/// Runs `body` on a thread of its own and returns what it returns, or nil when it is still running after
/// `seconds`: a hang fails the test that asked and does not block the suite. The limit is for a hang, not a
/// speed check (those use `LoadFactor.swift`).
func finishing<T: Sendable>(within seconds: Double, _ body: @escaping @Sendable () -> T) -> T? {
    let slot = Slot<T>()
    let done = DispatchGroup()
    done.enter()
    let thread = Thread {
        slot.set(body())
        done.leave()
    }
    thread.stackSize = 8 << 20
    thread.start()
    return done.wait(timeout: .now() + seconds) == .success ? slot.value : nil
}
