package packbin;

import static packbin.MemberCases.packs;
import static packbin.MemberCases.row;
import static packbin.MemberCases.u16;
import static packbin.MemberCases.u8;

import java.math.BigInteger;
import java.util.Map;

/**
 * AZ-2338 (owner decision 11, loop 19): an {@code eq} on an integer source is refused when the scheme is built if
 * its value is one the source could never hold: out of range, a string, a fraction, NaN, a boolean or null. The
 * value is checked as pack checks it. {@code eq(bool, true)} stays as AZ-2126 has it.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class EqValueCheckedTest {
    private EqValueCheckedTest() {}

    static void run() {
        ac1OutOfRange();
        ac2NotAnInteger();
        ac3BoolForInteger();
        ac4ValidValueBuilds();
    }

    private static Scheme<Map> on(Field source, Object value) {
        return Maps.scheme(1, source, Packbin.when(1, Packbin.eq(0, value), u8(1, "speed")));
    }

    private static String refusal(String against, String reason) {
        return "when 1 tests field 0 against " + against + ", which that field can not hold (" + reason + ")";
    }

    private static void ac1OutOfRange() {
        PackbinTest.expectThrows("AZ-2338 AC-1 eq(u8, 300)", () -> on(u8(0, "mode"), 300),
                refusal("300", "0: 300 does not fit"));
        PackbinTest.expectThrows("AZ-2338 AC-1 eq(u8, -1)", () -> on(u8(0, "mode"), -1),
                refusal("-1", "0: -1 does not fit"));
        PackbinTest.expectThrows("AZ-2338 AC-1 eq(u16, 2^32) hostile", () -> on(u16(0, "mode"), 4_294_967_296L),
                refusal("4294967296", "0: 4294967296 does not fit"));
        PackbinTest.expectThrows("AZ-2338 AC-1 eq(i8, 128)", () -> on(Packbin.i8(0, Access.get("m"), Access.set("m")), 128),
                refusal("128", "0: 128 does not fit"));
        PackbinTest.expectThrows("AZ-2338 AC-1 eq(u8, BigInteger 2^64-1) hostile",
                () -> on(u8(0, "mode"), new BigInteger("18446744073709551615")),
                refusal("18446744073709551615", "0: 18446744073709551615 does not fit"));
        PackbinTest.expectThrows("AZ-2338 AC-1 eq(u64, -1 as an int)",
                () -> on(Packbin.u64(0, Access.get("m"), Access.set("m")), -1),
                refusal("-1", "0: -1 does not fit"));
    }

    private static void ac2NotAnInteger() {
        PackbinTest.expectThrows("AZ-2338 AC-2 eq(u8, string)", () -> on(u8(0, "mode"), "x"),
                refusal("x", "0: expected int, got String"));
        PackbinTest.expectThrows("AZ-2338 AC-2 eq(u8, NaN)", () -> on(u8(0, "mode"), Double.NaN),
                refusal("NaN", "0: expected int, got Double"));
        PackbinTest.expectThrows("AZ-2338 AC-2 eq(u8, 1.5)", () -> on(u8(0, "mode"), 1.5),
                refusal("1.5", "0: expected int, got Double"));
        PackbinTest.expectThrows("AZ-2338 AC-2 eq(u8, null)", () -> on(u8(0, "mode"), null),
                refusal("null", "0: expected int, got null"));
    }

    private static void ac3BoolForInteger() {
        PackbinTest.expectThrows("AZ-2338 AC-3 eq(u8, true)", () -> on(u8(0, "mode"), true),
                refusal("true", "0: expected int, got Boolean"));
        PackbinTest.expectThrows("AZ-2338 AC-3 eq(u8, false) as the member of a flags", () -> Maps.scheme(1, u8(0, "mode"),
                Packbin.flags(1, Packbin.when(1, Packbin.eq(0, false), u8(1, "speed")), u16(2, "heading"))),
                refusal("false", "0: expected int, got Boolean"));
    }

    private static void ac4ValidValueBuilds() {
        Scheme<Map> scheme = on(u8(0, "mode"), 5);
        packs("AZ-2338 AC-4 eq(u8, 5) true", scheme, row("mode", 5, "speed", 7), "010507");
        packs("AZ-2338 AC-4 eq(u8, 5) false", scheme, row("mode", 4), "0104");
        packs("AZ-2338 AC-4 eq(u8, Long 5)", on(u8(0, "mode"), 5L), row("mode", 5, "speed", 7), "010507");
        packs("AZ-2338 AC-4 eq(u8, 255)", on(u8(0, "mode"), 255), row("mode", 255, "speed", 7), "01ff07");
        packs("AZ-2338 AC-4 eq(i8, -1)", on(Packbin.i8(0, Access.get("mode"), Access.set("mode")), -1),
                row("mode", -1, "speed", 7), "01ff07");
    }
}
