import Dispatch
import Packbin
import Testing

/// repeat { u8 k }
@Sendable func repeatK() throws -> Scheme { try Scheme(1, .repeat(0, .u8(0, "k"))) }

/// u8 n; times(n) { u8 k }
@Sendable func timesK() throws -> Scheme { try Scheme(1, .u8(0, "n"), .times(1, count: 0, .u8(1, "k"))) }

/// u32 n; times(n) { u8 k }
@Sendable func timesK32() throws -> Scheme { try Scheme(1, .u32(0, "n"), .times(1, count: 0, .u8(1, "k"))) }

/// The type byte 01, then `rounds` bytes of 7.
func roundsPacket(_ rounds: Int) -> [UInt8] {
    var packet = [UInt8](repeating: 7, count: 1 + rounds)
    packet[0] = 1
    return packet
}

/// The type byte 01, a little-endian u32 count, then `rounds` bytes of 7.
func countedPacket(_ count: UInt32, _ rounds: Int) -> [UInt8] {
    var packet: [UInt8] = [1]
    for i in 0..<4 { packet.append(UInt8(truncatingIfNeeded: count >> UInt32(i * 8))) }
    return packet + [UInt8](repeating: 7, count: rounds)
}

/// `count` copies of `v`, as the per-name list of a round.
func rounds(_ count: Int, _ v: Any) -> [Any] { [Any](repeating: v, count: count) }

/// `count` entries made by `entry`, as the per-name list of a round.
func perRound(_ count: Int, _ entry: (Int) -> Any?) -> [Any?] { (0..<count).map(entry) }

/// The error an unpack of `packet` throws, or nil when it gives a row.
func unpackError(_ packet: [UInt8], _ schemes: Scheme...) -> PackbinError? {
    packbinError { try unpackMap(packet, schemes) }
}

/// The error a pack of `row` throws, or nil when it gives bytes.
func packError(_ scheme: Scheme, _ row: [String: Any]) -> PackbinError? {
    packbinError { try pack(scheme, row) }
}

/// Whether `e` is a round refused when it would start: too many, nothing needed, `left` bytes left.
func isRefusedRound(_ e: PackbinError?, _ member: String, left: Int) -> Bool {
    e?.kind == .tooMany && e?.needed == 0 && e?.left == left && e?.name == member
}

/// Whether `e` is a pack refusal whose reason is `reason`, naming `member`.
func isPackRefusal(_ e: PackbinError?, _ member: String, _ reason: String) -> Bool {
    e?.kind == .packError && e?.name == member && e?.reason == reason
}

/// The text of a slot limit refusal.
func slotsText(_ member: String, _ slots: Int, _ limit: Int) -> String {
    "\(member): the rounds would hold \(slots) slots, above the limit of \(limit) slots"
}

/// The text of a bytes limit refusal.
func bytesText(_ member: String, _ bytes: Int, _ limit: Int) -> String {
    "\(member): the packet would be \(bytes) bytes, above the limit of \(limit) bytes"
}

/// The seconds `body` takes, and what it returns.
func timed<T>(_ body: () throws -> T) rethrows -> (T, Double) {
    let start = DispatchTime.now().uptimeNanoseconds
    let value = try body()
    return (value, Double(DispatchTime.now().uptimeNanoseconds - start) / 1e9)
}

/// The F10 packet (loop 21 security report): a list of 65 535 items, each a nested row of u8 n and a
/// times of n rounds of 64 u8 names k0 to k63; every byte is 1, so each item charges one round of 64
/// slots, 4 194 240 slots in all, in 4 259 778 bytes. `items` makes a smaller packet of the same shape.
func f10(items: Int = 65_535) throws -> (Scheme, [UInt8]) {
    let body = (0..<64).map { Field.u8(1 + $0, "k\($0)") }
    let scheme = try Scheme(1, .list("items", .group("item", [.u8(0, "n"), .times(1, count: 0, body)])))
    var packet = [UInt8](repeating: 1, count: 3 + 65 * items)
    packet[1] = UInt8(items & 0xff)
    packet[2] = UInt8(items >> 8)
    return (scheme, packet)
}

/// u32 n; times(n) { u8 m0 ... u8 m64 } and the row n = 65 535 with every m given once (it goes to
/// every round).
func wideRound() throws -> (Scheme, [String: Any]) {
    var row: [String: Any] = ["n": 65_535]
    for i in 0..<65 { row["m\(i)"] = 1 }
    let body = (0..<65).map { Field.u8(1 + $0, "m\($0)") }
    return (try Scheme(1, [.u32(0, "n"), .times(1, count: 0, body)]), row)
}

/// A named scheme and map row.
struct LimitRow: CustomTestStringConvertible, Sendable {
    let name: String
    let scheme: @Sendable () throws -> Scheme
    let row: @Sendable () -> [String: Any]
    var testDescription: String { name }

    init(_ name: String, _ scheme: @escaping @Sendable () throws -> Scheme, _ row: @escaping @Sendable () -> [String: Any]) {
        self.name = name
        self.scheme = scheme
        self.row = row
    }
}
