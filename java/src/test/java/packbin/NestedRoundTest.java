package packbin;

import java.util.Arrays;
import java.util.List;
import java.util.Map;

/**
 * AZ-2127: a repeat or times inside a repeat or times round packs and unpacks one inner list per outer round
 * ({@code v: [[5], [7]]}, null where the outer round skipped the inner group), and a nested row in a round is
 * one map per round. The loop 12 construction refusal is gone.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class NestedRoundTest {
    private NestedRoundTest() {}

    static void run() {
        ac1RepeatInTimesAndRepeat();
        ac2TimesInTimesAndRepeatInRepeat();
        threeLevelsNest();
        ac3BytesMatchCpp();
        ac4NestedRowInARound();
        aRepeatInARoundIsWrittenInOneRoundOnly();
        objectRowsAndIgnoringSetters();
        formerlyRefusedShapesBuildAndRoundTrip();
        neverThrowsOnAnyShortPacket();
    }

    private static Field u8(int id, String name) {
        return Packbin.u8(id, Access.get(name), Access.set(name));
    }

    private static final Scheme<Map> REPEAT_TIMES =
            Maps.scheme(1, Packbin.repeat(0, u8(0, "n"), Packbin.times(1, 0, u8(1, "v"))));

    private static void ac1RepeatInTimesAndRepeat() {
        Map<String, Object> row = Maps.map("n", List.of(1, 1), "v", List.of(List.of(5), List.of(7)));
        expectPack("AC-1 repeat -> times {n:[1,1], v:[[5],[7]]}", REPEAT_TIMES, row, "0101050107");
        expectUnpackRepack("AC-1 repeat -> times 0101050107", REPEAT_TIMES, "0101050107", row);

        Map<String, Object> counts = Maps.map("n", List.of(2, 1, 0), "v", List.of(List.of(1, 2), List.of(3), List.of()));
        expectPack("AC-1 inner counts 2, 1, 0", REPEAT_TIMES, counts, "01" + "020102" + "0103" + "00");
        expectUnpackRepack("AC-1 inner counts 2, 1, 0 read back", REPEAT_TIMES, "01" + "020102" + "0103" + "00", counts);

        Scheme<Map> skipped = Maps.scheme(1, Packbin.repeat(0, u8(0, "k"), u8(1, "n"),
                Packbin.when(2, Packbin.eq(0, 1), Packbin.times(2, 1, u8(2, "v")))));
        Map<String, Object> gaps = Maps.map("k", List.of(1, 2, 1), "n", List.of(1, 1, 2),
                "v", Arrays.asList(List.of(5), null, List.of(6, 7)));
        expectPack("AC-1 when skips the inner group in round 2", skipped, gaps, "01" + "010105" + "0201" + "01020607");
        expectUnpackRepack("AC-1 null for the skipped round", skipped, "01" + "010105" + "0201" + "01020607", gaps);
    }

    private static void ac2TimesInTimesAndRepeatInRepeat() {
        Scheme<Map> timesTimes = Maps.scheme(1, u8(0, "a"),
                Packbin.times(1, 0, u8(1, "m"), Packbin.times(2, 1, u8(2, "v"))));
        Map<String, Object> tt = Maps.map("a", 2, "m", List.of(1, 2), "v", List.of(List.of(5), List.of(6, 7)));
        expectPack("AC-2 times -> times", timesTimes, tt, "01" + "02" + "0105" + "02" + "0607");
        expectUnpackRepack("AC-2 times -> times read back", timesTimes, "010201050206" + "07", tt);

        Scheme<Map> timesRepeat = Maps.scheme(1, u8(0, "a"),
                Packbin.times(1, 0, u8(1, "m"), Packbin.repeat(2, u8(2, "v"))));
        Map<String, Object> tr = Maps.map("a", 1, "m", List.of(1), "v", List.of(List.of(5, 6)));
        expectPack("AC-2 times -> repeat, one round", timesRepeat, tr, "01" + "01" + "01" + "0506");
        expectUnpackRepack("AC-2 times -> repeat read back", timesRepeat, "0101010506", tr);

        Scheme<Map> repeatRepeat = Maps.scheme(1, Packbin.repeat(0, u8(0, "n"), Packbin.repeat(1, u8(1, "v"))));
        Map<String, Object> rr = Maps.map("n", List.of(1), "v", List.of(List.of(5, 6, 7)));
        expectPack("AC-2 repeat -> repeat, one round", repeatRepeat, rr, "0101050607");
        expectUnpackRepack("AC-2 repeat -> repeat read back", repeatRepeat, "0101050607", rr);

        HostileRun swallowed = HostileRun.of(timesRepeat, "0102" + "01" + "05" + "02" + "06");
        PackbinTest.expectTrue("AC-2 an inner repeat reads to the end, so the second round is short -> "
                + swallowed.kind(), swallowed.isErrorValue());
    }

    private static void threeLevelsNest() {
        Scheme<Map> deep = Maps.scheme(1, Packbin.repeat(0, u8(0, "n"),
                Packbin.times(1, 0, u8(1, "m"), Packbin.times(2, 1, u8(2, "v")))));
        Map<String, Object> row = Maps.map("n", List.of(1), "m", List.of(List.of(2)),
                "v", List.of(List.of(List.of(5, 6))));
        expectPack("AC-2 repeat -> times -> times", deep, row, "0101020506");
        expectUnpackRepack("AC-2 repeat -> times -> times read back", deep, "0101020506", row);
    }

    /** The bytes of the AC-1 scheme packed by the C++ package (scratch run of the same scheme and values). */
    private static void ac3BytesMatchCpp() {
        Map<String, Object> row = Maps.map("n", List.of(1, 1), "v", List.of(List.of(5), List.of(7)));
        expectPack("AC-3 C++ writes 0101050107 for the same values", REPEAT_TIMES, row, "0101050107");
    }

    private static void ac4NestedRowInARound() {
        Scheme<Map> rows = Maps.scheme(1, Packbin.repeat(0, Packbin.group(Access.get("g"), Access.set("g"), u8(0, "v"))));
        Map<String, Object> row = Maps.map("g", List.of(Maps.map("v", 1), Maps.map("v", 2)));
        expectPack("AC-4 nested row per round", rows, row, "010102");
        expectUnpackRepack("AC-4 nested row per round read back", rows, "010102", row);

        Scheme<Map> wide = Maps.scheme(1, Packbin.repeat(0, Packbin.group(Access.get("g"), Access.set("g"),
                u8(0, "v"), Packbin.u16(1, Access.get("w"), Access.set("w")))));
        Map<String, Object> two = Maps.map("g", List.of(Maps.map("v", 1, "w", 0x0302), Maps.map("v", 4, "w", 5)));
        expectUnpackRepack("AC-4 two fields per nested row", wide, "01" + "010203" + "040500", two);
        HostileRun cut = HostileRun.of(wide, "010102");
        PackbinTest.expectTrue("AC-4 a cut nested row is an error value, not a throw -> " + cut.kind(), cut.isErrorValue());

        Scheme<Map> repeatInRow = Maps.scheme(1, Packbin.repeat(0,
                Packbin.group(Access.get("g"), Access.set("g"), Packbin.repeat(0, u8(0, "v")))));
        Map<String, Object> inner = Maps.map("g", List.of(Maps.map("v", List.of(1, 2))));
        expectPack("AC-4 a repeat inside the nested row of a round", repeatInRow, inner, "01" + "0102");
        expectUnpackRepack("AC-4 a repeat inside the nested row read back", repeatInRow, "010102", inner);
    }

    private static final String ONE_ROUND =
            ": a repeat has no end marker, so it can be written in one round only";

    private static void expectRefused(String label, Scheme<Map> scheme, Map<String, Object> row, String message) {
        byte[][] wrote = {null};
        PackbinTest.expectThrows(label, () -> wrote[0] = BinaryPacker.pack(scheme, row), message);
        PackbinTest.expectTrue(label + ": no bytes returned", wrote[0] == null);
    }

    /** A repeat reads to the end of the packet, so pack refuses one that a second round would write after it. */
    private static void aRepeatInARoundIsWrittenInOneRoundOnly() {
        Scheme<Map> repeatRepeat = Maps.scheme(1, Packbin.repeat(0, u8(0, "n"), Packbin.repeat(1, u8(1, "v"))));
        expectRefused("one-round: repeat in repeat, two rounds", repeatRepeat,
                Maps.map("n", List.of(1, 1), "v", List.of(List.of(5), List.of(6))), "1" + ONE_ROUND);
        expectRefused("one-round: repeat in repeat, the first round writes nothing", repeatRepeat,
                Maps.map("n", List.of(1, 1), "v", List.of(List.of(), List.of(6))), "1" + ONE_ROUND);

        Scheme<Map> inRow = Maps.scheme(1, Packbin.repeat(0,
                Packbin.group(Access.get("g"), Access.set("g"), Packbin.repeat(0, u8(0, "v")))));
        expectRefused("one-round: repeat in a nested row, two rounds", inRow,
                Maps.map("g", List.of(Maps.map("v", List.of(1)), Maps.map("v", List.of(2)))), "0" + ONE_ROUND);

        Scheme<Map> timesRepeat = Maps.scheme(1, u8(0, "a"),
                Packbin.times(1, 0, u8(1, "m"), Packbin.repeat(2, u8(2, "v"))));
        expectRefused("one-round: repeat in times, two rounds", timesRepeat,
                Maps.map("a", 2, "m", List.of(1, 2), "v", List.of(List.of(5), List.of(6))), "2" + ONE_ROUND);

        Scheme<Map> deep = Maps.scheme(1, u8(0, "a"), Packbin.times(1, 0, u8(1, "b"),
                Packbin.times(2, 1, u8(2, "m"), Packbin.repeat(3, u8(3, "v")))));
        expectRefused("one-round: repeat under 1 outer round of 2 inner rounds", deep,
                Maps.map("a", 1, "b", List.of(2), "m", List.of(List.of(1, 2)),
                        "v", List.of(List.of(List.of(5), List.of(6)))), "3" + ONE_ROUND);
        expectRefused("one-round: repeat under 2 outer rounds of 1 inner round", deep,
                Maps.map("a", 2, "b", List.of(1, 1), "m", List.of(List.of(1), List.of(2)),
                        "v", List.of(List.of(List.of(5)), List.of(List.of(6)))), "3" + ONE_ROUND);
        expectPack("one-round: repeat under 1 outer round of 1 inner round", deep,
                Maps.map("a", 1, "b", List.of(1), "m", List.of(List.of(1)), "v", List.of(List.of(List.of(5, 6)))),
                "01" + "01" + "01" + "01" + "0506");

        expectPack("one-round: outer count 0 packs", repeatRepeat, Maps.map("n", List.of(), "v", List.of()), "01");
        expectPack("one-round: times count 0 packs", timesRepeat, Maps.map("a", 0), "0100");
        Scheme<Map> skipped = Maps.scheme(1, Packbin.repeat(0, u8(0, "k"),
                Packbin.when(1, Packbin.eq(0, 1), Packbin.repeat(1, u8(1, "v")))));
        expectPack("one-round: only one round holds the repeat", skipped,
                Maps.map("k", List.of(2, 1), "v", Arrays.asList(null, List.of(5, 6))), "01" + "02" + "010506");

        Map<String, Object> several = Maps.map("a", 2, "m", List.of(1, 2), "v", List.of(List.of(5), List.of(6, 7)));
        Scheme<Map> timesTimes = Maps.scheme(1, u8(0, "a"),
                Packbin.times(1, 0, u8(1, "m"), Packbin.times(2, 1, u8(2, "v"))));
        expectPack("one-round: an inner times under several outer rounds still packs", timesTimes, several, "010201050206" + "07");
        expectUnpackRepack("one-round: an inner times under several outer rounds reads back", timesTimes,
                "010201050206" + "07", several);
    }

    public static final class NestedRow {
        public List<Object> n;
        public List<Object> v;
    }

    /** A typed row keeps the lists its setters were given; a setter that keeps nothing costs one store per round. */
    private static void objectRowsAndIgnoringSetters() {
        Scheme<NestedRow> typed = new Scheme<>(1, NestedRow.class, Packbin.repeat(0,
                Packbin.u8(0, Access.get((NestedRow r) -> r.n), Access.set((NestedRow r, Object x) -> r.n = (List<Object>) x)),
                Packbin.times(1, 0, Packbin.u8(1, Access.get((NestedRow r) -> r.v),
                        Access.set((NestedRow r, Object x) -> r.v = (List<Object>) x)))));
        NestedRow[] got = new NestedRow[1];
        Object err = BinaryPacker.unpack(PackbinTest.parseHex("01" + "020102" + "0103"), typed.on(r -> got[0] = r));
        PackbinTest.expectTrue("object row unpack ok (" + err + ")", err == null && got[0] != null);
        PackbinTest.expectEq("object row n", List.of(2, 1), got[0] == null ? null : got[0].n);
        PackbinTest.expectEq("object row v", List.of(List.of(1, 2), List.of(3)), got[0] == null ? null : got[0].v);
        PackbinTest.expectEq("object row repack", "01" + "020102" + "0103",
                got[0] == null ? "" : PackbinTest.toHex(BinaryPacker.pack(typed, got[0])));

        Scheme<Map> ignoring = Maps.scheme(1, Packbin.repeat(0, u8(0, "n"),
                Packbin.times(1, 0, Packbin.u8(1, Access.get("v"), Access.ignore()))));
        HostileRun run = HostileRun.of(ignoring, "01" + "020102" + "0103");
        PackbinTest.expectTrue("a setter that keeps nothing unpacks nested rounds -> " + run.kind(),
                run.finished && run.result == null && run.handled);
    }

    /** Shapes that SchemeOrder refused until AZ-2127; each now builds and round-trips. */
    private static void formerlyRefusedShapesBuildAndRoundTrip() {
        Scheme<Map> timesTimes = Maps.scheme(1, u8(0, "n"),
                Packbin.times(1, 0, u8(1, "m"), Packbin.times(2, 1, u8(2, "v"))));
        PackbinTest.expectTrue("times inside times builds", timesTimes != null);

        Scheme<Map> inWhen = Maps.scheme(1, Packbin.repeat(0, u8(0, "k"),
                Packbin.when(1, Packbin.eq(0, 1), Packbin.repeat(1, u8(1, "v")))));
        Map<String, Object> skip = Maps.map("k", List.of(2, 1), "v", Arrays.asList(null, List.of(5, 6)));
        expectPack("repeat inside a when in a repeat", inWhen, skip, "01" + "02" + "010506");
        expectUnpackRepack("repeat inside a when in a repeat read back", inWhen, "01" + "02" + "010506", skip);

        Scheme<Map> inGroup = Maps.scheme(1, Packbin.repeat(0,
                Packbin.group(0, u8(0, "n"), Packbin.times(1, 0, u8(1, "v")))));
        Map<String, Object> grouped = Maps.map("n", List.of(2), "v", List.of(List.of(1, 2)));
        expectPack("times inside a group in a repeat", inGroup, grouped, "01" + "020102");
        expectUnpackRepack("times inside a group in a repeat read back", inGroup, "01" + "020102", grouped);
    }

    /** No packet of these schemes makes unpack throw; a bad one comes back as an error value. */
    private static void neverThrowsOnAnyShortPacket() {
        Scheme<Map>[] schemes = new Scheme[] {
                REPEAT_TIMES,
                Maps.scheme(1, Packbin.repeat(0, Packbin.group(Access.get("g"), Access.set("g"), u8(0, "v"),
                        Packbin.u16(1, Access.get("w"), Access.set("w"))))),
                Maps.scheme(1, u8(0, "a"), Packbin.times(1, 0, u8(1, "m"), Packbin.repeat(2, u8(2, "v")))),
                Maps.scheme(1, Packbin.repeat(0, Packbin.group(Access.get("g"), Access.set("g"),
                        Packbin.repeat(0, u8(0, "v")))))};
        int[] alphabet = {0, 1, 2, 255};
        boolean[] done = {false};
        String[] failure = {null};
        Thread worker = new Thread(() -> {
            for (int s = 0; s < schemes.length && failure[0] == null; s++) {
                for (int length = 0; length <= 5; length++) {
                    int total = (int) Math.pow(alphabet.length, length);
                    for (int code = 0; code < total && failure[0] == null; code++) {
                        byte[] packet = new byte[length + 1];
                        packet[0] = 1;
                        for (int i = 0, rest = code; i < length; i++, rest /= alphabet.length) {
                            packet[i + 1] = (byte) alphabet[rest % alphabet.length];
                        }
                        try {
                            BinaryPacker.unpack(packet, schemes[s].on(row -> {}));
                        } catch (RuntimeException ex) {
                            failure[0] = "scheme " + s + " packet " + PackbinTest.toHex(packet) + " threw " + ex;
                        }
                    }
                }
            }
            done[0] = true;
        });
        worker.setDaemon(true);
        worker.start();
        try {
            worker.join(20_000);
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException("interrupted while waiting for unpack", ex);
        }
        PackbinTest.expectTrue("AC-4 every packet of up to 5 bytes unpacks without a throw or a hang", done[0]);
        PackbinTest.expectTrue("AC-4 no packet threw (" + failure[0] + ")", failure[0] == null);
    }

    private static String packHex(String label, Scheme<Map> scheme, Map<String, Object> row) {
        try {
            return PackbinTest.toHex(BinaryPacker.pack(scheme, row));
        } catch (RuntimeException ex) {
            PackbinTest.fail(label + ": pack threw " + ex);
            return "";
        }
    }

    private static void expectPack(String label, Scheme<Map> scheme, Map<String, Object> row, String hex) {
        PackbinTest.expectEq(label + " bytes", hex, packHex(label, scheme, row));
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
}
