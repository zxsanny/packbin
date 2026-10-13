package packbin;

import java.util.List;
import java.util.Map;
import java.util.function.BiFunction;
import java.util.function.Function;

/**
 * Loop 23 G3 (AZ-2436): the U11 refusal (AZ-2410, {@code reference_loop22.md} row 56) pinned below the top level of
 * a scheme. The row 56 body is {@code u8 mode; when mode == 1 { u8 c }; <bit> { member(count c) }}, with the bit a
 * split flag byte bit or a combined {@code flags}, and the member a {@code bits}, {@code packed} or {@code sized}.
 * Positions: the body inside an anchored group and inside a nested row group, a bit that holds an anchored group
 * holding the member, the body inside an outer holding {@code when}, a bit that holds a holding {@code when} around
 * the member, the body as a {@code times} round and as a {@code repeat} round. Each refuses as at the top level, with
 * the text of TypeScript's {@code loop23-novalue-nested.test.ts}; count 0, the count left out and a holding inner
 * {@code when} (with and without a value) pack with the TypeScript hexes (as at b8b2809).
 *
 * <p>Not spellable in Java: TypeScript's named anchored group ({@code group(2, x => x.g, [member])}) whose member
 * takes its count from the row around it. Java's anchored group has no name (its fields are members of the row
 * around it), and a nested row group ({@code group(get, set, ...)}) numbers its ids from 0 and sees no id of the row
 * around it, so a member in it cannot count by {@code c}: construction refuses that (pinned below as observed).
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class NoValueCountNestedTest {
    private NoValueCountNestedTest() {}

    private static final String NOT_WRITTEN = "v: the count c is 3 in the row, but no field wrote it (the when that"
            + " holds it is clear), so the member reads nothing; give the count 0, leave it out, or make the when hold";
    private static final List<String> KINDS = List.of("bits", "packed", "sized");
    private static final List<String> BITS = List.of("split", "flags");

    /** A position of the row 56 body: its layout, the rows it refuses, and four unchanged rows with their wires. */
    private record Position(String name, String ac, BiFunction<String, String, Scheme<Map>> layout,
            List<Map<String, Object>> refused, Function<String, List<Map<String, Object>>> unchanged,
            Function<String, List<String>> wires) {}

    static void run() {
        for (Position position : positions()) {
            for (String kind : KINDS) {
                refusedNamingMemberAndCount(position, kind);
                unchangedPacksAsAtHead(position, kind);
            }
        }
        nestedRowCannotCountByTheRowAround();
        memberInsideTheClearWhenIsASilentSkip();
    }

    private static List<Position> positions() {
        return List.of(
                new Position("the row 56 body inside an anchored group", "AC-1",
                        (kind, bit) -> Maps.scheme(1, Packbin.group(0, body(kind, bit, 0))),
                        List.of(Maps.map("mode", 0, "c", 3)),
                        kind -> List.of(Maps.map("mode", 0, "c", 0), Maps.map("mode", 0), Maps.map("mode", 1, "c", 3),
                                Maps.map("mode", 1, "c", 3, "v", value(kind))),
                        kind -> List.of("010000", "010000", "01010300", "01010301" + setHex(kind))),
                new Position("the row 56 body inside a nested row group", "AC-1",
                        (kind, bit) -> Maps.scheme(1, Packbin.group(Access.get("g"), Access.set("g"), body(kind, bit, 0))),
                        List.of(Maps.map("g", Maps.map("mode", 0, "c", 3))),
                        kind -> List.of(Maps.map("g", Maps.map("mode", 0, "c", 0)), Maps.map("g", Maps.map("mode", 0)),
                                Maps.map("g", Maps.map("mode", 1, "c", 3)),
                                Maps.map("g", Maps.map("mode", 1, "c", 3, "v", value(kind)))),
                        kind -> List.of("010000", "010000", "01010300", "01010301" + setHex(kind))),
                new Position("a bit that holds an anchored group holding the member", "AC-1",
                        (kind, bit) -> Maps.scheme(1, with(new Field[] {u8(0, "mode"), whenSet(1, 0, u8(1, "c"))},
                                behind(bit, 2, Packbin.group(2, member(kind, 2, 1))))),
                        List.of(Maps.map("mode", 0, "c", 3)),
                        kind -> List.of(Maps.map("mode", 0, "c", 0), Maps.map("mode", 0), Maps.map("mode", 1, "c", 3),
                                Maps.map("mode", 1, "c", 3, "v", value(kind))),
                        kind -> List.of("010000", "010000", "01010300", "01010301" + setHex(kind))),
                new Position("the row 56 body inside an outer holding when", "AC-2",
                        (kind, bit) -> Maps.scheme(1, u8(0, "o"), whenSet(1, 0, body(kind, bit, 1))),
                        List.of(Maps.map("o", 1, "mode", 0, "c", 3)),
                        kind -> List.of(Maps.map("o", 1, "mode", 0, "c", 0), Maps.map("o", 1, "mode", 0),
                                Maps.map("o", 1, "mode", 1, "c", 3), Maps.map("o", 1, "mode", 1, "c", 3, "v", value(kind))),
                        kind -> List.of("01010000", "01010000", "0101010300", "0101010301" + setHex(kind))),
                new Position("a bit that holds a holding when around the member", "AC-2",
                        (kind, bit) -> Maps.scheme(1, with(new Field[] {u8(0, "o"), u8(1, "mode"), whenSet(2, 1, u8(2, "c"))},
                                behind(bit, 3, whenSet(3, 0, member(kind, 3, 2))))),
                        List.of(Maps.map("o", 1, "mode", 0, "c", 3)),
                        kind -> List.of(Maps.map("o", 1, "mode", 0, "c", 0), Maps.map("o", 1, "mode", 0),
                                Maps.map("o", 1, "mode", 1, "c", 3), Maps.map("o", 1, "mode", 1, "c", 3, "v", value(kind))),
                        kind -> List.of("01010000", "01010000", "0101010300", "0101010301" + setHex(kind))),
                new Position("a times round body", "AC-3",
                        (kind, bit) -> Maps.scheme(1, u8(0, "n"), Packbin.times(1, 0, body(kind, bit, 1))),
                        List.of(Maps.map("n", 1, "mode", List.of(0), "c", List.of(3)),
                                Maps.map("n", 2, "mode", List.of(1, 0), "c", List.of(0, 3))),
                        kind -> List.of(Maps.map("n", 2, "mode", List.of(1, 0), "c", List.of(0, 0)),
                                Maps.map("n", 1, "mode", List.of(0)), Maps.map("n", 1, "mode", List.of(1), "c", List.of(3)),
                                Maps.map("n", 1, "mode", List.of(1), "c", List.of(3), "v", List.of(value(kind)))),
                        kind -> List.of("01020100000000", "01010000", "0101010300", "0101010301" + setHex(kind))),
                new Position("a repeat round body", "AC-3",
                        (kind, bit) -> Maps.scheme(1, Packbin.repeat(0, body(kind, bit, 0))),
                        List.of(Maps.map("mode", List.of(0), "c", List.of(3)),
                                Maps.map("mode", List.of(1, 0), "c", List.of(0, 3))),
                        kind -> List.of(Maps.map("mode", List.of(1, 0), "c", List.of(0, 0)), Maps.map("mode", List.of(0)),
                                Maps.map("mode", List.of(1), "c", List.of(3)),
                                Maps.map("mode", List.of(1), "c", List.of(3), "v", List.of(value(kind)))),
                        kind -> List.of("010100000000", "010000", "01010300", "01010301" + setHex(kind))));
    }

    /** AC-1 to AC-3: count 3 and no value (in a round: in round 1 of one, or round 2 of two) is refused. */
    private static void refusedNamingMemberAndCount(Position position, String kind) {
        for (String bit : BITS) {
            // Arrange
            Scheme<Map> scheme = position.layout().apply(kind, bit);
            for (int i = 0; i < position.refused().size(); i++) {
                String label = "AZ-2436 " + position.ac() + " " + position.name() + ", " + kind + " " + bit
                        + ", refused row " + i;
                Map<String, Object> row = position.refused().get(i);
                // Act and Assert
                expectRefused(label, scheme, row, NOT_WRITTEN);
            }
        }
    }

    /** AC-4: count 0, the count left out, a holding inner when without and with a value pack as at HEAD. */
    private static void unchangedPacksAsAtHead(Position position, String kind) {
        for (String bit : BITS) {
            // Arrange
            Scheme<Map> scheme = position.layout().apply(kind, bit);
            List<Map<String, Object>> rows = position.unchanged().apply(kind);
            List<String> wires = position.wires().apply(kind);
            for (int i = 0; i < rows.size(); i++) {
                String label = "AZ-2436 AC-4 " + position.name() + ", " + kind + " " + bit + ", unchanged row " + i;
                // Act and Assert
                expectPacks(label, scheme, rows.get(i), wires.get(i));
            }
        }
    }

    /** Observed: a nested row group sees no id of the row around it, so its member cannot count by c. */
    private static void nestedRowCannotCountByTheRowAround() {
        for (String kind : KINDS) {
            for (String bit : BITS) {
                // Arrange
                String label = "AZ-2436 observed: a bit holding a nested row group, " + kind + " " + bit;
                Field[] fields = with(new Field[] {u8(0, "mode"), whenSet(1, 0, u8(1, "c"))},
                        behind(bit, 2, Packbin.group(Access.get("g"), Access.set("g"), member(kind, 0, 1))));
                // Act and Assert
                PackbinTest.expectThrows(label, () -> Maps.scheme(1, fields),
                        kind + " 0 takes its count from field 1, which is not an earlier integer field in its scope");
            }
        }
    }

    /**
     * AC-2 amended: {@code when(outer holds) { when(inner clear) { c; <bit> { member } } }} puts the member and its
     * bit in the clear when, so nothing of them is written or looked at: a silent skip, not U11. Observed at b8b2809.
     */
    private static void memberInsideTheClearWhenIsASilentSkip() {
        for (String kind : KINDS) {
            for (String bit : BITS) {
                // Arrange
                Scheme<Map> scheme = Maps.scheme(1, u8(0, "o"), whenSet(1, 0, u8(1, "mode"),
                        whenSet(2, 1, with(new Field[] {u8(2, "c")}, behind(bit, 3, member(kind, 3, 2))))));
                // Act and Assert
                expectPacks("AZ-2436 AC-2 observed, silent skip: " + kind + " " + bit + " inside the clear when", scheme,
                        Maps.map("o", 1, "mode", 0, "c", 3), "010100");
            }
        }
    }

    /** Row 56 with ids from {@code b}: mode b, c b+1, member b+2. */
    private static Field[] body(String kind, String bit, int b) {
        return with(new Field[] {u8(b, "mode"), whenSet(b + 1, b, u8(b + 1, "c"))},
                behind(bit, b + 2, member(kind, b + 2, b + 1)));
    }

    /** The member (or what holds it) behind a split bit, or as the one member of a combined flags at {@code id}. */
    private static Field[] behind(String bit, int id, Field inner) {
        if (bit.equals("flags")) {
            return new Field[] {Packbin.flags(id, inner)};
        }
        Field fb = Packbin.flagByte();
        return new Field[] {fb, fb.bit(inner)};
    }

    private static Field member(String kind, int id, int countId) {
        switch (kind) {
            case "bits":
                return Packbin.bits(id, Access.get("v"), Access.set("v"), countId);
            case "packed":
                return Packbin.packed(1, id, Access.get("v"), Access.set("v"), countId, 0);
            default:
                return Packbin.sized(id, Access.get("v"), Access.set("v"), countId);
        }
    }

    private static Object value(String kind) {
        return kind.equals("sized") ? new byte[] {1, 2, 3} : List.of(1, 0, 1);
    }

    private static String setHex(String kind) {
        return kind.equals("sized") ? "010203" : "05";
    }

    private static Field whenSet(int anchor, int fieldId, Field... fields) {
        return Packbin.when(anchor, Packbin.eq(fieldId, 1), fields);
    }

    private static Field[] with(Field[] head, Field... tail) {
        Field[] out = new Field[head.length + tail.length];
        System.arraycopy(head, 0, out, 0, head.length);
        System.arraycopy(tail, 0, out, head.length, tail.length);
        return out;
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
}
