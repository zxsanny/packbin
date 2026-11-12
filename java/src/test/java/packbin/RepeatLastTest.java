package packbin;

import static packbin.MemberCases.packs;
import static packbin.MemberCases.packsAs;
import static packbin.MemberCases.row;
import static packbin.MemberCases.u8;

import java.util.List;
import java.util.Map;
import java.util.function.Supplier;

/**
 * AZ-4214 (loop 113), contract repeat-last: a repeat has no count, so unpack reads its rounds to the end of the
 * packet and a repeat must be the last thing a packet reads. A scheme is refused when it is built if a field that
 * can write a byte follows a repeat (R1 to R6), if a repeat sits inside a list or dict element (R7, R8) or inside
 * a repeat or times round (R9; NestedRoundTest holds every place of a round). K1 to K5 build and keep their bytes.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class RepeatLastTest {
    private RepeatLastTest() {}

    static final String FOLLOWS = " follows it; a repeat reads to the end of the packet, so nothing can follow it;"
            + " use times";
    static final String IN_ELEMENT = " is inside a list or dict element; a repeat reads to the end of the packet, so"
            + " another element cannot follow it; use times";
    static final String IN_ROUND = " is inside a repeat or times round; a repeat reads to the end of the packet, so"
            + " another round cannot follow it; use times";

    static void run() {
        theRefusedCasesAreRefusedInBothForms();
        theFirstFieldThatFollowsIsNamed();
        theNearestElementOrRoundIsNamed();
        aFieldThatWritesNoByteMayFollow();
        aRepeatThatIsLastKeepsItsBytes();
    }

    public static final class Item {
        public Integer mode;
        public List<Object> v;
    }

    public static final class Nested {
        public List<Object> v;
    }

    /** The typed row of every case; a member a case does not use stays null. */
    public static final class Top {
        public Integer x;
        public Integer k;
        public List<Object> v;
        public List<Object> w;
        public List<Item> items;
        public Map<String, Item> d;
        public Nested m;
    }

    private record Refused(String id, String message, Supplier<Scheme<?>> mapRows, Supplier<Scheme<?>> typedRows) {}

    /** AC-1 (R1 to R8) and AC-5 (R9): each refused case of the contract, written with Map rows and with typed rows. */
    private static void theRefusedCasesAreRefusedInBothForms() {
        // Arrange
        List<Refused> cases = List.of(
                new Refused("R1 repeat(v), x", "repeat 0: u8 1" + FOLLOWS,
                        () -> Maps.scheme(1, rounds(0), u8(1, "x")),
                        () -> typed(Packbin.repeat(0, v(0)), x(1))),
                new Refused("R2 k, when(k == 1, repeat(v)), x", "repeat 1: u8 2" + FOLLOWS,
                        () -> Maps.scheme(1, u8(0, "k"), Packbin.when(1, Packbin.eq(0, 1), rounds(1)), u8(2, "x")),
                        () -> typed(k(0), Packbin.when(1, Packbin.eq(0, 1), Packbin.repeat(1, v(1))), x(2))),
                new Refused("R3 flags(repeat(v)), x", "repeat 0: u8 1" + FOLLOWS,
                        () -> Maps.scheme(1, Packbin.flags(0, rounds(0)), u8(1, "x")),
                        () -> typed(Packbin.flags(0, Packbin.repeat(0, v(0))), x(1))),
                // The nested row numbers its fields from 0, so x after it is id 0.
                new Refused("R4 nested row m (repeat(v)), x", "repeat 0: u8 0" + FOLLOWS,
                        () -> Maps.scheme(1, Packbin.group(Access.get("m"), Access.set("m"), rounds(0)), u8(0, "x")),
                        () -> typed(Packbin.group(Access.get((Top r) -> r.m),
                                Access.set((Top r, Object m) -> r.m = (Nested) m), Nested::new,
                                Packbin.repeat(0, nestedV())), x(0))),
                new Refused("R5 repeat(v), repeat(w)", "repeat 0: repeat 1" + FOLLOWS,
                        () -> Maps.scheme(1, rounds(0), Packbin.repeat(1, u8(1, "w"))),
                        () -> typed(Packbin.repeat(0, v(0)), Packbin.repeat(1, w(1)))),
                new Refused("R6 k, when(k == 1, repeat(v)), when(k == 2, x)", "repeat 1: u8 2" + FOLLOWS,
                        () -> Maps.scheme(1, u8(0, "k"), Packbin.when(1, Packbin.eq(0, 1), rounds(1)),
                                Packbin.when(2, Packbin.eq(0, 2), u8(2, "x"))),
                        () -> typed(k(0), Packbin.when(1, Packbin.eq(0, 1), Packbin.repeat(1, v(1))),
                                Packbin.when(2, Packbin.eq(0, 2), x(2)))),
                new Refused("R7 list of rows (mode, repeat(v))", "repeat 1" + IN_ELEMENT,
                        () -> Maps.scheme(1, Packbin.list(Access.get("items"), Access.set("items"), elementRow())),
                        () -> typed(Packbin.list(Access.get((Top r) -> r.items),
                                Access.set((Top r, Object items) -> r.items = (List<Item>) items), typedElementRow()))),
                new Refused("R8 dict of rows (mode, repeat(v))", "repeat 1" + IN_ELEMENT,
                        () -> Maps.scheme(1, Packbin.dict(Access.get("d"), Access.set("d"), elementRow())),
                        () -> typed(Packbin.dict(Access.get((Top r) -> r.d),
                                Access.set((Top r, Object d) -> r.d = (Map<String, Item>) d), typedElementRow()))),
                new Refused("R9 k, times(k, repeat(v))", "repeat 1 is inside a repeat or times round; a repeat reads to"
                        + " the end of the packet, so another round cannot follow it; use times",
                        () -> Maps.scheme(1, u8(0, "k"), Packbin.times(1, 0, rounds(1))),
                        () -> typed(k(0), Packbin.times(1, 0, Packbin.repeat(1, v(1))))));
        for (Refused c : cases) {
            // Act and Assert
            refusedAtBuild(c.id + ", Map rows", c.message, c.mapRows);
            refusedAtBuild(c.id + ", typed rows", c.message, c.typedRows);
        }
    }

    /** AC-1: the text names the first field after the repeat that can write a byte, by its kind and its id. */
    private static void theFirstFieldThatFollowsIsNamed() {
        // Arrange
        Field fb = Packbin.flagByte();
        Field holder = Packbin.flagByte();
        Field later = Packbin.flagByte();
        Field item = Packbin.u8(0, Access.identity(), Access.ignore());
        Field ints = Packbin.list(Access.get("xs"), Access.set("xs"), item);
        Field dict = Packbin.dict(Access.get("d"), Access.set("d"), item);
        // Act and Assert
        refusedAtBuild("a list", "repeat 0: list" + FOLLOWS, () -> Maps.scheme(1, rounds(0), ints));
        refusedAtBuild("a dict", "repeat 0: dict" + FOLLOWS, () -> Maps.scheme(1, rounds(0), dict));
        refusedAtBuild("a split flag byte", "repeat 0: flagByte" + FOLLOWS, () -> Maps.scheme(1, rounds(0), fb));
        refusedAtBuild("a flags that holds only a bool writes its byte", "repeat 0: flags 1" + FOLLOWS,
                () -> Maps.scheme(1, rounds(0), Packbin.flags(1, bool(1))));
        refusedAtBuild("a times", "repeat 1: times 2" + FOLLOWS,
                () -> Maps.scheme(1, u8(0, "n"), rounds(1), Packbin.times(2, 0, u8(2, "t"))));
        refusedAtBuild("a u2", "repeat 0: u2 1" + FOLLOWS, () -> Maps.scheme(1, rounds(0), Packbin.u2(
                Packbin.u2Slot(1, Access.get("a"), Access.set("a")),
                Packbin.u2Slot(2, Access.get("b"), Access.set("b")))));
        refusedAtBuild("bytes of size 2", "repeat 0: bytes 1" + FOLLOWS,
                () -> Maps.scheme(1, rounds(0), Packbin.bytes(1, Access.get("p"), Access.set("p"), 2)));
        refusedAtBuild("the first writer inside a nested row", "repeat 0: u16 1" + FOLLOWS,
                () -> Maps.scheme(1, rounds(0), Packbin.group(Access.get("g"), Access.set("g"), empty(0),
                        Packbin.u16(1, Access.get("h"), Access.set("h")))));
        refusedAtBuild("the field after a field that writes nothing", "repeat 0: u8 2" + FOLLOWS,
                () -> Maps.scheme(1, rounds(0), empty(1), u8(2, "x")));
        refusedAtBuild("a later member of the flags that holds the repeat", "repeat 0: u8 1" + FOLLOWS,
                () -> Maps.scheme(1, Packbin.flags(0, rounds(0), u8(1, "x"))));
        refusedAtBuild("after the split flag bit that holds the repeat", "repeat 0: u8 1" + FOLLOWS,
                () -> Maps.scheme(1, holder, holder.bit(rounds(0)), u8(1, "x")));
        refusedAtBuild("a split flag bit on a field that writes", "repeat 0: u8 1" + FOLLOWS,
                () -> Maps.scheme(1, later, rounds(0), later.bit(u8(1, "x"))));
        refusedAtBuild("three places up: flags in a group in a when", "repeat 1: u8 2" + FOLLOWS,
                () -> Maps.scheme(1, u8(0, "k"), Packbin.when(1, Packbin.eq(0, 1),
                        Packbin.group(1, Packbin.flags(1, rounds(1)))), u8(2, "x")));
        refusedAtBuild("a repeat whose rounds write nothing still reads to the end", "repeat 0: u8 1" + FOLLOWS,
                () -> Maps.scheme(1, Packbin.repeat(0, empty(0)), u8(1, "tail")));
    }

    /** AC-1 and AC-5: a repeat under both an element and a round is refused for the nearer one. */
    private static void theNearestElementOrRoundIsNamed() {
        // Arrange and Act and Assert
        refusedAtBuild("under a when of an element row", "repeat 1" + IN_ELEMENT,
                () -> Maps.scheme(1, Packbin.list(Access.get("xs"), Access.set("xs"),
                        Packbin.group(0, u8(0, "m"), Packbin.when(1, Packbin.eq(0, 1), rounds(1))))));
        refusedAtBuild("in a nested row of an element row", "repeat 0" + IN_ELEMENT,
                () -> Maps.scheme(1, Packbin.dict(Access.get("d"), Access.set("d"), Packbin.group(Access.identity(),
                        Access.ignore(), Packbin.group(Access.get("g"), Access.set("g"), rounds(0))))));
        refusedAtBuild("an element inside a round", "repeat 0" + IN_ELEMENT,
                () -> Maps.scheme(1, Packbin.repeat(0, u8(0, "k"), Packbin.list(Access.get("xs"), Access.set("xs"),
                        Packbin.group(0, rounds(0))))));
        refusedAtBuild("a times round inside an element", "repeat 1" + IN_ROUND,
                () -> Maps.scheme(1, Packbin.list(Access.get("xs"), Access.set("xs"),
                        Packbin.group(0, u8(0, "n"), Packbin.times(1, 0, rounds(1))))));
    }

    /** AC-1 (the unit row "a field that cannot write a byte"): a bool, a zero-width bytes and what holds only them. */
    private static void aFieldThatWritesNoByteMayFollow() {
        // Arrange
        byte[] none = new byte[0];
        Scheme<Map> zeroWidth = Maps.scheme(1, rounds(0), empty(1));
        Scheme<Map> boolMember = Maps.scheme(1, Packbin.flags(0, rounds(0), bool(1)));
        Scheme<Map> whenOfNothing = Maps.scheme(1, u8(0, "k"), rounds(1), Packbin.when(2, Packbin.eq(0, 1), empty(2)));
        Scheme<Map> rowOfNothing = Maps.scheme(1, rounds(0), Packbin.group(Access.get("g"), Access.set("g"), empty(0)));
        // Act
        String timesOfNothing = built(() -> Maps.scheme(1, u8(0, "n"), rounds(1), Packbin.times(2, 0, empty(2))));
        String repeatOfNothing = built(() -> Maps.scheme(1, rounds(0), Packbin.repeat(1, empty(1))));
        // Assert
        packsAs("a zero-width bytes after the repeat", zeroWidth, row("v", List.of(5, 6), "z", none), "010506",
                row("v", List.of(5, 6)));
        packs("a bool member after the repeat in one flags", boolMember,
                row("v", List.of(5, 6), "on", true), "01030506");
        packsAs("a when that holds only a zero-width bytes", whenOfNothing,
                row("k", 1, "v", List.of(5, 6), "z", none), "01010506", row("k", 1, "v", List.of(5, 6)));
        packsAs("a nested row that holds only a zero-width bytes", rowOfNothing,
                row("v", List.of(5, 6), "g", row("z", none)), "010506", row("v", List.of(5, 6), "g", row()));
        PackbinTest.expectEq("a times whose rounds write nothing", "built", timesOfNothing);
        PackbinTest.expectEq("a repeat whose rounds write nothing", "built", repeatOfNothing);
    }

    /** AC-2: K1 to K5 of the contract build, pack the contract's packet and read the values back. */
    private static void aRepeatThatIsLastKeepsItsBytes() {
        // Arrange
        Field fb = Packbin.flagByte();
        Scheme<Map> k1 = Maps.scheme(1, u8(0, "x"), rounds(1));
        Scheme<Map> k2 = Maps.scheme(1, u8(0, "k"), Packbin.when(1, Packbin.eq(0, 1), rounds(1)));
        Scheme<Map> k3 = Maps.scheme(1, Packbin.flags(0, u8(0, "x"), rounds(1)));
        Scheme<Map> k4 = Maps.scheme(1, u8(0, "k"), Packbin.times(1, 0, u8(1, "v")), u8(2, "x"));
        Scheme<Map> k5 = Maps.scheme(1, fb, fb.bit(u8(0, "x")), rounds(1), fb.bit(bool(2)));
        // Act and Assert
        packs("K1 x, repeat(v)", k1, row("x", 9, "v", List.of(5, 6)), "01090506");
        packs("K2 k, when(k == 1, repeat(v))", k2, row("k", 1, "v", List.of(5, 6)), "01010506");
        packs("K3 flags(x, repeat(v))", k3, row("x", 9, "v", List.of(5, 6)), "0103090506");
        packs("K4 k, times(k, v), x", k4, row("k", 2, "v", List.of(5, 6), "x", 9), "0102050609");
        packs("K5 flag byte, bit on x, repeat(v), bit on a bool", k5,
                row("x", 9, "v", List.of(5, 6), "on", true), "0103090506");
    }

    /** Passes only when building the scheme throws IllegalArgumentException with exactly {@code message}. */
    static void refusedAtBuild(String label, String message, Supplier<? extends Scheme<?>> build) {
        Scheme<?>[] built = {null};
        PackbinTest.expectThrows("repeat-last " + label, () -> built[0] = build.get(), message);
        PackbinTest.expectTrue("repeat-last " + label + ": no scheme was built", built[0] == null);
    }

    private static String built(Supplier<Scheme<Map>> build) {
        try {
            build.get();
        } catch (IllegalArgumentException ex) {
            return ex.getMessage();
        }
        return "built";
    }

    /** repeat anchor {@code id} { u8 v }: the body continues the ids of the place around it. */
    private static Field rounds(int id) {
        return Packbin.repeat(id, u8(id, "v"));
    }

    /** A bytes of size 0: a field that writes nothing. Unpack keeps nothing of it, so rows compare without it. */
    private static Field empty(int id) {
        return Packbin.bytes(id, Access.get("z"), Access.ignore(), 0);
    }

    private static Field bool(int id) {
        return Packbin.boolField(id, Access.get("on"), Access.set("on"));
    }

    /** The element row (u8 mode, repeat(u8 v)) of R7 and R8 as a nested row: each element is a Map of its own. */
    private static Field elementRow() {
        return Packbin.group(Access.identity(), Access.ignore(), u8(0, "mode"), rounds(1));
    }

    private static Scheme<Top> typed(Field... fields) {
        return new Scheme<>(1, Top.class, fields);
    }

    private static int number(Object value) {
        return ((Number) value).intValue();
    }

    private static Field x(int id) {
        return Packbin.u8(id, Access.get((Top r) -> r.x), Access.set((Top r, Object x) -> r.x = number(x)));
    }

    private static Field k(int id) {
        return Packbin.u8(id, Access.get((Top r) -> r.k), Access.set((Top r, Object k) -> r.k = number(k)));
    }

    /** In a round the member holds the list of what the rounds read. */
    private static Field v(int id) {
        return Packbin.u8(id, Access.get((Top r) -> r.v), Access.set((Top r, Object v) -> r.v = (List<Object>) v));
    }

    private static Field w(int id) {
        return Packbin.u8(id, Access.get((Top r) -> r.w), Access.set((Top r, Object w) -> r.w = (List<Object>) w));
    }

    private static Field nestedV() {
        return Packbin.u8(0, Access.get((Nested n) -> n.v), Access.set((Nested n, Object v) -> n.v = (List<Object>) v));
    }

    private static Field typedElementRow() {
        Field mode = Packbin.u8(0, Access.get((Item i) -> i.mode),
                Access.set((Item i, Object m) -> i.mode = number(m)));
        Field rounds = Packbin.u8(1, Access.get((Item i) -> i.v),
                Access.set((Item i, Object v) -> i.v = (List<Object>) v));
        return Packbin.group(Access.identity(), Access.ignore(), Item::new, mode, Packbin.repeat(1, rounds));
    }
}
