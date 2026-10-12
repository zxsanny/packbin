package packbin;

import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.function.LongFunction;

/**
 * AZ-2382 (loop 21): a round charges maxSlots by the TypeScript rule, pinned by rows 1 to 14 of
 * _docs/03_implementation/reference_loop21_slots.md. The width W of a round is the number of distinct names it can
 * hold; the rounds of one call share one counter; a round is all or nothing. Rows are built with Java's field ids and
 * accessors: an unanchored TypeScript group is a nested row here, and an empty group is an empty nested row (an
 * empty anchored group is refused at construction).
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class RoundSlotWidthTest {
    private RoundSlotWidthTest() {}

    private record Case(String name, LongFunction<Scheme<Map>> scheme, long width, String first, Map row2, String hex2,
            Map row3, String hex3, int left) {}

    static void run() {
        for (Case c : cases()) {
            atTheLimit(c);
            oneRoundOver(c);
            unpackAgrees(c);
        }
        timesAndOneCounter();
        duplicateNamesAreOneSlotInUnpackToo();
    }

    private static List<Case> cases() {
        Field fb = Packbin.flagByte();
        return List.of(
                new Case("1 empty group, flag byte",
                        limit -> repeat(limit, u8(0, "a"), Packbin.flags(1, Packbin.group(Access.get("g"), Access.set("g")))),
                        2, "a", row("a", List.of(1, 2), "g", Arrays.asList(Maps.map(), null)), "0101010200",
                        row("a", List.of(1, 2, 3), "g", Arrays.asList(Maps.map(), null, Maps.map())), "01010102000301", 2),
                new Case("2 duplicate leaf names",
                        limit -> repeat(limit, u8(0, "m"), Packbin.when(1, Packbin.eq(0, 1), u8(1, "k")),
                                Packbin.when(2, Packbin.eq(0, 2), u8(2, "k"))),
                        2, "m", row("m", List.of(1, 2), "k", List.of(7, 8)), "0101070208",
                        row("m", List.of(1, 2, 1), "k", List.of(7, 8, 9)), "01010702080109", 2),
                new Case("3 combined flags",
                        limit -> repeat(limit, Packbin.flags(0, bool(0, "on"), u8(1, "v"))),
                        2, "on", row("on", List.of(true, true), "v", List.of(5, 6)), "0103050306",
                        row("on", List.of(true, true, true), "v", List.of(5, 6, 7)), "01030503060307", 2),
                new Case("4 split bits and flag byte",
                        limit -> repeat(limit, fb, fb.bit(u8(0, "a")), fb.bit(u8(1, "b"))),
                        2, "a", row("a", List.of(1, 2), "b", List.of(4, 5)), "01030104030205",
                        row("a", List.of(1, 2, 3), "b", List.of(4, 5, 6)), "01030104030205030306", 3),
                new Case("5 when clear in every round",
                        limit -> repeat(limit, u8(0, "m"), Packbin.when(1, Packbin.eq(0, 1), u8(1, "k"))),
                        2, "m", row("m", List.of(0, 0)), "010000",
                        row("m", List.of(0, 0, 0)), "01000000", 1),
                new Case("6 nested anchored groups",
                        limit -> repeat(limit, u8(0, "a"), Packbin.group(1, u8(1, "b"), Packbin.group(2, u8(2, "c")))),
                        3, "a", row("a", List.of(1, 2), "b", List.of(4, 5), "c", List.of(7, 8)), "01010407020508",
                        row("a", List.of(1, 2, 3), "b", List.of(4, 5, 6), "c", List.of(7, 8, 9)), "01010407020508030609", 3),
                new Case("7 nested row",
                        limit -> repeat(limit, u8(0, "a"), Packbin.group(Access.get("g"), Access.set("g"), u8(0, "b"))),
                        2, "a", row("a", List.of(1, 2), "g", List.of(Maps.map("b", 4), Maps.map("b", 5))), "0101040205",
                        row("a", List.of(1, 2, 3), "g", List.of(Maps.map("b", 4), Maps.map("b", 5), Maps.map("b", 6))),
                        "01010402050306", 2),
                new Case("8 u2 slots",
                        limit -> repeat(limit, u8(0, "a"), Packbin.u2(slot(1, "p"), slot(2, "q"), slot(3, "r"))),
                        4, "a", row("a", List.of(1, 2), "p", List.of(1, 1), "q", List.of(2, 2), "r", List.of(3, 3)),
                        "0101390239",
                        row("a", List.of(1, 2, 3), "p", List.of(1, 1, 1), "q", List.of(2, 2, 2), "r", List.of(3, 3, 3)),
                        "01013902390339", 2),
                new Case("9 list and dict names",
                        limit -> repeat(limit, u8(0, "n"), Packbin.list(Access.get("l"), Access.set("l"), element()),
                                Packbin.dict(Access.get("d"), Access.set("d"), element())),
                        3, "n", row("n", List.of(1, 2), "l", List.of(List.of(0, 1), List.of(1, 2)),
                                "d", List.of(Maps.map("k", 0), Maps.map("k", 1))),
                        "010102000001010001006b000202000102010001006b01",
                        row("n", List.of(1, 2, 3), "l", List.of(List.of(0, 1), List.of(1, 2), List.of(2, 3)),
                                "d", List.of(Maps.map("k", 0), Maps.map("k", 1), Maps.map("k", 2))),
                        "010102000001010001006b000202000102010001006b010302000203010001006b02", 11),
                new Case("10 bytes and sized names",
                        limit -> repeat(limit, u8(0, "n"), Packbin.bytes(1, Access.get("b"), Access.set("b"), 2),
                                Packbin.sized(2, Access.get("s"), Access.set("s"), 0)),
                        3, "n", row("n", List.of(1, 1), "b", List.of(new byte[] {0, 0}, new byte[] {1, 1}),
                                "s", List.of(new byte[] {9}, new byte[] {9})),
                        "010100000901010109",
                        row("n", List.of(1, 1, 1), "b", List.of(new byte[] {0, 0}, new byte[] {1, 1}, new byte[] {2, 2}),
                                "s", List.of(new byte[] {9}, new byte[] {9}, new byte[] {9})),
                        "01010000090101010901020209", 4));
    }

    private static void atTheLimit(Case c) {
        // Arrange
        Scheme<Map> atLimit = c.scheme.apply(2 * c.width);
        // Act
        String hex = packHex(c.name, atLimit, c.row2);
        // Assert
        PackbinTest.expectEq("AC-1 row " + c.name + " packs two rounds at maxSlots " + 2 * c.width, c.hex2, hex);
    }

    private static void oneRoundOver(Case c) {
        // Arrange
        Scheme<Map> atLimit = c.scheme.apply(2 * c.width);
        Scheme<Map> roomy = c.scheme.apply(3 * c.width);
        String message = c.first + ": the rounds would hold " + 3 * c.width + " slots, above the limit of "
                + 2 * c.width + " slots";
        // Act
        String refusal = refusal(atLimit, c.row3);
        // Assert
        PackbinTest.expectEq("AC-1 row " + c.name + " the third round is refused", message, refusal);
        PackbinTest.expectEq("AC-1 row " + c.name + " three rounds pack at maxSlots " + 3 * c.width, c.hex3,
                packHex(c.name, roomy, c.row3));
    }

    /** AC-2: the packet pack writes at maxSlots unpacks, repacks to the same bytes, and unpack refuses where pack did. */
    private static void unpackAgrees(Case c) {
        // Arrange
        Scheme<Map> atLimit = c.scheme.apply(2 * c.width);
        Map[] got = new Map[1];
        // Act
        Object ok = BinaryPacker.unpack(PackbinTest.parseHex(c.hex2), atLimit.on(row -> got[0] = row));
        Object over = BinaryPacker.unpack(PackbinTest.parseHex(c.hex3), atLimit.on(row -> { }));
        // Assert
        PackbinTest.expectTrue("AC-2 row " + c.name + " the packet at the limit unpacks (" + ok + ")",
                ok == null && got[0] != null);
        PackbinTest.expectEq("AC-2 row " + c.name + " repacks to the same bytes", c.hex2, packHex(c.name, atLimit, got[0]));
        PackbinTest.expectEq("AC-2 row " + c.name + " the third round is refused by unpack too",
                "ShortPacket 0 0 " + c.left, over instanceof Packbin.ShortPacket s ? "ShortPacket " + s.field + " "
                        + s.needed + " " + s.left : String.valueOf(over));
    }

    /** Rows 11 to 14: one counter per call, shared by every times and repeat of it. */
    private static void timesAndOneCounter() {
        // Arrange
        LongFunction<Scheme<Map>> timesWhen = limit -> Maps.scheme(1, u8(0, "n"), Packbin.times(1, 0, u8(1, "m"),
                Packbin.when(2, Packbin.eq(1, 1), u8(2, "k")), Packbin.when(3, Packbin.eq(1, 2), u8(3, "k"))))
                .withLimits(Scheme.DEFAULT_MAX_ROUNDS, limit);
        LongFunction<Scheme<Map>> timesThenRepeat = limit -> Maps.scheme(1, u8(0, "n"),
                Packbin.times(1, 0, u8(1, "a")), Packbin.repeat(2, u8(2, "b")))
                .withLimits(Scheme.DEFAULT_MAX_ROUNDS, limit);
        // Act and Assert
        PackbinTest.expectEq("row 11 two rounds of width 2 at maxSlots 4", "010201070208",
                packHex("11", timesWhen.apply(4), row("n", 2, "m", List.of(1, 2), "k", List.of(7, 8))));
        PackbinTest.expectEq("row 12 a third round", "m: the rounds would hold 6 slots, above the limit of 4 slots",
                refusal(timesWhen.apply(4), row("n", 3, "m", List.of(1, 2, 1), "k", List.of(7, 8, 9))));
        PackbinTest.expectEq("row 13 times and repeat share three slots", "0101010203",
                packHex("13", timesThenRepeat.apply(3), row("n", 1, "a", List.of(1), "b", List.of(2, 3))));
        PackbinTest.expectEq("row 14 the fourth slot", "b: the rounds would hold 4 slots, above the limit of 3 slots",
                refusal(timesThenRepeat.apply(3), row("n", 1, "a", List.of(1), "b", List.of(2, 3, 4))));
    }

    /** Unpack charges a name once however many fields write it (row 2 at the packet level). */
    private static void duplicateNamesAreOneSlotInUnpackToo() {
        // Arrange
        Scheme<Map> scheme = repeat(4, u8(0, "m"), Packbin.when(1, Packbin.eq(0, 1), u8(1, "k")),
                Packbin.when(2, Packbin.eq(0, 2), u8(2, "k")));
        Map[] got = new Map[1];
        // Act
        Object ok = BinaryPacker.unpack(PackbinTest.parseHex("0101070208"), scheme.on(row -> got[0] = row));
        // Assert
        PackbinTest.expectTrue("AC-2 two rounds of m and k fit maxSlots 4 (" + ok + ")", ok == null);
        PackbinTest.expectEq("AC-2 m", List.of(1, 2), got[0].get("m"));
    }

    private static Scheme<Map> repeat(long maxSlots, Field... body) {
        return Maps.scheme(1, Packbin.repeat(0, body)).withLimits(Scheme.DEFAULT_MAX_ROUNDS, maxSlots);
    }

    private static Field element() {
        return Packbin.u8(0, Access.identity(), Access.ignore());
    }

    private static Map<String, Object> row(Object... kv) {
        return Maps.map(kv);
    }

    private static String packHex(String label, Scheme<Map> scheme, Map row) {
        try {
            return PackbinTest.toHex(BinaryPacker.pack(scheme, row));
        } catch (RuntimeException ex) {
            return "threw " + ex;
        }
    }

    private static String refusal(Scheme<Map> scheme, Map row) {
        try {
            BinaryPacker.pack(scheme, row);
        } catch (IllegalArgumentException ex) {
            return ex.getMessage();
        }
        return "packed";
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
