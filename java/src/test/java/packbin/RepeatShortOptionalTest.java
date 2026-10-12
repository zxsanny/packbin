package packbin;

import java.util.Arrays;
import java.util.List;
import java.util.Map;

/**
 * AZ-2383 (U3, loop 21): in a repeat, a non-empty list under a member that a flag bit can leave absent, shorter than
 * the rounds, is refused before any round (rows 27 to 39 of _docs/03_implementation/reference_loop21_slots.md).
 * A times keeps reading a short list under flags as absent for the rounds it does not reach (row 39). The message is
 * the TypeScript one with null for undefined.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class RepeatShortOptionalTest {
    private RepeatShortOptionalTest() {}

    static void run() {
        shortListsAreRefused();
        fullListsPackAsBefore();
        otherOptionalPositions();
        notOptionalPositionsAreUnchanged();
    }

    private static String short_(String name, int items, int rounds) {
        return name + ": " + items + " items, repeat count " + rounds
                + "; give one entry per round, null where the member is absent";
    }

    /** Rows 27, 28 and 37: the first short list in round order is named. */
    private static void shortListsAreRefused() {
        // Arrange
        Scheme<Map> scheme = Maps.scheme(1, Packbin.repeat(0, u8(0, "w"), Packbin.flags(1, u8(1, "v"))));
        Scheme<Map> twoOptional = Maps.scheme(1, Packbin.repeat(0, Packbin.flags(0, u8(0, "a"), u8(1, "b"))));
        // Act and Assert
        refused("AC-1 row 27 one item for two rounds", scheme, Maps.map("w", List.of(1, 2), "v", List.of(5)), short_("v", 1, 2));
        refused("AC-1 row 28 two items for three rounds", scheme,
                Maps.map("w", List.of(1, 2, 3), "v", Arrays.asList(5, null)), short_("v", 2, 3));
        refused("AC-1 row 37 a first", twoOptional, Maps.map("a", List.of(1), "b", List.of(5, 6)), short_("a", 1, 2));
        refused("AC-1 row 37 b second", twoOptional,
                Maps.map("a", List.of(1, 2, 3), "b", List.of(5, 6)), short_("b", 2, 3));
    }

    /** Rows 29 and 30: a full list with null entries, no list, an empty list and a lone value pack as before. */
    private static void fullListsPackAsBefore() {
        // Arrange
        Scheme<Map> scheme = Maps.scheme(1, Packbin.repeat(0, u8(0, "w"), Packbin.flags(1, u8(1, "v"))));
        // Act and Assert
        packs("AC-2 row 29 [5, null]", scheme, Maps.map("w", List.of(1, 2), "v", Arrays.asList(5, null)), "010101050200");
        packs("AC-2 row 30 [5, 6]", scheme, Maps.map("w", List.of(1, 2), "v", List.of(5, 6)), "01010105020106");
        packs("AC-2 row 30 no list", scheme, Maps.map("w", List.of(1, 2)), "0101000200");
        packs("AC-2 row 30 empty list", scheme, Maps.map("w", List.of(1, 2), "v", List.of()), "0101000200");
        packs("AC-2 row 30 a lone value", scheme, Maps.map("w", List.of(1, 2), "v", 5), "01010105020105");
        PackbinTest.expectTrue("row 31 a short required member is still refused",
                refusal(scheme, Maps.map("w", List.of(1), "v", List.of(5, 6))) != null);
    }

    /** Rows 32 to 36 and the kinds Java adds: bool, split bits, group, u2, when, nested row, list, dict. */
    private static void otherOptionalPositions() {
        // Arrange
        Scheme<Map> bool = Maps.scheme(1, Packbin.repeat(0, u8(0, "w"), Packbin.flags(1, bool(1, "on"))));
        Field fb = Packbin.flagByte();
        Scheme<Map> split = Maps.scheme(1, Packbin.repeat(0, u8(0, "w"), fb, fb.bit(u8(1, "v"))));
        Scheme<Map> group = Maps.scheme(1, Packbin.repeat(0, u8(0, "w"), Packbin.flags(1, Packbin.group(1, u8(1, "v")))));
        Scheme<Map> u2 = Maps.scheme(1, Packbin.repeat(0, u8(0, "w"), Packbin.flags(1, Packbin.u2(slot(1, "p"), slot(2, "q")))));
        Scheme<Map> when = Maps.scheme(1, Packbin.repeat(0, u8(0, "w"),
                Packbin.flags(1, Packbin.when(1, Packbin.eq(0, 1), u8(1, "v")))));
        Scheme<Map> nested = Maps.scheme(1, Packbin.repeat(0, u8(0, "w"),
                Packbin.flags(1, Packbin.group(Access.get("g"), Access.set("g"), u8(0, "b")))));
        Scheme<Map> list = Maps.scheme(1, Packbin.repeat(0, u8(0, "w"), Packbin.flags(1,
                Packbin.list(Access.get("xs"), Access.set("xs"), Packbin.u8(0, Access.identity(), Access.ignore())))));
        // Act and Assert
        refused("AC-1 row 32 bool", bool, Maps.map("w", List.of(1, 2), "on", List.of(true)), short_("on", 1, 2));
        packs("AC-2 row 32 bool, full", bool, Maps.map("w", List.of(1, 2), "on", Arrays.asList(true, null)), "0101010200");
        refused("AC-1 row 33 split bit", split, Maps.map("w", List.of(1, 2), "v", List.of(5)), short_("v", 1, 2));
        packs("AC-2 row 33 split bit, full", split, Maps.map("w", List.of(1, 2), "v", Arrays.asList(5, null)), "010101050200");
        refused("AC-1 row 34 group member", group, Maps.map("w", List.of(1, 2), "v", List.of(5)), short_("v", 1, 2));
        refused("AC-1 row 35 u2 slot p", u2, Maps.map("w", List.of(1, 2), "p", List.of(1), "q", List.of(2, 3)), short_("p", 1, 2));
        refused("AC-1 row 36 under a when in flags", when, Maps.map("w", List.of(1, 1), "v", List.of(5)), short_("v", 1, 2));
        refused("AC-1 a nested row", nested, Maps.map("w", List.of(1, 2), "g", List.of(Maps.map("b", 1))), short_("g", 1, 2));
        packs("AC-2 a nested row, full", nested,
                Maps.map("w", List.of(1, 2), "g", Arrays.asList(Maps.map("b", 1), null)), "010101010200");
        refused("AC-1 a list", list, Maps.map("w", List.of(1, 2), "xs", List.of(List.of(1))), short_("xs", 1, 2));
    }

    /** Rows 38 and 39: a when outside flags, and a times, keep accepting the short list. */
    private static void notOptionalPositionsAreUnchanged() {
        // Arrange
        Scheme<Map> when = Maps.scheme(1, Packbin.repeat(0, u8(0, "k"), Packbin.when(1, Packbin.eq(0, 1), u8(1, "v"))));
        Scheme<Map> times = Maps.scheme(1, u8(0, "c"), Packbin.times(1, 0, Packbin.flags(1, u8(1, "v"))));
        // Act and Assert
        packs("AC-2 row 38 a when outside flags", when, Maps.map("k", List.of(1, 2), "v", List.of(9)), "01010902");
        packs("AC-2 row 39 times keeps the short list", times, Maps.map("c", 2, "v", List.of(5)), "0102010500");
    }

    private static void refused(String label, Scheme<Map> scheme, Map<String, Object> row, String message) {
        byte[][] wrote = {null};
        PackbinTest.expectThrows(label, () -> wrote[0] = BinaryPacker.pack(scheme, row), message);
        PackbinTest.expectTrue(label + ": no bytes", wrote[0] == null);
    }

    private static String refusal(Scheme<Map> scheme, Map<String, Object> row) {
        try {
            BinaryPacker.pack(scheme, row);
        } catch (RuntimeException ex) {
            return ex.getMessage();
        }
        return null;
    }

    private static void packs(String label, Scheme<Map> scheme, Map<String, Object> row, String hex) {
        try {
            PackbinTest.expectEq(label, hex, PackbinTest.toHex(BinaryPacker.pack(scheme, row)));
        } catch (RuntimeException ex) {
            PackbinTest.fail(label + ": pack threw " + ex);
        }
    }

    private static Field u8(int id, String name) {
        return Packbin.u8(id, Access.get(name), Access.set(name));
    }

    private static Field bool(int id, String name) {
        return Packbin.boolField(id, Access.get(name), Access.set(name));
    }

    private static Field slot(int id, String name) {
        return Packbin.u2Slot(id, Access.get(name), Access.set(name));
    }
}
