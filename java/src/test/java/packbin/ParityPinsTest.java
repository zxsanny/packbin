package packbin;

import static packbin.MemberCases.list;
import static packbin.MemberCases.packs;
import static packbin.MemberCases.packsAs;
import static packbin.MemberCases.refused;
import static packbin.MemberCases.row;
import static packbin.MemberCases.u16;
import static packbin.MemberCases.u8;

import java.util.Map;

/**
 * Loop 20 parity rows: AZ-2356 (count 0 written after the flag byte: a list is refused, a lone scalar packs zero
 * rounds), AZ-2360 (a combined flags whose times count was skipped refuses the values given) and AZ-2359 (an enum
 * member is not a number in an integer slot).
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class ParityPinsTest {
    private ParityPinsTest() {}

    private enum Level { LOW, HIGH }

    private static final String SKIPPED = ": a value is given, but the count of its times is not written, so its bit is"
            + " clear; write the count before the times";

    static void run() {
        az2356CountZeroAfterTheByte();
        az2360SkippedCountWithValuesIsLoud();
        az2359AnEnumIsNotANumber();
    }

    private static void az2356CountZeroAfterTheByte() {
        // Arrange
        Field byteField = Packbin.flagByte();
        Scheme<Map> split = Maps.scheme(1, byteField, u8(0, "n"), byteField.bit(Packbin.times(1, 0, u8(1, "pt"))),
                u16(2, "heading"));
        // Act and Assert
        refused("AZ-2356 AC-1 list with count 0 after the byte", split, row("n", 0, "pt", list(5, 6), "heading", 90),
                "1: list has 2 entries for a count of 0");
        packs("AZ-2356 AC-2 lone scalar with count 0 packs zero rounds", split, row("n", 0, "heading", 90), "0100005a00");
        PackbinTest.expectEq("AZ-2356 AC-2 lone scalar bytes", "0100005a00",
                PackbinTest.toHex(BinaryPacker.pack(split, row("n", 0, "pt", 5, "heading", 90))));
    }

    private static void az2360SkippedCountWithValuesIsLoud() {
        // Arrange
        Scheme<Map> skipped = Maps.scheme(1, u8(0, "sel"), Packbin.when(1, Packbin.eq(0, 1), u8(1, "n")),
                Packbin.flags(2, Packbin.times(2, 1, u8(2, "pt")), u16(3, "heading")));
        Scheme<Map> nested = Maps.scheme(1, u8(0, "sel"), Packbin.when(1, Packbin.eq(0, 1), u8(1, "n")),
                Packbin.flags(2, Packbin.when(2, Packbin.eq(0, 0), Packbin.times(2, 1, u8(2, "pt"))), u16(3, "heading")));
        // Act and Assert
        refused("AZ-2360 AC-1 skipped count, values", skipped, row("sel", 0, "pt", list(5, 6), "heading", 90), "pt" + SKIPPED);
        refused("AZ-2360 AC-1 skipped count, one value", skipped, row("sel", 0, "pt", list(5)), "pt" + SKIPPED);
        refused("AZ-2360 AC-1 skipped count behind a when", nested, row("sel", 0, "pt", list(5), "heading", 90), "pt" + SKIPPED);
        packs("AZ-2360 AC-2 skipped count, no values", skipped, row("sel", 0, "heading", 90), "0100025a00");
        packsAs("AZ-2360 AC-2 skipped count, empty list", skipped, row("sel", 0, "pt", list(), "heading", 90), "0100025a00",
                row("sel", 0, "heading", 90));
        packs("AZ-2360 count written, values given", skipped, row("sel", 1, "n", 2, "pt", list(5, 6), "heading", 90),
                "0101020305065a00");
    }

    private static void az2359AnEnumIsNotANumber() {
        // Arrange
        Scheme<Map> wide = Maps.scheme(1, u8(0, "level"));
        Scheme<Map> slot = Maps.scheme(1, Packbin.u2(Packbin.u2Slot(0, Access.get("level"), Access.set("level"))));
        // Act and Assert
        refused("AZ-2359 enum in a u8 slot", wide, row("level", Level.HIGH), "0: expected int, got Level");
        refused("AZ-2359 enum in a u2 slot", slot, row("level", Level.HIGH), "0: expected 2-bit int");
        packs("AZ-2359 its ordinal packs", wide, row("level", Level.HIGH.ordinal()), "0101");
    }
}
