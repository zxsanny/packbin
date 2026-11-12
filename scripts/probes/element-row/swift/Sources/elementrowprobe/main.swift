// Probe of AZ-4242: a list or dict whose element is a row of required members (a group without an
// anchor as the element, no flag byte per element). It builds each shape of ../../../README.md with the
// public API, packs the values given there and unpacks its own bytes. One line per shape: package,
// shape, build, pack, unpack (tab separated). It asserts nothing: it prints what happens.
//
// Forms. A plain shape name is the typed form: every member is bound with `bind(get:set:)` to a
// `PackbinRow` struct, pack takes the struct and `unpack` gives one back. A shape with the suffix `-map`
// is the map form of the same scheme (no binding; a `[String: Any]` row, read back with `unpackMap`): it
// packs on another path (`mapValues`, not `walkedCollection`), so its outcome can differ. `other-row` and
// `nested-other-row` exist only in the typed form: a map row has no row type.
//
// Collection types. `bind` is generic over any `Member` type, so every coll-* line compiles; the package
// checks the member type when the scheme is built, so a type it does not take is a `refused:` build.
// A `Set` holds one comment (the `list-1` values): its order is not fixed, and three would not give the
// same bytes on every run.
//
// `refused:` is a `PackbinError`; `threw:` is any other error. A trap ends the process: `run.sh` runs
// one process per shape and prints `threw: trap: ...` for the call it ended in.
//
// `elementrowprobe` prints every shape; `elementrowprobe <shape>...` the ones named; `--shapes` their
// names.
import Foundation
import Packbin

/// Written at once: a line that a trap cuts short still holds the cells before it.
func emit(_ text: String) { FileHandle.standardOutput.write(Data(text.utf8)) }

func oneLine(_ text: String) -> String {
    text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
}

func hex(_ bytes: [UInt8]) -> String {
    bytes.map { ($0 < 16 ? "0" : "") + String($0, radix: 16) }.joined()
}

private protocol OptionalValue { var inner: Any? { get } }
extension Optional: OptionalValue {
    fileprivate var inner: Any? { map { $0 as Any } }
}

/// A value as text: struct members and dictionary keys in sorted order, a set's items sorted, an absent
/// value as null and every integer type as its number, so two rows that hold the same values print the
/// same text whatever Swift types hold them.
func shown(_ value: Any?) -> String {
    guard let value else { return "null" }
    if let optional = value as? OptionalValue { return optional.inner.map { shown($0) } ?? "null" }
    if let number = value as? any BinaryInteger { return "\(number)" }
    if let text = value as? String { return "\"\(text)\"" }
    let mirror = Mirror(reflecting: value)
    switch mirror.displayStyle {
    case .struct?, .class?:
        let members = mirror.children.map { ($0.label ?? "?", shown($0.value)) }.sorted { $0.0 < $1.0 }
        return "{" + members.map { "\"\($0.0)\":\($0.1)" }.joined(separator: ",") + "}"
    case .collection?:
        return "[" + mirror.children.map { shown($0.value) }.joined(separator: ",") + "]"
    case .set?:
        return "[" + mirror.children.map { shown($0.value) }.sorted().joined(separator: ",") + "]"
    case .dictionary?:
        let entries = mirror.children.map { entry -> (String, String) in
            let pair = Array(Mirror(reflecting: entry.value).children)
            return (String(describing: pair[0].value), shown(pair[1].value))
        }.sorted { $0.0 < $1.0 }
        return "{" + entries.map { "\"\($0.0)\":\($0.1)" }.joined(separator: ",") + "}"
    default:
        return "\(value)"
    }
}

/// A map row without the round lists (`v`) that hold no entry, at any depth. Unpack gives a times that
/// read no round no key; only the map-form comparison uses this.
func withoutEmptyRounds(_ value: Any) -> Any {
    if let map = value as? [String: Any] {
        var out: [String: Any] = [:]
        for (name, member) in map {
            if name == "v", let rounds = member as? [Any?], rounds.isEmpty { continue }
            out[name] = withoutEmptyRounds(member)
        }
        return out
    }
    if let list = value as? [Any?] { return list.map { $0.map { withoutEmptyRounds($0) } } }
    return value
}

