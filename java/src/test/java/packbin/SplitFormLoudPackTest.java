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
 * AZ-2331 (owner decision 3, loop 19): a split flag byte decides its bits where it stands. A {@code when} or
 * {@code times} bit whose condition or count is written after the byte, or whose count is never written, and that
 * holds values, fails pack naming the member instead of dropping the body. Shapes whose source is written before the
 * byte pack as the loop 18 reference rows say (FlagsWhenMemberTest, FlagsRoundMemberTest).
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class SplitFormLoudPackTest {
    private SplitFormLoudPackTest() {}

    private static final String LATE =
            ": its flag bit was decided before the value its condition or count reads was written";
    private static final String UNCOUNTED = ": values given, but the count of its times was never written";

    /** The condition source ({@code mode}) is written after the flag byte. */
    private static final Scheme<Map> WL = splitScheme(false);

    /** The count ({@code n}) is written after the flag byte. */
    private static final Scheme<Map> TL = splitScheme(true);

    /** The count sits in a {@code when} body that a row can skip. */
    private static final Scheme<Map> TSK = skippedCount();

    private static Scheme<Map> splitScheme(boolean times) {
        Field byteField = Packbin.flagByte();
        Field member = times
                ? Packbin.times(1, 0, u8(1, "pt"))
                : Packbin.when(1, Packbin.eq(0, 1), u8(1, "speed"));
        return Maps.scheme(1, byteField, u8(0, times ? "n" : "mode"), byteField.bit(member),
                byteField.bit(u16(2, "heading")));
    }

    private static Scheme<Map> skippedCount() {
        Field byteField = Packbin.flagByte();
        return Maps.scheme(1, u8(0, "sel"), Packbin.when(1, Packbin.eq(0, 1), u8(1, "n")), byteField,
                byteField.bit(Packbin.times(2, 1, u8(2, "pt"))), byteField.bit(u16(3, "heading")));
    }

    static void run() {
        ac1ConditionWrittenAfterTheByte();
        ac2CountWrittenAfterTheByteOrNeverWritten();
        ac3ConditionFalseOnWrittenValuesStillDropsTheBody();
        ac4SourceBeforeTheByteIsUnchanged();
    }

    private static void ac1ConditionWrittenAfterTheByte() {
        refused("AZ-2331 AC-1 when, body given", WL, row("mode", 1, "speed", 7, "heading", 90), "speed" + LATE);
        refused("AZ-2331 AC-1 hostile body 300", WL, row("mode", 1, "speed", 300, "heading", 90), "speed" + LATE);
        packs("AZ-2331 AC-1 when, no body", WL, row("mode", 1, "heading", 90), "0102015a00");
    }

    private static void ac2CountWrittenAfterTheByteOrNeverWritten() {
        refused("AZ-2331 AC-2 count after the byte", TL, row("n", 2, "pt", list(5, 6), "heading", 90), "pt" + LATE);
        packs("AZ-2331 AC-2 count after the byte, count 0", TL, row("n", 0, "heading", 90), "0102005a00");
        refused("AZ-2331 AC-2 count skipped, values given", TSK, row("sel", 0, "pt", list(5), "heading", 90),
                "pt" + UNCOUNTED);
        refused("AZ-2331 AC-2 count skipped, hostile value", TSK, row("sel", 0, "pt", list(300), "heading", 90),
                "pt" + UNCOUNTED);
        packs("AZ-2331 AC-2 count skipped, no values", TSK, row("sel", 0, "heading", 90), "0100025a00");
        packs("AZ-2331 AC-2 count written", TSK, row("sel", 1, "n", 1, "pt", list(5), "heading", 90),
                "01010103055a00");
    }

    private static void ac3ConditionFalseOnWrittenValuesStillDropsTheBody() {
        // The condition is false on values written before the byte: the loop 18 reference row W-split-false-body-given.
        Field byteField = Packbin.flagByte();
        Scheme<Map> ws = Maps.scheme(1, u8(0, "mode"), byteField,
                byteField.bit(Packbin.when(1, Packbin.eq(0, 1), u8(1, "speed"))), byteField.bit(u16(2, "heading")));
        packsAs("AZ-2331 AC-3 false condition before the byte", ws, row("mode", 0, "speed", 7, "heading", 90),
                "0100025a00", row("mode", 0, "heading", 90));
        // The condition source comes after the byte and the condition is false there: nothing was decided wrongly.
        packsAs("AZ-2331 AC-3 false condition after the byte", WL, row("mode", 0, "speed", 7, "heading", 90),
                "0102005a00", row("mode", 0, "heading", 90));
    }

    private static void ac4SourceBeforeTheByteIsUnchanged() {
        Field byteField = Packbin.flagByte();
        Scheme<Map> ts = Maps.scheme(1, u8(0, "n"), byteField,
                byteField.bit(Packbin.times(1, 0, u8(1, "pt"))), byteField.bit(u16(2, "heading")));
        packs("AZ-2331 AC-4 TS 2 rounds", ts, row("n", 2, "pt", list(5, 6), "heading", 90), "01020305065a00");
        refused("AZ-2331 AC-4 TS count 0 and values", ts, row("n", 0, "pt", list(5), "heading", 90),
                "1: list has 1 entries for a count of 0");
    }
}
