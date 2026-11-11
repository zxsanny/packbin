import Foundation
import Packbin

func hex(_ b: [UInt8]) -> String { b.map { String(format: "%02x", $0) }.joined() }
func fromHex(_ s: String) -> [UInt8] {
    var out: [UInt8] = []; var i = s.startIndex
    while i < s.endIndex { let j = s.index(i, offsetBy: 2); out.append(UInt8(s[i..<j], radix: 16)!); i = j }
    return out
}
func show(_ label: String, _ body: () throws -> String) {
    do { print("\(label): \(try body())") } catch let e as PackbinError {
        print("\(label): PackbinError kind=\(e.kind) name=\(e.name) reason=\"\(e.reason)\" needed=\(String(describing: e.needed)) left=\(String(describing: e.left))")
    } catch { print("\(label): error \(error)") }
}

let scheme = try Scheme(1, .dict("d", .u8(0, "v")))
func unp(_ h: String) throws -> String { String(describing: try unpackMap(fromHex(h), scheme)) }

print("== Swift probes")
let lone1 = String(decoding: [0xD800] as [UInt16], as: UTF16.self)
let lone2 = String(utf16CodeUnits: [0xD800], count: 1)
let lone3 = String(decoding: [0xDC00] as [UInt16], as: UTF16.self)
let fffd = "\u{FFFD}"
print("String(decoding:[0xD800],as:UTF16) scalars = \(lone1.unicodeScalars.map { String($0.value, radix: 16) }) utf8 = \(hex(Array(lone1.utf8)))")
print("String(utf16CodeUnits:[0xD800],count:1) scalars = \(lone2.unicodeScalars.map { String($0.value, radix: 16) })")
print("lone1 == FFFD: \(lone1 == fffd); lone2 == FFFD: \(lone2 == fffd); lone3 == lone1: \(lone3 == lone1)")
print("hash equal (FFFD, lone1, lone2): \(fffd.hashValue == lone1.hashValue && fffd.hashValue == lone2.hashValue)")
var d: [String: Any] = [:]
d[fffd] = 1; d[lone1] = 2; d[lone2] = 3
print("[String: Any] after 3 inserts of FFFD/lone1/lone2: count = \(d.count)")
print("String(validating: ED A0 80, as: UTF8) = \(String(validating: [0xED, 0xA0, 0x80] as [UInt8], as: UTF8.self) as Any)")
print("String(validatingUTF8:) ED A0 80 = \(String(validatingUTF8: [-19, -96, -128, 0]) as Any)")
print("String(decoding: ED A0 80, as: UTF8) scalars = \(String(decoding: [0xED, 0xA0, 0x80] as [UInt8], as: UTF8.self).unicodeScalars.map { String($0.value, radix: 16) })")
print("Unicode.Scalar(0xD800) = \(String(describing: Unicode.Scalar(0xD800 as UInt32)))")

print("-- harness: normal two-key pack/unpack")
show("pack a,b") { let w = try pack(scheme, ["d": ["a": 1, "b": 2]]); return "\(hex(w)); unpack \(try unp(hex(w)))" }

print("-- U+FFFD collision")
show("pack [FFFD:1, lone:2 (one key)]") { let w = try pack(scheme, ["d": d]); return "\(hex(w)); unpack \(try unp(hex(w)))" }
show("unpack two FFFD keys on wire (010200 0410efbfbd 01 0410efbfbd 02)") { try unp("0102000410efbfbd010410efbfbd02") }
show("unpack lone-half key ED A0 80 on wire (010100 0410eda080 01)") { try unp("0101000410eda08001") }

print("-- NFC vs NFD")
let nfc = "\u{00E9}", nfd = "e\u{0301}"
print("nfc == nfd: \(nfc == nfd); hash equal: \(nfc.hashValue == nfd.hashValue); utf8 nfc=\(hex(Array(nfc.utf8))) nfd=\(hex(Array(nfd.utf8)))")
var m: [String: Any] = [:]; m[nfc] = 1; m[nfd] = 2
print("[String: Any] after inserting both: count = \(m.count)")
show("pack Swift dict (one entry after merge)") { let w = try pack(scheme, ["d": m]); return hex(w) }
let both = NSDictionary(objects: [1, 2], forKeys: [nfc as NSString, nfd as NSString])
print("NSDictionary with both keys: count = \(both.count)")
show("pack NSDictionary holding both") { hex(try pack(scheme, ["d": both])) }
show("unpack wire with nfd then nfc (010200 0410 65cc81 01 0310 c3a9 02)") { try unp("01020004" + "10" + "65cc81" + "01" + "0310" + "c3a9" + "02") }
show("unpack wire with nfc only (010100 0310 c3a9 02)") { try unp("0101000310c3a902") }
