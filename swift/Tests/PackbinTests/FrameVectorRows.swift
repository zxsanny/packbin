import Packbin

/// One row of `fixtures/frame/vectors.txt` or `fixtures/crypto/vectors.txt`: the `name=value` fields, in file order
/// of the names that matter here. The frame rows start with `op=`, the primitive rows with the primitive and its
/// source (`sha256 fips180-4:b.1 ...`).
typealias VectorRow = [String: String]

/// The rows of a frame-vector file: every line that is not blank or a comment, split on spaces and on the first `=`.
func frameRows(_ text: String) -> [VectorRow] {
    text.split(separator: "\n").filter { !$0.isEmpty && !$0.hasPrefix("#") }.map { line in
        var row = VectorRow()
        for token in line.split(separator: " ") {
            let pair = token.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            row[String(pair[0])] = pair.count == 2 ? String(pair[1]) : ""
        }
        return row
    }
}

/// Hex with no separators; `-` is the empty string.
func vectorBytes(_ text: String) -> [UInt8] {
    text == "-" ? [] : bytes(text)
}

func vectorHex(_ value: [UInt8]) -> String {
    value.isEmpty ? "-" : hex(value)
}

/// The sentinel the output buffers hold before a call: a refused call must leave every byte of it.
let frameSentinel: UInt8 = 0xA5

func kindName(_ error: PackbinError) -> String {
    switch error.kind {
    case .badValue: return "BadValue"
    case .tooLong: return "TooLong"
    case .bufferFull: return "BufferFull"
    case .short: return "ShortPacket"
    case .tagMismatch: return "TagMismatch"
    case .duplicate: return "Duplicate"
    case .tooOld: return "TooOld"
    default: return "other:" + error.kind.rawValue
    }
}

func freshnessName(_ value: ReplayWindow.Freshness) -> String {
    switch value {
    case .fresh: return "Fresh"
    case .duplicate: return "Duplicate"
    case .tooOld: return "TooOld"
    }
}

func windowText(_ window: ReplayWindow) -> String {
    String(window.top, radix: 16) + ":" + String(window.bits, radix: 16)
}

func parseWindow(_ text: String) -> ReplayWindow {
    let pair = text.split(separator: ":")
    return ReplayWindow(top: UInt64(pair[0], radix: 16) ?? 0, bits: UInt64(pair[1], radix: 16) ?? 0)
}

private func directions(_ row: VectorRow) -> FrameDirections {
    var set: FrameDirections = []
    for digit in (row["dirs"] ?? "123") {
        switch digit {
        case "1": set.insert(.up)
        case "2": set.insert(.down)
        default: set.insert(.group)
        }
    }
    return set
}

private func load(_ row: VectorRow) throws -> FrameSession {
    let config = FrameConfig(tagLength: Int(row["tag_len"] ?? "4") ?? -1, directions: directions(row))
    return try FrameSession.load(key: vectorBytes(row["key"] ?? ""), epoch: UInt32(row["epoch"] ?? "") ?? 0, config: config)
}

private func context(_ row: VectorRow) -> MsgContext {
    MsgContext(msgID: vectorBytes(row["msg_id"] ?? ""), kind: UInt8(row["kind"] ?? "") ?? 0)
}

private func failed(_ error: Error) -> VectorRow {
    guard let error = error as? PackbinError else { return ["result": "not a PackbinError: \(error)"] }
    return ["result": kindName(error)]
}

/// The output fields of every row, by op: all must be in the row when the call gave them, and the call must give
/// every one the row has.
let frameOutputFields: [String: [String]] = [
    "keys": ["k_enc", "k_mac", "k_label"],
    "seal": ["body", "result"],
    "open": ["result", "slot", "plain", "window_after"],
    "mac": ["tag", "valid", "result"],
    "replay": ["results", "states"],
]

func runKeys(_ row: VectorRow) throws -> VectorRow {
    let key = vectorBytes(row["key"] ?? ""), epoch = UInt32(row["epoch"] ?? "") ?? 0
    if let label = row["label"] {
        let mac = try MacKey.derive(key: key, epoch: epoch, label: vectorBytes(label))
        return ["k_label": vectorHex(mac.storedKey)]
    }
    let session = try FrameSession.load(key: key, epoch: epoch, config: FrameConfig(tagLength: 4))
    let keys = session.derivedKeys(for: try FrameDirection(number: Int(row["dir"] ?? "") ?? 0))
    return ["k_enc": vectorHex(keys?.enc ?? []), "k_mac": vectorHex(keys?.mac ?? [])]
}

