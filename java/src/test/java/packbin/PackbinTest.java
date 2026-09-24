package packbin;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

public final class PackbinTest {
    private static int failures;

    private static final Scheme<PositionRow> TARGET = new Scheme<>(
            0x40,
            PositionRow.class,
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
        nfrRoundTripsWithinOneSecond();
        objectRoundTrip();
        PackbinFieldsTest.run();
        if (failures + PackbinFieldsTest.failures > 0) {
            System.err.println((failures + PackbinFieldsTest.failures) + " failure(s)");
            System.exit(1);
        }
        System.out.println("All tests passed");
    }

    private static Map<String, Object> position() {
        Map<String, Object> values = new HashMap<>();
        values.put("sid", 1);
        values.put("lat", 500_000_000);
        values.put("lon", 300_000_000);
        values.put("profile", 1);
        return values;
    }

    private static void ac1PositionPack() {
        byte[] bytes = Pack.run(TARGET, position());
        String hex = toHex(bytes);
        int mismatched = mismatchedBytes(bytes, parseHex(GOLDEN_HEX));
        expectEq("AC-1 hex", GOLDEN_HEX, hex);
        expectEq("AC-1 mismatched", 0, mismatched);
        expectEq("AC-1 length", 13, bytes.length);
        byte[] again = Pack.run(TARGET, position());
        expectEq("AC-1 packed twice", 0, mismatchedBytes(bytes, again));
    }

    private static void ac2PositionUnpack() {
        Packbin.UnpackResult got = Unpack.values(TARGET, parseHex(GOLDEN_HEX));
        expectTrue("AC-2 ok", got.ok);
        expectTrue("AC-2 no type", !got.value.containsKey("type"));
        expectEq("AC-2 sid", 1, ((Number) got.value.get("sid")).intValue());
        expectEq("AC-2 lat", 500_000_000, ((Number) got.value.get("lat")).intValue());
        expectEq("AC-2 lon", 300_000_000, ((Number) got.value.get("lon")).intValue());
        expectEq("AC-2 profile", 1, ((Number) got.value.get("profile")).intValue());
        int motionFields = 0;
        if (got.value.containsKey("heading")) motionFields++;
        if (got.value.containsKey("speed")) motionFields++;
        if (got.value.containsKey("altitude")) motionFields++;
        expectEq("AC-2 motion field count", 0, motionFields);
        expectEq("AC-2 four fields", 4, countNamed(got.value, "sid", "lat", "lon", "profile"));
    }

    private static void ac3BytesMatchFixture() throws IOException {
        byte[] bytes = Pack.run(TARGET, position());
        byte[] fixture = parseHex(Files.readString(findGoldenFixture()).trim());
        expectEq("AC-3 mismatched", 0, mismatchedBytes(bytes, fixture));
    }

    private static void ac4FlagsAndStoredZero() {
        Scheme<MapRow> packet = new Scheme<>(1, MapRow.class, Packbin.flags(
                "flags",
                Packbin.u8("b0"),
                Packbin.u8("b1"),
                Packbin.u8("b2"),
                Packbin.u8("b3"),
                Packbin.u8("b4"),
                Packbin.u16("wide")));

        byte[] clear = Pack.run(packet, Map.of());
        expectEq("AC-4 clear length", 2, clear.length);
        expectEq("AC-4 clear type", 0x01, clear[0] & 0xFF);
        expectEq("AC-4 clear byte", 0x00, clear[1] & 0xFF);
        expectEq("AC-4 flags 0x00 adds", 0, clear.length - 2);

        Map<String, Object> setBit5 = new HashMap<>();
        setBit5.put("wide", 0x1234);
        byte[] withWide = Pack.run(packet, setBit5);
        expectEq("AC-4 0x20 length", 4, withWide.length);
        expectEq("AC-4 0x20 flags", 0x20, withWide[1] & 0xFF);
        expectEq("AC-4 0x20 adds 2", 2, withWide.length - clear.length);

        Map<String, Object> presentZero = new HashMap<>();
        presentZero.put("wide", 0);
        byte[] zero = Pack.run(packet, presentZero);
        expectEq("AC-4 present 0 length", 4, zero.length);
        expectEq("AC-4 present 0 flags", 0x20, zero[1] & 0xFF);
        expectEq("AC-4 present 0 lo", 0x00, zero[2] & 0xFF);
        expectEq("AC-4 present 0 hi", 0x00, zero[3] & 0xFF);

        byte[] absent = Pack.run(packet, new HashMap<>());
        expectEq("AC-4 absence length", 2, absent.length);
        expectEq("AC-4 absence does not write 0 payload", 0, absent.length - 2);
    }