/// A `PackbinError` is the package's own refusal; anything else is not.
func failure(_ error: any Error) -> String {
    if let refusal = error as? PackbinError { return "refused: \(oneLine(refusal.description))" }
    return "threw: \(oneLine(String(describing: error)))"
}

/// Builds, packs and unpacks one shape. `pack` packs with the scheme; `unpack` reads the bytes back and
/// says whether the values came back.
func probe(_ shape: String, _ build: () throws -> Scheme, pack: (Scheme) throws -> [UInt8],
           unpack: ([UInt8], Scheme) throws -> String) {
    emit("swift\t\(shape)\t")
    let scheme: Scheme
    do {
        scheme = try build()
    } catch {
        emit("\(failure(error))\t-\t-\n")
        return
    }
    emit("built\t")
    let packed: [UInt8]
    do {
        packed = try pack(scheme)
    } catch {
        emit("\(failure(error))\t-\n")
        return
    }
    emit("\(hex(packed))\t")
    do {
        emit("\(try unpack(packed, scheme))\n")
    } catch {
        emit("\(failure(error))\n")
    }
}

/// The typed form: `row` packed, `unpack` read back and compared as text.
func typedProbe<Row>(_ shape: String, _ row: Row, _ build: () throws -> Scheme) {
    probe(shape, build, pack: { try Packbin.pack($0, row) }, unpack: { bytes, scheme in
        let got = try Packbin.unpack(bytes, scheme)
        return shown(got) == shown(row) ? "same" : "differs: \(oneLine(shown(got)))"
    })
}

/// The map form: `values` packed, `unpackMap` read back and compared as text.
func mapProbe(_ shape: String, _ values: [String: Any], _ build: () throws -> Scheme) {
    probe(shape, build, pack: { try Packbin.pack($0, values) }, unpack: { bytes, scheme in
        let got = try unpackMap(bytes, scheme)
        let same = shown(withoutEmptyRounds(got)) == shown(withoutEmptyRounds(values))
        return same ? "same" : "differs: \(oneLine(shown(got)))"
    })
}

/// The element row of AZ-4199: four required members, ids 0 to 3.
struct Comment: PackbinRow, Hashable {
    var id = ""
    var text = ""
    var authorId: UInt32 = 0
    var author = ""
    init() {}
    init(_ id: String, _ text: String, _ authorId: UInt32, _ author: String) {
        (self.id, self.text, self.authorId, self.author) = (id, text, authorId, author)
    }
}

/// Comment whose text may be absent (nil): the typed null-member shape.
struct CommentOpt: PackbinRow {
    var id = ""
    var text: String?
    var authorId: UInt32 = 0
    var author = ""
}

/// A row type that is not the element's: `other-row` binds one member to it.
struct Other: PackbinRow {
    var text = ""
}

/// Another row type with Comment's members: the -whole shapes bind every member to it.
struct OtherComment: PackbinRow {
    var id = ""
    var text = ""
    var authorId: UInt32 = 0
    var author = ""
}

/// A member type a holder can start from empty. (Its metatype is captured by the `@Sendable` accessors
/// of `typed`; every concrete type meets `SendableMetatype`.)
#if compiler(>=6.2)
protocol Blank: SendableMetatype { init() }
#else
protocol Blank { init() }
#endif
extension Array: Blank {}
extension ContiguousArray: Blank {}
extension ArraySlice: Blank {}
extension Set: Blank {}
extension Dictionary: Blank {}
extension Optional: Blank {
    init() { self = nil }
}

/// The typed row of a scheme with one list or dict member of type `V`.
struct Holder<V: Blank>: PackbinRow {
    var items = V()
    init() {}
    init(_ items: V) { self.items = items }
}

/// The typed row of nested-other-row: one nested row.
struct Note: PackbinRow {
    var note = Comment()
}

struct ModeRow: PackbinRow {
    var mode: UInt8 = 0
    var speed: UInt8?
}

struct VRound: PackbinRow {
    var v: UInt8 = 0
}

