package packbin;

import java.util.Arrays;
import java.util.List;
import java.util.Map;

/**
 * AZ-2089 review fixes: every repeat or times round packs and unpacks its own values, as C++ per-round items do.
 * F1 flag bits come from the round's value; F2 unpacked lists hold one entry per round (null where the round
 * skipped the field); F3 a round never sees a value read in an earlier round. Round 3: a round cannot hold
 * another repeat or times (#1), and padding a round costs one store, not one per earlier round (#2).
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class RepeatRoundTest {
    private RepeatRoundTest() {}

    static void run() {
        flagBitsUseTheRoundValue();
        roundListsStayAligned();
        roundsDoNotSeeEarlierRounds();
        nestedRoundsAreRefused();
        nestedRoundsInsideElementsStillBuild();
        paddingIsLinear();
    }

    private static final String NESTED = " is inside a repeat or times round; a round cannot hold another repeat or times";

    private static void expectRefused(String label, java.util.function.Supplier<Scheme<Map>> build, String message) {
        PackbinTest.expectThrows(label, build::get, message);
    }

    private static void nestedRoundsAreRefused() {
        Scheme[] built = new Scheme[1];
        byte[][] wrote = {new byte[0]};
        PackbinTest.expectThrows("#1 times inside repeat", () -> {
            built[0] = Maps.scheme(1, Packbin.repeat(0, u8(0, "n"), Packbin.times(1, 0, u8(1, "v"))));
            wrote[0] = BinaryPacker.pack(built[0], Maps.map("n", List.of(1, 1), "v", List.of(5, 7)));
        }, "times 1" + NESTED);
        PackbinTest.expectTrue("#1 times inside repeat: 0 schemes", built[0] == null);
        PackbinTest.expectEq("#1 times inside repeat: 0 bytes", 0, wrote[0].length);

        expectRefused("#1 times inside times", () -> Maps.scheme(1, u8(0, "n"),
                Packbin.times(1, 0, u8(1, "m"), Packbin.times(2, 1, u8(2, "v")))), "times 2" + NESTED);
        expectRefused("#1 repeat inside repeat", () -> Maps.scheme(1,
                Packbin.repeat(0, u8(0, "a"), Packbin.repeat(1, u8(1, "b")))), "repeat 1" + NESTED);
        expectRefused("#1 repeat inside times", () -> Maps.scheme(1, u8(0, "n"),
                Packbin.times(1, 0, Packbin.repeat(1, u8(1, "v")))), "repeat 1" + NESTED);
        expectRefused("#1 repeat inside a when in a repeat", () -> Maps.scheme(1, Packbin.repeat(0,
                u8(0, "k"), Packbin.when(1, Packbin.eq(0, 1), Packbin.repeat(1, u8(1, "v"))))), "repeat 1" + NESTED);
        expectRefused("#1 times inside a group in a repeat", () -> Maps.scheme(1, Packbin.repeat(0,
                Packbin.group(0, u8(0, "n"), Packbin.times(1, 0, u8(1, "v"))))), "times 1" + NESTED);
        expectRefused("#1 repeat as a flags bit in a repeat", () -> Maps.scheme(1, Packbin.repeat(0,
                u8(0, "k"), Packbin.flags(1, Packbin.repeat(1, u8(1, "v"))))), "repeat 1" + NESTED);
        expectRefused("#1 repeat inside a nested row in a repeat", () -> Maps.scheme(1, Packbin.repeat(0,
                u8(0, "k"), Packbin.group(Access.get("g"), Access.set("g"), Packbin.repeat(0, u8(0, "v"))))),
                "repeat 0" + NESTED);
    }

    /** A list or dict element is a row of its own, so a repeat inside it is not inside the enclosing round. */
    private static void nestedRoundsInsideElementsStillBuild() {
        Scheme<Map> list = Maps.scheme(1, Packbin.list(Access.get("xs"), Access.set("xs"),
                Packbin.group(0, Packbin.repeat(0, u8(0, "v")))));
        expectUnpackRepack("#1 repeat in a list element", list, "01" + "0100" + "0506",
                Maps.map("xs", List.of(Maps.map("v", List.of(5, 6)))));
        try {
            Maps.scheme(1, Packbin.dict(Access.get("m"), Access.set("m"),
                    Packbin.group(0, u8(0, "n"), Packbin.times(1, 0, u8(1, "v")))));
        } catch (IllegalArgumentException ex) {
            PackbinTest.fail("#1 times in a dict element: refused with \"" + ex.getMessage() + "\"");
        }
        Scheme<Map> inRound = Maps.scheme(1, Packbin.repeat(0, u8(0, "k"), Packbin.list(Access.get("xs"), Access.set("xs"),
                Packbin.group(0, Packbin.repeat(0, u8(0, "v"))))));
        expectUnpackRepack("#1 repeat in a list element inside a repeat round", inRound, "01" + "01" + "0100" + "0506",
                Maps.map("k", List.of(1), "xs", List.of(List.of(Maps.map("v", List.of(5, 6))))));
    }

    /** Padding stores one null per round, so a setter that keeps nothing does not make unpack quadratic. */
    private static void paddingIsLinear() {
        Scheme<Map> ignored = Maps.scheme(1, Packbin.repeat(0, Packbin.u8(0, Access.get("x"), Access.ignore())));
        byte[] packet = new byte[65536];
        java.util.Arrays.fill(packet, (byte) 5);
        packet[0] = 1;
        HostileRun run = HostileRun.of(ignored, packet, HostileRun.LIMIT_MS);
        PackbinTest.expectTrue("#2 64 KB repeat into an ignoring setter unpacks within " + HostileRun.LIMIT_MS
                + " ms -> " + run.kind(), run.finished && run.result == null && run.handled);
    }

    private static Field u8(int id, String name) {
        return Packbin.u8(id, Access.get(name), Access.set(name));
    }

    private static Field bool(int id, String name) {
        return Packbin.boolField(id, Access.get(name), Access.set(name));
    }

    /** Pack, or record the exception as a failure so the remaining tests still run. */
    private static String packHex(String label, Scheme<Map> scheme, Map<String, Object> row) {
        try {
            return PackbinTest.toHex(BinaryPacker.pack(scheme, row));
        } catch (RuntimeException ex) {
            PackbinTest.fail(label + ": pack threw " + ex);
            return "";
        }
    }

    /** Unpack {@code hex}, expect {@code unpacked}, then pack that row again and expect the same bytes. */
    private static void expectUnpackRepack(String label, Scheme<Map> scheme, String hex, Map<String, Object> unpacked) {
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(PackbinTest.parseHex(hex), scheme.on(row -> got[0] = row));
        PackbinTest.expectTrue(label + " unpack ok (" + err + ")", err == null && got[0] != null);
        if (got[0] != null) {
            PackbinTest.expectEq(label + " row", unpacked, got[0]);
            PackbinTest.expectEq(label + " repack", hex, packHex(label + " repack", scheme, got[0]));
        }
    }

    private static void expectPack(String label, Scheme<Map> scheme, Map<String, Object> row, String hex) {
        PackbinTest.expectEq(label + " bytes", hex, packHex(label, scheme, row));
    }

    private static void expectError(String label, Scheme<Map> scheme, String hex) {
        HostileRun run = HostileRun.of(scheme, hex);
        PackbinTest.expectTrue(label + " -> " + run.kind() + " is ShortPacket", run.result instanceof Packbin.ShortPacket);
        PackbinTest.expectTrue(label + " handler not called", !run.handled);
    }

    private static void flagBitsUseTheRoundValue() {
        Scheme<Map> boolAfterKey = Maps.scheme(1, Packbin.repeat(0, u8(0, "k"), Packbin.flags(1, bool(1, "b"))));
        expectPack("F1 repeat(u8 k, flags(bool b)) {k:[1,2], b:[true,true]}", boolAfterKey,
                Maps.map("k", List.of(1, 2), "b", List.of(true, true)), "01" + "0101" + "0201");
        expectUnpackRepack("F1 repeat(u8 k, flags(bool b)) 0101010201", boolAfterKey, "0101010201",
                Maps.map("k", List.of(1, 2), "b", List.of(true, true)));

        Scheme<Map> boolOnly = Maps.scheme(1, Packbin.repeat(0, Packbin.flags(0, bool(0, "b"))));
        expectPack("F1 repeat(flags(bool b)) b=[true,false,true]", boolOnly,
                Maps.map("b", List.of(true, false, true)), "01" + "01" + "00" + "01");
        expectUnpackRepack("F1 repeat(flags(bool b)) 01010001", boolOnly, "01010001",
                Maps.map("b", Arrays.asList(true, null, true)));

        Field fb = Packbin.flagByte();
        Scheme<Map> split = Maps.scheme(1, Packbin.repeat(0, fb, fb.bit(bool(0, "on")), u8(1, "x")));
        expectPack("F1 split repeat(fb, bit(bool on), u8 x) {on:[true,false], x:[5,6]}", split,
                Maps.map("on", List.of(true, false), "x", List.of(5, 6)), "01" + "0105" + "0006");
        expectUnpackRepack("F1 split repeat 0101050006", split, "0101050006",
                Maps.map("on", Arrays.asList(true, null), "x", List.of(5, 6)));

        Scheme<Map> shortList = Maps.scheme(1, Packbin.repeat(0, u8(0, "k"), Packbin.flags(1, u8(1, "v"))));
        expectPack("F1 repeat(u8 k, flags(u8 v)) {k:[1,2], v:[5]}", shortList,
                Maps.map("k", List.of(1, 2), "v", List.of(5)), "01" + "010105" + "0200");
    }

    private static void roundListsStayAligned() {
        Scheme<Map> when = Maps.scheme(1, Packbin.repeat(0, u8(0, "k"), Packbin.when(1, Packbin.eq(0, 1), u8(1, "v"))));
        expectUnpackRepack("F2 repeat when, skipped round first, 01020109", when, "01020109",
                Maps.map("k", List.of(2, 1), "v", Arrays.asList(null, 9)));
        Map<String, Object> three = Maps.map("k", List.of(1, 2, 1), "v", Arrays.asList(9, null, 8));
        expectPack("F2 repeat when {k:[1,2,1], v:[9,null,8]}", when, three, "01" + "0109" + "02" + "0108");
        expectUnpackRepack("F2 repeat when 010109020108", when, "010109020108", three);

        Scheme<Map> flags = Maps.scheme(1, Packbin.repeat(0, u8(0, "k"), Packbin.flags(1, u8(1, "v"))));
        expectUnpackRepack("F2 repeat flags, set round first, 010101050200", flags, "010101050200",
                Maps.map("k", List.of(1, 2), "v", Arrays.asList(5, null)));
        expectUnpackRepack("F2 repeat flags, clear round first, 010200010105", flags, "010200010105",
                Maps.map("k", List.of(2, 1), "v", Arrays.asList(null, 5)));

        Scheme<Map> times = Maps.scheme(1, u8(0, "n"),
                Packbin.times(1, 0, u8(1, "k"), Packbin.when(2, Packbin.eq(1, 1), u8(2, "v"))));
        expectUnpackRepack("F2 times when, skipped round first, 0102020109", times, "0102020109",
                Maps.map("n", 2, "k", List.of(2, 1), "v", Arrays.asList(null, 9)));
    }

    private static void roundsDoNotSeeEarlierRounds() {
        Scheme<Map> gated = Maps.scheme(1, Packbin.repeat(0,
                Packbin.flags(0, u8(0, "k")), Packbin.when(1, Packbin.eq(0, 1), u8(1, "v"))));
        expectError("F3 repeat: round 2 when must not match round 1's k, 010101050007", gated, "010101050007");
        expectPack("F3 repeat pack: round 2 when must not match round 1's k", gated,
                Maps.map("k", Arrays.asList(1, null), "v", List.of(5, 6)), "01" + "010105" + "00");
        expectUnpackRepack("F3 repeat 0101010500", gated, "0101010500",
                Maps.map("k", Arrays.asList(1, null), "v", Arrays.asList(5, null)));

        Scheme<Map> counted = Maps.scheme(1, Packbin.repeat(0,
                Packbin.flags(0, u8(0, "n")), Packbin.sized(1, Access.get("p"), Access.set("p"), 0)));
        expectError("F3 repeat: count behind a clear flag in round 2, 010102aabb00ccdd", counted, "010102aabb00ccdd");

        Scheme<Map> times = Maps.scheme(1, u8(0, "n"), Packbin.times(1, 0,
                Packbin.flags(1, u8(1, "k")), Packbin.when(2, Packbin.eq(1, 1), u8(2, "v"))));
        expectUnpackRepack("F3 times: round 2 when must not match round 1's k, 010201010500", times, "010201010500",
                Maps.map("n", 2, "k", Arrays.asList(1, null), "v", Arrays.asList(5, null)));
    }
}
