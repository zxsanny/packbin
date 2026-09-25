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

    private static final Scheme<PositionRow> TARGET = new Scheme<>(
            0x40,
            PositionRow.class,
            Packbin.u16(0, Access.get((PositionRow r) -> r.sid), Access.set((PositionRow r, Object v) -> r.sid = ((Number) v).intValue())),
            Packbin.i32(1, Access.get((PositionRow r) -> r.lat), Access.set((PositionRow r, Object v) -> r.lat = ((Number) v).intValue())),
            Packbin.i32(2, Access.get((PositionRow r) -> r.lon), Access.set((PositionRow r, Object v) -> r.lon = ((Number) v).intValue())),
            Packbin.u8(3, Access.get((PositionRow r) -> r.profile & 0xFF), Access.set((PositionRow r, Object v) -> r.profile = ((Number) v).byteValue())),
            Packbin.flags(
                    Packbin.u16(4, Access.get((PositionRow r) -> r.heading), Access.set((PositionRow r, Object v) -> r.heading = v == null ? null : ((Number) v).intValue())),
                    Packbin.u8(5, Access.get((PositionRow r) -> r.speed), Access.set((PositionRow r, Object v) -> r.speed = v == null ? null : ((Number) v).intValue())),
                    Packbin.i16(6, Access.get((PositionRow r) -> r.altitude), Access.set((PositionRow r, Object v) -> r.altitude = v == null ? null : ((Number) v).intValue()))));

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

    private static PositionRow position() {
        PositionRow row = new PositionRow();
        row.sid = 1;
        row.lat = 500_000_000;
        row.lon = 300_000_000;
        row.profile = 1;
        return row;
    }

    private static void ac1PositionPack() {
        byte[] bytes = BinaryPacker.pack(TARGET, position());
        String hex = toHex(bytes);
        int mismatched = mismatchedBytes(bytes, parseHex(GOLDEN_HEX));
        expectEq("AC-1 hex", GOLDEN_HEX, hex);
        expectEq("AC-1 mismatched", 0, mismatched);
        expectEq("AC-1 length", 13, bytes.length);
        byte[] again = BinaryPacker.pack(TARGET, position());
        expectEq("AC-1 packed twice", 0, mismatchedBytes(bytes, again));
    }

    private static void ac2PositionUnpack() {
        PositionRow[] got = new PositionRow[1];
        Object err = BinaryPacker.unpack(parseHex(GOLDEN_HEX), TARGET.on(row -> got[0] = row));
        expectTrue("AC-2 ok", err == null);
        expectEq("AC-2 sid", 1, got[0].sid);
        expectEq("AC-2 lat", 500_000_000, got[0].lat);
        expectEq("AC-2 lon", 300_000_000, got[0].lon);
        expectEq("AC-2 profile", (byte) 1, got[0].profile);
        expectTrue("AC-2 heading absent", got[0].heading == null);
        expectTrue("AC-2 speed absent", got[0].speed == null);
        expectTrue("AC-2 altitude absent", got[0].altitude == null);
    }

    private static void ac3BytesMatchFixture() throws IOException {
        byte[] bytes = BinaryPacker.pack(TARGET, position());
        byte[] fixture = parseHex(Files.readString(findGoldenFixture()).trim());
        expectEq("AC-3 mismatched", 0, mismatchedBytes(bytes, fixture));
    }

    private static void ac4FlagsAndStoredZero() {
        Field flags = Packbin.flags(
                Packbin.u8(0, Access.get("b0"), Access.set("b0")),
                Packbin.u8(1, Access.get("b1"), Access.set("b1")),
                Packbin.u8(2, Access.get("b2"), Access.set("b2")),
                Packbin.u8(3, Access.get("b3"), Access.set("b3")),
                Packbin.u8(4, Access.get("b4"), Access.set("b4")),
                Packbin.u16(5, Access.get("wide"), Access.set("wide")));
        Scheme<Map> packet = Maps.scheme(1, flags);

        byte[] clear = BinaryPacker.pack(packet, new HashMap<>());
        expectEq("AC-4 clear length", 2, clear.length);
        expectEq("AC-4 clear type", 0x01, clear[0] & 0xFF);
        expectEq("AC-4 clear byte", 0x00, clear[1] & 0xFF);
        expectEq("AC-4 flags 0x00 adds", 0, clear.length - 2);

        Map<String, Object> setBit5 = Maps.map("wide", 0x1234);
        byte[] withWide = BinaryPacker.pack(packet, setBit5);
        expectEq("AC-4 0x20 length", 4, withWide.length);
        expectEq("AC-4 0x20 flags", 0x20, withWide[1] & 0xFF);
        expectEq("AC-4 0x20 adds 2", 2, withWide.length - clear.length);

        Map<String, Object> presentZero = Maps.map("wide", 0);
        byte[] zero = BinaryPacker.pack(packet, presentZero);
        expectEq("AC-4 present 0 length", 4, zero.length);
        expectEq("AC-4 present 0 flags", 0x20, zero[1] & 0xFF);
        expectEq("AC-4 present 0 lo", 0x00, zero[2] & 0xFF);
        expectEq("AC-4 present 0 hi", 0x00, zero[3] & 0xFF);

        byte[] absent = BinaryPacker.pack(packet, new HashMap<>());
        expectEq("AC-4 absence length", 2, absent.length);
        expectEq("AC-4 absence does not write 0 payload", 0, absent.length - 2);
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private static void ac5ShortBufferThenPositionPack() {
        Field flags = Packbin.flags(
                Packbin.u8(0, Access.get("b0"), Access.set("b0")),
                Packbin.u8(1, Access.get("b1"), Access.set("b1")),
                Packbin.u8(2, Access.get("b2"), Access.set("b2")),
                Packbin.u8(3, Access.get("b3"), Access.set("b3")),
                Packbin.u8(4, Access.get("b4"), Access.set("b4")),
                Packbin.u16(5, Access.get("wide"), Access.set("wide")));
        Scheme<Map> packet = Maps.scheme(1, flags);
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(new byte[] {0x01, 0x20, 0x34}, packet.on(row -> got[0] = row));
        expectTrue("AC-5 not ok", err != null);
        expectTrue("AC-5 handler did not run", got[0] == null);
        expectTrue("AC-5 error is ShortPacket", err instanceof Packbin.ShortPacket);
        Packbin.ShortPacket missing = (Packbin.ShortPacket) err;
        expectEq("AC-5 field", "5", missing.field);
        expectEq("AC-5 needed", 2, missing.needed);
        expectEq("AC-5 left", 1, missing.left);

        byte[] bytes = BinaryPacker.pack(TARGET, position());
        expectEq("AC-5 next pack hex", GOLDEN_HEX, toHex(bytes));
    }

    private static void whenGroupWidth() {
        Scheme<Map> packet = Maps.scheme(1,
                Packbin.u8(0, Access.get("profile"), Access.set("profile")),
                Packbin.when(Packbin.eq(0, 0), Packbin.u8(1, Access.get("shape"), Access.set("shape"))));

        byte[] miss = BinaryPacker.pack(packet, Maps.map("profile", 1));
        expectEq("when miss length", 2, miss.length);

        byte[] hit = BinaryPacker.pack(packet, Maps.map("profile", 0, "shape", 9));
        expectEq("when hit length", 3, hit.length);
        expectEq("when added", 1, hit.length - miss.length);
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private static void repeatBoundary() {
        Scheme<Map> packet = Maps.scheme(1, Packbin.repeat(
                Packbin.u8(0, Access.get("a"), Access.set("a")),
                Packbin.u8(1, Access.get("b"), Access.set("b"))));

        Map[] ok = new Map[1];
        Object okErr = BinaryPacker.unpack(new byte[] {0x01, 1, 2}, packet.on(row -> ok[0] = row));
        expectTrue("repeat ok", okErr == null);
        expectTrue("repeat list", ok[0].get("a") instanceof List);
        expectEq("repeat count", 1, ((List<?>) ok[0].get("a")).size());

        Map[] bad = new Map[1];
        Object badErr = BinaryPacker.unpack(new byte[] {0x01, 1, 2, 3}, packet.on(row -> bad[0] = row));
        expectTrue("repeat short", badErr != null);
        expectTrue("repeat handler did not run", bad[0] == null);
        expectTrue("repeat short error", badErr instanceof Packbin.ShortPacket);
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private static void trailingBytesAreError() {
        Scheme<Map> packet = Maps.scheme(1, Packbin.u8(0, Access.get("type"), Access.set("type")));
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(new byte[] {0x01, 0x40, (byte) 0x99}, packet.on(row -> got[0] = row));
        expectTrue("trailing handler did not run", got[0] == null);
        expectTrue("trailing error", err instanceof Packbin.TrailingBytes);
        expectEq("trailing left", 1, ((Packbin.TrailingBytes) err).left);
    }

    private static void nfrRoundTripsWithinOneSecond() throws IOException {
        long start = System.nanoTime();
        for (int i = 0; i < 100_000; i++) {
            byte[] bytes = BinaryPacker.pack(TARGET, position());
            PositionRow[] got = new PositionRow[1];
            Object err = BinaryPacker.unpack(bytes, TARGET.on(row -> got[0] = row));
            if (err != null) {
                fail("NFR unpack failed");
                return;
            }
            if (got[0].lat != 500_000_000) {
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
        PositionRow row = position();
        byte[] bytes = BinaryPacker.pack(TARGET, row);
        expectEq("object hex", GOLDEN_HEX, toHex(bytes));
        PositionRow[] got = new PositionRow[1];
        Object err = BinaryPacker.unpack(bytes, TARGET.on(r -> got[0] = r));
        expectTrue("object ok", err == null);
        expectEq("object sid", 1, got[0].sid);
        expectEq("object lat", 500_000_000, got[0].lat);
        expectEq("object lon", 300_000_000, got[0].lon);
        expectEq("object profile", (byte) 1, got[0].profile);
        expectTrue("object heading absent", got[0].heading == null);
        expectTrue("object speed absent", got[0].speed == null);
        expectTrue("object altitude absent", got[0].altitude == null);

        Field wideFlags = Packbin.flags(
                Packbin.u8(0, Access.get((WideRow r) -> null), Access.set((WideRow r, Object v) -> {})),
                Packbin.u8(1, Access.get((WideRow r) -> null), Access.set((WideRow r, Object v) -> {})),
                Packbin.u8(2, Access.get((WideRow r) -> null), Access.set((WideRow r, Object v) -> {})),
                Packbin.u8(3, Access.get((WideRow r) -> null), Access.set((WideRow r, Object v) -> {})),
                Packbin.u8(4, Access.get((WideRow r) -> null), Access.set((WideRow r, Object v) -> {})),
                Packbin.u16(5, Access.get((WideRow r) -> r.b5), Access.set((WideRow r, Object v) -> r.b5 = v == null ? null : ((Number) v).intValue())));
        Scheme<WideRow> wide = new Scheme<>(1, WideRow.class, wideFlags);
        expectEq("object absent bit", "0100", toHex(BinaryPacker.pack(wide, new WideRow())));
        WideRow present = new WideRow();
        present.b5 = 0;
        expectEq("object present zero", "01200000", toHex(BinaryPacker.pack(wide, present)));

        Scheme<SessionRow> session = new Scheme<>(1, SessionRow.class,
                Packbin.flags(Packbin.group(
                        Packbin.u16(0, Access.get((SessionRow r) -> r.login), Access.set((SessionRow r, Object v) -> r.login = v == null ? null : ((Number) v).intValue())),
                        Packbin.u32(1, Access.get((SessionRow r) -> r.ts), Access.set((SessionRow r, Object v) -> r.ts = v == null ? null : ((Number) v).longValue())))));
        expectEq("object group clear", "0100", toHex(BinaryPacker.pack(session, new SessionRow())));
        SessionRow set = new SessionRow();
        set.login = 7;
        set.ts = 1000L;
        byte[] packed = BinaryPacker.pack(session, set);
        expectEq("object group set", "01010700e8030000", toHex(packed));
        SessionRow[] back = new SessionRow[1];
        Object backErr = BinaryPacker.unpack(packed, session.on(r -> back[0] = r));
        expectTrue("object group ok", backErr == null);
        expectEq("object login", 7, back[0].login);
        expectEq("object ts", 1000L, back[0].ts);
        SessionRow[] shortRow = new SessionRow[1];
        Object shortErr = BinaryPacker.unpack(new byte[] {0x01, 0x01, 0x07}, session.on(r -> shortRow[0] = r));
        expectTrue("object short", shortErr != null && shortRow[0] == null);
        expectEq("object short field", "0", ((Packbin.ShortPacket) shortErr).field);
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
