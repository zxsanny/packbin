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
        nfrRoundTripsWithinOneSecond();
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
        Packbin.UnpackResult got = Packbin.unpack(TARGET, parseHex("4001"));
        expectEq("AC-5 value count", 0, got.value.size());
        expectTrue("AC-5 error is ShortPacket", got.error instanceof Packbin.ShortPacket);
        Packbin.ShortPacket missing = (Packbin.ShortPacket) got.error;
        expectEq("AC-5 field", "sid", missing.field);
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

    private static void nfrRoundTripsWithinOneSecond() {
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
        double seconds = (System.nanoTime() - start) / 1_000_000_000.0;
        if (seconds > 1.0) {
            fail("NFR elapsed " + seconds + "s > 1s");
        } else {
            System.out.println("NFR round trips: " + seconds + "s");
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