    private static void ac5ShortBufferThenPositionPack() {
        Scheme<MapRow> packet = new Scheme<>(1, MapRow.class, Packbin.flags(
                "flags",
                Packbin.u8("b0"),
                Packbin.u8("b1"),
                Packbin.u8("b2"),
                Packbin.u8("b3"),
                Packbin.u8("b4"),
                Packbin.u16("wide")));
        Packbin.UnpackResult got = Unpack.values(packet, new byte[] {0x01, 0x20, 0x34});
        expectEq("AC-5 value count", 0, got.value.size());
        expectTrue("AC-5 error is ShortPacket", got.error instanceof Packbin.ShortPacket);
        Packbin.ShortPacket missing = (Packbin.ShortPacket) got.error;
        expectEq("AC-5 field", "wide", missing.field);
        expectEq("AC-5 needed", 2, missing.needed);
        expectEq("AC-5 left", 1, missing.left);

        byte[] bytes = Pack.run(TARGET, position());
        expectEq("AC-5 next pack hex", GOLDEN_HEX, toHex(bytes));
    }

    private static void whenGroupWidth() {
        Scheme<MapRow> packet = new Scheme<>(1, MapRow.class,
                Packbin.u8("profile"),
                Packbin.when(Packbin.eq("profile", 0), Packbin.u8("shape")));

        Map<String, Object> missValues = new HashMap<>();
        missValues.put("profile", 1);
        byte[] miss = Pack.run(packet, missValues);
        expectEq("when miss length", 2, miss.length);

        Map<String, Object> hitValues = new HashMap<>();
        hitValues.put("profile", 0);
        hitValues.put("shape", 9);
        byte[] hit = Pack.run(packet, hitValues);
        expectEq("when hit length", 3, hit.length);
        expectEq("when added", 1, hit.length - miss.length);
    }

    private static void repeatBoundary() {
        Scheme<MapRow> packet = new Scheme<>(1, MapRow.class, Packbin.repeat(Packbin.u8("a"), Packbin.u8("b")));

        Packbin.UnpackResult ok = Unpack.values(packet, new byte[] {0x01, 1, 2});
        expectTrue("repeat ok", ok.ok);
        expectTrue("repeat list", ok.value.get("a") instanceof java.util.List);
        expectEq("repeat count", 1, ((java.util.List<?>) ok.value.get("a")).size());

        Packbin.UnpackResult bad = Unpack.values(packet, new byte[] {0x01, 1, 2, 3});
        expectEq("repeat short values", 0, bad.value.size());
        expectTrue("repeat short error", bad.error instanceof Packbin.ShortPacket);
    }

    private static void trailingBytesAreError() {
        Scheme<MapRow> packet = new Scheme<>(1, MapRow.class, Packbin.u8("type"));
        Packbin.UnpackResult got = Unpack.values(packet, new byte[] {0x01, 0x40, (byte) 0x99});
        expectEq("trailing values", 0, got.value.size());
        expectTrue("trailing error", got.error instanceof Packbin.TrailingBytes);
        expectEq("trailing left", 1, ((Packbin.TrailingBytes) got.error).left);
    }

