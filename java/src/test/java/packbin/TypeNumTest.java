package packbin;

import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.HashMap;
import java.util.Locale;
import java.util.Map;

public final class TypeNumTest {
    private static int failures;

    private static final Packbin.Packet MARKER = Packbin.packet(
            Packbin.TypeNum.set(32),
            Packbin.u8("sid"));

    private static final Packbin.Packet POSITION = Packbin.packet(
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
        ac1ConstantU8IsNotAValue();
        ac2UnpackDropsTheConstant();
        ac3WrongTypeByte();
        ac4AbsentTypeNumber();
        ac5SchemeRejected();
        if (failures > 0) {
            System.err.println(failures + " failure(s)");
            System.exit(1);
        }
        System.out.println("TypeNum tests passed");
    }

    private static void ac1ConstantU8IsNotAValue() {
        Map<String, Object> values = new HashMap<>();
        values.put("sid", 23);
        byte[] bytes = Packbin.pack(MARKER, values);
        expectEq("AC-1 hex", "2017", toHex(bytes));
        expectEq("AC-1 byte0", 0x20, bytes[0] & 0xFF);
        expectEq("AC-1 byte1", 0x17, bytes[1] & 0xFF);
        expectEq("AC-1 length", 2, bytes.length);
    }

    private static void ac2UnpackDropsTheConstant() {
        Packbin.UnpackResult got = Packbin.unpack(MARKER, parseHex("2017"));
        expectTrue("AC-2 ok", got.ok);
        expectEq("AC-2 sid", 23, ((Number) got.value.get("sid")).intValue());
        expectTrue("AC-2 no type", !got.value.containsKey("type"));
        expectEq("AC-2 value count", 1, got.value.size());
    }

    private static void ac3WrongTypeByte() {
        Packbin.UnpackResult got = Packbin.unpack(MARKER, parseHex("2117"));
        expectTrue("AC-3 not ok", !got.ok);
        expectEq("AC-3 value count", 0, got.value.size());
        expectTrue("AC-3 TypeMismatch", got.error instanceof Packbin.TypeMismatch);
        Packbin.TypeMismatch mismatch = (Packbin.TypeMismatch) got.error;
        expectEq("AC-3 expected", 32, mismatch.expected);
        expectEq("AC-3 actual", 33, mismatch.actual);
    }

    private static void ac4AbsentTypeNumber() throws IOException {
        Map<String, Object> values = new HashMap<>();
        values.put("type", 0x40);
        values.put("sid", 1);
        values.put("lat", 500_000_000);
        values.put("lon", 300_000_000);
        values.put("profile", 1);
        byte[] bytes = Packbin.pack(POSITION, values);
        byte[] fixture = parseHex(Files.readString(findGoldenFixture()).trim());
        expectEq("AC-4 mismatched", 0, mismatchedBytes(bytes, fixture));
        expectEq("AC-4 hex", GOLDEN_HEX, toHex(bytes));
        Packbin.UnpackResult got = Packbin.unpack(POSITION, fixture);
        expectTrue("AC-4 ok", got.ok);
        expectEq("AC-4 type", 0x40, ((Number) got.value.get("type")).intValue());
        expectEq("AC-4 sid", 1, ((Number) got.value.get("sid")).intValue());
    }

    private static void ac5SchemeRejected() {
        expectThrows("AC-5 not first", () ->
                Packbin.packet(Packbin.u8("sid"), Packbin.TypeNum.set(32)));
        expectThrows("AC-5 twice", () ->
                Packbin.packet(Packbin.TypeNum.set(32), Packbin.TypeNum.set(33), Packbin.u8("sid")));
        expectThrows("AC-5 nested flags", () ->
                Packbin.packet(Packbin.flags("f", Packbin.TypeNum.set(32))));
        expectThrows("AC-5 nested when", () ->
                Packbin.packet(Packbin.when(Packbin.eq("x", 1), Packbin.TypeNum.set(32))));
        expectThrows("AC-5 nested repeat", () ->
                Packbin.packet(Packbin.repeat(Packbin.TypeNum.set(32))));
        expectThrows("AC-5 nested group", () ->
                Packbin.packet(Packbin.group("g", Packbin.TypeNum.set(32))));
        expectThrows("AC-5 nested list", () ->
                Packbin.packet(Packbin.list("xs", Packbin.TypeNum.set(32))));
        expectThrows("AC-5 nested dict", () ->
                Packbin.packet(Packbin.dict("d", Packbin.TypeNum.set(32))));
        expectThrows("AC-5 above 255", () -> Packbin.TypeNum.set(256));
        expectThrows("AC-5 below 0", () -> Packbin.TypeNum.set(-1));
    }

    private static void expectThrows(String label, Runnable action) {
        try {
            action.run();
            fail(label + ": expected exception");
        } catch (IllegalArgumentException | IllegalStateException ex) {
            // ok
        }
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
