import Packbin

/// The AC-1 scheme: the session ring and the position program both pack it.
func positionScheme() throws -> Scheme {
    try Scheme(0x40, .u16(0, "sid"), .i32(1, "lat"), .i32(2, "lon"), .u8(3, "profile"),
               .flags(4, .u16(4, "heading"), .u8(5, "speed"), .i16(6, "altitude")))
}

/// The session of the ring: seed bytes 1..32.
private func ringSession() throws -> PackSession {
    try PackSession.load((1...32).map { UInt8($0) })
}

/// 01 followed by 15 zero bytes.
private let ringNonce: [UInt8] = [1] + [UInt8](repeating: 0, count: 15)

/// The position scheme with `parity` parity bytes (0: the scheme as it is). The session-ecc commands use 4 (EC-10).
private func sessionScheme(parity: Int) throws -> Scheme {
    let position = try positionScheme()
    return parity == 0 ? position : try position.withLimits(parity: parity)
}

/// `pack-session` (parity 0) and `pack-session-ecc` (parity 4): the position row under the session.
func packSession(_ cmd: String, parity: Int) -> Int32 {
    do {
        let opener = try ringSession()
        _ = try opener.start(ringNonce)
        let payload = try opener.pack(try sessionScheme(parity: parity), ["sid": 1, "lat": 500_000_000, "lon": 300_000_000, "profile": 1])
        print(hexString(payload))
        return 0
    } catch {
        return fail("\(cmd): \(error)")
    }
}

func unpackSession(_ cmd: String, _ hex: String, parity: Int) -> Int32 {
    guard let payload = hexBytes(hex) else { return fail("\(cmd): bad hex: \(hex.debugDescription)") }
    let row: [String: Any]
    do {
        let waiter = try ringSession()
        try waiter.join(ringNonce)
        row = try waiter.unpackMap(payload, try sessionScheme(parity: parity))
    } catch {
        return fail("\(cmd): \(error)")
    }
    let want: [String: Any] = ["sid": UInt16(1), "lat": Int32(500_000_000), "lon": Int32(300_000_000), "profile": UInt8(1)]
    if render(row) != render(want) {
        return fail("\(cmd): read \(render(row)), expected \(render(want))")
    }
    return 0
}
