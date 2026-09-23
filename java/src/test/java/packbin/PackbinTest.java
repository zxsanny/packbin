package packbin;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.List;
import java.util.Locale;
import java.util.Map;

public final class PackbinTest {
    private static int failures;

    private static final Packbin.Packet TARGET = Packbin.packet(
            Packbin.u8("type"),
            Packbin.u16("sid"),
            Packbin.i32("lat"),
            Packbin.i32("lon"),
            Packbin.u8("profile"),
            Packbin.flags(
                    "motion",
                    Packbin.u16("heading"),
                    Packbin.u8("speed"),
                    Packbin.i16("altitude")));

    private static final String GOLDEN_HEX = "4001000065cd1d00a3e1110100";

    public static void main(String[] args) throws Exception {
        ac1PositionPack();
        ac2PositionUnpack();
        ac3BytesMatchFixture();
        ac4FlagsAndStoredZero();
        ac5ShortBufferThenPositionPack();
        whenGroupWidth();
        repeatBoundary();
        trailingBytesAreError();
        flagGroupMark();
        flagGroupWideBit();
        flagGroupSession();
        flagGroupStoredZero();
        flagGroupShortLogin();
        sizedPayload();
        u2Kinds();
        bitsSegs();
        nfrRoundTripsWithinOneSecond();
        objectRoundTrip();
        if (failures > 0) {
            System.err.println(failures + " failure(s)");
            System.exit(1);
        }
        System.out.println("All tests passed");
    }

    private static Map<String, Object> position() {
        Map<String, Object> values = new HashMap<>();
        values.put("type", 0x40);
        values.put("sid", 1);
        values.put("lat", 500_000_000);
        values.put("lon", 300_000_000);
        values.put("profile", 1);
        return values;
    }

    private static void ac1PositionPack() {
        byte[] bytes = Packbin.pack(TARGET, position());
        String hex = toHex(bytes);
        int mismatched = mismatchedBytes(bytes, parseHex(GOLDEN_HEX));
        expectEq("AC-1 hex", GOLDEN_HEX, hex);
        expectEq("AC-1 mismatched", 0, mismatched);
        expectEq("AC-1 length", 13, bytes.length);
        byte[] again = Packbin.pack(TARGET, position());
        expectEq("AC-1 packed twice", 0, mismatchedBytes(bytes, again));
    }

    private static void ac2PositionUnpack() {
        Packbin.UnpackResult got = Packbin.unpack(TARGET, parseHex(GOLDEN_HEX));
        expectTrue("AC-2 ok", got.ok);
        expectEq("AC-2 type", 0x40, ((Number) got.value.get("type")).intValue());
        expectEq("AC-2 sid", 1, ((Number) got.value.get("sid")).intValue());
        expectEq("AC-2 lat", 500_000_000, ((Number) got.value.get("lat")).intValue());
        expectEq("AC-2 lon", 300_000_000, ((Number) got.value.get("lon")).intValue());
        expectEq("AC-2 profile", 1, ((Number) got.value.get("profile")).intValue());
        int motionFields = 0;
        if (got.value.containsKey("heading")) motionFields++;
        if (got.value.containsKey("speed")) motionFields++;
        if (got.value.containsKey("altitude")) motionFields++;
        expectEq("AC-2 motion field count", 0, motionFields);
        expectEq("AC-2 five fields", 5, countNamed(
                got.value, "type", "sid", "lat", "lon", "profile"));
    }

    private static void ac3BytesMatchFixture() throws IOException {
        byte[] bytes = Packbin.pack(TARGET, position());
        byte[] fixture = parseHex(Files.readString(findGoldenFixture()).trim());
        expectEq("AC-3 mismatched", 0, mismatchedBytes(bytes, fixture));
    }

