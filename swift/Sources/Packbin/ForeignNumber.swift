#if canImport(Foundation)
import Foundation

/// The class of an `NSNumber` made from a `Bool` (`__NSCFBoolean`), and of one made from an integer.
/// A map row from `JSONSerialization` holds these: a boolean one is a `Bool`, never an integer, and an
/// integer one is never a `Bool` (owner ruling 2026-10-14, as Go-1 B and Go-2 A).
private let boolNumberClass = ObjectIdentifier(type(of: NSNumber(value: true)))
private let intNumberClass = ObjectIdentifier(type(of: NSNumber(value: 1)))

/// A Foundation number as pack reads it, or nil for any other object.
func foreignScalar(_ v: Any) -> Scalar? {
    guard let number = v as? NSNumber else { return nil }
    if boolNumberClass != intNumberClass, ObjectIdentifier(type(of: number)) == boolNumberClass {
        return .bool(number.boolValue)
    }
    switch UInt8(truncatingIfNeeded: number.objCType.pointee) {
    case UInt8(ascii: "f"), UInt8(ascii: "d"):
        return .float(number.doubleValue)
    case UInt8(ascii: "Q"):
        return Num(exactly: number.uint64Value).map(Scalar.int)
    case UInt8(ascii: "c"), UInt8(ascii: "s"), UInt8(ascii: "i"), UInt8(ascii: "l"), UInt8(ascii: "q"),
         UInt8(ascii: "C"), UInt8(ascii: "S"), UInt8(ascii: "I"), UInt8(ascii: "L"):
        return Num(exactly: number.int64Value).map(Scalar.int)
    default:
        return nil
    }
}

/// Whether `v` is a Foundation dictionary with more keys than the `[String: Any]` it bridged to holds
/// (`count`): two of its keys are equal as Swift strings although they differ as `NSString`s.
func foreignKeysMerged(_ v: Any, _ count: Int) -> Bool {
    guard type(of: v) is AnyObject.Type, let dictionary = v as? NSDictionary else { return false }
    return dictionary.count != count
}
#else
func foreignScalar(_ v: Any) -> Scalar? { nil }

func foreignKeysMerged(_ v: Any, _ count: Int) -> Bool { false }
#endif