struct CountRow: PackbinRow {
    var c: UInt8 = 0
    var v: [VRound] = []
}

/// Comment's members bound to Comment; with `textToOther` the text is bound to Other.
func commentMembers(textToOther: Bool = false) -> [Field] {
    let text = textToOther
        ? Field.utf8(1, "text").bind(get: { (r: Other) in r.text }, set: { $0.text = $1 })
        : Field.utf8(1, "text").bind(get: { (r: Comment) in r.text }, set: { $0.text = $1 })
    return [
        Field.utf8(0, "id").bind(get: { (r: Comment) in r.id }, set: { $0.id = $1 }),
        text,
        Field.u32(2, "authorId").bind(get: { (r: Comment) in r.authorId }, set: { $0.authorId = $1 }),
        Field.utf8(3, "author").bind(get: { (r: Comment) in r.author }, set: { $0.author = $1 }),
    ]
}

func otherMembers() -> [Field] {
    [
        Field.utf8(0, "id").bind(get: { (r: OtherComment) in r.id }, set: { $0.id = $1 }),
        Field.utf8(1, "text").bind(get: { (r: OtherComment) in r.text }, set: { $0.text = $1 }),
        Field.u32(2, "authorId").bind(get: { (r: OtherComment) in r.authorId }, set: { $0.authorId = $1 }),
        Field.utf8(3, "author").bind(get: { (r: OtherComment) in r.author }, set: { $0.author = $1 }),
    ]
}

func commentOptMembers() -> [Field] {
    [
        Field.utf8(0, "id").bind(get: { (r: CommentOpt) in r.id }, set: { $0.id = $1 }),
        Field.utf8(1, "text").bind(get: { (r: CommentOpt) in r.text }, set: { $0.text = $1 }),
        Field.u32(2, "authorId").bind(get: { (r: CommentOpt) in r.authorId }, set: { $0.authorId = $1 }),
        Field.utf8(3, "author").bind(get: { (r: CommentOpt) in r.author }, set: { $0.author = $1 }),
    ]
}

func plainComment() -> [Field] { [.utf8(0, "id"), .utf8(1, "text"), .u32(2, "authorId"), .utf8(3, "author")] }

typealias Collection = (String, Field) -> Field
let list: Collection = { Field.list($0, $1) }
let dict: Collection = { Field.dict($0, $1) }

/// A scheme of one list (or dict) of a group element, bound to `Holder<V>.items`.
func typed<V: Blank>(_ collection: Collection, _ members: [Field], _: V.Type) throws -> Scheme {
    try Scheme(1, collection("items", .group("item", members)).bind(get: { (r: Holder<V>) in r.items },
                                                                     set: { $0.items = $1 }))
}

/// The map-form scheme of one list (or dict) "items" of a group element.
func unbound(_ collection: Collection, _ members: [Field]) throws -> Scheme {
    try Scheme(1, collection("items", .group("item", members)))
}

/// A typed probe of one collection member of type `V` holding `items`, with Comment's members.
func coll<V: Blank>(_ shape: String, _ collection: Collection, _ items: V) {
    typedProbe(shape, Holder(items)) { try typed(collection, commentMembers(), V.self) }
}

let c1 = Comment("c1", "hi", 7, "ann")
let c2 = Comment("c2", "ok", 258, "bo")
let c3 = Comment("c3", "yes", 1, "cy")
let m1: [String: Any] = ["id": "c1", "text": "hi", "authorId": 7, "author": "ann"]
let m2: [String: Any] = ["id": "c2", "text": "ok", "authorId": 258, "author": "bo"]
let m3: [String: Any] = ["id": "c3", "text": "yes", "authorId": 1, "author": "cy"]
let h1: [String: AnyHashable] = ["id": "c1", "text": "hi", "authorId": 7, "author": "ann"]

