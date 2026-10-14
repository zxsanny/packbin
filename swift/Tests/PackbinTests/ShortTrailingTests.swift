import Packbin
import Testing

/// One unreadable buffer and the error TypeScript at HEAD gives for it (its field name, needed, left).
struct ShortCase: CustomTestStringConvertible, Sendable {
    let name: String
    let wire: String
    let kind: PackbinError.Kind
    let field: Int?
    let fieldName: String
    let needed: Int
    let left: Int
    var testDescription: String { name }
}

let shortCases: [ShortCase] = [
    ShortCase(name: "ends inside lat", wire: "40010000", kind: .short, field: 1, fieldName: "lat", needed: 4, left: 1),
    ShortCase(name: "empty buffer", wire: "", kind: .short, field: nil, fieldName: "", needed: 1, left: 0),
    ShortCase(name: "type byte only", wire: "40", kind: .short, field: 0, fieldName: "sid", needed: 2, left: 0),
    ShortCase(name: "no flag byte", wire: "4001000065cd1d00a3e11101", kind: .short, field: 4, fieldName: "",
              needed: 1, left: 0),
    ShortCase(name: "heading missing", wire: "4001000065cd1d00a3e1110101", kind: .short, field: 4,
              fieldName: "heading", needed: 2, left: 0),
    ShortCase(name: "heading half", wire: "4001000065cd1d00a3e111010100", kind: .short, field: 4,
              fieldName: "heading", needed: 2, left: 1),
    ShortCase(name: "one trailing byte", wire: "4001000065cd1d00a3e111010000", kind: .trailing, field: nil,
              fieldName: "", needed: 0, left: 1),
]

/// AC-3 (SW-2, S2): a short buffer, trailing bytes and an unknown type number throw a `PackbinError`
/// and give no row.
@Suite struct ShortTrailingTests {
    @Test(arguments: shortCases)
    func unpack_unreadableBuffer_throwsNamingFieldNeededLeft(_ c: ShortCase) throws {
        // Arrange
        let scheme = try positionTypedScheme()
        var row: Any?

        // Act
        let error = packbinError {
            row = try unpack(bytes(c.wire), scheme)
            return row as Any
        }

        // Assert
        #expect(row == nil)
        #expect(error?.kind == c.kind)
        #expect(error?.field == c.field && error?.name == c.fieldName)
        #expect(error?.needed == c.needed && error?.left == c.left)
    }

    @Test func unpack_firstByteNamesNoScheme_throwsUnknownTypeWithTheByte() throws {
        // Arrange
        let schemes = [try positionMapScheme(), try Scheme(1, .u8(0, "x"))]
        var row: [String: Any]?

        // Act
        let error = packbinError {
            row = try unpackMap(bytes("4101000065cd1d00a3e1110100"), schemes)
            return row as Any
        }

        // Assert
        #expect(row == nil)
        #expect(error?.kind == .unknownType && error?.actual == 0x41 && error?.field == nil)
        #expect(error?.kind.rawValue == "type_mismatch")
    }

    @Test func unpack_firstByteDispatch_picksTheSchemeTheByteNames() throws {
        // Arrange
        let other = try Scheme(1, .u8(0, "x"))
        let schemes = [other, try positionTypedScheme()]

        // Act
        let position = try unpack(bytes(expectedHex), schemes)
        let small = try unpack(bytes("0107"), schemes)

        // Assert
        #expect(position as? Position == goldenRow())
        #expect(describeMap(try #require(small as? [String: Any])) == "x=UInt8:7")
    }

    @Test func unpack_shortFixedBytesAndWhenBody_nameTheField() throws {
        // Arrange
        let fixed = try Scheme(1, .bytes(0, "b", size: 3))
        let when = try Scheme(1, .u8(0, "profile"), .when(1, .eq(0, 0), .u8(1, "shape")))

        // Act
        let bytesError = packbinError { try unpackMap(bytes("016162"), fixed) }
        let whenError = packbinError { try unpackMap(bytes("0100"), when) }

        // Assert
        #expect(shape(bytesError) == "short_packet 0 b needed 3 left 2")
        #expect(shape(whenError) == "short_packet 1 shape needed 1 left 0")
    }

    @Test func unpack_schemeLists_refuseNoSchemeAndDuplicateTypeNumbers() throws {
        // Arrange
        let one = try Scheme(1, .u8(0, "x"))

        // Act
        let none = packbinError { try unpack(bytes("0107"), [Scheme]()) }
        let twice = packbinError { try unpack(bytes("0107"), one, one) }

        // Assert
        #expect(none?.kind == .schemeError && twice?.kind == .schemeError)
        #expect(twice?.reason == "duplicate type number 1")
    }

    @Test func errorKinds_mapToTheHostileOutcomeTerms() {
        // Arrange
        let terms = PackbinError.Kind.allCases.map(\.rawValue)

        // Act
        let joined = terms.joined(separator: " ")

        // Assert
        #expect(joined == "short_packet trailing_bytes type_mismatch bad_value too_many scheme_error pack_error")
    }
}

/// The kind, field, name, needed and left of an error, in one line.
func shape(_ error: PackbinError?) -> String {
    guard let e = error else { return "no error" }
    return "\(e.kind.rawValue) \(e.field.map(String.init) ?? "-") \(e.name) needed \(e.needed) left \(e.left)"
}
