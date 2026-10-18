import Foundation
import Packbin
import Testing

/// AZ-2524 AC-1 (SW-13): the Swift snippets of README.md. Each snippet is the code between a
/// `README begin <name>` line and the next `README end` line of this file, without the 8 spaces of
/// indentation (the first README block also starts with `import Packbin`). Each test runs its snippet,
/// collects what it prints and compares it with the README output; `readme_swiftBlocks_areTheSnippets`
/// reads README.md and this file and fails when a README block or output differs from them.

/// What each snippet prints: the output block under it in README.md.
let readmeOutputs: [String: [String]] = [
    "typed": ["40 01 00 00 65 cd 1d 00 a3 e1 11 01 00", "500000000 true"],
    "map": ["40 01 00 00 65 cd 1d 00 a3 e1 11 01 00", "40 01 00 00 65 cd 1d 00 a3 e1 11 01 01 5a 00", "UInt16 90", "true"],
    "session": ["b5 5d 0a 29 c5 6c 20 37 12 b2 41 23 2e", "16 13 500000000"],
]

/// The README snippet names, in README order.
let readmeSnippetOrder = ["typed", "map", "ecc", "session"]

/// The `hex` function of the first README snippet, for the snippets after it.
func readmeHex(_ bytes: [UInt8]) -> String {
    bytes.map { $0 < 0x10 ? "0" + String($0, radix: 16) : String($0, radix: 16) }.joined(separator: " ")
}

@Suite struct ReadmeExampleTests {
    @Test func typedSnippet_printsTheGoldenHexAndUnpacksTheRow() throws {
        // Arrange: the snippet's `print` lines are collected.
        var printed: [String] = []
        func print(_ items: Any...) { printed.append(items.map { "\($0)" }.joined(separator: " ")) }

        // Act
        // README begin typed
        struct Position: PackbinRow {
            var sid: UInt16 = 0
            var lat: Int32 = 0
            var lon: Int32 = 0
            var profile: UInt8 = 0
            var heading: UInt16?
            var speed: UInt8?
            var altitude: Int16?
        }

        func hex(_ bytes: [UInt8]) -> String {
            bytes.map { $0 < 0x10 ? "0" + String($0, radix: 16) : String($0, radix: 16) }.joined(separator: " ")
        }

        let position = try Scheme(0x40,
            .u16(0, "sid").bind(get: { (r: Position) in r.sid }, set: { $0.sid = $1 }),
            .i32(1, "lat").bind(get: { (r: Position) in r.lat }, set: { $0.lat = $1 }),
            .i32(2, "lon").bind(get: { (r: Position) in r.lon }, set: { $0.lon = $1 }),
            .u8(3, "profile").bind(get: { (r: Position) in r.profile }, set: { $0.profile = $1 }),
            .flags(4,
                .u16(4, "heading").bind(get: { (r: Position) in r.heading }, set: { $0.heading = $1 }),
                .u8(5, "speed").bind(get: { (r: Position) in r.speed }, set: { $0.speed = $1 }),
                .i16(6, "altitude").bind(get: { (r: Position) in r.altitude }, set: { $0.altitude = $1 })))

        let raw = try pack(position, Position(sid: 1, lat: 500_000_000, lon: 300_000_000, profile: 1))
        print(hex(raw))

        if let got = try unpack(raw, position) as? Position {
            print(got.lat, got.heading == nil)
        }
        // README end

        // Assert
        #expect(printed == readmeOutputs["typed"])
        #expect(mismatchedBytes(raw, bytes(try goldenHex())) == 0)
        #expect(hex(raw) == readmeHex(raw))
    }

    @Test func mapSnippet_printsTheGoldenHexAndTheHeadingRow() throws {
        // Arrange: the snippet's `print` lines are collected; `hex` is the first snippet's.
        var printed: [String] = []
        func print(_ items: Any...) { printed.append(items.map { "\($0)" }.joined(separator: " ")) }
        let hex = readmeHex

        // Act
        // README begin map
        let position = try Scheme(0x40,
            .u16(0, "sid"),
            .i32(1, "lat"),
            .i32(2, "lon"),
            .u8(3, "profile"),
            .flags(4, .u16(4, "heading"), .u8(5, "speed"), .i16(6, "altitude")))

        let raw = try pack(position, ["sid": 1, "lat": 500_000_000, "lon": 300_000_000, "profile": 1])
        print(hex(raw))

        let withHeading = try pack(position, ["sid": 1, "lat": 500_000_000, "lon": 300_000_000, "profile": 1, "heading": 90])
        print(hex(withHeading))

        let row = try unpackMap(withHeading, position)
        if let heading = row["heading"] {
            print(type(of: heading), heading)
        }
        print(row["speed"] == nil)
        // README end

        // Assert
        #expect(printed == readmeOutputs["map"])
        #expect(mismatchedBytes(raw, bytes(try goldenHex())) == 0)
    }