    private static void ac4FlagsAndStoredZero() {
        Packbin.Packet packet = Packbin.packet(
                Packbin.flags(
                        "flags",
                        Packbin.u8("b0"),
                        Packbin.u8("b1"),
                        Packbin.u8("b2"),
                        Packbin.u8("b3"),
                        Packbin.u8("b4"),
                        Packbin.u16("wide")));

        byte[] clear = Packbin.pack(packet, Map.of());
        expectEq("AC-4 clear length", 1, clear.length);
        expectEq("AC-4 clear byte", 0x00, clear[0] & 0xFF);
        expectEq("AC-4 flags 0x00 adds", 0, clear.length - 1);

        Map<String, Object> setBit5 = new HashMap<>();
        setBit5.put("wide", 0x1234);
        byte[] withWide = Packbin.pack(packet, setBit5);
        expectEq("AC-4 0x20 length", 3, withWide.length);
        expectEq("AC-4 0x20 flags", 0x20, withWide[0] & 0xFF);
        expectEq("AC-4 0x20 adds 2", 2, withWide.length - clear.length);

        Map<String, Object> presentZero = new HashMap<>();
        presentZero.put("wide", 0);
        byte[] zero = Packbin.pack(packet, presentZero);
        expectEq("AC-4 present 0 length", 3, zero.length);
        expectEq("AC-4 present 0 flags", 0x20, zero[0] & 0xFF);
        expectEq("AC-4 present 0 lo", 0x00, zero[1] & 0xFF);
        expectEq("AC-4 present 0 hi", 0x00, zero[2] & 0xFF);

        byte[] absent = Packbin.pack(packet, new HashMap<>());
        expectEq("AC-4 absence length", 1, absent.length);
        expectEq("AC-4 absence does not write 0 payload", 0, absent.length - 1);
    }

    private static void ac5ShortBufferThenPositionPack() {
        Packbin.Packet packet = Packbin.packet(
                Packbin.flags(
                        "flags",
                        Packbin.u8("b0"),
                        Packbin.u8("b1"),
                        Packbin.u8("b2"),
                        Packbin.u8("b3"),
                        Packbin.u8("b4"),
                        Packbin.u16("wide")));
        Packbin.UnpackResult got = Packbin.unpack(packet, new byte[] {0x20, 0x34});
        expectEq("AC-5 value count", 0, got.value.size());
        expectTrue("AC-5 error is ShortPacket", got.error instanceof Packbin.ShortPacket);
        Packbin.ShortPacket missing = (Packbin.ShortPacket) got.error;
        expectEq("AC-5 field", "wide", missing.field);
        expectEq("AC-5 needed", 2, missing.needed);
        expectEq("AC-5 left", 1, missing.left);

        byte[] bytes = Packbin.pack(TARGET, position());
        expectEq("AC-5 next pack hex", GOLDEN_HEX, toHex(bytes));
    }

    private static void whenGroupWidth() {
        Packbin.Packet packet = Packbin.packet(
                Packbin.u8("profile"),
                Packbin.when(Packbin.eq("profile", 0), Packbin.u8("shape")));

        Map<String, Object> missValues = new HashMap<>();
        missValues.put("profile", 1);
        byte[] miss = Packbin.pack(packet, missValues);
        expectEq("when miss length", 1, miss.length);

        Map<String, Object> hitValues = new HashMap<>();
        hitValues.put("profile", 0);
        hitValues.put("shape", 9);
        byte[] hit = Packbin.pack(packet, hitValues);
        expectEq("when hit length", 2, hit.length);
        expectEq("when added", 1, hit.length - miss.length);
    }

    private static void repeatBoundary() {
        Packbin.Packet packet = Packbin.packet(Packbin.repeat(Packbin.u8("a"), Packbin.u8("b")));

        Packbin.UnpackResult ok = Packbin.unpack(packet, new byte[] {1, 2});
        expectTrue("repeat ok", ok.ok);
        expectTrue("repeat list", ok.value.get("a") instanceof List);
        expectEq("repeat count", 1, ((List<?>) ok.value.get("a")).size());

        Packbin.UnpackResult bad = Packbin.unpack(packet, new byte[] {1, 2, 3});
        expectEq("repeat short values", 0, bad.value.size());
        expectTrue("repeat short error", bad.error instanceof Packbin.ShortPacket);
    }

    private static void trailingBytesAreError() {
        Packbin.Packet packet = Packbin.packet(Packbin.u8("type"));
        Packbin.UnpackResult got = Packbin.unpack(packet, new byte[] {0x40, (byte) 0x99});
        expectEq("trailing values", 0, got.value.size());
        expectTrue("trailing error", got.error instanceof Packbin.TrailingBytes);
        expectEq("trailing left", 1, ((Packbin.TrailingBytes) got.error).left);
    }

    private static void flagGroupMark() {
        Packbin.Packet empty = Packbin.packet(Packbin.flags("f", Packbin.group("mark")));
        Map<String, Object> present = new HashMap<>();
        present.put("mark", Boolean.TRUE);
        byte[] setBit = Packbin.pack(empty, present);
        expectEq("mark set length", 1, setBit.length);
        expectEq("mark set byte", 0x01, setBit[0] & 0xFF);
        expectEq("mark set adds", 0, setBit.length - 1);
        byte[] clear = Packbin.pack(empty, Map.of());
        expectEq("mark clear length", 1, clear.length);
        expectEq("mark clear byte", 0x00, clear[0] & 0xFF);
    }

