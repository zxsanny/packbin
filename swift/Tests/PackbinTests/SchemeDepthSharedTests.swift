import Foundation
import Packbin
import Testing

/// AZ-4306 (contract scheme-depth): a field that two parents share (the same `Field` used twice) is measured
/// once, so a scheme that uses one field twice per level is answered at once, and a shared field reached deeper
/// later is still measured at its deepest path. Runs on the main thread (8 MiB stack) like SchemeDepthTests.
@MainActor @Suite(.serialized) struct SchemeDepthSharedTests {
    /// `u8 a`, then `levels` nested `when(a == 1)` that each hold the next level twice, the leaf `u8 b` too.
    private func diamond(_ levels: Int) -> [Field] {
        var inner: Field = .u8(1, "b")
        for _ in 0..<levels { inner = .when(1, .eq(0, 1), [inner, inner]) }
        return [.u8(0, "a"), inner]
    }

    /// A chain of `shared` nested rows used at the top level and at the bottom of a path of `path` more nested
    /// rows: the deepest path holds `path + shared` levels. `listedFirst` puts the chain before the path.
    private func sharedChain(path: Int, shared: Int, listedFirst: Bool) -> [Field] {
        var chain: Field = .group("g", [.u8(0, "b")])
        for _ in 1..<shared { chain = .group("g", [chain]) }
        var deep = chain
        for _ in 0..<path { deep = .group("p", [deep]) }
        return listedFirst ? [chain, deep] : [deep, chain]
    }

    @Test func diamondOf60Levels_isRefusedAtOnce() {
        // Arrange (AC-1)
        let fields = diamond(60)
        let limit = bound(1)

        // Act
        let (error, seconds) = timed { packbinError { try Scheme(1, fields) } }

        // Assert: the leaf is held twice, so the id rule refuses it.
        #expect(error?.kind == .schemeError)
        #expect(error?.description.contains("field id: expected") == true, "\(String(describing: error))")
        expectWithin(seconds, limit)
    }

    @Test(arguments: [true, false])
    func sharedChainReachedDeeperLater_isMeasuredAtItsDeepest(_ listedFirst: Bool) throws {
        // Arrange (AC-3): 100 shared rows; the path adds 156 levels (256 in all) or 157 (257).
        let at = sharedChain(path: 156, shared: 100, listedFirst: listedFirst)
        let over = sharedChain(path: 157, shared: 100, listedFirst: listedFirst)

        // Act
        let built = try Scheme(1, at)
        let error = packbinError { try Scheme(1, over) }

        // Assert
        #expect(built.typeNumber == 1)
        #expect(error?.description == depthRefusal, "listedFirst \(listedFirst): \(String(describing: error))")
    }
}
