import Packbin
import Testing

/// One line of fixtures/hostile/cases.txt: `id stage expected hex`.
struct HostileCase: CustomTestStringConvertible, Sendable {
    let id: String
    let stage: String
    let expected: [String]
    let hex: String
    var testDescription: String { id }

    func accepts(_ term: String) -> Bool { expected.contains(term) }
}

/// Every case of fixtures/hostile/cases.txt, in file order.
func hostileCases() throws -> [HostileCase] {
    try repositoryFile("fixtures/hostile/cases.txt").split(separator: "\n").compactMap { line in
        let f = line.split(whereSeparator: { $0 == " " || $0 == "\t" }).map(String.init)
        guard let id = f.first, !id.hasPrefix("#") else { return nil }
        guard f.count == 4 else { throw HostileFileError(line: String(line)) }
        return HostileCase(id: id, stage: f[1], expected: f[2].split(separator: "|").map(String.init), hex: f[3])
    }
}

/// The cases of one stage, in file order.
func hostileCases(_ stage: String) throws -> [HostileCase] { try hostileCases().filter { $0.stage == stage } }

struct HostileFileError: Error, CustomStringConvertible {
    let line: String
    var description: String { "cases.txt line \"\(line)\": want 4 fields" }
}

/// What one guarded call of a case gave: its error (nil when it returned), how long it took, and the bound
/// taken just before it.
struct HostileRun {
    let error: Error?
    let seconds: Double
    let limit: LoadBound
}

/// A trap ends the whole test process, so each case is named before it runs: a crash log points at it.
func runHostile(_ c: HostileCase, _ body: () throws -> Void) -> HostileRun {
    print("HostileTests: \(c.stage) \(c.id)")
    let limit = bound(unpackNominal, maxAge: 1)
    let (error, seconds) = timed { () -> Error? in
        do {
            try body()
            return nil
        } catch {
            return error
        }
    }
    return HostileRun(error: error, seconds: seconds, limit: limit)
}

/// The outcome term of an error. Unpack reports a value it cannot use in the interim bad-value shape of
/// TypeScript and Go, a short packet that needs 0 bytes (fixtures/hostile/README.md, "Outcome terms"); a
/// short packet that needs bytes is `short_packet`.
func hostileTerm(_ e: PackbinError) -> String {
    e.kind == .short && e.needed == 0 ? PackbinError.Kind.badValue.rawValue : e.kind.rawValue
}

/// What is wrong with a run that must end in a `PackbinError` whose outcome term the case lists and
/// whose text is `rule`, within the bound (`unpackNominal` scaled by the load factor), or nil.
func checkHostileRefusal(_ c: HostileCase, _ run: HostileRun, _ rule: String?) -> String? {
    guard let error = run.error else { return "\(c.id): expected \(c.expected.joined(separator: "|")), got no error" }
    guard let e = error as? PackbinError else { return "\(c.id): not a PackbinError: \(error)" }
    if !c.accepts(hostileTerm(e)) {
        return "\(c.id): returned \(hostileTerm(e)) (\(e)), vector accepts \(c.expected.joined(separator: "|"))"
    }
    guard let rule else { return "\(c.id): no rule is pinned for this refusal: \(e)" }
    if e.description != rule { return "\(c.id): refused by another rule: \"\(e)\", want \"\(rule)\"" }
    let (ok, decided) = run.limit.judge(run.seconds)
    if !ok { return "\(c.id): \(decided.describe(run.seconds))" }
    return nil
}

/// Builds the scheme of an unpack case and unpacks its packet; a scheme refused at construction is the
/// case's outcome (`scheme_error`, which some cases accept).
func checkHostileUnpack(_ c: HostileCase, _ build: HostileBuild?, _ rules: [String: String]) -> String? {
    guard let build else { return "no Swift scheme for unpack case \(c.id)" }
    let run = runHostile(c) { _ = try unpackMap(bytes(c.hex), try build()) }
    return checkHostileRefusal(c, run, rules[c.id])
}

/// Unpacks the packet of a limit case with the section's low limit: the refusal comes when a round would
/// start, so no bytes are needed and the byte of that round is left.
func checkHostileLimit(_ c: HostileCase, _ build: HostileBuild?, _ rules: [String: String]) -> String? {
    guard let build else { return "no Swift scheme for limit case \(c.id)" }
    let run = runHostile(c) { _ = try unpackMap(bytes(c.hex), try hostileLimited(try build())) }
    if let wrong = checkHostileRefusal(c, run, rules[c.id]) { return wrong }
    guard let e = run.error as? PackbinError, e.needed == 0, e.left == 1 else {
        return "\(c.id): \(String(describing: run.error)), want needed 0 and left 1"
    }
    return nil
}

/// Builds the scheme of a construct case, which must be refused with `entry.rule`.
func checkHostileConstruct(_ c: HostileCase, _ entry: HostileConstruct?) -> String? {
    guard let entry else { return "no Swift scheme for construct case \(c.id)" }
    if c.expected != ["scheme_error"] { return "\(c.id): vector expects \(c.expected.joined(separator: "|"))" }
    let run = runHostile(c) { _ = try entry.build() }
    return checkHostileRefusal(c, run, entry.rule)
}

/// Builds the scheme of a pack case and packs its row: the bytes of the case, or a refusal with the
/// rule `rules` pins and no bytes.
func checkHostilePack(_ c: HostileCase, _ entry: HostilePack?, _ rules: [String: String]) -> String? {
    guard let entry else { return "no Swift scheme for pack case \(c.id)" }
    let scheme: Scheme
    do {
        scheme = try entry.scheme()
    } catch {
        return "\(c.id): the scheme of a pack case did not build: \(error)"
    }
    var packed: [UInt8]?
    let run = runHostile(c) { packed = try pack(scheme, entry.row()) }
    switch c.expected {
    case ["bytes"]:
        if let error = run.error { return "\(c.id): expected bytes, got \(error)" }
        let got = hex(packed ?? [])
        return got == c.hex ? nil : "\(c.id): packed \(got), want \(c.hex)"
    case ["pack_error"]:
        if let packed { return "\(c.id): expected a refusal, got bytes \(hex(Array(packed.prefix(32))))" }
        guard let e = run.error as? PackbinError else { return "\(c.id): not a PackbinError: \(String(describing: run.error))" }
        guard let rule = rules[c.id] else { return "\(c.id): no rule is pinned for this refusal: \(e)" }
        return e.kind == .packError && e.description == rule ? nil : "\(c.id): refused by another rule: \"\(e)\", want \"\(rule)\""
    default:
        return "\(c.id): a pack case expects bytes or pack_error, got \(c.expected)"
    }
}
