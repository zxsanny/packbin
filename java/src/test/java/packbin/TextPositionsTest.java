package packbin;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;

/**
 * AZ-2651 AC-3 (every string position), AC-5 (limits and headers), AC-7 (dictionary keys), AC-8 (speed), and a seeded
 * sweep: random texts round trip, random buffers never throw.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class TextPositionsTest {
    private static final String CTRL = String.valueOf((char) 1);

    private TextPositionsTest() {}

    static void run() {
        everyPosition();
        absentAndEmptyOptional();
        limitsAndHeaders();
        dictionaryKeys();
        loneSurrogateKeepsTheLanguageBehavior();
        randomTextsRoundTrip();
        randomBuffersNeverThrow();
        speed();
    }

    private static Field utf8(int id, String name) {
        return Packbin.utf8(id, Access.get(name), Access.set(name));
    }

    private static Field element() {
        return Packbin.utf8(0, Access.identity(), Access.ignore());
    }

    private static void packs(String label, Scheme<Map> scheme, Map<String, Object> row, String hex) {
        PackbinTest.expectEq(label + " bytes", hex, PackbinTest.toHex(BinaryPacker.pack(scheme, row)));
        TextVectorsTest.Outcome got = TextVectorsTest.unpack(scheme, PackbinTest.parseHex(hex));
        PackbinTest.expectTrue(label + " unpacks (" + got.error + ", " + got.thrown + ")", got.error == null && got.row != null);
        PackbinTest.expectEq(label + " round trip", row, got.row);
    }

    private static void everyPosition() {
        packs("AC-3 list element", Maps.scheme(1, Packbin.list(Access.get("xs"), Access.set("xs"), element())),
                Maps.map("xs", List.of("a", "привіт")), "01" + "0200" + "021061" + "05a37aa424e0");
        packs("AC-3 dictionary key and value list", Maps.scheme(1, Packbin.dict(Access.get("m"), Access.set("m"),
                Packbin.list(Access.identity(), Access.ignore(), element()))),
                Maps.map("m", Map.of("b", List.of("x"))), "01" + "0100" + "021062" + "0100" + "021078");
        packs("AC-3 times string", Maps.scheme(1, Packbin.u8(0, Access.get("n"), Access.set("n")),
                Packbin.times(1, 0, utf8(1, "s"))),
                Maps.map("n", 2, "s", List.of("a", "b")), "01" + "02" + "021061" + "021062");
        packs("AC-3 repeat string", Maps.scheme(1, Packbin.repeat(0, utf8(0, "s"))),
                Maps.map("s", List.of("a", "b")), "01" + "021061" + "021062");
        Scheme<Map> flags = Maps.scheme(1, Packbin.flags(0, utf8(0, "note")));
        packs("AC-3 optional string under flags", flags, Maps.map("note", "a"), "01" + "01" + "021061");
        packs("AC-3 optional string under flags, after a count", Maps.scheme(1, Packbin.u8(0, Access.get("n"), Access.set("n")),
                Packbin.flags(1, utf8(1, "note"))), Maps.map("n", 7, "note", "привіт"), "01" + "07" + "01" + "05a37aa424e0");
    }

    private static void absentAndEmptyOptional() {
        Scheme<Map> flags = Maps.scheme(1, Packbin.flags(0, utf8(0, "note")));
        byte[] absent = BinaryPacker.pack(flags, new LinkedHashMap<String, Object>());
        byte[] empty = BinaryPacker.pack(flags, Maps.map("note", ""));
        PackbinTest.expectEq("S12 an absent optional string adds 0 bytes", "0100", PackbinTest.toHex(absent));
        PackbinTest.expectEq("S12 an empty optional string adds 1 byte", "010100", PackbinTest.toHex(empty));
        TextVectorsTest.Outcome back = TextVectorsTest.unpack(flags, empty);
        PackbinTest.expectTrue("S12 the empty string comes back empty", back.row != null && "".equals(back.row.get("note")));
        TextVectorsTest.Outcome none = TextVectorsTest.unpack(flags, absent);
        PackbinTest.expectTrue("S12 the absent one stays absent", none.row != null && none.row.get("note") == null);
    }

    private static String repeated(String piece, int times) {
        return piece.repeat(times);
    }

    private static void limitsAndHeaders() {
        Scheme<Map> scheme = Maps.scheme(1, utf8(0, "s"));
        String atLimit = repeated(CTRL, 65_535);
        byte[] packed = BinaryPacker.pack(scheme, Maps.map("s", atLimit));
        PackbinTest.expectEq("AC-5 65535 bytes packs, header 80 80 04 and the raw prefix", "01808004" + "10",
                PackbinTest.toHex(java.util.Arrays.copyOf(packed, 5)));
        PackbinTest.expectEq("AC-5 65535 bytes length", 1 + 3 + 65_536, packed.length);
        TextVectorsTest.Outcome back = TextVectorsTest.unpack(scheme, packed);
        PackbinTest.expectEq("AC-5 65535 bytes round trip", atLimit, back.row == null ? null : back.row.get("s"));
        String compressible = repeated("a", 65_535);
        TextVectorsTest.Outcome small = TextVectorsTest.unpack(scheme, BinaryPacker.pack(scheme, Maps.map("s", compressible)));
        PackbinTest.expectEq("AC-5 65535 compressible bytes round trip", compressible, small.row == null ? null : small.row.get("s"));
        try {
            BinaryPacker.pack(scheme, Maps.map("s", repeated(CTRL, 65_536)));
            PackbinTest.fail("AC-5 65536 bytes packed");
        } catch (IllegalArgumentException ex) {
            PackbinTest.expectTrue("AC-5 65536 bytes refused naming the field: " + ex.getMessage(), ex.getMessage().startsWith("0:"));
        }
        PackbinTest.expectEq("AC-5 payload of 127 bytes: 1 byte header", "7f10",
                PackbinTest.toHex(java.util.Arrays.copyOfRange(BinaryPacker.pack(scheme, Maps.map("s", repeated(CTRL, 126))), 1, 3)));
        PackbinTest.expectEq("AC-5 payload of 128 bytes: 2 byte header", "800110",
                PackbinTest.toHex(java.util.Arrays.copyOfRange(BinaryPacker.pack(scheme, Maps.map("s", repeated(CTRL, 127))), 1, 4)));
        String text = repeated(CTRL, 60);
        int size = BinaryPacker.pack(scheme, Maps.map("s", text)).length;
        PackbinTest.expectEq("AC-5 maxBytes exact packs", size,
                BinaryPacker.pack(scheme.withMaxBytes(size), Maps.map("s", text)).length);
        try {
            BinaryPacker.pack(scheme.withMaxBytes(size - 1), Maps.map("s", text));
            PackbinTest.fail("AC-5 one byte over maxBytes packed");
        } catch (IllegalArgumentException ex) {
            PackbinTest.expectEq("AC-5 one byte over maxBytes", "s: the packet would be " + size + " bytes, above the limit of "
                    + (size - 1) + " bytes", ex.getMessage());
        }
    }

    private static Scheme<Map> dictOfBytes() {
        return Maps.scheme(1, Packbin.dict(Access.get("m"), Access.set("m"), Packbin.u8(0, Access.identity(), Access.ignore())));
    }

    private static void dictionaryKeys() {
        String[] keys = {"", "a", "ab", "é", "Карта", "карта"};
        Map<String, Object> forward = new LinkedHashMap<>();
        Map<String, Object> backward = new LinkedHashMap<>();
        for (int i = 0; i < keys.length; i++) {
            forward.put(keys[i], i + 1);
            backward.put(keys[keys.length - 1 - i], keys.length - i);
        }
        String expected = "01" + "0600" + "00" + "01" + "021061" + "02" + "03106162" + "03" + "0310c3a9" + "04" + "05c7a9a59d00" + "05"
                + "048669674006";
        String forwardHex = PackbinTest.toHex(BinaryPacker.pack(dictOfBytes(), Maps.map("m", forward)));
        String backwardHex = PackbinTest.toHex(BinaryPacker.pack(dictOfBytes(), Maps.map("m", backward)));
        PackbinTest.expectEq("AC-7 two insertion orders give the same bytes", forwardHex, backwardHex);
        PackbinTest.expectEq("AC-7 keys sorted by UTF-8 bytes, bytes from the reference", expected, forwardHex);
        TextVectorsTest.Outcome got = TextVectorsTest.unpack(dictOfBytes(), PackbinTest.parseHex(forwardHex));
        PackbinTest.expectTrue("AC-7 unpacks", got.row != null);
        if (got.row != null) {
            PackbinTest.expectEq("AC-7 keys come back in byte order", List.of(keys), new ArrayList<>(((Map) got.row.get("m")).keySet()));
        }
        repeatedKeyIsRefused("AC-7 the same encoding twice", "021061", "021061");
        for (TextVectors.Row alt : TextVectors.ofKind("alt")) {
            for (TextVectors.Row enc : TextVectors.ofKind("enc")) {
                if (enc.cols[1].equals(alt.cols[1])) {
                    repeatedKeyIsRefused("AC-7 " + alt.id() + " and " + enc.id() + " decode to one key", alt.cols[2], enc.cols[2]);
                }
            }
        }
    }

    private static void repeatedKeyIsRefused(String label, String firstKey, String secondKey) {
        TextVectorsTest.Outcome got = TextVectorsTest.unpack(dictOfBytes(),
                PackbinTest.parseHex("01" + "0200" + firstKey + "01" + secondKey + "02"));
        PackbinTest.expectTrue(label + " is refused (" + got.error + ", " + got.thrown + ")",
                got.thrown == null && got.error instanceof Packbin.ShortPacket && got.row == null);
    }

    private static void loneSurrogateKeepsTheLanguageBehavior() {
        Scheme<Map> scheme = Maps.scheme(1, utf8(0, "s"));
        byte[] lone = BinaryPacker.pack(scheme, Maps.map("s", "\ud800x"));
        PackbinTest.expectEq("a lone surrogate packs as the '?' the language writes", PackbinTest.toHex(BinaryPacker.pack(scheme, Maps.map("s", "?x"))),
                PackbinTest.toHex(lone));
    }

    private static String randomText(Random random) {
        String pool = "абвгґдеєжзиіїйклмнопрстуфхцчшщьюя'АБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯ"
                + "ёъыэЁЪЫЭabcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789 ,.-:!?;()\"%/@+=*#&_$\n"
                + "éßłżą中文\t\u0000\u0001";
        int[] points = pool.codePoints().toArray();
        int[] emoji = {0x1F600, 0x1F468, 0x10FFFF, 0xFFFF, 0x7FF, 0x800};
        int length = random.nextInt(61);
        StringBuilder out = new StringBuilder();
        for (int i = 0; i < length; i++) {
            out.appendCodePoint(random.nextInt(25) == 0 ? emoji[random.nextInt(emoji.length)] : points[random.nextInt(points.length)]);
        }
        return out.toString();
    }

    private static void randomTextsRoundTrip() {
        Scheme<Map> scheme = Maps.scheme(1, utf8(0, "s"));
        Random random = new Random(35);
        int bad = 0;
        for (int i = 0; i < 20_000; i++) {
            String text = randomText(random);
            byte[] packed = BinaryPacker.pack(scheme, Maps.map("s", text));
            TextVectorsTest.Outcome got = TextVectorsTest.unpack(scheme, packed);
            int utf8 = text.getBytes(StandardCharsets.UTF_8).length;
            boolean same = got.row != null && text.equals(got.row.get("s"));
            boolean bounded = utf8 >= 128 || packed.length - 1 <= 2 + utf8;
            if (!same || !bounded) {
                bad++;
                if (bad <= 3) {
                    PackbinTest.fail("random text " + i + " " + PackbinTest.toHex(text.getBytes(StandardCharsets.UTF_8))
                            + " same=" + same + " bounded=" + bounded);
                }
            }
        }
        PackbinTest.expectEq("20000 random texts round trip and stay within 2 + UTF-8 bytes", 0, bad);
    }

    private static void randomBuffersNeverThrow() {
        Scheme<Map> scheme = Maps.scheme(1, utf8(0, "s"), Packbin.u8(1, Access.get("after"), Access.set("after")));
        Random random = new Random(2651);
        int threw = 0;
        int strings = 0;
        for (int i = 0; i < 60_000; i++) {
            byte[] buffer = new byte[2 + random.nextInt(40)];
            random.nextBytes(buffer);
            buffer[0] = 1;
            if (random.nextBoolean()) {
                buffer[1] = (byte) (buffer.length - 3);
            }
            TextVectorsTest.Outcome got = TextVectorsTest.unpack(scheme, buffer);
            if (got.thrown != null) {
                threw++;
            } else if (got.error == null) {
                strings++;
            }
        }
        PackbinTest.expectEq("60000 random buffers: nothing thrown", 0, threw);
        PackbinTest.expectTrue("60000 random buffers: some decode (" + strings + ")", strings > 0);
    }

    private static void speed() {
        Scheme<Map> scheme = Maps.scheme(1, utf8(0, "s"));
        String text = "Добрий день, друже!!";
        PackbinTest.expectEq("AC-8 the text has 20 characters", 20, text.codePointCount(0, text.length()));
        Map<String, Object> row = Maps.map("s", text);
        long start = System.nanoTime();
        int wrong = 0;
        for (int i = 0; i < 100_000; i++) {
            byte[] packed = BinaryPacker.pack(scheme, row);
            Map[] got = new Map[1];
            Object err = BinaryPacker.unpack(packed, scheme.on(r -> got[0] = r));
            if (err != null || !text.equals(got[0].get("s"))) {
                wrong++;
            }
        }
        double seconds = (System.nanoTime() - start) / 1e9;
        System.out.println("AC-8 100000 round trips of a 20-character Ukrainian string: " + seconds + " s");
        PackbinTest.expectEq("AC-8 every round trip is exact", 0, wrong);
        PackbinTest.expectTrue("AC-8 100000 round trips in " + seconds + " s (at most 1)", seconds <= 1.0);
    }
}
