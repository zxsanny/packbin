import Packbin
import Testing

/// AC-2 of AZ-2736 (CS-5, TW-2): random Unicode strings round-trip through the compact text codec. Seeded, so
/// a failure replays; the strings are compared as UTF-8 bytes, since Swift's `==` is canonical equivalence.
@Suite struct TextRandomTests {
    @Test func packThenUnpack_threeThousandRandomUnicodeStrings_returnEachStringUnchanged() throws {
        // Arrange
        let scheme = try loneString()
        var random = SeededRandom(state: 2736)
        var texts = [""]
        for _ in 0..<3_000 { texts.append(randomUnicodeText(&random)) }
        texts.append(filledText(bytes: 65_535) { randomUnicodeText(&random, longest: 40) })
        texts.append(filledText(bytes: 65_535) { "Привіт, світе! Як ти? " })
        texts.append(String(repeating: "q", count: 65_535))
        texts += ["a", "Я", "\u{0}", "😀", "e\u{301}", "\u{10FFFF}", String(repeating: "\u{301}", count: 100)]

        // Act
        var failures: [String] = []
        var largestSaving = 0
        for (index, text) in texts.enumerated() {
            let want = Array(text.utf8)
            do {
                let packet = try pack(scheme, ["s": text])
                let back = utf8Of(try unpackMap(packet, scheme)["s"])
                if back != want { failures.append("#\(index) \(hex(Array(want.prefix(40)))): came back as \(back.map { hex(Array($0.prefix(40))) } ?? "no text")") }
                if packet.count - 1 > fieldBound(utf8Count: want.count) {
                    failures.append("#\(index): field of \(packet.count - 1) bytes for \(want.count) UTF-8 bytes")
                }
                largestSaving = max(largestSaving, want.count - (packet.count - 1))
            } catch {
                failures.append("#\(index) \(hex(Array(want.prefix(40)))): \(error)")
            }
        }

        // Assert
        print("TextRandomTests: \(texts.count) strings, largest saving \(largestSaving) bytes, \(failures.count) failures")
        #expect(texts.count >= 3_000 && largestSaving > 1_000, "the compact payload is used")
        #expect(failures.isEmpty, "\(failures.prefix(10))")
    }

    @Test func randomStrings_coverCapitalsEmojiOtherScriptsCombiningMarksAndTheEmptyString() {
        // Arrange
        var random = SeededRandom(state: 2736)
        var texts: [String] = []
        for _ in 0..<3_000 { texts.append(randomUnicodeText(&random)) }

        // Act
        let empty = texts.filter { $0.isEmpty }.count
        let capitals = texts.filter { $0.unicodeScalars.contains { $0.properties.isUppercase } }.count
        let emoji = texts.filter { $0.unicodeScalars.contains { $0.properties.isEmojiPresentation } }.count
        let scripts = texts.filter { $0.unicodeScalars.contains { $0.value >= 0x590 && !$0.properties.isEmoji && $0.value < 0xE000 } }.count
        let marks = texts.filter { $0.unicodeScalars.contains { $0.properties.generalCategory == .nonspacingMark } }.count
        let wide = texts.filter { $0.utf8.count > 100 }.count

        // Assert
        print("TextRandomTests: of 3000 texts \(empty) empty, \(capitals) with capitals, \(emoji) emoji, \(scripts) other scripts, \(marks) combining marks, \(wide) over 100 bytes")
        #expect(empty >= 10 && capitals >= 500 && emoji >= 200 && scripts >= 200 && marks >= 200 && wide >= 100)
    }
}

/// The most bytes a field of a text of `utf8Count` UTF-8 bytes may take: the count header and the raw payload
/// (the format never writes a compact payload that is not smaller than the raw one).
private func fieldBound(utf8Count: Int) -> Int {
    utf8Count == 0 ? 1 : textCountHeader(1 + utf8Count).count + 1 + utf8Count
}
