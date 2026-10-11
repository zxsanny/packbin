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
 * AZ-2335 (owner decision 7, loop 19): a times count of 0 with a list of values given is a pack error naming the
 * member, outside and inside flags; count 0 with no values writes zero rounds.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class TimesCountZeroTest {
    private TimesCountZeroTest() {}

    private static final Scheme<Map> PLAIN = Maps.scheme(1, u8(0, "n"), Packbin.times(1, 0, u8(1, "pt"), u8(2, "pu")));

    private static final Scheme<Map> IN_FLAGS = Maps.scheme(1, u8(0, "n"),
            Packbin.flags(1, Packbin.times(1, 0, u8(1, "pt")), u16(2, "heading")));

    static void run() {
        ac1CountZeroWithValuesIsRefused();
        ac2CountZeroWithoutValuesPacks();
    }

    private static void ac1CountZeroWithValuesIsRefused() {
        refused("AZ-2335 AC-1 outside flags", PLAIN, row("n", 0, "pt", list(5), "pu", list()),
                "1: list has 1 entries for a count of 0");
        refused("AZ-2335 AC-1 second value", PLAIN, row("n", 0, "pu", list(7)), "2: list has 1 entries for a count of 0");
        refused("AZ-2335 AC-1 hostile entry 300", PLAIN, row("n", 0, "pt", list(300)),
                "1: list has 1 entries for a count of 0");
        refused("AZ-2335 AC-1 inside flags", IN_FLAGS, row("n", 0, "pt", list(5), "heading", 90),
                "1: list has 1 entries for a count of 0");
    }

    private static void ac2CountZeroWithoutValuesPacks() {
        packs("AZ-2335 AC-2 outside flags", PLAIN, row("n", 0), "0100");
        packsAs("AZ-2335 AC-2 empty lists", PLAIN, row("n", 0, "pt", list(), "pu", list()), "0100", row("n", 0));
        packs("AZ-2335 AC-2 inside flags", IN_FLAGS, row("n", 0, "heading", 90), "0100025a00");
    }
}
