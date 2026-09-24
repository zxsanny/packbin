package packbin;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Locale;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicInteger;
import java.util.concurrent.atomic.AtomicReference;
import java.util.stream.Collectors;

public final class SchemeTest {
    private static int failures;

    public static final class MarkerRow {
        public byte sid;
    }

    public static final class UserModifiedEvent {
        public int userId;
        public String userNameChange;
        public String userEmailChange;
        public byte userStatusChange;
    }

    public static final class UserPositionEvent {
        public int userId;
        public int latitude;
        public int longitude;
    }

    private static final Scheme<MarkerRow> MARKER = new Scheme<>(
            32,
            MarkerRow.class,
            Packbin.u8(0, Access.get((MarkerRow r) -> r.sid & 0xFF), Access.set((MarkerRow r, Object v) -> r.sid = ((Number) v).byteValue())));

    private static final Scheme<PositionRow> POSITION = new Scheme<>(
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

    private static final Scheme<UserModifiedEvent> MODIFIED = new Scheme<>(
            1,
            UserModifiedEvent.class,
            Packbin.i32(0, Access.get((UserModifiedEvent r) -> r.userId), Access.set((UserModifiedEvent r, Object v) -> r.userId = ((Number) v).intValue())),
            Packbin.utf8(1, Access.get((UserModifiedEvent r) -> r.userNameChange), Access.set((UserModifiedEvent r, Object v) -> r.userNameChange = (String) v)),
            Packbin.utf8(2, Access.get((UserModifiedEvent r) -> r.userEmailChange), Access.set((UserModifiedEvent r, Object v) -> r.userEmailChange = (String) v)),
            Packbin.u8(3, Access.get((UserModifiedEvent r) -> r.userStatusChange & 0xFF), Access.set((UserModifiedEvent r, Object v) -> r.userStatusChange = ((Number) v).byteValue())));

    private static final Scheme<UserPositionEvent> USER_POSITION = new Scheme<>(
            2,
            UserPositionEvent.class,
            Packbin.i32(0, Access.get((UserPositionEvent r) -> r.userId), Access.set((UserPositionEvent r, Object v) -> r.userId = ((Number) v).intValue())),
            Packbin.i32(1, Access.get((UserPositionEvent r) -> r.latitude), Access.set((UserPositionEvent r, Object v) -> r.latitude = ((Number) v).intValue())),
            Packbin.i32(2, Access.get((UserPositionEvent r) -> r.longitude), Access.set((UserPositionEvent r, Object v) -> r.longitude = ((Number) v).intValue())));

    private static final String GOLDEN_HEX = "4001000065cd1d00a3e1110100";
    private static final String AC4_HEX = "02070000000800000009000000";

    public static void main(String[] args) throws Exception {
        ac1SchemeReplacesPacket();
        ac2PositionGolden();
        ac3KnownWrongType();
        ac4UnknownDispatch();
        ac5UnknownTypeNumber();
        ac6DuplicateTypeNumbers();
        typeNumberRange();
        compileFailRequiresScheme();
        if (failures > 0) {
            System.err.println(failures + " failure(s)");
            System.exit(1);
        }
        System.out.println("Scheme tests passed");
    }

    private static void ac1SchemeReplacesPacket() throws IOException {
        Path main = findMainSources();
        expectTrue("AC-1 no Packet.java use", !readTree(main).contains("class Packet"));
        expectTrue("AC-1 no BinaryPacker", !Files.exists(main.resolve("BinaryPacker.java")));
        MarkerRow row = new MarkerRow();
        row.sid = 23;
        byte[] bytes = Pack.run(MARKER, row);
        expectEq("AC-1 hex", "2017", toHex(bytes));
    }

    private static void ac2PositionGolden() throws IOException {
        PositionRow row = new PositionRow();
        row.sid = 1;
        row.lat = 500_000_000;
        row.lon = 300_000_000;
        row.profile = 1;
        byte[] bytes = Pack.run(POSITION, row);
        expectEq("AC-2 hex", GOLDEN_HEX, toHex(bytes));
        expectEq("AC-2 mismatched", 0, mismatchedBytes(bytes, parseHex(Files.readString(findGoldenFixture()).trim())));
        try {
            PositionRow.class.getField("type");
            fail("AC-2 type member present");
        } catch (NoSuchFieldException ex) {
        }
    }

    private static void ac3KnownWrongType() {
        Packbin.Bound<MarkerRow> empty = Unpack.run(MARKER, new byte[0]);
        expectTrue("AC-3 empty not ok", !empty.ok);
        expectTrue("AC-3 empty no row", empty.value == null);
        expectTrue("AC-3 empty ShortPacket", empty.error instanceof Packbin.ShortPacket);
        Packbin.ShortPacket shortPacket = (Packbin.ShortPacket) empty.error;
        expectEq("AC-3 empty field", "", shortPacket.field);

        Scheme<MarkerRow> typeOne = new Scheme<>(1, MarkerRow.class,
                Packbin.u8(0, Access.get((MarkerRow r) -> r.sid & 0xFF), Access.set((MarkerRow r, Object v) -> r.sid = ((Number) v).byteValue())));
        Packbin.Bound<MarkerRow> back = Unpack.run(typeOne, parseHex("0217"));
        expectTrue("AC-3 not ok", !back.ok);
        expectTrue("AC-3 no row", back.value == null);
        expectTrue("AC-3 TypeMismatch", back.error instanceof Packbin.TypeMismatch);
        Packbin.TypeMismatch mismatch = (Packbin.TypeMismatch) back.error;
        expectEq("AC-3 expected", 1, mismatch.expected);
        expectEq("AC-3 actual", 2, mismatch.actual);
    }

    private static void ac4UnknownDispatch() {
        AtomicInteger modifiedCalls = new AtomicInteger();
        AtomicInteger positionCalls = new AtomicInteger();
        AtomicReference<UserPositionEvent> got = new AtomicReference<>();
        Object err = Unpack.run(
                parseHex(AC4_HEX),
                MODIFIED.on(ev -> modifiedCalls.incrementAndGet()),
                USER_POSITION.on(ev -> {
                    positionCalls.incrementAndGet();
                    got.set(ev);
                }));
        expectTrue("AC-4 ok", err == null);
        expectEq("AC-4 modified calls", 0, modifiedCalls.get());
        expectEq("AC-4 position calls", 1, positionCalls.get());
        expectTrue("AC-4 row", got.get() != null);
        expectEq("AC-4 userId", 7, got.get().userId);
        expectEq("AC-4 latitude", 8, got.get().latitude);
        expectEq("AC-4 longitude", 9, got.get().longitude);
        try {
            UserPositionEvent.class.getField("type");
            fail("AC-4 type member present");
        } catch (NoSuchFieldException ex) {
        }
        expectEq("AC-4 hex", AC4_HEX, toHex(Pack.run(USER_POSITION, got.get())));
    }

    private static void ac5UnknownTypeNumber() {
        AtomicInteger modifiedCalls = new AtomicInteger();
        AtomicInteger positionCalls = new AtomicInteger();
        Object err = Unpack.run(
                new byte[] {9},
                MODIFIED.on(ev -> modifiedCalls.incrementAndGet()),
                USER_POSITION.on(ev -> positionCalls.incrementAndGet()));
        expectEq("AC-5 modified calls", 0, modifiedCalls.get());
        expectEq("AC-5 position calls", 0, positionCalls.get());
        expectTrue("AC-5 TypeMismatch", err instanceof Packbin.TypeMismatch);
        expectEq("AC-5 actual", 9, ((Packbin.TypeMismatch) err).actual);
    }

    private static void ac6DuplicateTypeNumbers() {
        boolean threw = false;
        try {
            Unpack.run(
                    new byte[] {1},
                    MODIFIED.on(ev -> {}),
                    new Scheme<>(1, UserPositionEvent.class,
                            Packbin.i32(0, Access.get((UserPositionEvent r) -> r.userId), Access.set((UserPositionEvent r, Object v) -> r.userId = ((Number) v).intValue()))).on(ev -> {}));
        } catch (IllegalArgumentException ex) {
            threw = true;
        }
        expectTrue("AC-6 duplicate throws", threw);
    }

    private static void typeNumberRange() {
        expectThrows("above 255", () -> new Scheme<>(256, MarkerRow.class,
                Packbin.u8(0, Access.get((MarkerRow r) -> r.sid & 0xFF), Access.set((MarkerRow r, Object v) -> r.sid = ((Number) v).byteValue()))));
        expectThrows("below 0", () -> new Scheme<>(-1, MarkerRow.class,
                Packbin.u8(0, Access.get((MarkerRow r) -> r.sid & 0xFF), Access.set((MarkerRow r, Object v) -> r.sid = ((Number) v).byteValue()))));
        new Scheme<>(0, MarkerRow.class, Packbin.u8(0, Access.get((MarkerRow r) -> r.sid & 0xFF), Access.set((MarkerRow r, Object v) -> r.sid = ((Number) v).byteValue())));
        new Scheme<>(255, MarkerRow.class, Packbin.u8(0, Access.get((MarkerRow r) -> r.sid & 0xFF), Access.set((MarkerRow r, Object v) -> r.sid = ((Number) v).byteValue())));
    }

    private static void compileFailRequiresScheme() throws Exception {
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
        expectTrue("compile-fail finished", finished);
        expectTrue("compile-fail exit", process.exitValue() != 0);
        expectTrue("compile-fail no BinaryPacker", !output.toLowerCase(Locale.ROOT).contains("binarypacker"));
    }

    private static void expectThrows(String label, Runnable action) {
        try {
            action.run();
            fail(label + ": expected exception");
        } catch (IllegalArgumentException ex) {
        }
    }

    private static String readTree(Path dir) throws IOException {
        StringBuilder out = new StringBuilder();
        try (var stream = Files.walk(dir)) {
            for (Path path : stream.filter(p -> p.toString().endsWith(".java")).toList()) {
                out.append(Files.readString(path));
            }
        }
        return out.toString();
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
        return findUp("fixtures", "golden.hex");
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

    private static Path findMainOut() throws IOException {
        return findDir("java", "out", "main");
    }

    private static Path findMainSources() throws IOException {
        return findDir("java", "src", "main", "java", "packbin");
    }

    private static Path findUp(String... parts) throws IOException {
        Path dir = Path.of(System.getProperty("user.dir")).toAbsolutePath().normalize();
        while (dir != null) {
            Path candidate = dir;
            for (String part : parts) {
                candidate = candidate.resolve(part);
            }
            if (Files.isRegularFile(candidate)) {
                return candidate;
            }
            dir = dir.getParent();
        }
        throw new IOException(String.join("/", parts) + " not found");
    }

    private static Path findDir(String... parts) throws IOException {
        Path dir = Path.of(System.getProperty("user.dir")).toAbsolutePath().normalize();
        while (dir != null) {
            Path candidate = dir;
            for (String part : parts) {
                candidate = candidate.resolve(part);
            }
            if (Files.isDirectory(candidate)) {
                return candidate;
            }
            Path alt = dir;
            for (int i = 1; i < parts.length; i++) {
                alt = alt.resolve(parts[i]);
            }
            if (parts.length > 1 && Files.isDirectory(alt)) {
                return alt;
            }
            dir = dir.getParent();
        }
        throw new IOException(String.join("/", parts) + " not found");
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