    private static void nfrRoundTripsWithinOneSecond() throws IOException {
        long start = System.nanoTime();
        for (int i = 0; i < 100_000; i++) {
            byte[] bytes = Pack.run(TARGET, position());
            Packbin.UnpackResult got = Unpack.values(TARGET, bytes);
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

    private static void objectRoundTrip() {
        PositionRow row = new PositionRow();
        row.sid = 1;
        row.lat = 500_000_000;
        row.lon = 300_000_000;
        row.profile = 1;
        byte[] bytes = Pack.run(TARGET, row);
        expectEq("object hex", GOLDEN_HEX, toHex(bytes));
        Packbin.Bound<PositionRow> got = Unpack.run(TARGET, bytes);
        expectTrue("object ok", got.ok);
        expectEq("object sid", 1, got.value.sid);
        expectEq("object lat", 500_000_000, got.value.lat);
        expectEq("object lon", 300_000_000, got.value.lon);
        expectEq("object profile", (byte) 1, got.value.profile);
        expectTrue("object heading absent", got.value.heading == null);
        expectTrue("object speed absent", got.value.speed == null);
        expectTrue("object altitude absent", got.value.altitude == null);

        Scheme<WideRow> wide = new Scheme<>(1, WideRow.class, Packbin.flags(
                "f",
                Packbin.u8("a"),
                Packbin.u8("b"),
                Packbin.u8("c"),
                Packbin.u8("d"),
                Packbin.u8("e"),
                Packbin.u16("b5")));
        expectEq("object absent bit", "0100", toHex(Pack.run(wide, new WideRow())));
        WideRow present = new WideRow();
        present.b5 = 0;
        expectEq("object present zero", "01200000", toHex(Pack.run(wide, present)));

        Scheme<SessionRow> session = new Scheme<>(1, SessionRow.class,
                Packbin.flags("f", Packbin.group("session", Packbin.u16("login"), Packbin.u32("ts"))));
        expectEq("object group clear", "0100", toHex(Pack.run(session, new SessionRow())));
        SessionRow set = new SessionRow();
        set.session = new Session();
        set.session.login = 7;
        set.session.ts = 1000;
        byte[] packed = Pack.run(session, set);
        expectEq("object group set", "01010700e8030000", toHex(packed));
        Packbin.Bound<SessionRow> back = Unpack.run(session, packed);
        expectTrue("object group ok", back.ok && back.value.session != null);
        expectEq("object login", 7, back.value.session.login);
        expectEq("object ts", 1000L, back.value.session.ts);
        Packbin.Bound<SessionRow> shortRow = Unpack.run(session, new byte[] {0x01, 0x01, 0x07});
        expectTrue("object short", !shortRow.ok && shortRow.value == null);
        expectEq("object short field", "login", ((Packbin.ShortPacket) shortRow.error).field);
    }

    static int countNamed(Map<String, Object> values, String... names) {
        int n = 0;
        for (String name : names) {
            if (values.containsKey(name) && values.get(name) != null) {
                n++;
            }
        }
        return n;
    }

    static int mismatchedBytes(byte[] actual, byte[] expected) {
        int mismatches = Math.abs(actual.length - expected.length);
        int shared = Math.min(actual.length, expected.length);
        for (int i = 0; i < shared; i++) {
            if (actual[i] != expected[i]) {
                mismatches++;
            }
        }
        return mismatches;
    }

    static String toHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder(bytes.length * 2);
        for (byte b : bytes) {
            sb.append(String.format(Locale.ROOT, "%02x", b & 0xFF));
        }
        return sb.toString();
    }

    static byte[] parseHex(String hex) {
        hex = hex.trim();
        byte[] bytes = new byte[hex.length() / 2];
        for (int i = 0; i < bytes.length; i++) {
            bytes[i] = (byte) Integer.parseInt(hex.substring(i * 2, i * 2 + 2), 16);
        }
        return bytes;
    }

    static Path findGoldenFixture() throws IOException {
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

    static void expectEq(String label, Object expected, Object actual) {
        if (expected == null ? actual != null : !expected.equals(actual)) {
            fail(label + ": expected " + expected + ", got " + actual);
        }
    }

    static void expectTrue(String label, boolean condition) {
        if (!condition) {
            fail(label + ": expected true");
        }
    }

    static void fail(String message) {
        failures++;
        System.err.println("FAIL " + message);
    }
}
