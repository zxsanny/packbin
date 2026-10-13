package packbin;

import static packbin.MemberCases.packs;
import static packbin.MemberCases.packsAs;
import static packbin.MemberCases.row;
import static packbin.MemberCases.u8;
import static packbin.MemberCases.unpacks;

import java.util.Map;

/**
 * Loop 25 probes D1 (AZ-2476) and D7 (AZ-2478). Every hex is TypeScript's, measured with a throwaway script on the
 * same scheme and row. D1: an empty group under {@code flags} or a flag bit. Java has no anchored empty group
 * ({@code group(0)} is refused at construction), so the row uses the nested-row accessor form, where the nested row
 * carries presence only. D7: a split flag bit inside a {@code when} that does not match, with the member given.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class Loop25ProbeD1D7Test {
    private Loop25ProbeD1D7Test() {}

    static void run() {
        d1EmptyGroupMarkPacksLikeTypeScript();
        d1SplitEmptyGroupMarkPacksLikeTypeScript();
        d1EmptyGroupTakingNoIdLeavesTheNextFieldItsId();
        d1EmptyGroupUnpacksAsAnEmptyRowDiffersFromTypeScript();
        d1FalseMarkValueSetsTheBitDiffersFromTypeScript();
        d1AnchoredEmptyGroupIsRefusedDiffersFromTypeScript();
        d1EmptyGroupHasNoIdForAWhenRefusalTextDiffersFromTypeScript();
        d7SplitBitInsideAFalseWhenPacksLikeTypeScript();
        d7UnpackDropsTheBitOfAFalseWhenAndRepackIsTypeScripts();
    }

    private static Field mark() {
        return Packbin.group(Access.get("mark"), Access.set("mark"));
    }

    private static Scheme<Map> markOnly() {
        return Maps.scheme(1, Packbin.flags(0, mark()));
    }

    private static Scheme<Map> markThenN() {
        return Maps.scheme(1, Packbin.flags(0, mark()), u8(0, "n"));
    }

    private static Scheme<Map> splitMarkAndN() {
        Field m = Packbin.flagByte();
        return Maps.scheme(1, m, m.bit(mark()), m.bit(u8(0, "n")));
    }

    private static Scheme<Map> splitBitInsideWhen() {
        Field m = Packbin.flagByte();
        return Maps.scheme(1, u8(0, "k"), m, Packbin.when(1, Packbin.eq(0, 1), m.bit(u8(1, "a"))), m.bit(u8(2, "b")));
    }

    private static void d1EmptyGroupMarkPacksLikeTypeScript() {
        // Arrange
        Scheme<Map> scheme = markOnly();
        // Act and Assert
        packs("D1 empty group mark given", scheme, row("mark", Maps.map()), "0101");
        packsAs("D1 empty group mark null", scheme, row("mark", null), "0100", row());
        packsAs("D1 empty group mark left out", scheme, row(), "0100", row());
    }

    private static void d1SplitEmptyGroupMarkPacksLikeTypeScript() {
        // Arrange
        Scheme<Map> scheme = splitMarkAndN();
        // Act and Assert
        packs("D1 split empty group mark and n", scheme, row("mark", Maps.map(), "n", 3), "010303");
    }

    /** The group takes no id, so the u8 after the flags keeps id 0, and TypeScript packs this row. */
    private static void d1EmptyGroupTakingNoIdLeavesTheNextFieldItsId() {
        // Arrange
        Scheme<Map> scheme = markThenN();
        // Act and Assert
        packs("D1 handoff mark given", scheme, row("mark", Maps.map(), "n", 3), "010103");
        packs("D1 handoff mark left out", scheme, row("n", 1), "010001");
        PackbinTest.expectThrows("D1 handoff row empty", () -> BinaryPacker.pack(scheme, row()), "missing field 0");
    }

    /** TypeScript unpacks the set bit as {@code mark: true}; the Java nested row comes back as an empty map. */
    private static void d1EmptyGroupUnpacksAsAnEmptyRowDiffersFromTypeScript() {
        // Arrange and Act and Assert
        unpacks("D1 differs: bit set", markOnly(), "0101", row("mark", Maps.map()));
        unpacks("D1 same as TypeScript: bit clear", markOnly(), "0100", row());
        unpacks("D1 differs: split", splitMarkAndN(), "010303", row("mark", Maps.map(), "n", 3));
        unpacks("D1 differs: handoff", markThenN(), "010103", row("mark", Maps.map(), "n", 3));
    }

    /** TypeScript packs {@code mark: false} to {@code 0100}; Java reads any value that is not null as present. */
    private static void d1FalseMarkValueSetsTheBitDiffersFromTypeScript() {
        // Arrange and Act and Assert
        packsAs("D1 differs: mark false", markOnly(), row("mark", false), "0101", row("mark", Maps.map()));
        packsAs("D1 differs: handoff mark false", markThenN(), row("mark", false, "n", 3), "010103",
                row("mark", Maps.map(), "n", 3));
    }

    /** TypeScript builds {@code flags(0, group(0, mark, []))}; the Java anchored empty group has no accessor. */
    private static void d1AnchoredEmptyGroupIsRefusedDiffersFromTypeScript() {
        // Arrange
        String never = "empty group 0 has no fields and no accessor, so its bit can never be set";
        // Act and Assert
        PackbinTest.expectThrows("D1 differs: anchored empty group in flags",
                () -> Maps.scheme(1, Packbin.flags(0, Packbin.group(0)), u8(0, "n")), never);
    }

    /** Both packages refuse naming the same cause; the text differs. */
    private static void d1EmptyGroupHasNoIdForAWhenRefusalTextDiffersFromTypeScript() {
        // Arrange and Act and Assert
        PackbinTest.expectThrows("D1 differs: eq names the empty group's id",
                () -> Maps.scheme(1, Packbin.flags(0, mark()), Packbin.when(0, Packbin.eq(0, true), u8(0, "v"))),
                "when 0 tests field 0, which is not an earlier integer or bool field in its scope");
    }

    private static void d7SplitBitInsideAFalseWhenPacksLikeTypeScript() {
        // Arrange
        Scheme<Map> scheme = splitBitInsideWhen();
        // Act and Assert
        packs("D7 when holds", scheme, row("k", 1, "a", 5, "b", 6), "0101030506");
        packsAs("D7 when does not match, a given: bit set, no a byte", scheme, row("k", 0, "a", 5, "b", 6), "01000306",
                row("k", 0, "b", 6));
    }

    private static void d7UnpackDropsTheBitOfAFalseWhenAndRepackIsTypeScripts() {
        // Arrange
        Scheme<Map> scheme = splitBitInsideWhen();
        // Act
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(PackbinTest.parseHex("01000306"), scheme.on(r -> got[0] = r));
        // Assert
        PackbinTest.expectTrue("D7 unpack 01000306 ok (" + err + ")", err == null && got[0] != null);
        PackbinTest.expectEq("D7 unpack 01000306 row", row("k", 0, "b", 6), got[0]);
        PackbinTest.expectEq("D7 repack of the unpacked row", "01000206", PackbinTest.toHex(BinaryPacker.pack(scheme, got[0])));
        unpacks("D7 unpack 0101030506", scheme, "0101030506", row("k", 1, "a", 5, "b", 6));
    }
}
