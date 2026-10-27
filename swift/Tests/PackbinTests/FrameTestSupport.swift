import Foundation
import Packbin
import Testing

/// A sealed message of the worked examples E1 to E3 of the contract, from the rows of `fixtures/frame/vectors.txt`.
struct WorkedExample {
    let name: String
    let key: [UInt8]
    let epoch: UInt32
    let direction: FrameDirection
    let tagLength: Int
    let context: MsgContext
    let ad: [UInt8]
    let clear: [UInt8]
    let plain: [UInt8]
    let body: [UInt8]

    func session() throws -> FrameSession {
        try FrameSession.load(key: key, epoch: epoch, config: FrameConfig(tagLength: tagLength))
    }
}

func workedExamples() throws -> [WorkedExample] {
    let rows = frameRows(try repositoryFile("fixtures/frame/vectors.txt"))
    return try ["E1.seal", "E2.seal", "E3.seal"].map { name in
        let row = try #require(rows.first { $0["case"] == name })
        return WorkedExample(
            name: name, key: vectorBytes(row["key"] ?? ""), epoch: UInt32(row["epoch"] ?? "") ?? 0,
            direction: try FrameDirection(number: Int(row["dir"] ?? "") ?? 0), tagLength: Int(row["tag_len"] ?? "") ?? 0,
            context: MsgContext(msgID: vectorBytes(row["msg_id"] ?? ""), kind: UInt8(row["kind"] ?? "") ?? 0),
            ad: vectorBytes(row["ad"] ?? "-"), clear: vectorBytes(row["clear"] ?? "-"),
            plain: vectorBytes(row["plain"] ?? "-"), body: vectorBytes(row["body"] ?? "-"))
    }
}

/// What one open did: the error kind or `nil` for Ok, the result, whether the output buffer still holds only the
/// sentinel, and whether the window is as it was.
struct OpenOutcome {
    var kind: PackbinError.Kind?
    var opened: FrameOpened?
    var plain: [UInt8]
    var untouched: Bool
    var windowKept: Bool
}

/// Opens `body` into a sentinel-filled buffer of `outLength` bytes with `window` and `counter` (no window when
/// `counter` is nil).
func attemptOpen(_ session: FrameSession, _ direction: FrameDirection, _ context: MsgContext, ad: [UInt8],
                 body: [UInt8], clearLength: Int, window: inout ReplayWindow, counter: UInt64? = nil,
                 outLength: Int = 300) -> OpenOutcome {
    var out = [UInt8](repeating: frameSentinel, count: outLength)
    let before = window
    do {
        let opened: FrameOpened
        if let counter {
            opened = try session.open(direction: direction, context: context, ad: ad, body: body,
                                      clearLength: clearLength, window: &window, counter: counter, into: &out)
        } else {
            opened = try session.open(direction: direction, context: context, ad: ad, body: body,
                                      clearLength: clearLength, into: &out)
        }
        return OpenOutcome(kind: nil, opened: opened, plain: Array(out[0..<opened.plainLength]),
                           untouched: false, windowKept: window == before)
    } catch let error as PackbinError {
        return OpenOutcome(kind: error.kind, opened: nil, plain: [],
                           untouched: out.allSatisfy { $0 == frameSentinel }, windowKept: window == before)
    } catch {
        Issue.record("not a PackbinError: \(error)")
        return OpenOutcome(kind: .badValue, opened: nil, plain: [], untouched: false, windowKept: false)
    }
}

/// A key of 32 bytes `byte`.
func repeatedKey(_ byte: UInt8) -> [UInt8] {
    [UInt8](repeating: byte, count: 32)
}

/// `bytes` with bit `bit` flipped.
func flipped(_ bytes: [UInt8], bit: Int) -> [UInt8] {
    var copy = bytes
    copy[bit / 8] ^= UInt8(1 << (bit % 8))
    return copy
}

/// A count of MAC computations that the session's probe bumps (from any thread).
final class MacCount: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func bump() {
        lock.lock()
        count += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }

    var probe: FrameProbe { FrameProbe(onMac: { [self] in bump() }) }
}

/// Seals one message into an exact-size buffer and returns the body.
func sealBody(_ session: FrameSession, _ direction: FrameDirection, _ context: MsgContext,
              ad: [UInt8] = [], clear: [UInt8] = [], plain: [UInt8]) throws -> [UInt8] {
    var out = [UInt8](repeating: frameSentinel, count: 255)
    let n = try session.seal(direction: direction, context: context, ad: ad, clear: clear, plain: plain, into: &out)
    return Array(out[0..<n])
}

/// A message id whose 8 bytes are `n` little-endian.
func messageID(_ n: UInt64) -> [UInt8] {
    (0..<8).map { UInt8(truncatingIfNeeded: n >> UInt64($0 * 8)) }
}
