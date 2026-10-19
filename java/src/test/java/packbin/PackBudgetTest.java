package packbin;

import static packbin.MemberCases.list;
import static packbin.MemberCases.packs;
import static packbin.MemberCases.refused;
import static packbin.MemberCases.row;
import static packbin.MemberCases.u8;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.Map;

/**
 * AZ-2354 (loop 20): pack has one output budget, {@code maxBytes} (16 MiB by default), checked before the append
 * that would pass it, and charges {@code maxSlots} per round as unpack does. The rows are the TypeScript
 * reference's ({@code _docs/03_implementation/reference_loop20_budget.md}, AZ-2354 rows 1 to 28), with Java's
 * member names: an accessor key where the field has one, a flag byte has none ({@code flag_byte}).
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class PackBudgetTest {
    private PackBudgetTest() {}

    private static final long DEFAULT_SLOTS = Scheme.DEFAULT_MAX_SLOTS;

    static void run() {
        row1LoneUtf8UnderACappedTimes();
        rows2And3AnElementThatHoldsATimes();
        rows2And3AnElementThatHoldsATimesUnderTheSlotsLimit();
        rows4To13TheBoundaryIsExact();
        rows14To16SlotsAreChargedOnPack();
        rows17To21TheOrderOfTheChecks();
        rows22To25ScopeAndWidth();
        rows26To28TheLimitsApi();
        growthStaysInsideTheArrayLimit();
    }

    private static Field u32(int id, String name) {
        return Packbin.u32(id, Access.get(name), Access.set(name));
    }

    private static Field u64(int id, String name) {
        return Packbin.u64(id, Access.get(name), Access.set(name));
    }

    private static Field utf8(int id, String name) {
        return Packbin.utf8(id, Access.get(name), Access.set(name));
    }

    private static String repeated(char c, int n) {
        char[] chars = new char[n];
        Arrays.fill(chars, c);
        return new String(chars);
    }

    private static String refusal(Scheme<Map> scheme, Map row) {
        try {
            BinaryPacker.pack(scheme, row);
        } catch (IllegalArgumentException ex) {
            return ex.getMessage();
        }
        return "packed";
    }

    /** Packs to {@code hex}; the row is a lone value for every round, so it does not unpack to itself. */
    private static void expectHex(String label, Scheme<Map> scheme, Map row, String hex) {
        PackbinTest.expectEq(label, hex, PackbinTest.toHex(BinaryPacker.pack(scheme, row)));
    }

    private static String hexAt(byte[] packet, int from, int n) {
        return PackbinTest.toHex(Arrays.copyOfRange(packet, from, from + n));
    }

    /** AC-1, row 1: refused at round 255 in a child JVM with a small heap and a second to spare (LoneUtf8Budget). */
    private static void row1LoneUtf8UnderACappedTimes() {
        // Arrange
        Scheme<Map> scheme = Maps.scheme(1, u32(0, "n"), Packbin.times(1, 0, utf8(1, "s")));
        Map row = Maps.map("n", 65_535, "s", repeated((char) 1, 65_535));
        String refused = "s: the packet would be 16777989 bytes, above the limit of 16777216 bytes";
        // Act
        Timing.Limit limit = Timing.bound(1.0);
        long start = System.nanoTime();
        String got = refusal(scheme, row);
        long ms = (System.nanoTime() - start) / 1_000_000;
        // Assert
        PackbinTest.expectEq("AC-1 row 1 message", refused, got);
        limit.expectWithin("AC-1 row 1 refused", ms / 1000.0);
        LoneUtf8Budget.expectRefusedInASmallHeap(refused);
    }

    /**
     * Rows 2 and 3: 40 items that each hold 65 535 rounds of a u64, about 21 MB. That is 2 621 400 slots, so the
     * default limit of 1 048 576 slots refuses it first (loop 22, AZ-2415); row 3 raises maxSlots to pack it.
     */
    private static void rows2And3AnElementThatHoldsATimes() {
        // Arrange
        Scheme<Map> scheme = Maps.scheme(1, Packbin.list(Access.get("items"), Access.set("items"),
                Packbin.group(0, u32(0, "n"), Packbin.times(1, 0, u64(1, "k")))));
        List<Object> items = new ArrayList<>();
        for (int i = 0; i < 40; i++) {
            items.add(Maps.map("n", 65_535, "k", 5));
        }
        Map row = Maps.map("items", items);
        // Act
        String refused = refusal(scheme, row);
        Scheme<Map> raised = scheme.withLimits(Scheme.DEFAULT_MAX_ROUNDS, 4_194_304L).withMaxBytes(33_554_432L);
        byte[] packet = BinaryPacker.pack(raised, row);
        Map[] back = new Map[1];
        Object err = BinaryPacker.unpack(packet, raised.on(r -> back[0] = r));
        // Assert
        PackbinTest.expectEq("AC-2 row 2 refused at the default",
                "k: the rounds would hold 1048577 slots, above the limit of 1048576 slots", refused);
        PackbinTest.expectEq("AC-2 row 3 length", 20_971_363, packet.length);
        PackbinTest.expectEq("AC-2 row 3 first 16", "012800ffff0000050000000000000005", hexAt(packet, 0, 16));
        PackbinTest.expectEq("AC-2 row 3 last 16", "05000000000000000500000000000000", hexAt(packet, packet.length - 16, 16));
        PackbinTest.expectTrue("AC-2 row 3 unpacks (" + err + ")", err == null && back[0] != null);
        List<Map> got = (List<Map>) back[0].get("items");
        PackbinTest.expectEq("AC-2 row 3 items", 40, got.size());
        PackbinTest.expectEq("AC-2 row 3 n", 65_535, ((Number) got.get(0).get("n")).intValue());
        PackbinTest.expectEq("AC-2 row 3 k rounds", 65_535, ((List) got.get(39).get("k")).size());
    }

    /**
     * The bytes-budget route through an element that holds a times, under the slots limit: 16 items of 65 535 rounds
     * of one 16-char text that stays raw are 1 048 560 slots and 18 874 147 bytes (the TypeScript row of reference_loop22.md).
     */
    private static void rows2And3AnElementThatHoldsATimesUnderTheSlotsLimit() {
        // Arrange
        Scheme<Map> scheme = Maps.scheme(1, Packbin.list(Access.get("items"), Access.set("items"),
                Packbin.group(0, u32(0, "n"), Packbin.times(1, 0, utf8(1, "s")))));
        List<Object> items = new ArrayList<>();
        for (int i = 0; i < 16; i++) {
            items.add(Maps.map("n", 65_535, "s", repeated((char) 1, 16)));
        }
        Map row = Maps.map("items", items);
        // Act
        String refused = refusal(scheme, row);
        Scheme<Map> raised = scheme.withMaxBytes(33_554_432L);
        byte[] packet = BinaryPacker.pack(raised, row);
        Map[] back = new Map[1];
        Object err = BinaryPacker.unpack(packet, raised.on(r -> back[0] = r));
        // Assert
        PackbinTest.expectEq("AC-2 bytes route refused at the default",
                "s: the packet would be 16777233 bytes, above the limit of 16777216 bytes", refused);
        PackbinTest.expectEq("AC-2 bytes route length", 18_874_147, packet.length);
        PackbinTest.expectTrue("AC-2 bytes route unpacks (" + err + ")", err == null && back[0] != null);
        PackbinTest.expectEq("AC-2 bytes route items", 16, ((List) back[0].get("items")).size());
    }

    /** Rows 4 to 13: a packet of exactly maxBytes packs, one byte more is refused, the member being written is named. */
    private static void rows4To13TheBoundaryIsExact() {
        // Arrange
        Scheme<Map> text = Maps.scheme(1, utf8(0, "s")).withMaxBytes(64);
        Scheme<Map> repeat = Maps.scheme(1, Packbin.repeat(0, u8(0, "k"))).withMaxBytes(64);
        // Act
        byte[] sixtyOne = BinaryPacker.pack(text, row("s", repeated((char) 1, 61)));
        byte[] sixtyThree = BinaryPacker.pack(repeat, row("k", Collections.nCopies(63, 7)));
        // Assert
        PackbinTest.expectEq("AC-3 row 4 length", 64, sixtyOne.length);
        PackbinTest.expectEq("AC-3 row 4 head", "013e1001", hexAt(sixtyOne, 0, 4));
        refused("AC-3 row 5", text, row("s", repeated((char) 1, 62)),
                "s: the packet would be 65 bytes, above the limit of 64 bytes");
        PackbinTest.expectEq("AC-3 row 6 length", 64, sixtyThree.length);
        PackbinTest.expectEq("AC-3 row 6 head", "0107070707", hexAt(sixtyThree, 0, 5));
        refused("AC-3 row 7", repeat, row("k", Collections.nCopies(64, 7)),
                "k: the packet would be 65 bytes, above the limit of 64 bytes");
        packs("AC-3 row 8 type byte counts", Maps.scheme(1).withMaxBytes(1), row(), "01");
        refused("AC-3 row 9", Maps.scheme(1, u8(0, "a")).withMaxBytes(1), row("a", 1),
                "a: the packet would be 2 bytes, above the limit of 1 bytes");
        Field byteField = Packbin.flagByte();
        refused("AC-3 row 10 split flag byte (no name: its kind)",
                Maps.scheme(1, byteField, byteField.bit(u8(0, "c"))).withMaxBytes(1), row("c", 1),
                "flag_byte: the packet would be 2 bytes, above the limit of 1 bytes");
        refused("AC-3 row 11 combined flags byte, first member", Maps.scheme(1, Packbin.flags(0, u8(0, "c"))).withMaxBytes(1),
                row("c", 1), "c: the packet would be 2 bytes, above the limit of 1 bytes");
        refused("AC-3 row 12 combined flags byte, named through the times",
                Maps.scheme(1, u8(0, "n"), Packbin.flags(1, Packbin.times(1, 0, u8(1, "k")))).withMaxBytes(2),
                row("n", 1, "k", 3), "k: the packet would be 3 bytes, above the limit of 2 bytes");
        refused("AC-3 row 13 list count prefix",
                Maps.scheme(1, Packbin.list(Access.get("xs"), Access.set("xs"), u8(0, "v"))).withMaxBytes(2),
                row("xs", list()), "xs: the packet would be 3 bytes, above the limit of 2 bytes");
        refused("AC-3 u2 names its first slot",
                Maps.scheme(1, Packbin.u2(Packbin.u2Slot(0, Access.get("a"), Access.set("a")),
                        Packbin.u2Slot(1, Access.get("b"), Access.set("b")))).withMaxBytes(1),
                row("a", 1, "b", 2), "a: the packet would be 2 bytes, above the limit of 1 bytes");
        refused("AC-3 dict key names the dict",
                Maps.scheme(1, Packbin.dict(Access.get("d"), Access.set("d"), u8(0, "v"))).withMaxBytes(4),
                row("d", Maps.map("key", 1)), "d: the packet would be 7 bytes, above the limit of 4 bytes");
    }

    private static Map<String, Object> wideRow(int count) {
        Map<String, Object> wide = Maps.map("n", count);
        for (int i = 0; i < 65; i++) {
            wide.put("m" + i, Collections.nCopies(count, 1));
        }
        return wide;
    }

    private static Scheme<Map> wideScheme() {
        Field[] members = new Field[65];
        for (int i = 0; i < 65; i++) {
            members[i] = u8(i + 1, "m" + i);
        }
        return Maps.scheme(1, u32(0, "n"), Packbin.times(1, 0, members));
    }

    /** Rows 14 to 16: 65 members x 65 535 rounds is 4 259 775 slots. */
    private static void rows14To16SlotsAreChargedOnPack() {
        // Arrange
        Scheme<Map> scheme = wideScheme();
        Map row = wideRow(65_535);
        // Act
        String refused = refusal(scheme, row);
        byte[] packet = BinaryPacker.pack(scheme.withLimits(Scheme.DEFAULT_MAX_ROUNDS, 4_259_775L), row);
        Map[] back = new Map[1];
        Object okErr = BinaryPacker.unpack(packet, scheme.withLimits(Scheme.DEFAULT_MAX_ROUNDS, 4_259_775L)
                .on(r -> back[0] = r));
        Object refusedErr = BinaryPacker.unpack(packet, scheme.on(r -> { }));
        // Assert
        PackbinTest.expectEq("AC-4 row 14", "m0: the rounds would hold 1048580 slots, above the limit of 1048576 slots", refused);
        PackbinTest.expectEq("AC-4 row 15 length", 4_259_780, packet.length);
        PackbinTest.expectEq("AC-4 row 15 first 16", "01ffff00000101010101010101010101", hexAt(packet, 0, 16));
        PackbinTest.expectEq("AC-4 row 15 last 16", "01010101010101010101010101010101", hexAt(packet, packet.length - 16, 16));
        PackbinTest.expectTrue("AC-4 row 15 unpacks (" + okErr + ")", okErr == null && back[0] != null);
        PackbinTest.expectEq("AC-4 row 15 m64 rounds", 65_535, ((List) back[0].get("m64")).size());
        PackbinTest.expectTrue("AC-4 row 16 unpack refuses at the same round",
                refusedErr instanceof Packbin.ShortPacket s && s.field.equals("times") && s.needed == 0 && s.left == 3_211_260);
    }

    private static Scheme<Map> timesOfK() {
        return Maps.scheme(1, u32(0, "n"), Packbin.times(1, 0, u8(1, "k")));
    }

    /** Rows 17 to 21: per round slots first, then bytes; the rounds cap before any round; the count field first. */
    private static void rows17To21TheOrderOfTheChecks() {
        // Arrange
        Scheme<Map> atBoth = timesOfK().withLimits(Scheme.DEFAULT_MAX_ROUNDS, 3).withMaxBytes(8);
        // Act and Assert
        expectHex("order row 17 at both limits", atBoth, row("n", 3, "k", 7), "0103000000070707");
        refused("order row 18 slots first", atBoth, row("n", 10, "k", 7),
                "k: the rounds would hold 4 slots, above the limit of 3 slots");
        refused("order row 19 bytes in the 3rd round",
                timesOfK().withLimits(Scheme.DEFAULT_MAX_ROUNDS, 3).withMaxBytes(7), row("n", 10, "k", 7), "k: the packet would be 8 bytes, above the limit of 7 bytes");
        refused("order row 20 rounds before any round (Java text: times)",
                timesOfK().withLimits(5, 3).withMaxBytes(8), row("n", 10, "k", 7),
                "times: count 10 is above the limit of 5 rounds");
        refused("order row 21 the count field first",
                timesOfK().withLimits(5, 3).withMaxBytes(4), row("n", 10, "k", 7),
                "n: the packet would be 5 bytes, above the limit of 4 bytes");
    }

    private static void rows22To25ScopeAndWidth() {
        // Arrange
        Scheme<Map> inElements = Maps.scheme(1, Packbin.list(Access.get("items"), Access.set("items"),
                Packbin.group(0, u8(0, "n"), Packbin.times(1, 0, u8(1, "k"))))).withLimits(Scheme.DEFAULT_MAX_ROUNDS, 5);
        Scheme<Map> groupRound = Maps.scheme(1, Packbin.repeat(0, u8(0, "a"), Packbin.group(1, u8(1, "b"))))
                .withLimits(Scheme.DEFAULT_MAX_ROUNDS, 5);
        // Act and Assert
        refused("scope row 22 slots accumulate across elements", inElements,
                row("items", List.of(Maps.map("n", 3, "k", 1), Maps.map("n", 3, "k", 2))),
                "k: the rounds would hold 6 slots, above the limit of 5 slots");
        expectHex("scope row 23 five slots", inElements,
                row("items", List.of(Maps.map("n", 3, "k", 1), Maps.map("n", 2, "k", 2))), "01020003010101020202");
        packs("width row 24 a group's own name is not counted", groupRound,
                row("a", list(1, 2), "b", list(3, 4)), "0101030204");
        refused("width row 25", groupRound, row("a", list(1, 2, 3), "b", list(3, 4, 5)),
                "a: the rounds would hold 6 slots, above the limit of 5 slots");
    }

    private static void rows26To28TheLimitsApi() {
        // Arrange
        Scheme<Map> scheme = Maps.scheme(1, u8(0, "a"));
        // Act and Assert
        PackbinTest.expectEq("AC-5 row 26 DEFAULT_MAX_BYTES", 16_777_216L, Scheme.DEFAULT_MAX_BYTES);
        PackbinTest.expectEq("AC-5 row 26 default", 16_777_216L, scheme.maxBytes());
        PackbinTest.expectEq("AC-5 row 26 withLimits takes the default", 16_777_216L,
                scheme.withLimits(9, 9).maxBytes());
        PackbinTest.expectEq("AC-5 row 26 a later withLimits takes the default", 16_777_216L,
                scheme.withMaxBytes(64).withLimits(9, 9).maxBytes());
        PackbinTest.expectEq("AC-5 withMaxBytes", 64L, scheme.withMaxBytes(64).maxBytes());
        PackbinTest.expectEq("AC-5 withMaxBytes keeps maxRounds", 9, scheme.withLimits(9, 8).withMaxBytes(64).maxRounds());
        PackbinTest.expectEq("AC-5 withMaxBytes keeps maxSlots", 8L, scheme.withLimits(9, 8).withMaxBytes(64).maxSlots());
        PackbinTest.expectEq("AC-5 the receiver is unchanged", 16_777_216L, scheme.maxBytes());
        PackbinTest.expectThrows("AC-5 row 27 maxBytes 0", () -> scheme.withMaxBytes(0), "maxBytes must be at least 1");
        PackbinTest.expectThrows("AC-5 row 27 maxBytes -1", () -> scheme.withMaxBytes(-1), "maxBytes must be at least 1");
        PackbinTest.expectEq("AC-5 maxBytes Long.MAX_VALUE", Long.MAX_VALUE, scheme.withMaxBytes(Long.MAX_VALUE).maxBytes());
        expectHex("AC-5/6 row 28 existing call form", timesOfK().withLimits(3, 3), row("n", 3, "k", 7), "0103000000070707");
    }

    /** F29 and AC-3 of AZ-2361 live in CountsFractionsSinkTest; this is the sink against the budget. */
    private static void growthStaysInsideTheArrayLimit() {
        // Arrange
        ByteSink sink = new ByteSink(1, 1, Long.MAX_VALUE);
        Field member = u8(0, "a");
        // Act and Assert
        PackbinTest.expectThrows("AZ-2361 AC-3 above the array limit is a typed error",
                () -> sink.ensure(member, ByteSink.MAX_ARRAY + 1L),
                "a: the packet would be 2147483640 bytes, above the largest array of 2147483639 bytes");
    }
}