    private static void flagGroupWideBit() {
        Packbin.Packet one = Packbin.packet(
                Packbin.flags(
                        "f",
                        Packbin.u8("a"),
                        Packbin.u8("b"),
                        Packbin.u8("c"),
                        Packbin.u8("d"),
                        Packbin.u8("e"),
                        Packbin.u16("b5")));
        Map<String, Object> aOnly = new HashMap<>();
        aOnly.put("a", 1);
        expectEq("wide a length", 2, Packbin.pack(one, aOnly).length);
        Map<String, Object> b5Only = new HashMap<>();
        b5Only.put("b5", 1);
        byte[] wide = Packbin.pack(one, b5Only);
        expectEq("wide flags", 0x20, wide[0] & 0xFF);
        expectEq("wide adds", 2, wide.length - Packbin.pack(one, Map.of()).length);
    }

    private static void flagGroupSession() {
        Packbin.Packet two = Packbin.packet(
                Packbin.flags(
                        "f",
                        Packbin.group("session", Packbin.u16("login"), Packbin.u32("ts"))));
        Map<String, Object> values = new HashMap<>();
        values.put("login", 7);
        values.put("ts", 1000);
        byte[] raw = Packbin.pack(two, values);
        expectEq("session payload", "0700e8030000", toHex(java.util.Arrays.copyOfRange(raw, 1, raw.length)));
        expectEq("session adds", 6, raw.length - 1);
        byte[] absent = Packbin.pack(two, Map.of());
        expectEq("session absent", "00", toHex(absent));
        Packbin.UnpackResult got = Packbin.unpack(two, absent);
        expectTrue("session absent ok", got.ok);
        expectTrue("session no login", !got.value.containsKey("login"));
        expectTrue("session no ts", !got.value.containsKey("ts"));
    }

    private static void flagGroupStoredZero() {
        Packbin.Packet zero = Packbin.packet(
                Packbin.flags("f", Packbin.group("g", Packbin.u8("b"))));
        Map<String, Object> values = new HashMap<>();
        values.put("b", 0);
        byte[] stored = Packbin.pack(zero, values);
        expectEq("group zero", "0100", toHex(stored));
    }

    private static void flagGroupShortLogin() {
        Packbin.Packet two = Packbin.packet(
                Packbin.flags(
                        "f",
                        Packbin.group("session", Packbin.u16("login"), Packbin.u32("ts"))));
        Packbin.UnpackResult shortRead = Packbin.unpack(two, new byte[] {0x01, 0x07});
        expectEq("short login values", 0, shortRead.value.size());
        expectTrue("short login error", shortRead.error instanceof Packbin.ShortPacket);
        Packbin.ShortPacket missing = (Packbin.ShortPacket) shortRead.error;
        expectEq("short login field", "login", missing.field);
        expectEq("short login needed", 2, missing.needed);
        expectEq("short login left", 1, missing.left);
    }

    private static void sizedPayload() {
        Packbin.Packet layout = Packbin.packet(Packbin.u16("n"), Packbin.sized("payload", "n"));
        Map<String, Object> values = new HashMap<>();
        values.put("n", 3);
        values.put("payload", parseHex("756176"));
        byte[] raw = Packbin.pack(layout, values);
        expectEq("sized hex", "0300756176", toHex(raw));
        Packbin.UnpackResult got = Packbin.unpack(layout, raw);
        expectTrue("sized ok", got.ok);
        expectEq("sized payload", 0, mismatchedBytes((byte[]) got.value.get("payload"), parseHex("756176")));
        Map<String, Object> emptyValues = new HashMap<>();
        emptyValues.put("n", 0);
        emptyValues.put("payload", new byte[0]);
        byte[] empty = Packbin.pack(layout, emptyValues);
        expectEq("sized empty hex", "0000", toHex(empty));
        Packbin.UnpackResult emptyGot = Packbin.unpack(layout, empty);
        expectTrue("sized empty ok", emptyGot.ok);
        expectEq("sized empty length", 0, ((byte[]) emptyGot.value.get("payload")).length);
        Packbin.UnpackResult shortRead = Packbin.unpack(layout, parseHex("030075"));
        expectEq("sized short values", 0, shortRead.value.size());
        expectTrue("sized short error", shortRead.error instanceof Packbin.ShortPacket);
        Packbin.ShortPacket missing = (Packbin.ShortPacket) shortRead.error;
        expectEq("sized short field", "payload", missing.field);
        expectEq("sized short needed", 3, missing.needed);
        expectEq("sized short left", 1, missing.left);
    }

