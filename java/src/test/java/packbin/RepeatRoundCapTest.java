package packbin;

import static packbin.MemberCases.list;
import static packbin.MemberCases.packs;
import static packbin.MemberCases.refused;
import static packbin.MemberCases.row;
import static packbin.MemberCases.u8;

import java.util.Collections;
import java.util.List;
import java.util.Map;

/**
 * AZ-2355 (loop 20): a {@code repeat} whose list holds more entries than {@code maxRounds} is refused on pack,
 * before any round, naming the member whose list passes the limit, so pack never writes a packet its own unpack
 * refuses. Rows 1 to 10 of the AZ-2355 table in the TypeScript reference.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class RepeatRoundCapTest {
    private RepeatRoundCapTest() {}

    private static final long SLOTS = Scheme.DEFAULT_MAX_SLOTS;
    private static final List<Integer> FOUR = list(1, 2, 3, 4);

    private static String over(int count, int limit) {
        return ": the repeat count is " + count + ", above the limit of " + limit + " rounds";
    }

    private static Scheme<Map> repeatOfK(int maxRounds) {
        return Maps.scheme(1, Packbin.repeat(0, u8(0, "k"))).withLimits(maxRounds, SLOTS);
    }

    static void run() {
        rows1To3TheDefaultLimit();
        rows4To6TheMemberNamed();
        rows7To10EveryPlaceARepeatSits();
    }

    private static void rows1To3TheDefaultLimit() {
        // Arrange
        Scheme<Map> scheme = repeatOfK(Scheme.DEFAULT_MAX_ROUNDS);
        // Act
        byte[] atLimit = BinaryPacker.pack(scheme, row("k", Collections.nCopies(65_535, 7)));
        Map[] back = new Map[1];
        Object err = BinaryPacker.unpack(atLimit, scheme.on(r -> back[0] = r));
        byte[] raised = BinaryPacker.pack(repeatOfK(70_000), row("k", Collections.nCopies(70_000, 7)));
        // Assert
        refused("AZ-2355 AC-1 row 1 65,536 entries", scheme, row("k", Collections.nCopies(65_536, 7)),
                "k" + over(65_536, 65_535));
        PackbinTest.expectEq("AZ-2355 AC-2 row 2 length", 65_536, atLimit.length);
        PackbinTest.expectEq("AZ-2355 AC-2 row 2 head", "01070707", PackbinTest.toHex(java.util.Arrays.copyOf(atLimit, 4)));
        PackbinTest.expectTrue("AZ-2355 AC-2 row 2 unpacks (" + err + ")", err == null && back[0] != null);
        PackbinTest.expectEq("AZ-2355 AC-2 row 2 round trip", 65_535, ((List) back[0].get("k")).size());
        PackbinTest.expectTrue("AZ-2355 AC-2 row 2 repack gives the same bytes",
                java.util.Arrays.equals(atLimit, BinaryPacker.pack(scheme, back[0])));
        PackbinTest.expectEq("AZ-2355 AC-3 row 3 raised limit", 70_001, raised.length);
    }

    private static void rows4To6TheMemberNamed() {
        // Arrange
        Scheme<Map> two = Maps.scheme(1, Packbin.repeat(0, u8(0, "a"), u8(1, "b"))).withLimits(3, SLOTS);
        // Act and Assert
        refused("AZ-2355 row 4", repeatOfK(3), row("k", list(1, 2, 3, 4)), "k" + over(4, 3));
        packs("AZ-2355 row 5", repeatOfK(3), row("k", list(1, 2, 3)), "01010203");
        refused("AZ-2355 row 6 names the long list, not the first member", two,
                row("a", 1, "b", list(1, 2, 3, 4)), "b" + over(4, 3));
        refused("AZ-2355 row 6 both lists long, the first in order", two,
                row("a", list(1, 2, 3, 4, 5), "b", list(1, 2, 3, 4)), "a" + over(5, 3));
    }

    private static void rows7To10EveryPlaceARepeatSits() {
        // Arrange
        String text = "k" + over(4, 3);
        Scheme<Map> inFlags = Maps.scheme(1, Packbin.flags(0, Packbin.repeat(0, u8(0, "k")))).withLimits(3, SLOTS);
        Field byteField = Packbin.flagByte();
        Scheme<Map> inSplitBit = Maps.scheme(1, byteField, byteField.bit(Packbin.repeat(0, u8(0, "k"))))
                .withLimits(3, SLOTS);
        Scheme<Map> inWhen = Maps.scheme(1, u8(0, "m"), Packbin.when(1, Packbin.eq(0, 1), Packbin.repeat(1, u8(1, "k"))))
                .withLimits(3, SLOTS);
        Scheme<Map> inElement = Maps.scheme(1, Packbin.list(Access.get("items"), Access.set("items"),
                Packbin.group(0, Packbin.repeat(0, u8(0, "k"))))).withLimits(3, SLOTS);
        // Act and Assert
        refused("AZ-2355 row 7 flags", inFlags, row("k", FOUR), text);
        refused("AZ-2355 row 8 split bit", inSplitBit, row("k", FOUR), text);
        refused("AZ-2355 row 9 when", inWhen, row("m", 1, "k", FOUR), text);
        refused("AZ-2355 row 10 list element", inElement, row("items", List.of(Maps.map("k", FOUR))), text);
        packs("AZ-2355 row 7 at the limit", inFlags, row("k", list(1, 2, 3)), "0101010203");
    }

}
