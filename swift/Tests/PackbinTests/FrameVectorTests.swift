import Foundation
@_spi(Vectors) import Packbin
import Testing

/// `text` with the first digit of `field` changed in the line `matches` accepts.
func corrupted(_ text: String, field: String, where matches: (String) -> Bool) -> String {
    text.components(separatedBy: "\n").map { line -> String in
        guard matches(line), let at = line.range(of: " \(field)=") else { return line }
        var changed = line
        changed.replaceSubrange(at.upperBound...at.upperBound, with: line[at.upperBound] == "0" ? "1" : "0")
        return changed
    }.joined(separator: "\n")
}

/// AZ-3234 AC-1 and AC-3 (S1, S3, S5, S7; AC-G1.1, AC-G1.3): every row of `fixtures/frame/vectors.txt` through the
/// public API, and the loader on a copy with one expected byte changed.
@Suite struct FrameVectorTests {
    @Test func everyRow_matchesTheFile_includingTheWorkedExamplesAndTheRefusals() throws {
        // Arrange
        let text = try repositoryFile("fixtures/frame/vectors.txt")
        var ran = 0

        // Act
        let failures = frameFixtureFailures(text, ran: &ran)

        // Assert
        #expect(failures.isEmpty, "\(failures.prefix(5))")
        #expect(ran == frameRows(text).count)
        #expect(ran >= 150, "only \(ran) rows ran")
    }

    @Test func theFile_holdsE1ToE5AndTheOperations() throws {
        // Arrange
        let rows = frameRows(try repositoryFile("fixtures/frame/vectors.txt"))
        let cases = Set(rows.compactMap { $0["case"] })

        // Act
        let missing = ["E1.seal", "E2.seal", "E3.seal", "E3.seal16", "E4.mac", "E5.mac", "refuse.seal.epoch1000000",
                       "refuse.seal.dir0", "refuse.seal.dir4", "refuse.seal.kind16", "refuse.seal.tag0",
                       "refuse.seal.tag5", "refuse.seal.tag32", "keys.d1.effffff"].filter { !cases.contains($0) }

        // Assert
        #expect(missing.isEmpty, "\(missing)")
        #expect(Set(rows.compactMap { $0["op"] }) == ["keys", "seal", "open", "mac", "replay"])
    }

    @Test(arguments: [("E1.seal", "body"), ("E2.open", "plain"), ("E4.mac", "tag"), ("E1.keys", "k_enc"),
                      ("replay.empty0", "states"), ("openwin.fresh", "window_after")])
    func loader_oneExpectedByteChanged_failsAndNamesTheRow(caseName: String, field: String) throws {
        // Arrange
        let text = try repositoryFile("fixtures/frame/vectors.txt")
        let changed = corrupted(text, field: field) { $0.contains(" case=\(caseName) ") }
        var ran = 0

        // Act
        let failures = frameFixtureFailures(changed, ran: &ran)

        // Assert
        #expect(changed != text, "the copy differs from the file")
        #expect(failures.count == 1, "\(failures)")
        #expect(failures.first?.hasPrefix(caseName + ":") == true, "\(failures)")
    }
}
