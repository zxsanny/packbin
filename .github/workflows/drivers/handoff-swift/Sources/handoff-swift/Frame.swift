import Foundation
import Packbin

private func frameBytes(_ token: String) -> [UInt8] {
    token == "-" ? [] : hexBytes(token) ?? []
}

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
private func frameLoaded(_ w: [String]) -> (directions: FrameDirections, size: Int) {
    let digits = w.count > 9 ? w[9] : "123"
    let size = w.count > 10 ? Int(w[10])! : 300
    let mask = digits.reduce(UInt8(0)) { $0 | UInt8(1 << (Int(String($1))! - 1)) }
    return (FrameDirections(rawValue: mask), size)
}

private func frameSeal(_ w: [String]) -> String {
    let key = frameBytes(w[0])
    let epoch = UInt32(w[1])!, d = Int(w[2])!, tagLen = Int(w[3])!
    let msgId = frameBytes(w[4])
    let kind = UInt8(w[5])!
    let ad = frameBytes(w[6]), clear = frameBytes(w[7]), plain = frameBytes(w[8])
    let (directions, size) = frameLoaded(w)
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

private func frameOpen(_ w: [String]) -> String {
    let key = frameBytes(w[0])
    let epoch = UInt32(w[1])!, d = Int(w[2])!, tagLen = Int(w[3])!
    let msgId = frameBytes(w[4])
    let kind = UInt8(w[5])!
    let ad = frameBytes(w[6])
    let clearLen = Int(w[7])!
    let body = frameBytes(w[8])
    let (directions, size) = frameLoaded(w)
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

private func frameMac(_ w: [String]) -> String {
    let key = frameBytes(w[0])
    let epoch = UInt32(w[1])!
    let label = frameBytes(w[2])
    let n = Int(w[3])!
    let message = frameBytes(w[4])
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

private func frameVerify(_ w: [String]) -> String {
    let key = frameBytes(w[0])
    let epoch = UInt32(w[1])!
    let label = frameBytes(w[2])
    // n = w[3], not used for verify
    let message = frameBytes(w[4])
    let tag = frameBytes(w[5])
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

private func frameLine(_ words: [String]) -> String {
    switch words[0] {
    case "seal": return frameSeal(Array(words[1...]))
    case "open": return frameOpen(Array(words[1...]))
    case "mac": return frameMac(Array(words[1...]))
    case "verify": return frameVerify(Array(words[1...]))
    case "open-skip", "verify-skip": return "skip"
    default: fatalError("frame line: \(words[0])")
    }
}

func frameCommand(_ args: [String]) -> Int32 {
    guard args.count == 2, args[0] == "frame-batch" else { return 2 }
    let path = args[1]
    guard let contents = try? String(contentsOfFile: path, encoding: .utf8) else {
        return fail("frame-batch: cannot read \(path)")
    }
    for line in contents.split(separator: "\n") {
        let words = line.split(separator: " ").map(String.init)
        if !words.isEmpty {
            print(frameLine(words))
        }
    }
    return 0
}
