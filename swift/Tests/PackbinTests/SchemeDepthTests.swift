import Foundation
import Packbin
import Testing

/// The contract scheme-depth (loop 126, AZ-4300): a scheme nested deeper than 256 containers is refused when
/// it is built, before any walk, and 256 levels build, pack and unpack at the default stack.
let depthRefusal = "packbin: invalid scheme: scheme nested too deep: more than 256 levels; the limit is 256"

/// The chains of the 1,000 and 50,000 tests (the scheme fields and the nested row) are kept for the life of the
/// process: releasing a chain that deep is a recursive release in Swift, and the test is about the scheme build,
/// not about that release.
private nonisolated(unsafe) var keptChains: [DepthChain] = []

/// Every test runs on the main thread, whose default stack is 8 MiB.
@MainActor @Suite(.serialized) struct SchemeDepthTests {
    /// The 256-level tests need it: a debug build on a 512 KiB thread of Swift concurrency (where Swift Testing
    /// runs a plain test) needs about 560 KiB for 256 `when`s, and more for the row kinds.
    @Test(arguments: DepthKind.allCases)
    func scheme256Levels_buildsPacksAndUnpacks(_ kind: DepthKind) throws {
        // Arrange (AC-2)
        let chain = kind.chain(256)

        // Act
        let scheme = try chain.scheme()
        let wire = try pack(scheme, chain.row)
        let back = try unpackMap(wire, scheme)
        let again = try pack(scheme, back)

        // Assert
        if let want = chain.wire { #expect(hex(wire) == want, "\(kind)") }
        #expect(again == wire, "\(kind): the unpacked row packs to other bytes")
    }

    @Test(arguments: DepthKind.allCases)
    func scheme257Levels_isRefusedWithTheContractText(_ kind: DepthKind) {
        // Arrange (AC-1, the boundary)
        let chain = kind.chain(257)

        // Act
        let error = packbinError { try chain.scheme() }

        // Assert
        #expect(error?.kind == .schemeError, "\(kind)")
        #expect(error?.description == depthRefusal, "\(kind): \(String(describing: error))")
    }

    @Test(arguments: DepthKind.allCases, [1_000, 50_000])
    func schemeFarOverTheLimit_isRefusedQuicklyWithNoStackError(_ kind: DepthKind, _ levels: Int) {
        // Arrange (AC-1)
        let chain = kind.chain(levels)
        keptChains.append(chain)
        let limit = bound(5)

        // Act
        let (error, seconds) = timed { packbinError { try chain.scheme() } }

        // Assert
        #expect(error?.kind == .schemeError, "\(kind) \(levels)")
        #expect(error?.description == depthRefusal, "\(kind) \(levels): \(String(describing: error))")
        expectWithin(seconds, limit)
    }

    @Test func nestedRows256Levels_buildInWellUnderASecond() throws {
        // Arrange (the nested-row cost was cubic in depth)
        let chain = DepthKind.group.chain(256)
        let limit = bound(1)

        // Act
        let (scheme, seconds) = timed { try? chain.scheme() }
        print("SchemeDepthTests: 256 nested rows built in \(seconds) s")

        // Assert
        #expect(scheme != nil)
        expectWithin(seconds, limit)
    }

    @Test func tooDeepSchemeWithABadId_isRefusedForItsDepthFirst() throws {
        // Arrange (the depth rule runs before every other check: a too deep scheme with a bad id says depth)
        var inner: [Field] = [.u8(7, "b")]
        for _ in 0..<257 { inner = [.when(1, .eq(0, 1), inner)] }

        // Act
        let error = packbinError { try Scheme(1, [.u8(0, "a")] + inner) }

        // Assert
        #expect(error?.description == depthRefusal)
    }

    @Test func splitFlagBitHoldingFlags_addsNoLevelOfItsOwn() throws {
        // Arrange (a flag bit holds a member and adds no level; the 255 flags in it count 255)
        let fb = FlagByte("fb")
        var inner: Field = .u8(0, "c")
        for _ in 0..<255 { inner = .flags(0, inner) }
        let fields: [Field] = [.flagByte(fb), fb.bit(inner)]

        // Act
        let scheme = try Scheme(1, fields)
        let wire = try pack(scheme, ["c": 9])

        // Assert
        #expect(hex(wire) == "01" + "01" + String(repeating: "01", count: 255) + "09")
    }
}
