package packbin;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;
import java.util.Map;
import java.util.concurrent.TimeUnit;
import java.util.stream.Collectors;

public final class SchemeTest {
    private static int failures;

    public static final class MarkerRow {
        public byte sid;
    }

    private static final Scheme<MarkerRow> MARKER_ROW_SCHEME = Scheme.of(
            MarkerRow.class,
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
        ac1PackTakesTheScheme();
        ac2UnpackTakesTheSameScheme();
        ac3SchemeArgumentIsRequired();
        ac4WrongTypeByte();
        ac5UntypedPath();
        ac6RowStaysData();
        if (failures > 0) {
            System.err.println(failures + " failure(s)");
            System.exit(1);
        }
        System.out.println("Scheme tests passed");
    }

    private static void ac1PackTakesTheScheme() {
        MarkerRow row = new MarkerRow();
        row.sid = 23;
        byte[] bytes = BinaryPacker.pack(MARKER_ROW_SCHEME, row);
        expectEq("AC-1 hex", "2017", toHex(bytes));
        expectEq("AC-1 byte0", 0x20, bytes[0] & 0xFF);
        expectEq("AC-1 byte1", 0x17, bytes[1] & 0xFF);
    }

    private static void ac2UnpackTakesTheSameScheme() {
        Packbin.Bound<MarkerRow> back = BinaryPacker.unpack(MARKER_ROW_SCHEME, parseHex("2017"));
        expectTrue("AC-2 ok", back.ok);
        expectTrue("AC-2 value", back.value != null);
        expectEq("AC-2 sid", (byte) 23, back.value.sid);
        try {
            expectTrue("AC-2 no type field", MarkerRow.class.getField("type") == null);
        } catch (NoSuchFieldException ex) {
            // expected — no type member
        }
        expectEq("AC-2 public field count", 1, MarkerRow.class.getFields().length);
        expectEq("AC-2 field name", "sid", MarkerRow.class.getFields()[0].getName());
    }

    private static void ac3SchemeArgumentIsRequired() throws Exception {
        Path fixture = findCompileFailFixture();
        Path mainOut = findMainOut();
        Path failOut = Files.createTempDirectory("packbin-compile-fail");
        ProcessBuilder pb = new ProcessBuilder(
                "javac",
                "-encoding", "UTF-8",
                "-cp", mainOut.toString(),
                "-d", failOut.toString(),
                fixture.toString());
        pb.redirectErrorStream(true);
        Process process = pb.start();
        String output;
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(process.getInputStream(), StandardCharsets.UTF_8))) {
            output = reader.lines().collect(Collectors.joining("\n"));
        }
        boolean finished = process.waitFor(60, TimeUnit.SECONDS);
        expectTrue("AC-3 javac finished", finished);
        expectTrue(
                "AC-3 expected javac failure, exit=" + process.exitValue() + "\n" + output,
                process.exitValue() != 0);
    }

    private static void ac4WrongTypeByte() {
        Packbin.Bound<MarkerRow> back = BinaryPacker.unpack(MARKER_ROW_SCHEME, parseHex("2117"));
        expectTrue("AC-4 not ok", !back.ok);
        expectTrue("AC-4 no row", back.value == null);
        expectTrue("AC-4 TypeMismatch", back.error instanceof Packbin.TypeMismatch);
        Packbin.TypeMismatch mismatch = (Packbin.TypeMismatch) back.error;
        expectEq("AC-4 expected", 32, mismatch.expected);
        expectEq("AC-4 actual", 33, mismatch.actual);
    }

    private static void ac5UntypedPath() throws IOException {
        Map<String, Object> values = new java.util.HashMap<>();
        values.put("type", 0x40);
        values.put("sid", 1);
        values.put("lat", 500_000_000);
        values.put("lon", 300_000_000);
        values.put("profile", 1);
        byte[] bytes = Packbin.pack(POSITION, values);
        byte[] fixture = parseHex(Files.readString(findGoldenFixture()).trim());
        expectEq("AC-5 mismatched", 0, mismatchedBytes(bytes, fixture));
        expectEq("AC-5 hex", GOLDEN_HEX, toHex(bytes));
    }

    private static void ac6RowStaysData() throws IOException {
        String source = Files.readString(findMarkerRowSource());
        int bodyStart = source.indexOf("class MarkerRow");
        expectTrue("AC-6 MarkerRow present", bodyStart >= 0);
        int bodyEnd = source.indexOf('}', bodyStart);
        expectTrue("AC-6 MarkerRow body", bodyEnd > bodyStart);
        String body = source.substring(bodyStart, bodyEnd);
        expectTrue("AC-6 sid", body.contains("sid"));
        expectTrue("AC-6 no scheme", !body.toLowerCase(Locale.ROOT).contains("scheme"));
        expectTrue("AC-6 no Pack", !body.contains("Pack"));
        expectTrue("AC-6 no interface", !body.toLowerCase(Locale.ROOT).contains("interface"));
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

    private static Path findCompileFailFixture() throws IOException {
        Path dir = Path.of(System.getProperty("user.dir")).toAbsolutePath().normalize();
        while (dir != null) {
            Path candidate = dir.resolve("java").resolve("src").resolve("test").resolve("compile-fail")
                    .resolve("PackWithoutScheme.java");
            if (Files.isRegularFile(candidate)) {
                return candidate;
            }
            candidate = dir.resolve("src").resolve("test").resolve("compile-fail")
                    .resolve("PackWithoutScheme.java");
            if (Files.isRegularFile(candidate)) {
                return candidate;
            }
            dir = dir.getParent();
        }
        throw new IOException("compile-fail/PackWithoutScheme.java not found");
    }

    private static Path findMarkerRowSource() throws IOException {
        Path dir = Path.of(System.getProperty("user.dir")).toAbsolutePath().normalize();
        while (dir != null) {
            Path candidate = dir.resolve("java").resolve("src").resolve("test").resolve("java")
                    .resolve("packbin").resolve("SchemeTest.java");
            if (Files.isRegularFile(candidate)) {
                return candidate;
            }
            candidate = dir.resolve("src").resolve("test").resolve("java")
                    .resolve("packbin").resolve("SchemeTest.java");
            if (Files.isRegularFile(candidate)) {
                return candidate;
            }
            dir = dir.getParent();
        }
        throw new IOException("SchemeTest.java not found");
    }

    private static Path findMainOut() throws IOException {
        Path dir = Path.of(System.getProperty("user.dir")).toAbsolutePath().normalize();
        while (dir != null) {
            Path candidate = dir.resolve("java").resolve("out").resolve("main");
            if (Files.isDirectory(candidate)) {
                return candidate;
            }
            candidate = dir.resolve("out").resolve("main");
            if (Files.isDirectory(candidate)) {
                return candidate;
            }
            dir = dir.getParent();
        }
        throw new IOException("java/out/main not found");
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