    @Test func eccSnippet_repairsTheWrongByteAndReturnsTheRow() throws {
        // Act
        // README begin ecc
        // Packbin is imported as in the examples above.
        struct Reading: PackbinRow {
            var level: UInt16 = 0
        }

        let reading = try Scheme(2,
            .u16(0, "level").bind(get: { (r: Reading) in r.level }, set: { $0.level = $1 })).withLimits(parity: 4)

        var raw = try pack(reading, Reading(level: 7))   // 7 bytes
        raw[1] ^= 0x55                                   // one wrong byte

        let (row, repaired) = try unpackRepair(raw, limit: 2, reading)   // repaired == 1, (row as? Reading)?.level == 7
        // README end

        // Assert
        #expect(raw.count == 7 && repaired == 1 && (row as? Reading)?.level == 7)
    }

    @Test func sessionSnippet_printsTheCSharpCiphertextAndUnpacksIt() throws {
        // Arrange: the snippet's `print` lines are collected; `position` and `hex` are the map
        // snippet's scheme and the first snippet's function.
        var printed: [String] = []
        func print(_ items: Any...) { printed.append(items.map { "\($0)" }.joined(separator: " ")) }
        let position = try positionMapScheme()
        let hex = readmeHex

        // Act
        // README begin session
        let seed: [UInt8] = Array(1...32)   // the 32 bytes both sides hold, shared out of band
        let opener = try PackSession.load(seed)
        let hello = try opener.start([1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])   // start() draws them at random
        let waiter = try PackSession.load(seed)
        try waiter.join(hello)

        let payload = try opener.pack(position, ["sid": 1, "lat": 500_000_000, "lon": 300_000_000, "profile": 1])
        print(hex(payload))

        let back = try waiter.unpackMap(payload, position)
        if let lat = back["lat"] {
            print(hello.count, payload.count, lat)
        }
        // README end

        // Assert
        #expect(printed == readmeOutputs["session"])
        #expect(mismatchedBytes(payload, bytes(sessionCipherHex)) == 0)
    }

    @Test func readme_swiftBlocks_areTheSnippets() throws {
        // Arrange
        let snippets = try readmeSnippets()
        let blocks = try readmeSwiftBlocks()

        // Act
        let code = blocks.filter { !$0.code.contains(".package(url:") }

        // Assert
        #expect(snippets.map(\.name) == readmeSnippetOrder, "the README begin/end lines of this file")
        #expect(code.count == snippets.count, "Swift code blocks in README.md other than the install block")
        for (snippet, block) in zip(snippets, code) {
            let expected = (snippet.name == "typed" ? "import Packbin\n\n" : "") + snippet.code
            #expect(block.code == expected, "README block for the \(snippet.name) snippet")
            #expect(block.output == readmeOutputs[snippet.name], "README output of the \(snippet.name) snippet")
        }
    }
}

/// One snippet of this file: its name and its code without the indentation.
struct ReadmeSnippet {
    let name: String
    let code: String
}

/// One Swift block of README.md: its code and the lines of the plain block that follows it, if any.
struct ReadmeBlock {
    let code: String
    let output: [String]?
}

/// The snippets of this file, in file order.
func readmeSnippets() throws -> [ReadmeSnippet] {
    let source = try String(contentsOf: URL(fileURLWithPath: #filePath), encoding: .utf8)
    var snippets: [ReadmeSnippet] = []
    var name: String?
    var lines: [String] = []
    for line in source.components(separatedBy: "\n") {
        let text = line.trimmingCharacters(in: .whitespaces)
        if text.hasPrefix("// README begin ") {
            name = String(text.dropFirst("// README begin ".count))
            lines = []
        } else if text == "// README end", let current = name {
            snippets.append(ReadmeSnippet(name: current, code: lines.map { $0 + "\n" }.joined()))
            name = nil
        } else if name != nil {
            lines.append(line.hasPrefix("        ") ? String(line.dropFirst(8)) : line)
        }
    }
    return snippets
}

/// Every ```swift block of README.md, with the plain ``` block that follows it after blank lines.
func readmeSwiftBlocks() throws -> [ReadmeBlock] {
    let lines = try repositoryFile("README.md").components(separatedBy: "\n")
    var blocks: [ReadmeBlock] = []
    var i = 0
    while i < lines.count {
        guard lines[i] == "```swift" else {
            i += 1
            continue
        }
        let code = fencedBody(lines, from: i + 1)
        var next = code.end + 1
        while next < lines.count && lines[next].isEmpty { next += 1 }
        let output = next < lines.count && lines[next] == "```" ? fencedBody(lines, from: next + 1) : nil
        blocks.append(ReadmeBlock(code: code.lines.map { $0 + "\n" }.joined(), output: output?.lines))
        i = (output?.end ?? code.end) + 1
    }
    return blocks
}

/// The lines from `start` up to the closing fence, and the index of that fence.
func fencedBody(_ lines: [String], from start: Int) -> (lines: [String], end: Int) {
    var end = start
    while end < lines.count && lines[end] != "```" { end += 1 }
    return (Array(lines[start..<min(end, lines.count)]), end)
}
