import Packbin
import Testing

struct GInner: PackbinRow, Equatable {
    var b: UInt8 = 0
    var c: UInt8?
}

struct GOuter: PackbinRow, Equatable {
    var a: UInt8 = 0
    var g: GInner?
}

struct GMark: PackbinRow, Equatable {
    var mark = false
    var n: UInt8 = 0
}

struct GOther: PackbinRow {
    var b: UInt8 = 0
}

func innerFields() -> [Field] {
    [.u8(1, "b").bind(get: { (r: GInner) in r.b }, set: { $0.b = $1 }),
     .flags(2, .u8(2, "c").bind(get: { (r: GInner) in r.c }, set: { $0.c = $1 }))]
}

private let outerA = Field.u8(0, "a").bind(get: { (r: GOuter) in r.a }, set: { $0.a = $1 })

private func boundGroup(_ fields: [Field]) -> Field {
    .group(1, "g", fields).bind(get: { (r: GOuter) in r.g }, set: { $0.g = $1 })
}

/// nested-group "flags inside an anchored group" in the typed form: the group is a `GInner?`.
func typedGroupScheme() throws -> Scheme { try Scheme(1, outerA, boundGroup(innerFields())) }

/// The same group under flags: nil is no value, the bit is clear.
func typedFlagsGroupScheme() throws -> Scheme { try Scheme(1, outerA, .flags(1, boundGroup(innerFields()))) }

/// D1 typed: the empty group's mark is a `Bool` member.
func typedMarkScheme() throws -> Scheme {
    try Scheme(1, .flags(0, .group(0, "mark").bind(get: { (r: GMark) in r.mark }, set: { $0.mark = $1 })),
               .u8(0, "n").bind(get: { (r: GMark) in r.n }, set: { $0.n = $1 }))
}

struct TypedGroupRow: CustomTestStringConvertible, Sendable {
    let name: String
    let scheme: @Sendable () throws -> Scheme
    let row: GOuter
    let wire: String
    var testDescription: String { name }
}

let typedGroupRows: [TypedGroupRow] = [
    TypedGroupRow(name: "flags inside an anchored group", scheme: { try typedGroupScheme() },
                  row: GOuter(a: 1, g: GInner(b: 2, c: 3)), wire: "0101020103"),
    TypedGroupRow(name: "flags member nil", scheme: { try typedGroupScheme() }, row: GOuter(a: 1, g: GInner(b: 2)), wire: "01010200"),
    TypedGroupRow(name: "group under flags, given", scheme: { try typedFlagsGroupScheme() },
                  row: GOuter(a: 1, g: GInner(b: 2, c: 3)), wire: "010101020103"),
    TypedGroupRow(name: "group under flags, nil", scheme: { try typedFlagsGroupScheme() }, row: GOuter(a: 1), wire: "010100"),
]

@Suite struct GroupTypedTests {
    @Test(arguments: typedGroupRows)
    func packAndUnpack_typedGroupRow_giveTheMapRowHex(_ c: TypedGroupRow) throws {
        // Arrange
        let scheme = try c.scheme()

        // Act
        let wire = try packHex(scheme, c.row)
        let back = try unpack(bytes(c.wire), scheme) as? GOuter
        let map = try unpackMap(bytes(c.wire), scheme)

        // Assert
        #expect(wire == c.wire)
        #expect(back == c.row)
        #expect(try packHex(scheme, map) == c.wire)
    }

    @Test func pack_typedTopLevelGroupNil_isRefusedNamingTheMember() throws {
        // Arrange
        let scheme = try typedGroupScheme()

        // Act
        let error = packbinError { try pack(scheme, GOuter(a: 1)) }

        // Assert
        #expect(error?.kind == .packError && error?.field == 1 && error?.name == "b" && error?.reason == "missing b")
    }

    @Test func packAndUnpack_typedEmptyGroupMark_giveTypeScriptHex() throws {
        // Arrange
        let scheme = try typedMarkScheme()

        // Act
        let set = try packHex(scheme, GMark(mark: true, n: 3))
        let clear = try packHex(scheme, GMark(mark: false, n: 3))
        let back = try unpack(bytes("010103"), scheme) as? GMark
        let backClear = try unpack(bytes("010003"), scheme) as? GMark

        // Assert
        #expect(set == "010103" && clear == "010003")
        #expect(back == GMark(mark: true, n: 3) && backClear == GMark(mark: false, n: 3))
    }

    @Test func scheme_groupBoundButItsMembersNot_isRefused() {
        // Arrange, Act
        let error = packbinError { try Scheme(1, outerA, boundGroup([.u8(1, "b")])) }

        // Assert
        #expect(error?.kind == .schemeError && error?.field == 1 && error?.name == "b")
        #expect(error?.reason == "not bound to row type GInner (the row of group g); bind every value field of a scheme, or none")
    }

    @Test func scheme_membersBoundButTheGroupNot_isRefused() {
        // Arrange, Act
        let error = packbinError {
            try Scheme(1, .group(0, "g", .u8(0, "b").bind(get: { (r: GInner) in r.b }, set: { $0.b = $1 })))
        }

        // Assert
        #expect(error?.field == 0 && error?.name == "b")
        #expect(error?.reason == "bound to row type GInner, but its group g is not bound")
    }

    @Test func scheme_membersBoundToAnotherTypeThanTheGroup_isRefused() {
        // Arrange, Act
        let error = packbinError {
            try Scheme(1, outerA, boundGroup([.u8(1, "b").bind(get: { (r: GOther) in r.b }, set: { $0.b = $1 })]))
        }

        // Assert
        #expect(error?.field == 1 && error?.name == "b")
        #expect(error?.reason == "bound to row type GOther, but its group g is bound to GInner")
    }

    @Test func scheme_groupLeftUnboundBesideABoundField_isRefused() {
        // Arrange, Act
        let error = packbinError { try Scheme(1, outerA, .group(1, "g", innerFields())) }

        // Assert
        #expect(error?.field == 1 && error?.name == "g")
        #expect(error?.reason == "not bound to row type GOuter; bind every value field of a scheme, or none")
    }

    @Test func bind_groupOrMarkToAMemberThatCannotHoldIt_isRefused() {
        // Arrange, Act
        let group = packbinError {
            try Scheme(1, .group(0, "g", .u8(0, "b")).bind(get: { (r: GMark) in r.n }, set: { $0.n = $1 }))
        }
        let mark = packbinError {
            try Scheme(1, .flags(0, .group(0, "mark").bind(get: { (r: GMark) in r.n }, set: { $0.n = $1 })))
        }

        // Assert
        #expect(group?.field == 0 && group?.reason == "a UInt8 member cannot hold group g; bind a PackbinRow")
        #expect(mark?.field == 0 && mark?.reason == "a UInt8 member cannot hold the mark of group mark; bind a Bool")
    }
}