func runSeal(_ row: VectorRow, sentinelFailures: inout [String]) -> VectorRow {
    do {
        let direction = try FrameDirection(number: Int(row["dir"] ?? "") ?? 0)
        let session = try load(row)
        var out = [UInt8](repeating: frameSentinel, count: Int(row["out_len"] ?? "300") ?? 300)
        do {
            let n = try session.seal(direction: direction, context: context(row), ad: vectorBytes(row["ad"] ?? "-"),
                                     clear: vectorBytes(row["clear"] ?? "-"), plain: vectorBytes(row["plain"] ?? "-"),
                                     into: &out)
            return ["body": vectorHex(Array(out[0..<n]))]
        } catch {
            if out.contains(where: { $0 != frameSentinel }) { sentinelFailures.append("a refused seal wrote bytes") }
            throw error
        }
    } catch {
        return failed(error)
    }
}

func runOpen(_ row: VectorRow, sentinelFailures: inout [String]) -> VectorRow {
    var window = row["window"].map(parseWindow)
    let before = window
    var result: VectorRow
    do {
        let direction = try FrameDirection(number: Int(row["dir"] ?? "") ?? 0)
        let session = try load(row)
        if let previous = row["prev_key"] {
            try session.setPrevious(key: vectorBytes(previous), epoch: UInt32(row["prev_epoch"] ?? "") ?? 0)
        }
        var out = [UInt8](repeating: frameSentinel, count: Int(row["out_len"] ?? "300") ?? 300)
        let ad = vectorBytes(row["ad"] ?? "-"), body = vectorBytes(row["body"] ?? "-")
        let clearLength = Int(row["clear_len"] ?? "") ?? 0
        do {
            let opened: FrameOpened
            if let counter = row["counter"].flatMap({ UInt64($0) }), var w = window {
                opened = try session.open(direction: direction, context: context(row), ad: ad, body: body,
                                          clearLength: clearLength, window: &w, counter: counter, into: &out)
                window = w
            } else {
                opened = try session.open(direction: direction, context: context(row), ad: ad, body: body,
                                          clearLength: clearLength, into: &out)
            }
            result = ["result": "Ok", "slot": opened.slot == .current ? "current" : "previous",
                      "plain": vectorHex(Array(out[0..<opened.plainLength]))]
        } catch {
            if out.contains(where: { $0 != frameSentinel }) { sentinelFailures.append("a refused open wrote bytes") }
            throw error
        }
    } catch {
        result = failed(error)
        if window != before { sentinelFailures.append("a failed open changed the window") }
    }
    if let window { result["window_after"] = windowText(window) }
    return result
}

func runMac(_ row: VectorRow) -> VectorRow {
    let parts = (row["parts"].map { $0.split(separator: "|").map { vectorBytes(String($0)) } })
        ?? [vectorBytes(row["message"] ?? "-")]
    do {
        let key = try MacKey.derive(key: vectorBytes(row["key"] ?? ""), epoch: UInt32(row["epoch"] ?? "") ?? 0,
                                    label: vectorBytes(row["label"] ?? ""))
        if let tag = row["verify"] { return ["valid": String(key.verify(parts, tag: vectorBytes(tag)))] }
        return ["tag": vectorHex(try key.tag(parts, length: Int(row["n"] ?? "") ?? 0))]
    } catch {
        return failed(error)
    }
}

func runReplay(_ row: VectorRow) -> VectorRow {
    var window = ReplayWindow()
    var results: [String] = [], states: [String] = []
    for step in (row["steps"] ?? "").split(separator: ",") {
        let pair = step.split(separator: ":")
        let n = UInt64(pair[1]) ?? 0
        if pair[0] == "check" {
            results.append(freshnessName(window.check(n)))
        } else {
            window.commit(n)
            states.append(windowText(window))
        }
    }
    return ["results": results.joined(separator: ","), "states": states.isEmpty ? "-" : states.joined(separator: ",")]
}

/// Every row of a frame-vector file run through the public API; the rows that do not match, each as
/// `<case>: <what>`. An empty list means 0 mismatches. `ran` counts the rows that were run.
func frameFixtureFailures(_ text: String, ran: inout Int) -> [String] {
    var failures: [String] = []
    for row in frameRows(text) {
        let name = row["case"] ?? "?"
        var extra: [String] = []
        let derived: VectorRow
        switch row["op"] ?? "" {
        case "keys": derived = (try? runKeys(row)) ?? ["result": "keys failed"]
        case "seal": derived = runSeal(row, sentinelFailures: &extra)
        case "open": derived = runOpen(row, sentinelFailures: &extra)
        case "mac": derived = runMac(row)
        case "replay": derived = runReplay(row)
        default:
            failures.append("\(name): unknown op \(row["op"] ?? "")")
            continue
        }
        ran += 1
        failures += extra.map { "\(name): \($0)" }
        for (field, value) in derived where row[field] != value {
            failures.append("\(name): \(field) expected \(row[field] ?? "(none)") got \(value)")
        }
        for field in frameOutputFields[row["op"] ?? ""] ?? [] where row[field] != nil && derived[field] == nil {
            failures.append("\(name): the row has \(field) and the call gave none")
        }
    }
    return failures
}