    private static void u2Kinds() {
        Packbin.Packet kinds = Packbin.packet(Packbin.u2("a", "b", "c", "d"));
        Map<String, Object> values = new HashMap<>();
        values.put("a", 0);
        values.put("b", 1);
        values.put("c", 2);
        values.put("d", 3);
        byte[] raw = Packbin.pack(kinds, values);
        expectEq("u2 hex", "e4", toHex(raw));
        Packbin.UnpackResult got = Packbin.unpack(kinds, raw);
        expectTrue("u2 ok", got.ok);
        expectEq("u2 a", 0, ((Number) got.value.get("a")).intValue());
        expectEq("u2 b", 1, ((Number) got.value.get("b")).intValue());
        expectEq("u2 c", 2, ((Number) got.value.get("c")).intValue());
        expectEq("u2 d", 3, ((Number) got.value.get("d")).intValue());
        Map<String, Object> oneValues = new HashMap<>();
        oneValues.put("a", 1);
        byte[] one = Packbin.pack(Packbin.packet(Packbin.u2("a")), oneValues);
        expectEq("u2 one", "01", toHex(one));
    }

    private static void bitsSegs() {
        Packbin.Packet layout = Packbin.packet(Packbin.u8("n"), Packbin.bits("segs", "n"));
        Map<String, Object> eightValues = new HashMap<>();
        eightValues.put("n", 8);
        eightValues.put("segs", List.of(1, 1, 1, 1, 1, 1, 1, 1));
        byte[] eight = Packbin.pack(layout, eightValues);
        expectEq("bits eight payload", "ff", toHex(java.util.Arrays.copyOfRange(eight, 1, eight.length)));
        expectEq("bits eight adds", 1, eight.length - 1);
        Map<String, Object> nineValues = new HashMap<>();
        nineValues.put("n", 9);
        nineValues.put("segs", List.of(1, 1, 1, 1, 1, 1, 1, 1, 1));
        byte[] nine = Packbin.pack(layout, nineValues);
        expectEq("bits nine adds", 2, nine.length - 1);
        expectEq("bits nine lo", 0xFF, nine[1] & 0xFF);
        expectEq("bits nine hi masked", 0, nine[2] & 0xFE);
        Packbin.UnpackResult shortRead = Packbin.unpack(layout, new byte[] {9, 0x01});
        expectEq("bits short values", 0, shortRead.value.size());
        expectTrue("bits short error", shortRead.error instanceof Packbin.ShortPacket);
        Packbin.ShortPacket missing = (Packbin.ShortPacket) shortRead.error;
        expectEq("bits short field", "segs", missing.field);
        expectEq("bits short needed", 2, missing.needed);
        expectEq("bits short left", 1, missing.left);
    }

    private static void nfrRoundTripsWithinOneSecond() throws IOException {
        long start = System.nanoTime();
        for (int i = 0; i < 100_000; i++) {
            byte[] bytes = Packbin.pack(TARGET, position());
            Packbin.UnpackResult got = Packbin.unpack(TARGET, bytes);
            if (!got.ok) {
                fail("NFR unpack failed");
                return;
            }
            if (((Number) got.value.get("lat")).intValue() != 500_000_000) {
                fail("NFR lat mismatch");
                return;
            }
        }
        assertNoGpu();
        double seconds = (System.nanoTime() - start) / 1_000_000_000.0;
        if (seconds > 1.0) {
            fail("NFR elapsed " + seconds + "s > 1s");
        } else {
            System.out.println("NFR round trips: " + seconds + "s");
        }
    }

    private static void assertNoGpu() throws IOException {
        Path maps = Path.of("/proc/self/maps");
        if (!Files.exists(maps)) {
            return;
        }
        String blob = Files.readString(maps).toLowerCase(Locale.ROOT);
        for (String bad : new String[] {"libcuda", "libnvidia", "libvulkan", "libopencl", "metal.framework"}) {
            if (blob.contains(bad)) {
                fail("GPU library loaded: " + bad);
            }
        }
    }