let shapes: [(String, () -> Void)] = [
    ("list-0", { coll("list-0", list, [Comment]()) }),
    ("list-1", { coll("list-1", list, [c1]) }),
    ("list-3", { coll("list-3", list, [c1, c2, c3]) }),
    ("dict-2", { coll("dict-2", dict, ["b": c2, "a": c1]) }),
    ("list-3-map", { mapProbe("list-3-map", ["items": [m1, m2, m3] as [Any]]) { try unbound(list, plainComment()) } }),
    ("dict-2-map", { mapProbe("dict-2-map", ["items": ["b": m2, "a": m1] as [String: Any]]) {
        try unbound(dict, plainComment())
    } }),

    // Other list member types (typed form): bind checks the member type when the scheme is built.
    ("coll-optional-array", { coll("coll-optional-array", list, Optional([c1, c2, c3])) }),
    ("coll-optional-elements", { coll("coll-optional-elements", list, [Comment?]([c1, c2, c3])) }),
    ("coll-contiguous-array", { coll("coll-contiguous-array", list, ContiguousArray([c1, c2, c3])) }),
    ("coll-array-slice", { coll("coll-array-slice", list, [c1, c2, c3][...]) }),
    ("coll-set", { coll("coll-set", list, Set([c1])) }),
    ("coll-any-elements", { coll("coll-any-elements", list, [Any]([c1, c2, c3])) }),
    // Other dict member types (typed form).
    ("coll-dict-optional", { coll("coll-dict-optional", dict, Optional(["b": c2, "a": c1])) }),
    ("coll-dict-optional-values", { coll("coll-dict-optional-values", dict, ["b": c2, "a": c1] as [String: Comment?]) }),
    ("coll-dict-substring-key", { coll("coll-dict-substring-key", dict, ["b": c2, "a": c1] as [Substring: Comment]) }),
    ("coll-dict-int-key", { coll("coll-dict-int-key", dict, [2: c2, 1: c1] as [Int: Comment]) }),
    // Other collection types (map form): the package reads a list as `[Any?]` or `[Any]`, a dict as
    // `[String: Any]`, each item a `[String: Any]`.
    ("coll-typed-array-map", { mapProbe("coll-typed-array-map", ["items": [m1, m2, m3]]) { try unbound(list, plainComment()) } }),
    ("coll-contiguous-array-map", { mapProbe("coll-contiguous-array-map", ["items": ContiguousArray<Any>([m1, m2, m3])]) {
        try unbound(list, plainComment())
    } }),
    ("coll-array-slice-map", { mapProbe("coll-array-slice-map", ["items": ([m1, m2, m3] as [Any])[...]]) {
        try unbound(list, plainComment())
    } }),
    ("coll-set-map", { mapProbe("coll-set-map", ["items": Set([h1])]) { try unbound(list, plainComment()) } }),
    ("coll-nsarray-map", { mapProbe("coll-nsarray-map", ["items": NSArray(array: [m1, m2, m3])]) {
        try unbound(list, plainComment())
    } }),
    ("coll-struct-item-map", { mapProbe("coll-struct-item-map", ["items": [c1, c2, c3]]) { try unbound(list, plainComment()) } }),
    ("coll-dict-typed-map", { mapProbe("coll-dict-typed-map", ["items": ["b": m2, "a": m1] as [String: [String: Any]]]) {
        try unbound(dict, plainComment())
    } }),
    ("coll-dict-nsdictionary-map", { mapProbe("coll-dict-nsdictionary-map",
                                              ["items": NSDictionary(dictionary: ["b": m2, "a": m1])]) {
        try unbound(dict, plainComment())
    } }),
    ("coll-dict-substring-key-map", { mapProbe("coll-dict-substring-key-map", ["items": ["b": m2, "a": m1] as [Substring: Any]]) {
        try unbound(dict, plainComment())
    } }),
    ("coll-dict-anyhashable-key-map", { mapProbe("coll-dict-anyhashable-key-map",
                                                 ["items": ["b": m2, "a": m1] as [AnyHashable: Any]]) {
        try unbound(dict, plainComment())
    } }),
    ("coll-dict-int-key-map", { mapProbe("coll-dict-int-key-map", ["items": [2: m2, 1: m1] as [Int: Any]]) {
        try unbound(dict, plainComment())
    } }),

    // when inside an element row: speed is written only for mode 1.
    ("when", { typedProbe("when", Holder([ModeRow(mode: 1, speed: 7), ModeRow(mode: 0)])) {
        try typed(list, [
            Field.u8(0, "mode").bind(get: { (r: ModeRow) in r.mode }, set: { $0.mode = $1 }),
            .when(1, .eq(0, 1), Field.u8(1, "speed").bind(get: { (r: ModeRow) in r.speed }, set: { $0.speed = $1 })),
        ], [ModeRow].self)
    } }),
    ("when-map", { mapProbe("when-map", ["items": [["mode": 1, "speed": 7], ["mode": 0]] as [Any]]) {
        try unbound(list, [.u8(0, "mode"), .when(1, .eq(0, 1), .u8(1, "speed"))])
    } }),

    // times inside an element row: c rounds of v.
    ("times", { typedProbe("times", Holder([CountRow(c: 2, v: [VRound(v: 5), VRound(v: 6)]), CountRow(c: 0, v: [])])) {
        try typed(list, [
            Field.u8(0, "c").bind(get: { (r: CountRow) in r.c }, set: { $0.c = $1 }),
            Field.times(1, count: 0, Field.u8(1, "v").bind(get: { (r: VRound) in r.v }, set: { $0.v = $1 }))
                .bind(get: { (r: CountRow) in r.v }, set: { $0.v = $1 }),
        ], [CountRow].self)
    } }),
    ("times-map", { mapProbe("times-map", ["items": [["c": 2, "v": [5, 6]], ["c": 0, "v": [Int]()]] as [Any]]) {
        try unbound(list, [.u8(0, "c"), .times(1, count: 0, .u8(1, "v"))])
    } }),

    // other-row: the element is a [Comment], its text member is bound to Other.
    ("other-row", { typedProbe("other-row", Holder([c1])) { try typed(list, commentMembers(textToOther: true), [Comment].self) } }),
    // nested-other-row: a nested row (a group without an anchor at the top level) bound to Comment, its
    // text bound to Other.
    ("nested-other-row", { typedProbe("nested-other-row", Note(note: c1)) {
        try Scheme(1, Field.group("note", commentMembers(textToOther: true))
            .bind(get: { (r: Note) in r.note }, set: { $0.note = $1 }))
    } }),
    // -whole: every member of the element row (nested row) is bound to OtherComment, so the row is one
    // type and only its owner's type differs: another check (checkChildBinding) than one stray member.
    ("other-row-whole", { typedProbe("other-row-whole", Holder([c1])) { try typed(list, otherMembers(), [Comment].self) } }),
    ("nested-other-row-whole", { typedProbe("nested-other-row-whole", Note(note: c1)) {
        try Scheme(1, Field.group("note", otherMembers()).bind(get: { (r: Note) in r.note }, set: { $0.note = $1 }))
    } }),

    // null-member: a required member left out (a nil String? in the typed form, no key in the map form).
    ("null-member", { typedProbe("null-member", Holder([CommentOpt(id: "c1", text: nil, authorId: 7, author: "ann")])) {
        try typed(list, commentOptMembers(), [CommentOpt].self)
    } }),
    ("null-member-map", { mapProbe("null-member-map", ["items": [["id": "c1", "authorId": 7, "author": "ann"]] as [Any]]) {
        try unbound(list, plainComment())
    } }),

    // null-item: a list that holds c1 and a nil element (the typed form needs optional elements).
    ("null-item", { typedProbe("null-item", Holder([c1, nil] as [Comment?])) { try typed(list, commentMembers(), [Comment?].self) } }),
    ("null-item-map", { mapProbe("null-item-map", ["items": [m1, nil] as [Any?]]) { try unbound(list, plainComment()) } }),
]

let named = Array(CommandLine.arguments.dropFirst())
if named == ["--shapes"] {
    emit(shapes.map(\.0).joined(separator: "\n") + "\n")
    exit(0)
}
for name in named.isEmpty ? shapes.map(\.0) : named {
    guard let shape = shapes.first(where: { $0.0 == name }) else {
        FileHandle.standardError.write(Data("elementrowprobe: no shape \(name)\n".utf8))
        exit(2)
    }
    shape.1()
}
