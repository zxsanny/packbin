package packbin;

import java.nio.charset.StandardCharsets;
import java.util.LinkedHashMap;
import java.util.Map;

/** AZ-2713: a decoded dict key must be strictly greater than the key before it, by UTF-8 bytes. */
@SuppressWarnings({"unchecked", "rawtypes"})
final class DictKeyOrderTest {
    private DictKeyOrderTest() {}

    static void run() {
        ascendingKeysAreAccepted();
        notAscendingKeysAreRefused();
        speed();
    }

    private static Scheme<Map> scheme() {
        return Maps.scheme(1, Packbin.dict(Access.get("m"), Access.set("m"),
                Packbin.u8(0, Access.identity(), Access.ignore())));
    }

    /** A key as the raw payload (prefix 10, then the UTF-8 bytes; the keys here stay under 127 bytes) and a value 00. */
    private static String pair(String key) {
        byte[] utf8 = key.getBytes(StandardCharsets.UTF_8);
        return String.format("%02x10", utf8.length + 1) + PackbinTest.toHex(utf8) + "00";
    }

    private static byte[] packet(String... keys) {
        StringBuilder hex = new StringBuilder(String.format("01%02x00", keys.length));
        for (String key : keys) {
            hex.append(pair(key));
        }
        return PackbinTest.parseHex(hex.toString());
    }

    private static void ascendingKeysAreAccepted() {
        // U+FF5E is ef bd 9e and U+10000 is f0 90 80 80: ascending in UTF-8, descending in UTF-16 units.
        TextVectorsTest.Outcome got = TextVectorsTest.unpack(scheme(),
                packet("", "a", "ab", "b", "～", new String(Character.toChars(0x10000))));
        PackbinTest.expectTrue("AZ-2713 ascending keys are accepted (" + got.error + ", " + got.thrown + ")",
                got.error == null && got.row != null);
        PackbinTest.expectEq("AZ-2713 ascending keys all kept", 6, ((Map) got.row.get("m")).size());
    }

    private static void refused(String label, String first, String second) {
        TextVectorsTest.Outcome got = TextVectorsTest.unpack(scheme(), packet(first, second));
        PackbinTest.expectTrue("AZ-2713 " + label + " is refused", got.thrown == null && got.error != null && got.row == null);
    }

    private static void notAscendingKeysAreRefused() {
        refused("U+10000 then U+FF5E (descending in UTF-8)", new String(Character.toChars(0x10000)), "～");
        refused("b then a", "b", "a");
        refused("a prefix after its longer key", "ab", "a");
        refused("a repeated key", "a", "a");
        refused("a repeated non-ASCII key", "～", "～");
        TextVectorsTest.Outcome got = TextVectorsTest.unpack(scheme(), packet("a", "c", "b"));
        PackbinTest.expectTrue("AZ-2713 a key out of order behind two good keys is refused", got.error != null && got.row == null);
    }

    private static void speed() {
        Scheme<Map> scheme = scheme();
        Map<String, Object> map = new LinkedHashMap<>();
        for (int i = 0; i < 65_535; i++) {
            map.put(String.format("%05d", i), i & 0xff);
        }
        byte[] packed = BinaryPacker.pack(scheme, Maps.map("m", map));
        TextVectorsTest.Outcome warm = TextVectorsTest.unpack(scheme, packed);
        PackbinTest.expectTrue("AZ-2713 AC-3 warm-up unpack is clean", warm.error == null && warm.row != null);

        Timing.Limit limit = Timing.bound(1.0);
        long start = System.nanoTime();
        TextVectorsTest.Outcome got = TextVectorsTest.unpack(scheme, packed);
        double seconds = (System.nanoTime() - start) / 1e9;

        System.out.println("AZ-2713 AC-3 unpack of 65535 ascending keys (" + packed.length + " bytes): " + seconds + " s");
        PackbinTest.expectTrue("AZ-2713 AC-3 unpack is clean", got.error == null && got.row != null);
        PackbinTest.expectEq("AZ-2713 AC-3 all keys kept", 65_535, ((Map) got.row.get("m")).size());
        limit.expectWithin("AZ-2713 AC-3 unpack of 65535 ascending keys", seconds);
    }
}
