package packbin;

import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Map;
import java.util.function.Supplier;

/**
 * AZ-2390 (F33, loop 21): a repeat or times whose body holds no member is refused when the scheme is built, so no
 * round charges 0 slots and writes 0 bytes. Rows 15 to 26 of _docs/03_implementation/reference_loop21_slots.md.
 * A member is any field but a container (when, anchored group) that holds none; a zero-width bytes, a flag byte and
 * a flags without members are members. Rows 17 and 18 (a body of only empty whens) cannot be written in Java: a
 * when must test a field of its own round, and that field is a member (pinned below).
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class EmptyRoundBodyTest {
    private EmptyRoundBodyTest() {}

    private static final String REST = ": the body holds no member; a round of it would charge no slot and write nothing";

    static void run() {
        bothFormsAreRefused();
        containersWithoutMembersAreEmpty();
        everywhereTheRoundStands();
        theF33RequestFailsAtBuild();
        zeroWidthMembersStillBuild();
        nonEmptyBodiesAreUnchanged();
    }

    /** AC-1, rows 15 and 16. */
    private static void bothFormsAreRefused() {
        // Arrange and Act and Assert
        refusedAtBuild("AC-1 row 15 repeat(0) {}", "repeat 0" + REST, () -> Maps.scheme(1, Packbin.repeat(0)));
        refusedAtBuild("AC-1 row 16 u8 n, times(1, 0) {}", "times 1" + REST,
                () -> Maps.scheme(1, u8(0, "n"), Packbin.times(1, 0)));
    }

    /** Rows 17 to 19: an empty when is no member; an empty anchored group is refused first, as before. */
    private static void containersWithoutMembersAreEmpty() {
        // Arrange and Act and Assert
        refusedAtBuild("row 17 a when with no member cannot test a field outside its round",
                "when 1 tests field 0, which is not an earlier integer or bool field in its scope",
                () -> Maps.scheme(1, u8(0, "m"), Packbin.repeat(1, Packbin.when(1, Packbin.eq(0, 1)))));
        refusedAtBuild("row 19 repeat(0) { group(0) {} }",
                "empty group 0 has no fields and no accessor, so its bit can never be set",
                () -> Maps.scheme(1, Packbin.repeat(0, Packbin.group(0))));
    }

    /** Row 25: the same text wherever the round stands (the anchor in the text is the round's own). */
    private static void everywhereTheRoundStands() {
        // Arrange
        Field fb = Packbin.flagByte();
        // Act and Assert
        refusedAtBuild("row 25 under flags", "repeat 0" + REST,
                () -> Maps.scheme(1, Packbin.flags(0, Packbin.repeat(0))));
        refusedAtBuild("row 25 as a flag bit", "repeat 0" + REST,
                () -> Maps.scheme(1, fb, fb.bit(Packbin.repeat(0))));
        refusedAtBuild("row 25 under a when", "repeat 1" + REST,
                () -> Maps.scheme(1, u8(0, "m"), Packbin.when(1, Packbin.eq(0, 1), Packbin.repeat(1))));
        refusedAtBuild("row 25 in a group", "repeat 0" + REST,
                () -> Maps.scheme(1, Packbin.group(0, Packbin.repeat(0))));
        refusedAtBuild("row 25 as a list item", "repeat 0" + REST,
                () -> Maps.scheme(1, Packbin.list(Access.get("xs"), Access.set("xs"), Packbin.group(0, Packbin.repeat(0)))));
        refusedAtBuild("row 25 as a dict item", "times 1" + REST,
                () -> Maps.scheme(1, Packbin.dict(Access.get("d"), Access.set("d"),
                        Packbin.group(0, u8(0, "n"), Packbin.times(1, 0)))));
        refusedAtBuild("row 25 in a nested row", "times 1" + REST,
                () -> Maps.scheme(1, Packbin.group(Access.get("g"), Access.set("g"), u8(0, "n"), Packbin.times(1, 0))));
    }

    /** AC-2, row 20: a list of groups holding times(65535) {} fails at build, before any packet is attempted. */
    private static void theF33RequestFailsAtBuild() {
        // Arrange
        Timing.Limit limit = Timing.bound(1.0);
        long start = System.nanoTime();
        // Act
        String message = refusal(() -> Maps.scheme(1, Packbin.list(Access.get("items"), Access.set("items"),
                Packbin.group(0, Packbin.u32(0, Access.get("n"), Access.set("n")), Packbin.times(1, 0)))));
        long ms = (System.nanoTime() - start) / 1_000_000;
        // Assert
        PackbinTest.expectEq("AC-2 row 20 the F33 shape is refused at build", "times 1" + REST, message);
        limit.expectWithin("AC-2 row 20 refused at build", ms / 1000.0);
    }

    /** Rows 21 to 23 and 26: a member that charges a slot or writes a byte is enough; the budgets bound it. */
    private static void zeroWidthMembersStillBuild() {
        // Arrange
        Field fb = Packbin.flagByte();
        Scheme<Map> zeroWidth = Maps.scheme(1, u8(0, "n"),
                Packbin.times(1, 0, Packbin.bytes(1, Access.get("v"), Access.set("v"), 0)))
                .withLimits(Scheme.DEFAULT_MAX_ROUNDS, 5);
        List<byte[]> ten = Collections.nCopies(10, new byte[0]);
        // Act and Assert
        PackbinTest.expectEq("AC-3 row 21 a zero-width bytes member: pack is bounded by slots",
                "v: the rounds would hold 6 slots, above the limit of 5 slots",
                refusal(() -> BinaryPacker.pack(zeroWidth, Maps.map("n", 10, "v", ten))));
        PackbinTest.expectEq("row 21 five empty buffers pack at maxSlots 5", "0105",
                hexOf(zeroWidth, Maps.map("n", 5, "v", ten.subList(0, 5))));
        PackbinTest.expectEq("row 22 a flag byte is a member", "01", hexOf(Maps.scheme(1, Packbin.repeat(0, fb)), Maps.map()));
        PackbinTest.expectEq("row 23 a flags without members is a member", "01",
                hexOf(Maps.scheme(1, Packbin.repeat(0, Packbin.flags(0))), Maps.map()));
        PackbinTest.expectEq("row 26 a flags with an empty nested row writes its byte", "010100",
                hexOf(Maps.scheme(1, Packbin.repeat(0, Packbin.flags(0, Packbin.group(Access.get("g"), Access.set("g"))))),
                        Maps.map("g", Arrays.asList(Maps.map(), null))));
        PackbinTest.expectEq("a nested row is a member", "0101",
                hexOf(Maps.scheme(1, Packbin.repeat(0, Packbin.group(Access.get("g"), Access.set("g"), u8(0, "b")))),
                        Maps.map("g", List.of(Maps.map("b", 1)))));
        Scheme<Map> zeroRepeat = Maps.scheme(1, Packbin.repeat(0, Packbin.bytes(0, Access.get("v"), Access.set("v"), 0)));
        PackbinTest.expectEq("zero_progress_repeat shape: unpack still refuses a round that reads nothing",
                "TrailingBytes 1", unpackShape(zeroRepeat, "0100"));
    }

    /** AC-3, row 24: a body with a member builds and packs the same bytes. */
    private static void nonEmptyBodiesAreUnchanged() {
        // Arrange
        Scheme<Map> repeat = Maps.scheme(1, Packbin.repeat(0, u8(0, "k")));
        Scheme<Map> times = Maps.scheme(1, u8(0, "n"), Packbin.times(1, 0, u8(1, "k")));
        // Act and Assert
        PackbinTest.expectEq("AC-3 row 24 repeat", "010708", hexOf(repeat, Maps.map("k", List.of(7, 8))));
        PackbinTest.expectEq("AC-3 row 24 times", "01020708", hexOf(times, Maps.map("n", 2, "k", List.of(7, 8))));
    }

    private static void refusedAtBuild(String label, String message, Supplier<Scheme<Map>> build) {
        PackbinTest.expectEq(label, message, refusal(build::get));
    }

    private static String refusal(Runnable action) {
        try {
            action.run();
        } catch (IllegalArgumentException ex) {
            return ex.getMessage();
        }
        return "built";
    }

    private static String hexOf(Scheme<Map> scheme, Map row) {
        return PackbinTest.toHex(BinaryPacker.pack(scheme, row));
    }

    private static String unpackShape(Scheme<Map> scheme, String hex) {
        Object err = BinaryPacker.unpack(PackbinTest.parseHex(hex), scheme.on(row -> { }));
        return err instanceof Packbin.TrailingBytes t ? "TrailingBytes " + t.left : String.valueOf(err);
    }

    private static Field u8(int id, String name) {
        return Packbin.u8(id, Access.get(name), Access.set(name));
    }
}
