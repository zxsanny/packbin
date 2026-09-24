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
        Packbin.Bound<PositionRow> got = BinaryPacker.unpack(TARGET, parseHex(GOLDEN_HEX));
        expectTrue("AC-2 ok", got.ok);
        expectEq("AC-2 sid", 1, got.value.sid);
        expectEq("AC-2 lat", 500_000_000, got.value.lat);
        expectEq("AC-2 lon", 300_000_000, got.value.lon);
        expectEq("AC-2 profile", (byte) 1, got.value.profile);
        expectTrue("AC-2 heading absent", got.value.heading == null);
        expectTrue("AC-2 speed absent", got.value.speed == null);
        expectTrue("AC-2 altitude absent", got.value.altitude == null);
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

    private static void ac5ShortBufferThenPositionPack() {
        Field flags = Packbin.flags(
                Packbin.u8(0, Access.get("b0"), Access.set("b0")),
                Packbin.u8(1, Access.get("b1"), Access.set("b1")),
                Packbin.u8(2, Access.get("b2"), Access.set("b2")),
                Packbin.u8(3, Access.get("b3"), Access.set("b3")),
                Packbin.u8(4, Access.get("b4"), Access.set("b4")),
                Packbin.u16(5, Access.get("wide"), Access.set("wide")));
        Scheme<Map> packet = Maps.scheme(1, flags);
        Packbin.Bound<Map> got = BinaryPacker.unpack(packet, new byte[] {0x01, 0x20, 0x34});
        expectTrue("AC-5 not ok", !got.ok);
        expectTrue("AC-5 error is ShortPacket", got.error instanceof Packbin.ShortPacket);
        Packbin.ShortPacket missing = (Packbin.ShortPacket) got.error;
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

    private static void repeatBoundary() {
        Scheme<Map> packet = Maps.scheme(1, Packbin.repeat(
                Packbin.u8(0, Access.get("a"), Access.set("a")),
                Packbin.u8(1, Access.get("b"), Access.set("b"))));

        Packbin.Bound<Map> ok = BinaryPacker.unpack(packet, new byte[] {0x01, 1, 2});
        expectTrue("repeat ok", ok.ok);
        expectTrue("repeat list", ok.value.get("a") instanceof List);
        expectEq("repeat count", 1, ((List<?>) ok.value.get("a")).size());

        Packbin.Bound<Map> bad = BinaryPacker.unpack(packet, new byte[] {0x01, 1, 2, 3});
        expectTrue("repeat short", !bad.ok);
        expectTrue("repeat short error", bad.error instanceof Packbin.ShortPacket);
    }

    private static void trailingBytesAreError() {
        Scheme<Map> packet = Maps.scheme(1, Packbin.u8(0, Access.get("type"), Access.set("type")));
        Packbin.Bound<Map> got = BinaryPacker.unpack(packet, new byte[] {0x01, 0x40, (byte) 0x99});
        expectTrue("trailing error", got.error instanceof Packbin.TrailingBytes);
        expectEq("trailing left", 1, ((Packbin.TrailingBytes) got.error).left);
    }

    private static void nfrRoundTripsWithinOneSecond() throws IOException {
        long start = System.nanoTime();
        for (int i = 0; i < 100_000; i++) {
            byte[] bytes = BinaryPacker.pack(TARGET, position());
            Packbin.Bound<PositionRow> got = BinaryPacker.unpack(TARGET, bytes);
            if (!got.ok) {
                fail("NFR unpack failed");
                return;
            }
            if (got.value.lat != 500_000_000) {
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
        Packbin.Bound<PositionRow> got = BinaryPacker.unpack(TARGET, bytes);
        expectTrue("object ok", got.ok);
        expectEq("object sid", 1, got.value.sid);
        expectEq("object lat", 500_000_000, got.value.lat);
        expectEq("object lon", 300_000_000, got.value.lon);
        expectEq("object profile", (byte) 1, got.value.profile);
        expectTrue("object heading absent", got.value.heading == null);
        expectTrue("object speed absent", got.value.speed == null);
        expectTrue("object altitude absent", got.value.altitude == null);

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
        Packbin.Bound<SessionRow> back = BinaryPacker.unpack(session, packed);
        expectTrue("object group ok", back.ok);
        expectEq("object login", 7, back.value.login);
        expectEq("object ts", 1000L, back.value.ts);
        Packbin.Bound<SessionRow> shortRow = BinaryPacker.unpack(session, new byte[] {0x01, 0x01, 0x07});
        expectTrue("object short", !shortRow.ok && shortRow.value == null);
        expectEq("object short field", "0", ((Packbin.ShortPacket) shortRow.error).field);
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
