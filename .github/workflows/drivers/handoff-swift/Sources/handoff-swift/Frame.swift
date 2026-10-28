import Foundation
import Packbin

// A token that is not hex (a bad digit, an odd length), a number with other characters and a missing field are errors of
// the line, never an empty array or a trap; the batch loop reports the line number and stops.
private struct FrameLineError: Error {
    let message: String
}

private struct FrameWords {
    let w: [String]

    func word(_ i: Int) throws -> String {
        guard i < w.count else { throw FrameLineError(message: "missing field \(i)") }
        return w[i]
    }

    func bytes(_ i: Int) throws -> [UInt8] {
        let token = try word(i)
        if token == "-" { return [] }
        guard let raw = hexBytes(token) else { throw FrameLineError(message: "bad hex: \(token)") }
        return raw
    }

    // A number is decimal digits only (no sign, space or `_`) and at most top; no digit string wraps or overflows into
    // another value.
    func int<T: FixedWidthInteger>(_ i: Int, top: UInt64) throws -> T {
        let token = try word(i)
        let bad = FrameLineError(message: "bad number: \(token) (digits of 0 to \(top))")
        guard !token.isEmpty else { throw bad }
        var n: UInt64 = 0
        for c in token.utf8 {
            guard c >= 0x30, c <= 0x39 else { throw bad }
            n = n * 10 + UInt64(c - 0x30)
            guard n <= top else { throw bad }
        }
        guard let value = T(exactly: n) else { throw bad }
        return value
    }
}

private let byteTop: UInt64 = 255, lengthTop: UInt64 = 65535, epochTop: UInt64 = 4294967295

private func frameHex(_ data: [UInt8]) -> String {
    data.isEmpty ? "-" : hexString(data)
}

private func frameKind(_ error: PackbinError) -> String {
    switch error.kind {
    case .badValue: return "BadValue"
    case .tooLong: return "TooLong"
    case .bufferFull: return "BufferFull"
    case .short: return "ShortPacket"
    case .tagMismatch: return "TagMismatch"
    default: return "error"
    }
}

// The optional trailing fields of a seal or open line: the directions loaded (digits 1 to 3) and the output buffer size.
private func frameLoaded(_ f: FrameWords) throws -> (directions: FrameDirections, size: Int) {
    let digits = f.w.count > 9 ? f.w[9] : "123"
    let size: Int = try f.w.count > 10 ? f.int(10, top: lengthTop) : 300
    guard !digits.isEmpty, digits.allSatisfy({ "123".contains($0) }) else {
        throw FrameLineError(message: "bad dirs: \(digits)")
    }
    let mask = digits.reduce(UInt8(0)) { $0 | UInt8(1 << (Int(String($1))! - 1)) }
    return (FrameDirections(rawValue: mask), size)
}

private func frameSeal(_ w: [String]) throws -> String {
    let f = FrameWords(w: w)
    let key = try f.bytes(0)
    let epoch: UInt32 = try f.int(1, top: epochTop), d: Int = try f.int(2, top: byteTop)
    let tagLen: Int = try f.int(3, top: byteTop)
    let msgId = try f.bytes(4)
    let kind: UInt8 = try f.int(5, top: byteTop)
    let ad = try f.bytes(6), clear = try f.bytes(7), plain = try f.bytes(8)
    let (directions, size) = try frameLoaded(f)
    let session: FrameSession
    do {
        session = try FrameSession.load(key: key, epoch: epoch,
            config: FrameConfig(tagLength: tagLen, directions: directions))
    } catch let e as PackbinError {
        return frameKind(e)
    } catch {
        return "error"
    }
    var out = [UInt8](repeating: 0, count: size)
    do {
        let n = try session.seal(direction: FrameDirection(number: d), context: MsgContext(msgID: msgId, kind: kind),
            ad: ad, clear: clear, plain: plain, into: &out)
        return frameHex(Array(out[..<n]))
    } catch let e as PackbinError {
        return frameKind(e)
    } catch {
        return "error"
    }
}

