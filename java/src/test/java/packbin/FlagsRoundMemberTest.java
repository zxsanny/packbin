package packbin;

import static packbin.MemberCases.list;
import static packbin.MemberCases.packs;
import static packbin.MemberCases.packsAs;
import static packbin.MemberCases.refused;
import static packbin.MemberCases.row;
import static packbin.MemberCases.u16;
import static packbin.MemberCases.u8;
import static packbin.MemberCases.unpacks;

import java.util.Map;

/**
 * AZ-2120 AC-4 and AC-5 (owner decision 2026-10-10): a {@code times} or {@code repeat} that is a member of a flags
 * container, a split flag bit or a group under one is written like any other value. A times bit is on exactly when
 * its count is above 0, a repeat bit when a round holds a value. A set member that cannot be written in full fails
 * pack naming the missing value. Every hex is the C# package's, pinned in the wave 3 reference table.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class FlagsRoundMemberTest {
    private FlagsRoundMemberTest() {}

    private static final Scheme<Map> TA = Maps.scheme(1, u8(0, "n"),
            Packbin.flags(1, Packbin.times(1, 0, u8(1, "pt")), u16(2, "heading")));

    private static final Scheme<Map> TS = splitScheme();

    private static final Scheme<Map> TG = Maps.scheme(1, u8(0, "n"),
            Packbin.flags(1, Packbin.group(1, Packbin.times(1, 0, u8(1, "pt"))), u16(2, "heading")));

    private static final Scheme<Map> T2 = Maps.scheme(1, u8(0, "n"),
            Packbin.flags(1, Packbin.times(1, 0, u8(1, "pt"), u8(2, "pu")), u16(3, "heading")));

    private static final Scheme<Map> RA = Maps.scheme(1, u8(0, "mode"),
            Packbin.flags(1, u16(1, "heading"), Packbin.repeat(2, u8(2, "pt"))));

    private static final Scheme<Map> R2 = Maps.scheme(1, u8(0, "mode"),
            Packbin.flags(1, u16(1, "heading"), Packbin.repeat(2, u8(2, "pt"), u8(3, "pu"))));

    private static Scheme<Map> splitScheme() {
        Field byteField = Packbin.flagByte();
        return Maps.scheme(1, u8(0, "n"), byteField,
                byteField.bit(Packbin.times(1, 0, u8(1, "pt"))), byteField.bit(u16(2, "heading")));
    }

    private static final String LONGER = "1: list has ";

    static void run() {
        ac4TimesUnderFlags();
        ac4TimesErrors();
        ac4TimesInASplitFlagByteAndInAGroup();
        ac4TimesWithTwoValues();
        ac5TimesPacketsUnpack();
        ac4RepeatUnderFlags();
        ac4RepeatWithTwoValues();
        ac5RepeatPacketsUnpack();
        ac4HostileRoundValueFailsNamingTheField();
    }

    private static void ac4TimesUnderFlags() {
        packs("AC-4 T-0-rounds", TA, row("n", 0, "heading", 90), "0100025a00");
        packs("AC-4 T-1-round", TA, row("n", 1, "pt", list(5), "heading", 90), "010103055a00");
        packs("AC-4 T-2-rounds", TA, row("n", 2, "pt", list(5, 6), "heading", 90), "01020305065a00");
        packs("AC-4 T-only-times", TA, row("n", 2, "pt", list(5, 6)), "0102010506");
        packs("AC-4 T-only-n", TA, row("n", 0), "010000");
    }

    private static void ac4TimesErrors() {
        for (Object[] form : new Object[][] {{"TA", TA}, {"TS", TS}, {"TG", TG}}) {
            String label = "AC-4 T-errors " + form[0];
            Scheme<Map> scheme = (Scheme<Map>) form[1];
            refused(label + " list too short", scheme, row("n", 2, "pt", list(5), "heading", 90), "1: expected int, got null");
            refused(label + " values missing", scheme, row("n", 1, "heading", 90), "1: expected int, got null");
            refused(label + " count 0 with a list given", scheme, row("n", 0, "pt", list(5), "heading", 90),
                    LONGER + "1 entries for a count of 0");
            refused(label + " list too long", scheme, row("n", 1, "pt", list(5, 6), "heading", 90),
                    LONGER + "2 entries for a count of 1");
        }
    }

    private static void ac4TimesInASplitFlagByteAndInAGroup() {
        for (Object[] form : new Object[][] {{"TS", TS}, {"TG", TG}}) {
            String label = "AC-4 T-" + form[0];
            Scheme<Map> scheme = (Scheme<Map>) form[1];
            packs(label + " 0 rounds", scheme, row("n", 0, "heading", 90), "0100025a00");
            packs(label + " 1 round", scheme, row("n", 1, "pt", list(5), "heading", 90), "010103055a00");
            packs(label + " 2 rounds", scheme, row("n", 2, "pt", list(5, 6), "heading", 90), "01020305065a00");
        }
    }

    private static void ac4TimesWithTwoValues() {
        refused("AC-4 T-two-values-missing", T2, row("n", 1, "pt", list(5), "heading", 90), "2: expected int, got null");
        packs("AC-4 T-two-values-1", T2, row("n", 1, "pt", list(5), "pu", list(6), "heading", 90), "01010305065a00");
        packs("AC-4 T-two-values-2", T2, row("n", 2, "pt", list(5, 6), "pu", list(7, 8), "heading", 90),
                "010203050706085a00");
    }

    private static void ac5TimesPacketsUnpack() {
        unpacks("AC-5 T-old-packet", TA, "0100025a00", row("n", 0, "heading", 90));
        unpacks("AC-5 T-new-packet", TA, "01020305065a00", row("n", 2, "pt", list(5, 6), "heading", 90));
        unpacks("AC-5 T-split-new-packet", TS, "01020305065a00", row("n", 2, "pt", list(5, 6), "heading", 90));
        unpacks("AC-5 T-group-new-packet", TG, "01020305065a00", row("n", 2, "pt", list(5, 6), "heading", 90));
    }

    private static void ac4RepeatUnderFlags() {
        packs("AC-4 R-0-rounds", RA, row("mode", 1, "heading", 90), "0101015a00");
        packs("AC-4 R-1-round", RA, row("mode", 1, "pt", list(5), "heading", 90), "0101035a0005");
        packs("AC-4 R-2-rounds", RA, row("mode", 1, "pt", list(5, 6), "heading", 90), "0101035a000506");
        packs("AC-4 R-only-repeat", RA, row("mode", 1, "pt", list(5, 6)), "0101020506");
        packs("AC-4 R-only-mode", RA, row("mode", 1), "010100");
        packsAs("AC-4 R-lone-value is one round", RA, row("mode", 1, "pt", 5, "heading", 90), "0101035a0005",
                row("mode", 1, "pt", list(5), "heading", 90));
    }

    private static void ac4RepeatWithTwoValues() {
        refused("AC-4 R-missing-body-value", R2, row("mode", 1, "pt", list(5), "heading", 90), "3: expected int, got null");
        packs("AC-4 R-two-values-1", R2, row("mode", 1, "pt", list(5), "pu", list(6), "heading", 90), "0101035a000506");
        packs("AC-4 R-two-values-2", R2, row("mode", 1, "pt", list(5, 6), "pu", list(7, 8), "heading", 90),
                "0101035a0005070608");
    }

    private static void ac5RepeatPacketsUnpack() {
        unpacks("AC-5 R-old-packet", RA, "0101015a00", row("mode", 1, "heading", 90));
        unpacks("AC-5 R-new-packet", RA, "0101035a000506", row("mode", 1, "pt", list(5, 6), "heading", 90));
        unpacks("AC-5 R-two-values-unpack", R2, "0101035a0005060708",
                row("mode", 1, "pt", list(5, 7), "pu", list(6, 8), "heading", 90));
    }

    /** A round value outside its field range fails pack naming the field and returns no bytes. */
    private static void ac4HostileRoundValueFailsNamingTheField() {
        refused("AC-4 hostile times entry 300", TA, row("n", 1, "pt", list(300), "heading", 90), "1: 300 does not fit");
        refused("AC-4 hostile repeat entry 300", RA, row("mode", 1, "pt", list(300), "heading", 90), "2: 300 does not fit");
    }
}
