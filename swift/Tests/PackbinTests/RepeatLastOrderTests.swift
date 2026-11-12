import Packbin
import Testing

/// A run of scheme shapes with many siblings that write no byte, for the speed of the repeat-last walk.
struct SiblingShape: CustomTestStringConvertible, Sendable {
    let name: String
    let fields: @Sendable (Int) -> [Field]
    var testDescription: String { name }

    init(_ name: String, _ fields: @escaping @Sendable (Int) -> [Field]) {
        self.name = name
        self.fields = fields
    }
}

/// `count` siblings `when(k == 1) { bytes 0 }`, ids from `first`: each holds a field that writes no byte.
private func freeWhens(_ count: Int, from first: Int) -> [Field] {
    (0..<count).map { i in .when(first + i, .eq(0, 1), .bytes(first + i, "z\(i)", size: 0)) }
}

/// AZ-4216, contract repeat-last: the walk that refuses a repeat that is not last visits each field a
/// bounded number of times, whatever the shape of the scheme, and the first violation in document order
/// is the one it reports.
@Suite struct RepeatLastOrderTests {
    static let siblings = 8_000

    static let shapes: [SiblingShape] = [
        SiblingShape("no repeat, then siblings that write nothing") { n in
            [.u8(0, "k")] + freeWhens(n, from: 1)
        },
        SiblingShape("a repeat, then siblings that write nothing") { n in
            [.u8(0, "k"), .repeat(1, .u8(1, "v"))] + freeWhens(n, from: 2)
        },
        SiblingShape("siblings that write nothing, then a repeat") { n in
            [.u8(0, "k")] + freeWhens(n, from: 1) + [.repeat(1 + n, .u8(1 + n, "v"))]
        },
        SiblingShape("a repeat, then repeats whose body writes nothing") { n in
            [.u8(0, "k"), .repeat(1, .u8(1, "v"))]
                + (0..<n).map { i in Field.repeat(2 + i, .bytes(2 + i, "z\(i)", size: 0)) }
        },
    ]

    /// The nominal bound of the build of `siblings` fields: the linear walk takes 0.08 to 0.14 s in a debug
    /// build and 0.013 to 0.02 s in a release build; a walk that looks ahead at each sibling takes 9 s and
    /// 0.34 to 0.39 s.
    #if DEBUG
    static let nominalBuildSeconds = 0.8
    #else
    static let nominalBuildSeconds = 0.1
    #endif

    /// AC-1: a scheme that is not refused is walked once, so the build of 8 000 siblings takes time in
    /// proportion to its size, whatever the shape.
    @Test(arguments: shapes)
    func scheme_manySiblingsThatWriteNothing_isBuiltInTimeLinearInItsSize(_ shape: SiblingShape) throws {
        // Arrange
        let fields = shape.fields(Self.siblings)
        let limit = bound(Self.nominalBuildSeconds)

        // Act
        let (built, seconds) = try timed { try Scheme(1, fields) }

        // Assert
        #expect(built.typeNumber == 1)
        expectWithin(seconds, limit)
    }

    /// The first violation in document order is reported: the repeat inside the list element of the round
    /// comes before the field that follows the round, so the element text is the answer, as in the other
    /// packages.
    @Test func scheme_elementRepeatInsideARepeatThatAFieldFollows_isRefusedWithTheElementText() {
        // Arrange
        let build = {
            try Scheme(1, .repeat(0, .u8(0, "k"), .list("rows", .group("row", .repeat(0, .u8(0, "v"))))), .u8(1, "x"))
        }

        // Act
        let error = packbinError(build)

        // Assert
        #expect(error?.kind == .schemeError)
        #expect(error?.description == "packbin: invalid scheme at field 0: repeat 0 is inside a list or dict element; "
            + "a repeat reads to the end of the packet, so another element cannot follow it; use times")
    }
}
