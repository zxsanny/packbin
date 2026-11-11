package packbin;

import java.util.ArrayList;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Random;
import java.util.Set;
import java.nio.charset.StandardCharsets;

/**
 * AZ-4169: two keys that differ only in unpaired surrogates are one key on the wire (each half is written as U+FFFD, as
 * the TypeScript, Dart and C# packages write it), and unpack refuses a repeated key, so pack refuses them: it never
 * writes a packet its own unpack cannot read. Java used to write a '?' (0x3F) for a lone half, which also merged it with a
 * real '?'. The packets are the ones TypeScript writes.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class DictCollidingKeysTest {
    private static final String MESSAGE = "dict: two keys are the same once an unpaired surrogate is written as U+FFFD";

    private DictCollidingKeysTest() {}

    static void run() {
        collidingKeysAreRefused();
        keysWithoutACollisionKeepTheirBytes();
        aLoneHalfIsWrittenAsFffd();
        textsMatchTypeScript();
        seededDictionariesAreNeverUnreadable();
    }

    private static Scheme<Map> dictScheme() {
        return Maps.scheme(1, Packbin.dict(Access.get("d"), Access.set("d"),
                Packbin.u8(0, Access.identity(), Access.ignore())));
    }

    private static byte[] pack(String... keys) {
        Map<String, Object> map = new LinkedHashMap<>();
        for (int i = 0; i < keys.length; i++) {
            map.put(keys[i], i + 1);
        }
        return BinaryPacker.pack(dictScheme(), Maps.map("d", map));
    }

    private static void collidingKeysAreRefused() {
        String[][] collisions = {
            {"\ud800", "\udc00"},
            {"�", "\ud800"},
            {"a", "\ud800", "\udc00"},
            {"\udc00\ud800", "��"},
        };
        for (String[] keys : collisions) {
            PackbinTest.expectThrows("AZ-4169 colliding keys " + keys.length + " refused", () -> pack(keys), MESSAGE);
        }
    }

    private static void keysWithoutACollisionKeepTheirBytes() {
        String[][] keys = {{"\ud800", "￿"}, {"a", "\ud800"}, {"?", "\ud800"}};
        String[] packets = {
            "0102000410efbfbd010410efbfbf02",
            "010200021061010410efbfbd02",
            "01020002103f010410efbfbd02",
        };
        for (int i = 0; i < keys.length; i++) {
            byte[] bytes = pack(keys[i]);
            PackbinTest.expectEq("AZ-4169 no collision " + i + " bytes", packets[i], PackbinTest.toHex(bytes));
            TextVectorsTest.Outcome got = TextVectorsTest.unpack(dictScheme(), bytes);
            PackbinTest.expectTrue("AZ-4169 no collision " + i + " unpacks", got.error == null && got.row != null);
        }
    }

    private static void aLoneHalfIsWrittenAsFffd() {
        byte[] bytes = pack("\ud800");
        PackbinTest.expectEq("AZ-4169 a lone high half in a key is EF BF BD", "0101000410efbfbd01", PackbinTest.toHex(bytes));
        TextVectorsTest.Outcome got = TextVectorsTest.unpack(dictScheme(), bytes);
        Set<Object> keys = new HashSet<>(((Map) got.row.get("d")).keySet());
        PackbinTest.expectEq("AZ-4169 and reads back as U+FFFD", Set.of("�"), keys);
    }

    private static void textsMatchTypeScript() {
        Scheme<Map> text = Maps.scheme(1, Packbin.utf8(0, Access.get("s"), Access.set("s")));
        String[] halves = {"\ud800", "\udc00", "\udc00\ud800", "a\ud800b"};
        String[][] contexts = {{"", "bare"}, {"中文", "raw"}, {"hello world ", "compact"}};
        String[][] packets = {
            {"010410efbfbd", "010410efbfbd", "010710efbfbdefbfbd", "01061061efbfbd62"},
            {"010a10e4b8ade69687efbfbd", "010a10e4b8ade69687efbfbd", "010d10e4b8ade69687efbfbdefbfbd",
                "010c10e4b8ade6968761efbfbd62"},
            {"010deaa2d673dbe2d43ff977dfde80", "010deaa2d673dbe2d43ff977dfde80",
                "01116aa2d673dbe2d43fbffefbfbdfff7dfde8", "010e8aa2d673dbe2d429ff977dfdefa0"},
        };
        for (int c = 0; c < contexts.length; c++) {
            for (int h = 0; h < halves.length; h++) {
                byte[] bytes = BinaryPacker.pack(text, Maps.map("s", contexts[c][0] + halves[h]));
                PackbinTest.expectEq("AZ-4169 text " + contexts[c][1] + " case " + h, packets[c][h], PackbinTest.toHex(bytes));
            }
        }
        byte[] lone = BinaryPacker.pack(text, Maps.map("s", "\ud800"));
        PackbinTest.expectTrue("AZ-4169 a text with a lone half holds no '?'",
                !PackbinTest.toHex(lone).contains("3f"));
    }

    private static void seededDictionariesAreNeverUnreadable() {
        Random random = new Random(20261111L); // a fixed seed, so a failure replays
        String[] alphabet = {"a", "z", "?", "\ud800", "\udbff", "\udc00", "\udfff", "�", "￿", "😀", ""};
        int written = 0;
        int refused = 0;
        for (int n = 0; n < 20_000; n++) {
            Map<String, Object> map = new LinkedHashMap<>();
            for (int k = 1 + random.nextInt(4); k > 0; k--) {
                StringBuilder key = new StringBuilder();
                for (int u = random.nextInt(4); u > 0; u--) {
                    key.append(alphabet[random.nextInt(alphabet.length)]);
                }
                map.put(key.toString(), 1 + random.nextInt(200));
            }
            List<String> swapped = new ArrayList<>();
            for (String key : map.keySet()) {
                swapped.add(VarFields.replaceLoneSurrogates(key));
            }
            boolean collides = new HashSet<>(swapped).size() != swapped.size();
            byte[] packet = null;
            try {
                packet = BinaryPacker.pack(dictScheme(), Maps.map("d", map));
            } catch (IllegalArgumentException ex) {
                PackbinTest.expectEq("AZ-4169 seeded refusal message", MESSAGE, ex.getMessage());
            }
            if (packet == null) {
                PackbinTest.expectTrue("AZ-4169 seeded: refused without a collision " + swapped, collides);
                refused++;
                continue;
            }
            PackbinTest.expectTrue("AZ-4169 seeded: wrote a colliding dictionary " + swapped, !collides);
            TextVectorsTest.Outcome got = TextVectorsTest.unpack(dictScheme(), packet);
            PackbinTest.expectTrue("AZ-4169 seeded: its own unpack refused " + PackbinTest.toHex(packet),
                    got.error == null && got.row != null);
            if (got.row != null) {
                Set<Object> back = new HashSet<>(((Map) got.row.get("d")).keySet());
                PackbinTest.expectEq("AZ-4169 seeded keys read back", new HashSet<>(swapped), back);
            }
            written++;
        }
        PackbinTest.expectTrue("AZ-4169 seeded run wrote " + written + " and refused " + refused,
                written > 5_000 && refused > 500);
    }
}
