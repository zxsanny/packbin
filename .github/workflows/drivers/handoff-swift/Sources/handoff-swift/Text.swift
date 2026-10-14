#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif

/// The lowercase hex of `bytes`.
func hexString(_ bytes: [UInt8]) -> String {
    let digits = Array("0123456789abcdef")
    var text = ""
    text.reserveCapacity(bytes.count &* 2)
    for b in bytes {
        text.append(digits[Int(b >> 4)])
        text.append(digits[Int(b & 0x0f)])
    }
    return text
}

/// The bytes of `text`, or nil when it is not an even run of hex digits. It reads with checked indices
/// only, so no argument traps.
func hexBytes(_ text: String) -> [UInt8]? {
    let chars = Array(text.utf8)
    guard chars.count % 2 == 0 else { return nil }
    var out: [UInt8] = []
    out.reserveCapacity(chars.count / 2)
    var i = 0
    while i + 1 < chars.count {
        guard let hi = nibble(chars[i]), let lo = nibble(chars[i + 1]) else { return nil }
        out.append(hi << 4 | lo)
        i += 2
    }
    return out
}

private func nibble(_ c: UInt8) -> UInt8? {
    switch c {
    case UInt8(ascii: "0")...UInt8(ascii: "9"): return c - UInt8(ascii: "0")
    case UInt8(ascii: "a")...UInt8(ascii: "f"): return c - UInt8(ascii: "a") + 10
    case UInt8(ascii: "A")...UInt8(ascii: "F"): return c - UInt8(ascii: "A") + 10
    default: return nil
    }
}

/// A typed text of a row value, for comparing rows by Swift type and value (as the Go driver compares
/// with reflect.DeepEqual): each scalar with its type, a dictionary with its keys sorted, an absent
/// round entry as nil.
func render(_ v: Any) -> String {
    let mirror = Mirror(reflecting: v)
    if mirror.displayStyle == .optional {
        guard let wrapped = mirror.children.first?.value else { return "nil" }
        return render(wrapped)
    }
    if let s = v as? String { return "String(\(s.debugDescription))" }
    if let d = v as? [String: Any] {
        if d.isEmpty { return "[:]" }
        return "[" + d.sorted { $0.key < $1.key }.map { "\($0.key.debugDescription): \(render($0.value))" }
            .joined(separator: ", ") + "]"
    }
    if let a = v as? [Any] { return "[" + a.map(render).joined(separator: ", ") + "]" }
    return "\(type(of: v))(\(v))"
}

/// Writes `message` to stderr and returns 1, the exit of a failed command.
func fail(_ message: String) -> Int32 {
    fputs(message + "\n", stderr)
    return 1
}
