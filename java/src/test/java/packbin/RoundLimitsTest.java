package packbin;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.Map;

/**
 * AZ-2218 (F10): a scheme refuses a repeat or times round that would start past its maxRounds, or that would take
 * the slots of one unpack call past its maxSlots, with ShortPacket(label, 0, left) and no handler call.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class RoundLimitsTest {
    private RoundLimitsTest() {}

    private static final long NO_SLOT_LIMIT = Scheme.DEFAULT_MAX_SLOTS;

    static void run() {
        defaultsAndSurface();
        repeatAtTheDefaultLimit();
        repeatRefusedAtTheNextRound();
        timesRefusedAtTheNextRound();
        timesAtTheDefaultLimit();
        slotLimit();
        slotTotalSpansFieldsAndElements();
        refusedMegabyteIsBoundedByTheLimits();
        limitsBelongToTheScheme();
        invalidLimitsAreRefused();
        existingCallSitesAreUnchanged();
    }

    private static Scheme<Map> repeatOfK() {
        return Maps.scheme(1, Packbin.repeat(0, u8(0, "k")));
    }

    private static Scheme<Map> timesOfK() {
        return Maps.scheme(1, u8(0, "n"), Packbin.times(1, 0, u8(1, "k")));
    }

    private static Scheme<Map> u32TimesOfK() {
        return Maps.scheme(1, Packbin.u32(0, Access.get("n"), Access.set("n")),
                Packbin.times(1, 0, u8(1, "k")));
    }

    private static void defaultsAndSurface() {
        // Arrange
        Scheme<Map> base = repeatOfK();
        // Act
        Scheme<Map> lowered = base.withLimits(10, Scheme.DEFAULT_MAX_SLOTS);
        // Assert
        PackbinTest.expectEq("AC-1 DEFAULT_MAX_ROUNDS", 65_535, Scheme.DEFAULT_MAX_ROUNDS);
        PackbinTest.expectEq("AC-1 DEFAULT_MAX_SLOTS", 4_194_304L, Scheme.DEFAULT_MAX_SLOTS);
        PackbinTest.expectEq("AC-1 default maxRounds", 65_535, base.maxRounds());
        PackbinTest.expectEq("AC-1 default maxSlots", 4_194_304L, base.maxSlots());
        PackbinTest.expectEq("AC-1 withLimits maxRounds", 10, lowered.maxRounds());
        PackbinTest.expectEq("AC-1 withLimits maxSlots", 4_194_304L, lowered.maxSlots());
        PackbinTest.expectEq("AC-1 receiver keeps maxRounds", 65_535, base.maxRounds());
    }

    private static void repeatAtTheDefaultLimit() {
        // Arrange
        Scheme<Map> scheme = repeatOfK();
        // Act
        HostileRun atLimit = HostileRun.of(scheme, rounds(Scheme.DEFAULT_MAX_ROUNDS, 7), HostileRun.LIMIT_MS);
        HostileRun over = HostileRun.of(scheme, rounds(Scheme.DEFAULT_MAX_ROUNDS + 1, 7), HostileRun.LIMIT_MS);
        // Assert
        PackbinTest.expectTrue("AC-2 65,535 rounds -> " + atLimit.kind(), atLimit.finished && atLimit.result == null && atLimit.handled);
        PackbinTest.expectEq("AC-2 65,536 rounds", "ShortPacket 0 0 1", shape(over.result));
        PackbinTest.expectTrue("AC-2 65,536 rounds: handler not called -> " + over.kind(), over.finished && !over.handled);
        Map[] got = new Map[1];
        BinaryPacker.unpack(rounds(Scheme.DEFAULT_MAX_ROUNDS, 7), scheme.on(row -> got[0] = row));
        PackbinTest.expectEq("AC-2 65,535 entries", Scheme.DEFAULT_MAX_ROUNDS, ((List) got[0].get("k")).size());
    }

    private static void repeatRefusedAtTheNextRound() {
        // Arrange
        Scheme<Map> scheme = repeatOfK().withLimits(3, NO_SLOT_LIMIT);
        // Act
        Map[] got = new Map[1];
        Object ok = BinaryPacker.unpack(hex("01aabbcc"), scheme.on(row -> got[0] = row));
        // Assert
        PackbinTest.expectTrue("AC-3 three rounds ok", ok == null && got[0] != null);
        PackbinTest.expectEq("AC-3 k", List.of(170, 187, 204), got[0].get("k"));
        expectShape("AC-3 four rounds", scheme, "01aabbccdd", "ShortPacket 0 0 1");
    }

    private static void timesRefusedAtTheNextRound() {
        // Arrange
        Scheme<Map> scheme = timesOfK().withLimits(3, NO_SLOT_LIMIT);
        Map[] got = new Map[1];
        // Act
        Object ok = BinaryPacker.unpack(hex("0103090909"), scheme.on(row -> got[0] = row));
        // Assert
        PackbinTest.expectTrue("AC-4 three rounds ok", ok == null && got[0] != null);
        PackbinTest.expectEq("AC-4 k", List.of(9, 9, 9), got[0].get("k"));
        PackbinTest.expectEq("AC-4 n", 3, got[0].get("n"));
        expectShape("AC-4 round 4 with one byte left", scheme, "010409090909", "ShortPacket times 0 1");
        expectShape("AC-4 round 4 with none left", scheme, "0104090909", "ShortPacket times 0 0");
        expectShape("AC-4 count 255, one round present", scheme, "01ff09", "ShortPacket 1 1 0");
        expectShape("AC-4 count 3, two rounds present", scheme, "01030909", "ShortPacket 1 1 0");
    }

    private static void timesAtTheDefaultLimit() {
        // Arrange
        Scheme<Map> scheme = u32TimesOfK();
        byte[] max = {(byte) 0xff, (byte) 0xff, (byte) 0xff, (byte) 0xff};
        // Act
        HostileRun atLimit = HostileRun.of(scheme, timesPacket(new byte[] {-1, -1, 0, 0}, 65_535), HostileRun.LIMIT_MS);
        HostileRun over = HostileRun.of(scheme, timesPacket(new byte[] {0, 0, 1, 0}, 65_536), HostileRun.LIMIT_MS);
        HostileRun hugeCountOver = HostileRun.of(scheme, timesPacket(max, 65_536), HostileRun.LIMIT_MS);
        HostileRun hugeCountAtLimit = HostileRun.of(scheme, timesPacket(max, 65_535), HostileRun.LIMIT_MS);
        // Assert
        PackbinTest.expectTrue("AC-5 65,535 rounds -> " + atLimit.kind(), atLimit.finished && atLimit.result == null && atLimit.handled);
        PackbinTest.expectEq("AC-5 65,536 rounds", "ShortPacket times 0 1", shape(over.result));
        PackbinTest.expectEq("AC-5 max count, 65,536 bytes", "ShortPacket times 0 1", shape(hugeCountOver.result));
        PackbinTest.expectEq("AC-5 max count, 65,535 bytes", "ShortPacket times 0 0", shape(hugeCountAtLimit.result));
        PackbinTest.expectTrue("AC-5 refusals: handler not called", !over.handled && !hugeCountOver.handled && !hugeCountAtLimit.handled);
        expectShape("AC-5 max count, one round present", scheme, "01ffffffff00", "ShortPacket 1 1 0");
        Map[] got = new Map[1];
        BinaryPacker.unpack(timesPacket(new byte[] {-1, -1, 0, 0}, 65_535), scheme.on(row -> got[0] = row));
        PackbinTest.expectEq("AC-5 65,535 entries", 65_535, ((List) got[0].get("k")).size());
    }

    private static void slotLimit() {
        // Arrange
        Scheme<Map> scheme = Maps.scheme(1, Packbin.repeat(0, u8(0, "k"),
                Packbin.when(1, Packbin.eq(0, 1), u8(1, "a"), u8(2, "b"))))
                .withLimits(Scheme.DEFAULT_MAX_ROUNDS, 6);
        Map[] got = new Map[1];
        // Act
        Object ok = BinaryPacker.unpack(hex("010000"), scheme.on(row -> got[0] = row));
        // Assert
        PackbinTest.expectTrue("AC-6 two rounds x 3 slots ok", ok == null && got[0] != null);
        PackbinTest.expectEq("AC-6 k", Arrays.asList(0, 0), got[0].get("k"));
        PackbinTest.expectEq("AC-6 a", Arrays.asList(null, null), got[0].get("a"));
        PackbinTest.expectEq("AC-6 b", Arrays.asList(null, null), got[0].get("b"));
        expectShape("AC-6 round 3 would pass 6 slots", scheme, "01000000", "ShortPacket 0 0 1");
        expectShape("AC-6 round 3 with two bytes left", scheme, "0100000000", "ShortPacket 0 0 2");
    }

    private static void slotTotalSpansFieldsAndElements() {
        // Arrange
        Scheme<Map> twoTimes = Maps.scheme(1, u8(0, "n"), Packbin.times(1, 0, u8(1, "k")),
                Packbin.times(2, 0, u8(2, "v")));
        Scheme<Map> inElements = Maps.scheme(1, Packbin.list(Access.get("xs"), Access.set("xs"),
                Packbin.group(0, u8(0, "n"), Packbin.times(1, 0, u8(1, "v")))));
        Map[] got = new Map[1];
        // Act
        Object okA = BinaryPacker.unpack(hex("0102aabbccdd"), twoTimes.withLimits(3, 4).on(row -> got[0] = row));
        // Assert
        PackbinTest.expectTrue("AC-7a slots 4 of 4 ok", okA == null && got[0] != null);
        PackbinTest.expectEq("AC-7a row", Maps.map("n", 2, "k", List.of(170, 187), "v", List.of(204, 221)), got[0]);
        expectShape("AC-7a slots past 3", twoTimes.withLimits(3, 3), "0102aabbccdd", "ShortPacket times 0 1");

        got[0] = null;
        String packet = "01" + "0200" + "020708" + "02090a";
        Object okB = BinaryPacker.unpack(hex(packet), inElements.withLimits(3, 4).on(row -> got[0] = row));
        PackbinTest.expectTrue("AC-7b slots 4 of 4 ok", okB == null && got[0] != null);
        PackbinTest.expectEq("AC-7b row", Maps.map("xs", List.of(Maps.map("n", 2, "v", List.of(7, 8)),
                Maps.map("n", 2, "v", List.of(9, 10)))), got[0]);
        expectShape("AC-7b total spans elements", inElements.withLimits(3, 3), packet, "ShortPacket times 0 1");
        expectShape("AC-7b maxRounds 1", inElements.withLimits(1, NO_SLOT_LIMIT), packet, "ShortPacket times 0 4");
    }

    /** 37 names per round: refused at round 65,536, so the 1 MiB tail is never walked. */
    private static void refusedMegabyteIsBoundedByTheLimits() {
        // Arrange
        Scheme<Map> scheme = wideRepeat();
        byte[] megabyte = rounds(1 << 20, 0);
        // Act
        long start = System.nanoTime();
        HostileRun refused = HostileRun.of(scheme, megabyte, HostileRun.LIMIT_MS);
        long ms = (System.nanoTime() - start) / 1_000_000;
        HostileRun atLimit = HostileRun.of(scheme, rounds(Scheme.DEFAULT_MAX_ROUNDS, 0), HostileRun.LIMIT_MS);
        // Assert
        PackbinTest.expectEq("AC-8 1 MiB refused at round 65,536", "ShortPacket 0 0 983041", shape(refused.result));
        PackbinTest.expectTrue("AC-8 handler not called, " + ms + " ms -> " + refused.kind(), refused.finished && !refused.handled);
        PackbinTest.expectTrue("AC-8 65,535 rounds -> " + atLimit.kind(), atLimit.finished && atLimit.result == null);
    }

    /** A repeat of u8 k and a when of 36 more fields (alternating u8 and u16), as in the audit. */
    static Scheme<Map> wideRepeat() {
        List<Field> inner = new ArrayList<>();
        for (int i = 0; i < 36; i++) {
            inner.add(i % 2 == 0 ? u8(i + 1, "f" + i)
                    : Packbin.u16(i + 1, Access.get("f" + i), Access.set("f" + i)));
        }
        return Maps.scheme(1, Packbin.repeat(0, u8(0, "k"),
                Packbin.when(1, Packbin.eq(0, 1), inner.toArray(new Field[0]))));
    }

    private static void limitsBelongToTheScheme() {
        // Arrange
        Scheme<Map> base = repeatOfK();
        Scheme<Map> strict = base.withLimits(3, NO_SLOT_LIMIT);
        Scheme<Map> other = Maps.scheme(2, Packbin.repeat(0, u8(0, "k"))).withLimits(2, NO_SLOT_LIMIT);
        Map[] got = new Map[1];
        // Act
        Object receiver = BinaryPacker.unpack(hex("01aabbccdd"), base.on(row -> got[0] = row));
        Object lowered = BinaryPacker.unpack(hex("01aabbccdd"), strict.on(row -> { }));
        Object dispatched = BinaryPacker.unpack(hex("02aabbcc"), base.on(row -> { }), other.on(row -> { }));
        Object baseWins = BinaryPacker.unpack(hex("01aabbcc"), base.on(row -> { }), other.on(row -> { }));
        // Assert
        PackbinTest.expectTrue("AC-9 receiver kept its limits", receiver == null && ((List) got[0].get("k")).size() == 4);
        PackbinTest.expectEq("AC-9 strict", "ShortPacket 0 0 1", shape(lowered));
        PackbinTest.expectEq("AC-9 type 2 uses its own limit", "ShortPacket 0 0 1", shape(dispatched));
        PackbinTest.expectTrue("AC-9 type 1 is not limited by type 2", baseWins == null);
    }

    private static void invalidLimitsAreRefused() {
        // Arrange
        Scheme<Map> scheme = repeatOfK();
        // Act and Assert
        PackbinTest.expectThrows("AC-10 maxRounds 0", () -> scheme.withLimits(0, 1), "maxRounds must be at least 1");
        PackbinTest.expectThrows("AC-10 maxRounds -1", () -> scheme.withLimits(-1, 1), "maxRounds must be at least 1");
        PackbinTest.expectThrows("AC-10 maxSlots 0", () -> scheme.withLimits(1, 0), "maxSlots must be at least 1");
        PackbinTest.expectThrows("AC-10 maxSlots -1", () -> scheme.withLimits(1, -1), "maxSlots must be at least 1");
        Scheme<Map> huge = scheme.withLimits(Integer.MAX_VALUE, Long.MAX_VALUE);
        HostileRun run = HostileRun.of(huge, rounds(Scheme.DEFAULT_MAX_ROUNDS + 1, 7), HostileRun.LIMIT_MS);
        PackbinTest.expectTrue("AC-10 max values accept 65,536 rounds -> " + run.kind(),
                run.finished && run.result == null && run.handled);
    }

    /** A scheme built and used exactly as before the limits existed: same constructor, same calls, same bytes. */
    private static void existingCallSitesAreUnchanged() {
        // Arrange
        Scheme<Map> scheme = new Scheme<>(1, (Class) Map.class, Packbin.repeat(0, u8(0, "k")));
        Map<String, Object> row = Maps.map("k", List.of(1, 2, 3));
        Map[] got = new Map[1];
        // Act
        byte[] packed = BinaryPacker.pack(scheme, row);
        Object err = BinaryPacker.unpack(packed, scheme.on(r -> got[0] = r));
        // Assert
        PackbinTest.expectEq("AC-11 bytes", "01010203", PackbinTest.toHex(packed));
        PackbinTest.expectTrue("AC-11 unpack ok", err == null);
        PackbinTest.expectEq("AC-11 row", row, got[0]);
    }

    private static void expectShape(String label, Scheme<Map> scheme, String hex, String expected) {
        boolean[] handled = new boolean[1];
        Object err = BinaryPacker.unpack(hex(hex), scheme.on(row -> handled[0] = true));
        PackbinTest.expectEq(label, expected, shape(err));
        PackbinTest.expectTrue(label + ": handler not called", !handled[0]);
    }

    private static String shape(Object err) {
        if (err instanceof Packbin.ShortPacket s) {
            return "ShortPacket " + s.field + " " + s.needed + " " + s.left;
        }
        return String.valueOf(err);
    }

    /** Type 1 followed by {@code count} one-byte rounds of {@code fill}. */
    private static byte[] rounds(int count, int fill) {
        byte[] packet = new byte[1 + count];
        Arrays.fill(packet, (byte) fill);
        packet[0] = 1;
        return packet;
    }

    /** Type 1, a u32 count (little endian), then {@code rounds} bytes of 7. */
    private static byte[] timesPacket(byte[] count, int rounds) {
        byte[] packet = new byte[5 + rounds];
        Arrays.fill(packet, (byte) 7);
        packet[0] = 1;
        System.arraycopy(count, 0, packet, 1, 4);
        return packet;
    }

    private static byte[] hex(String text) {
        return PackbinTest.parseHex(text);
    }

    private static Field u8(int id, String name) {
        return Packbin.u8(id, Access.get(name), Access.set(name));
    }
}
