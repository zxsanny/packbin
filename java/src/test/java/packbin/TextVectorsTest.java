package packbin;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Arrays;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * AZ-2651 AC-1, AC-2, AC-3 (ring packets), AC-4, AC-6: every row of fixtures/text/vectors.txt against the Java
 * package, and the tables against fixtures/text/tables.json.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class TextVectorsTest {
    private TextVectorsTest() {}

    static void run() throws Exception {
        tablesMatchTheFixture();
        encRowsPackAndUnpack();
        altRowsUnpack();
        badRowsAreRefused();
        refRowsAreTheRingPackets();
        flipRowsNeverTrap();
    }

    private static Scheme<Map> single() {
        return Maps.scheme(1, Packbin.utf8(0, Access.get("s"), Access.set("s")));
    }

    private static Scheme<Map> withNext() {
        return Maps.scheme(1, Packbin.utf8(0, Access.get("s"), Access.set("s")),
                Packbin.u8(1, Access.get("after"), Access.set("after")));
    }

    /** The outcome of one unpack: the error value or null, the row or null, and anything thrown. */
    static final class Outcome {
        Object error;
        Map row;
        Throwable thrown;
    }

    static Outcome unpack(Scheme<Map> scheme, byte[] packet) {
        Outcome out = new Outcome();
        try {
            out.error = BinaryPacker.unpack(packet, scheme.on(row -> out.row = row));
        } catch (RuntimeException | Error ex) {
            out.thrown = ex;
        }
        return out;
    }

    private static void tablesMatchTheFixture() throws IOException, NoSuchAlgorithmException {
        byte[] raw = Files.readAllBytes(Path.of("fixtures", "text", "tables.json"));
        StringBuilder sha = new StringBuilder();
        for (byte b : MessageDigest.getInstance("SHA-256").digest(raw)) {
            sha.append(String.format("%02x", b & 0xff));
        }
        PackbinTest.expectEq("tables.json sha256 equals the generated file", sha.toString(), TextTables.SHA256);
        String json = new String(raw, StandardCharsets.UTF_8);
        Matcher lengths = Pattern.compile("\"lengths\":\\s*\\[([^\\]]*)\\]").matcher(json);
        int[][] expected = {TextTables.LENGTHS_UA, TextTables.LENGTHS_RU, TextTables.LENGTHS_EN, TextTables.LENGTHS_NUM};
        for (int m = 0; m < 4; m++) {
            PackbinTest.expectTrue("tables.json holds the lengths of mode " + m, lengths.find());
            int[] got = Arrays.stream(lengths.group(1).trim().split("\\s*,\\s*")).mapToInt(Integer::parseInt).toArray();
            PackbinTest.expectTrue("tables lengths of mode " + m + " equal tables.json", Arrays.equals(expected[m], got));
        }
        Matcher alphabets = Pattern.compile("\"(ua|ru|en)\": \"([^\"]*)\"").matcher(json);
        int[][] letters = {TextTables.UA, TextTables.RU, TextTables.EN};
        for (int m = 0; m < 3; m++) {
            PackbinTest.expectTrue("tables.json holds the alphabet of mode " + m, alphabets.find());
            PackbinTest.expectTrue("tables alphabet " + m + " equals tables.json",
                    Arrays.equals(letters[m], alphabets.group(2).codePoints().toArray()));
        }
        emitterAgrees();
    }

    /** The emitter's own check, when a python3 is on the PATH; the sha256 and arrays above hold without it. */
    private static void emitterAgrees() {
        try {
            ProcessBuilder builder = new ProcessBuilder("python3", "-I", "scripts/text/emit_tables.py", "java", "--check",
                    "java/src/main/java/packbin/TextTables.java");
            builder.redirectInput(ProcessBuilder.Redirect.from(new java.io.File("/dev/null")));
            builder.redirectErrorStream(true);
            Process child = builder.start();
            byte[] out = child.getInputStream().readAllBytes();
            boolean done = child.waitFor(60, java.util.concurrent.TimeUnit.SECONDS);
            if (!done) {
                child.destroyForcibly();
            }
            PackbinTest.expectTrue("emit_tables.py java --check finished", done);
            PackbinTest.expectTrue("emit_tables.py java --check passes: " + new String(out, StandardCharsets.UTF_8),
                    done && child.exitValue() == 0);
        } catch (IOException ex) {
            System.out.println("emit_tables.py not run (no python3 here): " + ex.getMessage());
        } catch (InterruptedException ex) {
            Thread.currentThread().interrupt();
            PackbinTest.fail("emit_tables.py check interrupted");
        }
    }

    private static void encRowsPackAndUnpack() {
        int rows = 0;
        for (TextVectors.Row row : TextVectors.ofKind("enc")) {
            String text = row.text();
            String field = row.cols[2];
            String packet = "01" + field;
            byte[] packed = BinaryPacker.pack(single(), Maps.map("s", text));
            PackbinTest.expectEq("AC-1 pack " + row.id(), packet, PackbinTest.toHex(packed));
            Outcome got = unpack(single(), PackbinTest.parseHex(packet));
            PackbinTest.expectTrue("AC-2 unpack " + row.id() + " (" + got.error + ", " + got.thrown + ")",
                    got.error == null && got.thrown == null && got.row != null);
            if (got.row != null) {
                PackbinTest.expectEq("AC-2 text " + row.id(), text, got.row.get("s"));
            }
            rows++;
        }
        PackbinTest.expectTrue("AC-1 enc rows read: " + rows, rows >= 250);
    }

    private static void altRowsUnpack() {
        int rows = 0;
        for (TextVectors.Row row : TextVectors.ofKind("alt")) {
            Outcome got = unpack(single(), PackbinTest.parseHex("01" + row.cols[2]));
            PackbinTest.expectTrue("AC-2 alt " + row.id() + " (" + got.error + ")", got.error == null && got.row != null);
            if (got.row != null) {
                PackbinTest.expectEq("AC-2 alt text " + row.id(), row.text(), got.row.get("s"));
            }
            rows++;
        }
        PackbinTest.expectTrue("AC-2 alt rows read: " + rows, rows >= 10);
    }

    private static void badRowsAreRefused() {
        Map<String, Integer> kinds = new HashMap<>();
        for (TextVectors.Row row : TextVectors.ofKind("bad")) {
            String buffer = row.cols[2];
            Outcome got = unpack(single(), PackbinTest.parseHex("01" + buffer));
            kinds.merge(row.cols[1], 1, Integer::sum);
            PackbinTest.expectTrue("AC-4 bad " + row.id() + " is refused with no exception and no row (" + got.error + ", " + got.thrown + ")",
                    got.thrown == null && got.error instanceof Packbin.ShortPacket && got.row == null);
            if (got.error instanceof Packbin.ShortPacket refused) {
                PackbinTest.expectEq("AC-4 bad " + row.id() + " names the field", "0", refused.field);
            }
        }
        for (String kind : List.of("short", "varint", "mode", "pad", "code", "cap", "esc", "utf8", "raw", "length")) {
            PackbinTest.expectTrue("AC-4/AC-6 a bad row of kind " + kind, kinds.containsKey(kind));
        }
    }

    private static Scheme<Map> userScheme() {
        return Maps.scheme(1, Packbin.utf8(0, Access.get("username"), Access.set("username")),
                Packbin.list(Access.get("roles"), Access.set("roles"),
                        Packbin.utf8(0, Access.identity(), Access.ignore())),
                Packbin.dict(Access.get("access"), Access.set("access"),
                        Packbin.list(Access.identity(), Access.ignore(),
                                Packbin.utf8(0, Access.identity(), Access.ignore()))));
    }

    private static Scheme<Map> nestedScheme() {
        return Maps.scheme(1, Packbin.dict(Access.get("access"), Access.set("access"),
                Packbin.list(Access.identity(), Access.ignore(),
                        Packbin.dict(Access.identity(), Access.ignore(),
                                Packbin.utf8(0, Access.identity(), Access.ignore())))));
    }

    private static Map<String, Object> user(String name, List<String> roles, Object... access) {
        Map<String, Object> grants = new LinkedHashMap<>();
        for (int i = 0; i < access.length; i += 2) {
            grants.put((String) access[i], access[i + 1]);
        }
        return Maps.map("username", name, "roles", roles, "access", grants);
    }

    private static Map<String, Object> nested(Object... access) {
        Map<String, Object> grants = new LinkedHashMap<>();
        for (int i = 0; i < access.length; i += 2) {
            grants.put((String) access[i], access[i + 1]);
        }
        return Maps.map("access", grants);
    }

    private static void refRowsAreTheRingPackets() {
        ref("ref.user", userScheme(), user("zxsanny", List.of("user", "dispatcher"),
                "channel", List.of("read"), "map", List.of("read", "gps_fix", "set", "edit"),
                "store", List.of("read", "write")));
        ref("ref.nested", nestedScheme(), nested("map", List.of(Map.of("op", "gps_fix")),
                "store", List.of(Map.of("op", "read"), Map.of("op", "write"))));
        ref("ref.user_ua", userScheme(), user("Олександр", List.of("диспетчер", "Оператор"),
                "карта", List.of("читати", "правити"), "канал", List.of("читати")));
        Map<String, Object> mixed = new LinkedHashMap<>();
        mixed.put("op", "gps_fix");
        mixed.put("note", "увага 48.46, 35.04");
        ref("ref.nested_mixed", nestedScheme(), nested("Карта", List.of(mixed), "store", List.of(Map.of("op", "ЧИТАТИ"))));
    }

    private static void ref(String id, Scheme<Map> scheme, Map<String, Object> values) {
        String expected = TextVectors.ref(id);
        PackbinTest.expectEq("AC-3 pack " + id, expected, PackbinTest.toHex(BinaryPacker.pack(scheme, values)));
        Outcome got = unpack(scheme, PackbinTest.parseHex(expected));
        PackbinTest.expectTrue("AC-3 unpack " + id + " (" + got.error + ", " + got.thrown + ")",
                got.error == null && got.row != null);
        if (got.row != null) {
            PackbinTest.expectEq("AC-3 values of " + id, values, got.row);
            PackbinTest.expectEq("AC-3 repack " + id, expected, PackbinTest.toHex(BinaryPacker.pack(scheme, got.row)));
        }
    }

    /** Each bit of the payload (not the count) flipped in [field][5a]: a string or an error, 5a intact, nothing thrown. */
    private static void flipRowsNeverTrap() {
        int rows = 0;
        int strings = 0;
        int errors = 0;
        for (TextVectors.Row row : TextVectors.ofKind("flip")) {
            byte[] field = PackbinTest.parseHex(TextVectors.byId(row.cols[1]).cols[2]);
            int head = field[0] < 0 ? (field[1] < 0 ? 3 : 2) : 1;
            for (int bit = 0; bit < 8 * (field.length - head); bit++) {
                byte[] packet = new byte[field.length + 2];
                packet[0] = 1;
                System.arraycopy(field, 0, packet, 1, field.length);
                packet[packet.length - 1] = 0x5a;
                packet[1 + head + bit / 8] ^= (byte) (0x80 >> (bit % 8));
                Outcome got = unpack(withNext(), packet);
                String label = "AC-4 flip " + row.id() + " bit " + bit;
                PackbinTest.expectTrue(label + " threw " + got.thrown, got.thrown == null);
                if (got.error == null) {
                    strings++;
                    PackbinTest.expectTrue(label + " gave a string and a row", got.row != null && got.row.get("s") instanceof String);
                    PackbinTest.expectEq(label + " keeps the byte after the string", 0x5a, got.row == null ? null : ((Number) got.row.get("after")).intValue());
                } else {
                    errors++;
                    PackbinTest.expectTrue(label + " error names the field", got.error instanceof Packbin.ShortPacket
                            && ((Packbin.ShortPacket) got.error).field.equals("0") && got.row == null);
                }
            }
            rows++;
        }
        System.out.println("text flip rows: " + rows + ", strings " + strings + ", errors " + errors);
        PackbinTest.expectTrue("AC-4 at least 20 flip rows: " + rows, rows >= 20);
        PackbinTest.expectTrue("AC-4 the sweep saw both strings and errors", strings > 0 && errors > 0);
    }
}