private func frameOpen(_ w: [String]) throws -> String {
    let f = FrameWords(w: w)
    let key = try f.bytes(0)
    let epoch: UInt32 = try f.int(1, top: epochTop), d: Int = try f.int(2, top: byteTop)
    let tagLen: Int = try f.int(3, top: byteTop)
    let msgId = try f.bytes(4)
    let kind: UInt8 = try f.int(5, top: byteTop)
    let ad = try f.bytes(6)
    let clearLen: Int = try f.int(7, top: lengthTop)
    let body = try f.bytes(8)
    let (directions, size) = try frameLoaded(f)
    let session: FrameSession
    do {
        session = try FrameSession.load(key: key, epoch: epoch,
            config: FrameConfig(tagLength: tagLen, directions: directions))
    } catch let e as PackbinError {
        return frameKind(e)
    } catch {
        return "error"
    }
    var out = [UInt8](repeating: 0, count: size)
    do {
        let opened = try session.open(direction: FrameDirection(number: d), context: MsgContext(msgID: msgId, kind: kind),
            ad: ad, body: body, clearLength: clearLen, into: &out)
        return frameHex(Array(out[..<opened.plainLength]))
    } catch let e as PackbinError {
        return frameKind(e)
    } catch {
        return "error"
    }
}

private func frameMac(_ w: [String]) throws -> String {
    let f = FrameWords(w: w)
    let key = try f.bytes(0)
    let epoch: UInt32 = try f.int(1, top: epochTop)
    let label = try f.bytes(2)
    let n: Int = try f.int(3, top: byteTop)
    let message = try f.bytes(4)
    let mk: MacKey
    do {
        mk = try MacKey.derive(key: key, epoch: epoch, label: label)
    } catch let e as PackbinError {
        return frameKind(e)
    } catch {
        return "error"
    }
    do {
        let tag = try mk.tag([message], length: n)
        return frameHex(tag)
    } catch let e as PackbinError {
        return frameKind(e)
    } catch {
        return "error"
    }
}

private func frameVerify(_ w: [String]) throws -> String {
    let f = FrameWords(w: w)
    let key = try f.bytes(0)
    let epoch: UInt32 = try f.int(1, top: epochTop)
    let label = try f.bytes(2)
    let _: Int = try f.int(3, top: byteTop)  // n: checked, not used (the tag length comes from the tag)
    let message = try f.bytes(4)
    let tag = try f.bytes(5)
    let mk: MacKey
    do {
        mk = try MacKey.derive(key: key, epoch: epoch, label: label)
    } catch let e as PackbinError {
        return frameKind(e)
    } catch {
        return "error"
    }
    return mk.verify([message], tag: tag) ? "valid" : "invalid"
}

private func frameLine(_ words: [String]) throws -> String {
    switch words[0] {
    case "seal": return try frameSeal(Array(words[1...]))
    case "open": return try frameOpen(Array(words[1...]))
    case "mac": return try frameMac(Array(words[1...]))
    case "verify": return try frameVerify(Array(words[1...]))
    case "open-skip", "verify-skip": return "skip"
    default: throw FrameLineError(message: "unknown word \(words[0])")
    }
}

func frameCommand(_ args: [String]) -> Int32 {
    guard args.count == 2, args[0] == "frame-batch" else { return 2 }
    let path = args[1]
    guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
        return fail("frame-batch: cannot read \(path)")
    }
    for (index, line) in contents.split(separator: "\n", omittingEmptySubsequences: false).enumerated() {
        let words = line.split(whereSeparator: { $0 == " " || $0 == "\t" || $0 == "\r" }).map(String.init)
        if words.isEmpty { continue }
        do {
            print(try frameLine(words))
        } catch let e as FrameLineError {
            return fail("frame line \(index + 1): \(e.message)")
        } catch {
            return fail("frame line \(index + 1): \(error)")
        }
    }
    return 0
}
