import Packbin
import Testing

/// One README data-type row: the scheme, the map row, the hex both ways and the map unpack gives.
struct ReadmeCase: CustomTestStringConvertible, Sendable {
    let name: String
    let scheme: @Sendable () throws -> Scheme
    let row: @Sendable () -> [String: Any]
    let wire: String
    let back: String
    var testDescription: String { name }
}

let readmeCases: [ReadmeCase] = [
    ReadmeCase(name: "integers", scheme: { try Scheme(1, .u16(0, "n"), .i16(1, "d")) },
               row: { ["n": 1, "d": -2] }, wire: "010100feff", back: "d=Int16:-2,n=UInt16:1"),
    ReadmeCase(name: "f32", scheme: { try Scheme(1, .f32(0, "x")) },
               row: { ["x": 1.5] }, wire: "010000c03f", back: "x=Float:1.5"),
    ReadmeCase(name: "f64", scheme: { try Scheme(1, .f64(0, "x")) },
               row: { ["x": 1.5] }, wire: "01000000000000f83f", back: "x=Double:1.5"),
    ReadmeCase(name: "fixed bytes", scheme: { try Scheme(1, .bytes(0, "b", size: 3)) },
               row: { ["b": Array("abc".utf8)] }, wire: "01616263", back: "b=Array<UInt8>:616263"),
    ReadmeCase(name: "big-endian", scheme: { try Scheme(1, .be(.u16(0, "n"))) },
               row: { ["n": 1] }, wire: "010001", back: "n=UInt16:1"),
    ReadmeCase(name: "flags", scheme: { try Scheme(1, .flags(0, .u16(0, "heading"), .u8(1, "speed"))) },
               row: { ["heading": 90] }, wire: "01015a00", back: "heading=UInt16:90"),
    ReadmeCase(name: "flags zero", scheme: { try Scheme(1, .flags(0, .u16(0, "heading"), .u8(1, "speed"))) },
               row: { ["heading": 0] }, wire: "01010000", back: "heading=UInt16:0"),
    ReadmeCase(name: "flags speed", scheme: { try Scheme(1, .flags(0, .u16(0, "heading"), .u8(1, "speed"))) },
               row: { ["speed": 10] }, wire: "01020a", back: "speed=UInt8:10"),
    ReadmeCase(name: "bool", scheme: { try Scheme(1, .flags(0, .bool(0, "on"), .u8(1, "n"))) },
               row: { ["on": true, "n": 7] }, wire: "010307", back: "n=UInt8:7,on=Bool:true"),
    ReadmeCase(name: "bool false", scheme: { try Scheme(1, .flags(0, .bool(0, "on"), .u8(1, "n"))) },
               row: { ["on": false, "n": 7] }, wire: "010207", back: "n=UInt8:7"),
    ReadmeCase(name: "when", scheme: { try Scheme(1, .u8(0, "profile"), .when(1, .eq(0, 0), .u8(1, "shape"))) },
               row: { ["profile": 0, "shape": 9] }, wire: "010009", back: "profile=UInt8:0,shape=UInt8:9"),
    ReadmeCase(name: "when miss", scheme: { try Scheme(1, .u8(0, "profile"), .when(1, .eq(0, 0), .u8(1, "shape"))) },
               row: { ["profile": 1, "shape": 9] }, wire: "0101", back: "profile=UInt8:1"),
    ReadmeCase(name: "flags when mode 1", scheme: flagsWhenScheme,
               row: { ["mode": 1, "speed": 7, "heading": 90] }, wire: "010103075a00",
               back: "heading=UInt16:90,mode=UInt8:1,speed=UInt8:7"),
    ReadmeCase(name: "flags when mode 0", scheme: flagsWhenScheme,
               row: { ["mode": 0, "speed": 7, "heading": 90] }, wire: "0100025a00",
               back: "heading=UInt16:90,mode=UInt8:0"),
    ReadmeCase(name: "split when mode 0", scheme: splitWhenScheme,
               row: { ["mode": 0, "speed": 7, "heading": 90] }, wire: "0100025a00",
               back: "heading=UInt16:90,mode=UInt8:0"),
    ReadmeCase(name: "split when mode 1", scheme: splitWhenScheme,
               row: { ["mode": 1, "speed": 7, "heading": 90] }, wire: "010103075a00",
               back: "heading=UInt16:90,mode=UInt8:1,speed=UInt8:7"),
]

@Sendable func flagsWhenScheme() throws -> Scheme {
    try Scheme(1, .u8(0, "mode"), .flags(1, .when(1, .eq(0, 1), .u8(1, "speed")), .u16(2, "heading")))
}

@Sendable func splitWhenScheme() throws -> Scheme {
    let m = FlagByte("m")
    return try Scheme(1, .u8(0, "mode"), .flagByte(m), m.bit(.when(1, .eq(0, 1), .u8(1, "speed"))),
                      m.bit(.u16(2, "heading")))
}

