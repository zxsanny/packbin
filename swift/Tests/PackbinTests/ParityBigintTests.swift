import Packbin
import Testing

private let memberTail = " in the row, but no field wrote it (the when that holds it is clear), so the member reads nothing; "
    + "give the count 0, leave it out, or make the when hold"
private let timesTail = " in the row, but no field wrote it (the when that holds it is clear), so its times reads no round; "
    + "give the count 0, leave it out, or make the when hold"

/// One member of the U11 shape: its kind and how it is built at id 2, counted by c (id 1).
struct BigintMember: CustomTestStringConvertible, Sendable {
    let name: String
    let member: @Sendable () -> Field
    var testDescription: String { name }
}

private let bigintMembers: [BigintMember] = [
    BigintMember(name: "bits") { .bits(2, "v", count: 1) },
    BigintMember(name: "packed") { .packed(1, 2, "v", count: 1) },
    BigintMember(name: "packed bias -1") { .packed(1, 2, "v", count: 1, bias: -1) },
    BigintMember(name: "sized") { .sized(2, "v", count: 1) },
]

/// `u8 mode; when mode == 1 { u8 c }` and then `member` behind a split bit or as the one member of a
/// combined flags.
private func layouts(_ member: @Sendable () -> Field) throws -> [Scheme] {
    let head: [Field] = [.u8(0, "mode"), .when(1, .eq(0, 1), .u8(1, "c"))]
    let fb = FlagByte("fb")
    return [try Scheme(1, head + [.flagByte(fb), fb.bit(member())]), try Scheme(1, head + [.flags(2, member())])]
}

private func outcome(_ scheme: Scheme, _ row: [String: Any]) -> String {
    do { return hex(try pack(scheme, row)) } catch let e as PackbinError { return "refused \(e.field ?? -1) \(e.name): \(e.reason)" } catch {
        return "not a PackbinError: \(error)"
    }
}

/// Counts above 0 as the row gives them, each with the number the refusal shows.
private func countsAbove0() -> [(Any, String)] { [
    (UInt64(1) << 60, "1152921504606846976"), (Int64(1) << 60, "1152921504606846976"), (1 << 60, "1152921504606846976"),
    ((UInt64(1) << 53) + 1, "9007199254740993"), (UInt64(1) << 53, "9007199254740992"), (UInt64.max, "18446744073709551615"),
    (UInt64(3), "3"), (3, "3"), ((UInt64(1) << 53) - 1, "9007199254740991"),
] }

/// Values that are not a count above 0: TypeScript packs the clear bit for each (`0n`, 3.5, -1, "3",
/// NaN, true, null, -2^60n), as for a count left out.
private func notCounts() -> [(String, Any)] { [
    ("0", UInt64(0)), ("3.5", 3.5), ("-1", -1), ("\"3\"", "3"), ("NaN", Double.nan), ("true", true),
    ("nil", Int?.none as Any), ("-2^60", -(Int64(1) << 60)),
] }

/// AC-1 (U23, `loop23-bigint-count`, FT-X-79) and AC-2 (U6, `loop21-parity-probes`): in the U11 shape a
/// count above 2^53 is a count above 0, refused naming the member and the number; a `times` does the
/// same, as C#, Python, Rust, Java and Go refuse it (TypeScript alone packs the clear bit for a bigint
/// count above 2^53 or 2^64-1, its documented U6 split).
@Suite struct ParityBigintTests {
    @Test(arguments: bigintMembers)
    func pack_countAbove0BehindAClearWhen_isRefusedNamingMemberAndCount(_ m: BigintMember) throws {
        for scheme in try layouts(m.member) {
            for (count, shown) in countsAbove0() {
                // Act
                let error = packbinError { try pack(scheme, ["mode": 0, "c": count]) }

                // Assert
                #expect(error?.kind == .packError && error?.field == 2 && error?.name == "v", "\(m.name) \(shown)")
                #expect(error?.reason == "v: the count c is \(shown)" + memberTail, "\(m.name) \(shown)")
            }
        }
    }

    @Test(arguments: bigintMembers)
    func pack_valueThatIsNotACountAbove0_packsTheClearBit(_ m: BigintMember) throws {
        for scheme in try layouts(m.member) {
            for (label, count) in notCounts() {
                #expect(outcome(scheme, ["mode": 0, "c": count]) == "010000", "\(m.name) \(label)")
            }
            #expect(outcome(scheme, ["mode": 0]) == "010000", "\(m.name) left out")
        }
    }

    /// `packed` with bias -1 reads one item fewer: count 1 is no item, so the clear bit packs (TypeScript).
    @Test func pack_packedBiasMinus1Count1BehindAClearWhen_packsTheClearBit() throws {
        for scheme in try layouts({ .packed(1, 2, "v", count: 1, bias: -1) }) {
            #expect(outcome(scheme, ["mode": 0, "c": 1]) == "010000")
            #expect(outcome(scheme, ["mode": 0, "c": UInt64(1)]) == "010000")
        }
    }

    @Test func pack_timesCountAbove2Pow53BehindAClearWhen_followsTheOthersNotTypeScript() throws {
        for scheme in try layouts({ .times(2, count: 1, .u8(2, "pt")) }) {
            for (count, shown) in countsAbove0() + [(1, "1")] {
                // Act
                let error = packbinError { try pack(scheme, ["mode": 0, "c": count]) }

                // Assert: TypeScript packs 010000 for 2^60n, 2^53n + 1n, 2^53n and 2^64n - 1n (U6).
                #expect(error?.kind == .packError && error?.field == 2 && error?.name == "pt", "\(shown)")
                #expect(error?.reason == "pt: the count c is \(shown)" + timesTail, "\(shown)")
            }
            for (label, count) in notCounts() {
                #expect(outcome(scheme, ["mode": 0, "c": count]) == "010000", "times \(label)")
            }
            #expect(outcome(scheme, ["mode": 0]) == "010000", "times left out")
        }
    }
}
