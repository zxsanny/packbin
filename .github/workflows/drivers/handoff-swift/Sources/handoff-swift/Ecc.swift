import Foundation
import Packbin

// The message ECC commands of the handoff driver (AZ-2689; contract message-ecc.md).
//
//   ecc-protect <n> <clear hex>   prints the clear position message packed again with n parity bytes, or the error kind
//   ecc-repair <n> <t> <hex>      prints the position message repaired (hex, then the repaired count), or the error kind
//   ecc-batch <file>              one line per line of the file: `protect <n> <hex>` or `repair <n> <t> <hex>`
//
// "-" is the empty buffer. The kind names are the ones of fixtures/ecc/vectors.txt (uncorrectable, short, too_long,
// bad_parity, bad_limit) plus trailing, type_mismatch and unpack_failed for the walk of the unprotected fields.

private func eccBytes(_ token: String) -> [UInt8]? {
    token == "-" ? [] : hexBytes(token)
}

private func eccKind(_ error: PackbinError) -> String {
    switch error.kind {
    case .uncorrectable: return "uncorrectable"
    case .tooMany: return error.field == nil ? "too_long" : "unpack_failed"
    case .short: return error.name == "parity" ? "short" : "unpack_failed"
    case .trailing: return "trailing"
    case .unknownType: return "type_mismatch"
    default: return "unpack_failed"
    }
}

private func eccProtect(_ n: Int, _ clear: [UInt8]) throws -> String {
    let position = try positionScheme()
    let row: [String: Any]
    do {
        row = try unpackMap(clear, position)
    } catch is PackbinError {
        return "unpack_failed"
    }
    let protected: Scheme
    do {
        protected = try position.withLimits(parity: n)
    } catch is PackbinError {
        return "bad_parity"
    }
    do {
        return hexString(try pack(protected, row))
    } catch is PackbinError {
        return "pack_error"
    }
}

private func eccRepair(_ n: Int, _ t: Int, _ received: [UInt8]) throws -> String {
    let position = try positionScheme()
    let protected: Scheme
    do {
        protected = try position.withLimits(parity: n)
    } catch is PackbinError {
        return "bad_parity"
    }
    let got: (row: [String: Any], repaired: Int)
    do {
        got = try unpackMapRepair(received, limit: t, protected)
    } catch let error as PackbinError {
        return error.kind == .schemeError ? "bad_limit" : eccKind(error)
    }
    do {
        return "\(hexString(try pack(position, got.row))) \(got.repaired)"
    } catch is PackbinError {
        return "pack_error"
    }
}

private func eccLine(_ words: [String]) throws -> String? {
    if words.count == 3, words[0] == "protect", let n = Int(words[1]), let clear = eccBytes(words[2]) {
        return try eccProtect(n, clear)
    }
    if words.count == 4, words[0] == "repair", let n = Int(words[1]), let t = Int(words[2]), let received = eccBytes(words[3]) {
        return try eccRepair(n, t, received)
    }
    return nil
}

/// Runs one ecc command (`args` starts with its name) and returns the exit status.
func eccCommand(_ args: [String]) -> Int32 {
    var lines: [[String]]
    switch (args[0], args.count) {
    case ("ecc-protect", 3): lines = [["protect", args[1], args[2]]]
    case ("ecc-repair", 4): lines = [["repair", args[1], args[2], args[3]]]
    case ("ecc-batch", 2):
        guard let text = try? String(contentsOfFile: args[1], encoding: .utf8) else {
            return fail("ecc-batch: cannot read \(args[1])")
        }
        lines = text.split(separator: "\n").map { $0.split(separator: " ").map(String.init) }.filter { !$0.isEmpty }
    default: return 2
    }
    for words in lines {
        do {
            guard let out = try eccLine(words) else { return fail("ecc line: \(words.joined(separator: " "))") }
            print(out)
        } catch {
            return fail("ecc line: \(words.joined(separator: " ")): \(error)")
        }
    }
    return 0
}
