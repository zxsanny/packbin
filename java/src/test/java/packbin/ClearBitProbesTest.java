package packbin;

import java.math.BigInteger;
import java.util.List;
import java.util.Map;
import java.util.function.Supplier;

/**
 * Loop 21 parity rows, pinned from _docs/03_implementation/reference_loop21_slots.md section 5:
 * U4 (AZ-2384) rows 40 to 43, a split-bit times with its count after the flag byte and the body absent packs a clear
 * bit; U6 (AZ-2386) rows 44 to 52, a count above 0 that no field wrote behind a clear when is refused in a split bit
 * and in combined flags; U7 (AZ-2387) rows 53 to 56, bits, packed and sized counts behind a clear when.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class ClearBitProbesTest {
    private ClearBitProbesTest() {}

    private static final String AFTER_BYTE = "pt: its flag bit was decided before the value its condition or count"
            + " reads was written";
    private static final String CLEAR_WHEN = "the count c is %s in the row, but no field wrote it (the when that holds it"
            + " is clear), so its times reads no round; give the count 0, leave it out, or make the when hold";

    static void run() {
        u4SplitTimesCountAfterTheByte();
        u6CountBehindAClearWhen();
        u6TheWhenHolds();
        u7CountKinds();
        u7NoValueIsAClearBit();
    }

    /** Rows 40 to 43. */
    private static void u4SplitTimesCountAfterTheByte() {
        // Arrange
        Field fb = Packbin.flagByte();
        Scheme<Map> scheme = Maps.scheme(1, fb, u8(0, "n"), fb.bit(Packbin.times(1, 0, u8(1, "pt"))),
                fb.bit(Packbin.u16(2, Access.get("heading"), Access.set("heading"))));
        // Act and Assert
        expectPacks("AC-1 row 40 body absent", scheme, Maps.map("n", 2, "heading", 90), "0102025a00");
        expectPacks("AC-1 row 41 body []", scheme, Maps.map("n", 2, "pt", List.of(), "heading", 90), "0102025a00");
        expectPacks("AC-1 row 42 count 0", scheme, Maps.map("n", 0, "heading", 90), "0102005a00");
        expectRefused("AC-2 row 43 body present", scheme, Maps.map("n", 2, "pt", List.of(5, 6), "heading", 90), AFTER_BYTE);
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(PackbinTest.parseHex("0102025a00"), scheme.on(row -> got[0] = row));
        PackbinTest.expectTrue("AC-1 row 40 the packet unpacks without a body (" + err + ")",
                err == null && Integer.valueOf(2).equals(got[0].get("n")) && !got[0].containsKey("pt"));
    }

    /** Rows 44 to 52. */
    private static void u6CountBehindAClearWhen() {
        // Arrange
        Field fb = Packbin.flagByte();
        Scheme<Map> split = Maps.scheme(1, mode(), c(), fb, fb.bit(Packbin.times(2, 1, u8(2, "pt"))), heading(3, fb));
        Scheme<Map> combined = Maps.scheme(1, mode(), c(),
                Packbin.flags(2, Packbin.times(2, 1, u8(2, "pt")), Packbin.u16(3, Access.get("heading"), Access.set("heading"))));
        Scheme<Map> plain = Maps.scheme(1, mode(), c(), Packbin.times(2, 1, u8(2, "pt")),
                Packbin.u16(3, Access.get("heading"), Access.set("heading")));
        // Act and Assert
        expectRefused("AC-1 row 44 split bit, no body", split, Maps.map("mode", 0, "c", 1, "heading", 90), "pt: " + clear("1"));
        expectRefused("AC-1 row 45 split bit, body []", split,
                Maps.map("mode", 0, "c", 1, "pt", List.of(), "heading", 90), "pt: " + clear("1"));
        expectRefused("AC-1 row 46 a long count", split, Maps.map("mode", 0, "c", 3L, "heading", 90), "pt: " + clear("3"));
        expectRefused("AC-1 row 46 a big count", split,
                Maps.map("mode", 0, "c", BigInteger.valueOf(3), "heading", 90), "pt: " + clear("3"));
        expectPacks("AC-2 row 47 count 0", split, Maps.map("mode", 0, "c", 0, "heading", 90), "0100025a00");
        expectPacks("AC-2 row 48 count left out", split, Maps.map("mode", 0, "heading", 90), "0100025a00");
        expectRefused("row 49 a body given: the older message comes first", split,
                Maps.map("mode", 0, "c", 2, "pt", List.of(5, 6), "heading", 90),
                "pt: values given, but the count of its times was never written");
        expectRefused("AC-1 row 50 combined flags", combined, Maps.map("mode", 0, "c", 2, "heading", 90), "pt: " + clear("2"));
        expectPacks("AC-2 row 50 combined flags, count 0", combined, Maps.map("mode", 0, "c", 0, "heading", 90), "0100025a00");
        expectPacks("AC-2 row 50 combined flags, count left out", combined, Maps.map("mode", 0, "heading", 90), "0100025a00");
        expectIllegalState("row 52 a plain times, count 1", plain, Maps.map("mode", 0, "c", 1, "heading", 90),
                "times: count 1 is missing");
        expectIllegalState("row 52 a plain times, count 0", plain, Maps.map("mode", 0, "c", 0, "heading", 90),
                "times: count 1 is missing");
    }

    /** Row 51: the when holds, so the count is written and the packet is as before. */
    private static void u6TheWhenHolds() {
        // Arrange
        Field fb = Packbin.flagByte();
        Scheme<Map> split = Maps.scheme(1, mode(), c(), fb, fb.bit(Packbin.times(2, 1, u8(2, "pt"))), heading(3, fb));
        // Act and Assert
        expectPacks("AC-2 row 51 a holding when", split, Maps.map("mode", 1, "c", 1, "pt", List.of(5), "heading", 90),
                "01010103055a00");
        expectPacks("AC-2 a holding when, count 0", split, Maps.map("mode", 1, "c", 0, "heading", 90), "010100025a00");
    }

    /** Rows 53 to 55: bits, packed and sized with their count behind a clear when are refused in nine positions. */
    private static void u7CountKinds() {
        // Arrange
        Map<String, Supplier<Field>> kinds = Map.of(
                "bits", () -> Packbin.bits(2, Access.get("v"), Access.set("v"), 1),
                "packed", () -> Packbin.packed(1, 2, Access.get("v"), Access.set("v"), 1, 0),
                "sized", () -> Packbin.sized(2, Access.get("v"), Access.set("v"), 1));
        for (Map.Entry<String, Supplier<Field>> kind : kinds.entrySet()) {
            boolean sized = kind.getKey().equals("sized");
            Object clearRow = sized ? new byte[] {1, 2, 3} : List.of(1, 0, 1);
            Map<String, Object> clear = Maps.map("mode", 0, "c", 3, "v", clearRow);
            Map<String, Object> holds = Maps.map("mode", 1, "c", 3, "v", clearRow);
            // Act and Assert
            for (String position : List.of("plain", "split bit", "combined flags")) {
                Scheme<Map> scheme = at(position, kind.getValue());
                expectRefusedAnyway("AC-1 row 53 " + kind.getKey() + " " + position + ", when clear", scheme, clear);
            }
            expectPacks("AC-2 row 54/55 " + kind.getKey() + " plain, when set", at("plain", kind.getValue()), holds,
                    sized ? "010103010203" : "01010305");
            expectPacks("AC-2 row 54/55 " + kind.getKey() + " split bit, when set", at("split bit", kind.getValue()), holds,
                    sized ? "01010301010203" : "0101030105");
        }
    }

    /** Row 56: no value given, so the bit is clear and nothing is dropped: a packet, not an error (the reference). */
    private static void u7NoValueIsAClearBit() {
        // Arrange
        Map<String, Supplier<Field>> kinds = Map.of(
                "bits", () -> Packbin.bits(2, Access.get("v"), Access.set("v"), 1),
                "packed", () -> Packbin.packed(2, 2, Access.get("v"), Access.set("v"), 1, 0),
                "sized", () -> Packbin.sized(2, Access.get("v"), Access.set("v"), 1));
        for (Map.Entry<String, Supplier<Field>> kind : kinds.entrySet()) {
            // Act and Assert
            for (String position : List.of("split bit", "combined flags")) {
                expectPacks("row 56 " + kind.getKey() + " " + position + ", no value", at(position, kind.getValue()),
                        Maps.map("mode", 0, "c", 3), "010000");
            }
        }
    }

    private static Scheme<Map> at(String position, Supplier<Field> member) {
        if (position.equals("plain")) {
            return Maps.scheme(1, mode(), c(), member.get());
        }
        if (position.equals("split bit")) {
            Field fb = Packbin.flagByte();
            return Maps.scheme(1, mode(), c(), fb, fb.bit(member.get()));
        }
        return Maps.scheme(1, mode(), c(), Packbin.flags(2, member.get()));
    }

    private static String clear(String count) {
        return String.format(CLEAR_WHEN, count);
    }

    private static Field mode() {
        return u8(0, "mode");
    }

    private static Field c() {
        return Packbin.when(1, Packbin.eq(0, 1), u8(1, "c"));
    }

    private static Field heading(int id, Field fb) {
        return fb.bit(Packbin.u16(id, Access.get("heading"), Access.set("heading")));
    }

    private static Field u8(int id, String name) {
        return Packbin.u8(id, Access.get(name), Access.set(name));
    }

    private static void expectPacks(String label, Scheme<Map> scheme, Map<String, Object> row, String hex) {
        try {
            PackbinTest.expectEq(label, hex, PackbinTest.toHex(BinaryPacker.pack(scheme, row)));
        } catch (RuntimeException ex) {
            PackbinTest.fail(label + ": pack threw " + ex);
        }
    }

    private static void expectRefused(String label, Scheme<Map> scheme, Map<String, Object> row, String message) {
        byte[][] wrote = {null};
        PackbinTest.expectThrows(label, () -> wrote[0] = BinaryPacker.pack(scheme, row), message);
        PackbinTest.expectTrue(label + ": no bytes", wrote[0] == null);
    }

    private static void expectIllegalState(String label, Scheme<Map> scheme, Map<String, Object> row, String message) {
        try {
            BinaryPacker.pack(scheme, row);
            PackbinTest.fail(label + ": packed");
        } catch (IllegalStateException ex) {
            PackbinTest.expectEq(label, message, ex.getMessage());
        } catch (RuntimeException ex) {
            PackbinTest.fail(label + ": threw " + ex);
        }
    }

    /** Refused with any error that names the member (Java reports a count no field wrote as an IllegalStateException). */
    private static void expectRefusedAnyway(String label, Scheme<Map> scheme, Map<String, Object> row) {
        try {
            BinaryPacker.pack(scheme, row);
            PackbinTest.fail(label + ": packed");
        } catch (IllegalStateException | IllegalArgumentException ex) {
            PackbinTest.expectEq(label, true, ex.getMessage() != null && ex.getMessage().contains("count 1 is missing"));
        }
    }
}
