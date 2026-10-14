import Foundation
import Packbin
import Testing

struct WideRow: PackbinRow {
    var a: UInt8 = 0
    var b = 0
    var c: Int64 = 0
}

func wideScheme() throws -> Scheme {
    try Scheme(1,
               .u8(0, "a").bind(get: { (r: WideRow) in r.a }, set: { $0.a = $1 }),
               .u16(1, "b").bind(get: { (r: WideRow) in r.b }, set: { $0.b = $1 }),
               .i8(2, "c").bind(get: { (r: WideRow) in r.c }, set: { $0.c = $1 }))
}

/// One refused row: what packs it, the field id the error must name, and its reason.
struct RefusedRow: CustomTestStringConvertible, Sendable {
    let name: String
    let id: Int?
    let reason: String
    let pack: @Sendable () throws -> [UInt8]
    var testDescription: String { name }
}

private func mapRow(_ changes: [String: Any]) -> [String: Any] {
    goldenMap().merging(changes) { _, new in new }
}

private func json(_ text: String) -> [String: Any] {
    let object = try? JSONSerialization.jsonObject(with: Data(text.utf8))
    return object as? [String: Any] ?? [:]
}

let refusedRows: [RefusedRow] = [
    RefusedRow(name: "typed getter above u16", id: 1, reason: "70000 does not fit in u16") {
        try pack(try wideScheme(), WideRow(b: 70000))
    },
    RefusedRow(name: "typed getter negative for unsigned", id: 1, reason: "-1 does not fit in u16") {
        try pack(try wideScheme(), WideRow(b: -1))
    },
    RefusedRow(name: "typed getter below i8", id: 2, reason: "-129 does not fit in i8") {
        try pack(try wideScheme(), WideRow(c: -129))
    },
    RefusedRow(name: "string for an integer", id: 0, reason: "expected an integer for u16, got String") {
        try pack(try positionMapScheme(), mapRow(["sid": "1"]))
    },
    RefusedRow(name: "fraction for an integer", id: 1, reason: "expected an integer for i32, got a float (Double)") {
        try pack(try positionMapScheme(), mapRow(["lat": 1.5]))
    },
    RefusedRow(name: "whole Double for an integer", id: 1, reason: "expected an integer for i32, got a float (Double)") {
        try pack(try positionMapScheme(), mapRow(["lat": 2.0]))
    },
    RefusedRow(name: "Bool for an integer", id: 2, reason: "expected an integer for i32, got a Bool (Bool)") {
        try pack(try positionMapScheme(), mapRow(["lon": true]))
    },
    RefusedRow(name: "integer for a bool", id: 0, reason: "expected a Bool for bool on, got Int") {
        try pack(try Scheme(1, .flags(0, .bool(0, "on"))), ["on": 1])
    },
    RefusedRow(name: "string for a float", id: 0, reason: "expected a number for f64, got String") {
        try pack(try Scheme(1, .f64(0, "x")), ["x": "1.5"])
    },
    RefusedRow(name: "Bool for a float", id: 0, reason: "expected a number for f32, got a Bool (Bool)") {
        try pack(try Scheme(1, .f32(0, "x")), ["x": true])
    },
    RefusedRow(name: "finite value too large for f32", id: 0, reason: "1e+39 does not fit in f32") {
        try pack(try Scheme(1, .f32(0, "x")), ["x": 1e39])
    },
    RefusedRow(name: "string for bytes", id: 0, reason: "expected [UInt8] for bytes(3), got String") {
        try pack(try Scheme(1, .bytes(0, "b", size: 3)), ["b": "abc"])
    },
    RefusedRow(name: "bytes of another length", id: 0, reason: "expected 3 bytes, got 2") {
        try pack(try Scheme(1, .bytes(0, "b", size: 3)), ["b": [UInt8]([0x61, 0x62])])
    },
    RefusedRow(name: "missing key", id: 2, reason: "missing lon") {
        try pack(try positionMapScheme(), ["sid": 1, "lat": 1, "profile": 1])
    },
    RefusedRow(name: "third field out of range", id: 2, reason: "2147483648 does not fit in i32") {
        try pack(try positionMapScheme(), mapRow(["lon": Int64(Int32.max) + 1]))
    },
    RefusedRow(name: "flags member out of range", id: 5, reason: "256 does not fit in u8") {
        try pack(try positionMapScheme(), mapRow(["speed": 256]))
    },
    RefusedRow(name: "JSON true for an integer", id: 1, reason: "expected an integer for i32, got a Bool") {
        try pack(try positionMapScheme(), json(#"{"sid":1,"lat":true,"lon":1,"profile":1}"#))
    },
    RefusedRow(name: "NSNumber(true) for an integer", id: 3, reason: "expected an integer for u8, got a Bool") {
        try pack(try positionMapScheme(), mapRow(["profile": NSNumber(value: true)]))
    },
    RefusedRow(name: "NSNumber(1) for a bool", id: 0, reason: "expected a Bool for bool on, got") {
        try pack(try Scheme(1, .flags(0, .bool(0, "on"))), ["on": NSNumber(value: 1)])
    },
    RefusedRow(name: "NSNumber(2.0) for an integer", id: 0, reason: "expected an integer for u16, got a float") {
        try pack(try positionMapScheme(), mapRow(["sid": NSNumber(value: 2.0)]))
    },
    RefusedRow(name: "typed row for a map scheme", id: 0,
               reason: "a Position row needs fields bound with bind(get:set:); this scheme packs a [String: Any]") {
        try pack(try positionMapScheme(), goldenRow())
    },
    RefusedRow(name: "another row type", id: 0, reason: "the row is a WideRow; this scheme is bound to Position") {
        try pack(try positionTypedScheme(), WideRow())
    },
]

/// AC-5 (SW-15, S4, S5): an out-of-range getter, a wrong Swift type, a missing key and a bad third
/// field throw a pack error naming the field id, and no bytes are returned.
@Suite struct InvalidValueTests {
    @Test(arguments: refusedRows)
    func pack_invalidRow_throwsNamingTheFieldAndReturnsNoBytes(_ c: RefusedRow) {
        // Arrange
        var out: [UInt8]?

        // Act
        let error = packbinError {
            out = try c.pack()
            return out as Any
        }

        // Assert
        #expect(out == nil, "partial output 0 bytes")
        #expect(error?.kind == .packError)
        #expect(error?.field == c.id)
        #expect(error?.reason.hasPrefix(c.reason) == true, "\(error?.reason ?? "no error")")
    }

    @Test func pack_foundationNumbersOfTheRightKind_areTaken() throws {
        // Arrange
        let scheme = try positionMapScheme()
        let fromJSON = json(#"{"sid":1,"lat":500000000,"lon":300000000,"profile":1}"#)
        let flags = try Scheme(1, .flags(0, .bool(0, "on"), .f64(1, "x")))

        // Act
        let golden = try packHex(scheme, fromJSON)
        let jsonBool = try packHex(flags, json(#"{"on":true,"x":1.5}"#))
        let integerForFloat = try packHex(flags, ["x": NSNumber(value: 2)])

        // Assert
        #expect(golden == expectedHex)
        #expect(jsonBool == "0103000000000000f83f")
        #expect(integerForFloat == "01020000000000000040")
    }

    @Test func scheme_memberThatCannotHoldTheField_isRefusedAtConstruction() {
        // Arrange
        let narrow = Field.u16(0, "n").bind(get: { (r: WideRow) in r.a }, set: { $0.a = $1 })
        let float = Field.f64(0, "x").bind(get: { (r: ReadmeRow) in r.x }, set: { $0.x = $1 })
        let flag = Field.u8(0, "n").bind(get: { (r: ReadmeRow) in r.on }, set: { $0.on = $1 })

        // Act
        let errors = [narrow, float, flag].map { field in packbinError { try Scheme(1, field) } }

        // Assert
        #expect(errors.map { $0?.reason } == [
            "a UInt8 member cannot hold every u16 value",
            "a Float member cannot hold every f64 value",
            "a Bool member cannot hold every u8 value",
        ])
        #expect(errors.allSatisfy { $0?.kind == .schemeError && $0?.field == 0 })
    }

    @Test func scheme_partlyBoundOrBoundToTwoRowTypes_isRefused() {
        // Arrange
        let sid = Field.u16(0, "sid").bind(get: { (r: Position) in r.sid }, set: { $0.sid = $1 })
        let other = Field.u8(1, "a").bind(get: { (r: WideRow) in r.a }, set: { $0.a = $1 })

        // Act
        let partly = packbinError { try Scheme(1, sid, .u8(1, "x")) }
        let two = packbinError { try Scheme(1, sid, other) }
        let twice = packbinError {
            try Scheme(1, sid.bind(get: { (r: Position) in r.sid }, set: { $0.sid = $1 }))
        }
        let notValue = packbinError {
            try Scheme(1, Field.flags(0, .u8(0, "x")).bind(get: { (r: WideRow) in r.a }, set: { $0.a = $1 }))
        }

        // Assert
        #expect(partly?.field == 1 && partly?.reason == "not bound to row type Position; bind every value field of a scheme, or none")
        #expect(two?.field == 1 && two?.reason == "bound to row type WideRow, but an earlier field is bound to Position")
        #expect(twice?.reason == "the field is already bound")
        #expect(notValue?.reason == "bind takes a value field, not flags")
    }
}
