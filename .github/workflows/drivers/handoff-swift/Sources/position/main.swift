// Prints the hex of the AC-1 position row (the golden 4001000065cd1d00a3e1110100), as the position
// programs of the other packages do. ring-swift.sh builds it.
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif
import Packbin

do {
    let scheme = try Scheme(0x40, .u16(0, "sid"), .i32(1, "lat"), .i32(2, "lon"), .u8(3, "profile"),
                            .flags(4, .u16(4, "heading"), .u8(5, "speed"), .i16(6, "altitude")))
    let raw = try pack(scheme, ["sid": 1, "lat": 500_000_000, "lon": 300_000_000, "profile": 1])
    let digits = Array("0123456789abcdef")
    print(String(raw.flatMap { [digits[Int($0 >> 4)], digits[Int($0 & 0x0f)]] }))
} catch {
    fputs("position: \(error)\n", stderr)
    exit(1)
}