    private static int countNamed(Map<String, Object> values, String... names) {
        int n = 0;
        for (String name : names) {
            if (values.containsKey(name) && values.get(name) != null) {
                n++;
            }
        }
        return n;
    }

    private static int mismatchedBytes(byte[] actual, byte[] expected) {
        int mismatches = Math.abs(actual.length - expected.length);
        int shared = Math.min(actual.length, expected.length);
        for (int i = 0; i < shared; i++) {
            if (actual[i] != expected[i]) {
                mismatches++;
            }
        }
        return mismatches;
    }

    private static String toHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder(bytes.length * 2);
        for (byte b : bytes) {
            sb.append(String.format(Locale.ROOT, "%02x", b & 0xFF));
        }
        return sb.toString();
    }

    private static void objectRoundTrip() {
        PositionRow row = new PositionRow();
        row.type = 0x40;
        row.sid = 1;
        row.lat = 500_000_000;
        row.lon = 300_000_000;
        row.profile = 1;
        byte[] bytes = Packbin.pack(TARGET, row);
        expectEq("object hex", GOLDEN_HEX, toHex(bytes));
        Packbin.Bound<PositionRow> got = Packbin.unpack(TARGET, bytes, PositionRow.class);
        expectTrue("object ok", got.ok);
        expectEq("object type", (byte) 0x40, got.value.type);
        expectEq("object sid", 1, got.value.sid);
        expectEq("object lat", 500_000_000, got.value.lat);
        expectEq("object lon", 300_000_000, got.value.lon);
        expectEq("object profile", (byte) 1, got.value.profile);
        expectTrue("object heading absent", got.value.heading == null);
        expectTrue("object speed absent", got.value.speed == null);
        expectTrue("object altitude absent", got.value.altitude == null);

        Packbin.Packet wide = Packbin.packet(Packbin.flags(
                "f",
                Packbin.u8("a"),
                Packbin.u8("b"),
                Packbin.u8("c"),
                Packbin.u8("d"),
                Packbin.u8("e"),
                Packbin.u16("b5")));
        expectEq("object absent bit", "00", toHex(Packbin.pack(wide, new WideRow())));
        WideRow present = new WideRow();
        present.b5 = 0;
        expectEq("object present zero", "200000", toHex(Packbin.pack(wide, present)));

        Packbin.Packet session = Packbin.packet(
                Packbin.flags("f", Packbin.group("session", Packbin.u16("login"), Packbin.u32("ts"))));
        expectEq("object group clear", "00", toHex(Packbin.pack(session, new SessionRow())));
        SessionRow set = new SessionRow();
        set.session = new Session();
        set.session.login = 7;
        set.session.ts = 1000;
        byte[] packed = Packbin.pack(session, set);
        expectEq("object group set", "010700e8030000", toHex(packed));
        Packbin.Bound<SessionRow> back = Packbin.unpack(session, packed, SessionRow.class);
        expectTrue("object group ok", back.ok && back.value.session != null);
        expectEq("object login", 7, back.value.session.login);
        expectEq("object ts", 1000L, back.value.session.ts);
        Packbin.Bound<SessionRow> shortRow = Packbin.unpack(session, new byte[] {0x01, 0x07}, SessionRow.class);
        expectTrue("object short", !shortRow.ok && shortRow.value == null);
        expectEq("object short field", "login", ((Packbin.ShortPacket) shortRow.error).field);
    }

    private static byte[] parseHex(String hex) {
        hex = hex.trim();
        byte[] bytes = new byte[hex.length() / 2];
        for (int i = 0; i < bytes.length; i++) {
            bytes[i] = (byte) Integer.parseInt(hex.substring(i * 2, i * 2 + 2), 16);
        }
        return bytes;
    }

    private static Path findGoldenFixture() throws IOException {
        Path dir = Path.of(System.getProperty("user.dir")).toAbsolutePath().normalize();
        while (dir != null) {
            Path candidate = dir.resolve("fixtures").resolve("golden.hex");
            if (Files.isRegularFile(candidate)) {
                return candidate;
            }
            dir = dir.getParent();
        }
        throw new IOException("fixtures/golden.hex not found");
    }

    private static void expectEq(String label, Object expected, Object actual) {
        if (expected == null ? actual != null : !expected.equals(actual)) {
            fail(label + ": expected " + expected + ", got " + actual);
        }
    }

    private static void expectTrue(String label, boolean condition) {
        if (!condition) {
            fail(label + ": expected true");
        }
    }

    private static void fail(String message) {
        failures++;
        System.err.println("FAIL " + message);
    }
}