/// AC-2 (SW-2): the README examples for integers, floats, fixed bytes, big-endian, bool, flags and
/// `when` give the README hex both ways, as TypeScript at HEAD gives them.
@Suite struct ReadmeScalarTests {
    @Test(arguments: readmeCases)
    func packAndUnpack_readmeRow_giveReadmeHex(_ c: ReadmeCase) throws {
        // Arrange
        let scheme = try c.scheme()

        // Act
        let raw = try pack(scheme, c.row())
        let back = try unpackMap(bytes(c.wire), scheme)

        // Assert
        #expect(mismatchedBytes(raw, bytes(c.wire)) == 0, "packed \(hex(raw))")
        #expect(describeMap(back) == c.back)
        #expect(try packHex(scheme, back) == c.wire)
    }

    @Test func pack_typedReadmeRows_giveReadmeHex() throws {
        // Arrange
        let n = Field.u16(0, "n").bind(get: { (r: ReadmeRow) in r.n }, set: { $0.n = $1 })
        let d = Field.i16(1, "d").bind(get: { (r: ReadmeRow) in r.d }, set: { $0.d = $1 })
        let x = Field.f32(0, "x").bind(get: { (r: ReadmeRow) in r.x }, set: { $0.x = $1 })
        let b = Field.bytes(0, "b", size: 3).bind(get: { (r: ReadmeRow) in r.b }, set: { $0.b = $1 })
        let on = Field.bool(0, "on").bind(get: { (r: ReadmeRow) in r.on }, set: { $0.on = $1 })
        let speed = Field.u8(1, "n").bind(get: { (r: ReadmeRow) in r.speed }, set: { $0.speed = $1 })
        let cases: [(Scheme, ReadmeRow, String)] = [
            (try Scheme(1, n, d), ReadmeRow(n: 1, d: -2), "010100feff"),
            (try Scheme(1, x), ReadmeRow(x: 1.5), "010000c03f"),
            (try Scheme(1, b), ReadmeRow(b: Array("abc".utf8)), "01616263"),
            (try Scheme(1, .be(n)), ReadmeRow(n: 1), "010001"),
            (try Scheme(1, .flags(0, on, speed)), ReadmeRow(on: true, speed: 7), "010307"),
        ]
        for (scheme, row, wire) in cases {
            // Act
            let packed = try packHex(scheme, row)
            let back = try unpack(bytes(wire), scheme) as? ReadmeRow

            // Assert
            #expect(packed == wire)
            #expect(back == row)
        }
    }

    @Test func pack_bigEndianWidths_giveTypeScriptHex() throws {
        // Arrange
        let scheme = try Scheme(1, .be(.i32(0, "n")), .be(.f32(1, "x")), .be(.u64(2, "q")))
        let wire = "01fffffffe3fc000000000000000000001"

        // Act
        let packed = try packHex(scheme, ["n": -2, "x": 1.5, "q": 1])
        let back = try unpackMap(bytes(wire), scheme)

        // Assert
        #expect(packed == wire)
        #expect(describeMap(back) == "n=Int32:-2,q=UInt64:1,x=Float:1.5")
    }

    @Test func pack_integerLimits_giveTypeScriptHex() throws {
        // Arrange
        let scheme = try Scheme(1, .u8(0, "a"), .u16(1, "b"), .u32(2, "c"), .u64(3, "d"),
                                .i8(4, "e"), .i16(5, "f"), .i32(6, "g"), .i64(7, "h"))
        let row: [String: Any] = ["a": 255, "b": 65535, "c": 4_294_967_295, "d": UInt64.max,
                                  "e": -128, "f": -32768, "g": Int32.min, "h": Int64.min]
        let wire = "01ffffffffffffffffffffffffffffff800080000000800000000000000080"

        // Act
        let packed = try packHex(scheme, row)
        let back = try unpackMap(bytes(wire), scheme)

        // Assert
        #expect(packed == wire)
        #expect(try packHex(scheme, back) == wire)
        #expect(back["d"] as? UInt64 == UInt64.max && back["h"] as? Int64 == Int64.min)
    }

    @Test func pack_f32SpecialValues_areWrittenAsGiven() throws {
        // Arrange
        let scheme = try Scheme(1, .f32(0, "x"))

        // Act
        let nan = try packHex(scheme, ["x": Double.nan])
        let inf = try packHex(scheme, ["x": Double.infinity])
        let negInf = try packHex(scheme, ["x": -Double.infinity])

        // Assert
        #expect(nan == "010000c07f" && inf == "010000807f" && negInf == "01000080ff")
    }
}

struct ReadmeRow: PackbinRow, Equatable {
    var n: UInt16 = 0
    var d: Int16 = 0
    var x: Float = 0
    var b: [UInt8] = []
    var on = false
    var speed: UInt8?
}
