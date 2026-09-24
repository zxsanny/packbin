package packbin;

import java.util.HashMap;
import java.util.List;
import java.util.Map;

final class PackbinFieldsTest {
    static int failures;

    static void run() throws Exception {
        flagGroupMark();
        flagGroupWideBit();
        flagGroupSession();
        flagGroupStoredZero();
        flagGroupShortLogin();
        sizedPayload();
        utf8String();
        countedList();
        dictionary();
        u2Kinds();
        bitsSegs();
    }

    private static void flagGroupMark() {
        Scheme<MapRow> empty = new Scheme<>(1, MapRow.class, Packbin.flags("f", Packbin.group("mark")));
        Map<String, Object> present = new HashMap<>();
        present.put("mark", Boolean.TRUE);
        byte[] setBit = Pack.run(empty, present);
        expectEq("mark set length", 2, setBit.length);
        expectEq("mark set byte", 0x01, setBit[1] & 0xFF);
        expectEq("mark set adds", 0, setBit.length - 2);
        byte[] clear = Pack.run(empty, Map.of());
        expectEq("mark clear length", 2, clear.length);
        expectEq("mark clear byte", 0x00, clear[1] & 0xFF);
    }

    private static void flagGroupWideBit() {
        Scheme<MapRow> one = new Scheme<>(1, MapRow.class, Packbin.flags(
                "f",
                Packbin.u8("a"),
                Packbin.u8("b"),
                Packbin.u8("c"),
                Packbin.u8("d"),
                Packbin.u8("e"),
                Packbin.u16("b5")));
        Map<String, Object> aOnly = new HashMap<>();
        aOnly.put("a", 1);
        expectEq("wide a length", 3, Pack.run(one, aOnly).length);
        Map<String, Object> b5Only = new HashMap<>();
        b5Only.put("b5", 1);
        byte[] wide = Pack.run(one, b5Only);
        expectEq("wide flags", 0x20, wide[1] & 0xFF);
        expectEq("wide adds", 2, wide.length - Pack.run(one, Map.of()).length);
    }

    private static void flagGroupSession() {
        Scheme<MapRow> two = new Scheme<>(1, MapRow.class, Packbin.flags(
                "f",
                Packbin.group("session", Packbin.u16("login"), Packbin.u32("ts"))));
        Map<String, Object> values = new HashMap<>();
        values.put("login", 7);
        values.put("ts", 1000);
        byte[] raw = Pack.run(two, values);
        expectEq("session payload", "0700e8030000", PackbinTest.toHex(java.util.Arrays.copyOfRange(raw, 2, raw.length)));
        expectEq("session adds", 6, raw.length - 2);
        byte[] absent = Pack.run(two, Map.of());
        expectEq("session absent", "0100", PackbinTest.toHex(absent));
        Packbin.UnpackResult got = Unpack.values(two, absent);
        expectTrue("session absent ok", got.ok);
        expectTrue("session no login", !got.value.containsKey("login"));
        expectTrue("session no ts", !got.value.containsKey("ts"));
    }

    private static void flagGroupStoredZero() {
        Scheme<MapRow> zero = new Scheme<>(1, MapRow.class, Packbin.flags("f", Packbin.group("g", Packbin.u8("b"))));
        Map<String, Object> values = new HashMap<>();
        values.put("b", 0);
        byte[] stored = Pack.run(zero, values);
        expectEq("group zero", "010100", PackbinTest.toHex(stored));
    }

    private static void flagGroupShortLogin() {
        Scheme<MapRow> two = new Scheme<>(1, MapRow.class, Packbin.flags(
                "f",
                Packbin.group("session", Packbin.u16("login"), Packbin.u32("ts"))));
        Packbin.UnpackResult shortRead = Unpack.values(two, new byte[] {0x01, 0x01, 0x07});
        expectEq("short login values", 0, shortRead.value.size());
        expectTrue("short login error", shortRead.error instanceof Packbin.ShortPacket);
        Packbin.ShortPacket missing = (Packbin.ShortPacket) shortRead.error;
        expectEq("short login field", "login", missing.field);
        expectEq("short login needed", 2, missing.needed);
        expectEq("short login left", 1, missing.left);
    }

    private static void sizedPayload() {
        Scheme<MapRow> layout = new Scheme<>(1, MapRow.class, Packbin.u16("n"), Packbin.sized("payload", "n"));
        Map<String, Object> values = new HashMap<>();
        values.put("n", 3);
        values.put("payload", PackbinTest.parseHex("756176"));
        byte[] raw = Pack.run(layout, values);
        expectEq("sized hex", "010300756176", PackbinTest.toHex(raw));
        Packbin.UnpackResult got = Unpack.values(layout, raw);
        expectTrue("sized ok", got.ok);
        expectEq("sized payload", 0, PackbinTest.mismatchedBytes((byte[]) got.value.get("payload"), PackbinTest.parseHex("756176")));
        Map<String, Object> emptyValues = new HashMap<>();
        emptyValues.put("n", 0);
        emptyValues.put("payload", new byte[0]);
        byte[] empty = Pack.run(layout, emptyValues);
        expectEq("sized empty hex", "010000", PackbinTest.toHex(empty));
        Packbin.UnpackResult emptyGot = Unpack.values(layout, empty);
        expectTrue("sized empty ok", emptyGot.ok);
        expectEq("sized empty length", 0, ((byte[]) emptyGot.value.get("payload")).length);
        Packbin.UnpackResult shortRead = Unpack.values(layout, PackbinTest.parseHex("01030075"));
        expectEq("sized short values", 0, shortRead.value.size());
        expectTrue("sized short error", shortRead.error instanceof Packbin.ShortPacket);
        Packbin.ShortPacket missing = (Packbin.ShortPacket) shortRead.error;
        expectEq("sized short field", "payload", missing.field);
        expectEq("sized short needed", 3, missing.needed);
        expectEq("sized short left", 1, missing.left);
    }

    private static void utf8String() {
        Scheme<MapRow> layout = new Scheme<>(1, MapRow.class, Packbin.utf8("name"));
        Map<String, Object> values = new HashMap<>();
        values.put("name", "zxsanny");
        byte[] raw = Pack.run(layout, values);
        expectEq("utf8 hex", "0107007a7873616e6e79", PackbinTest.toHex(raw));
        expectEq("utf8 len", 10, raw.length);
        Packbin.UnpackResult got = Unpack.values(layout, raw);
        expectTrue("utf8 ok", got.ok);
        expectEq("utf8 text", "zxsanny", got.value.get("name"));

        values.put("name", "");
        byte[] empty = Pack.run(layout, values);
        expectEq("utf8 empty", "010000", PackbinTest.toHex(empty));
        Packbin.UnpackResult emptyGot = Unpack.values(layout, empty);
        expectTrue("utf8 empty ok", emptyGot.ok);
        expectEq("utf8 empty text", "", emptyGot.value.get("name"));

        values.put("name", "a".repeat(65536));
        boolean failed = false;
        try {
            Pack.run(layout, values);
        } catch (IllegalArgumentException ex) {
            failed = true;
        }
        expectTrue("utf8 too long", failed);

        Packbin.UnpackResult shortGot = Unpack.values(layout, new byte[] {0x01, 0x07, 0x00, 0x7a, 0x78});
        expectTrue("utf8 short", !shortGot.ok);
        expectEq("utf8 short values", 0, shortGot.value.size());
        expectEq("utf8 short field", "name", shortGot.field());
        expectEq("utf8 short needed", 7, shortGot.needed());
        expectEq("utf8 short left", 2, shortGot.left());
    }

    private static void countedList() {
        Scheme<MapRow> two = new Scheme<>(1, MapRow.class, Packbin.list("xs", Packbin.u16("n")));
        Map<String, Object> values = new HashMap<>();
        values.put("xs", List.of(1, 2));
        byte[] raw = Pack.run(two, values);
        expectEq("list hex", "01020001000200", PackbinTest.toHex(raw));
        Packbin.UnpackResult got = Unpack.values(two, raw);
        expectTrue("list ok", got.ok);
        expectEq("list 0", 1, ((Number) ((List<?>) got.value.get("xs")).get(0)).intValue());
        expectEq("list 1", 2, ((Number) ((List<?>) got.value.get("xs")).get(1)).intValue());

        Scheme<MapRow> beOne = new Scheme<>(1, MapRow.class, Packbin.list("xs", Packbin.be(Packbin.u16("n"))));
        values.put("xs", List.of(1));
        expectEq("list be", "0101000001", PackbinTest.toHex(Pack.run(beOne, values)));

        Scheme<MapRow> followed = new Scheme<>(1, MapRow.class, Packbin.list("xs", Packbin.u8("n")), Packbin.u8("y"));
        values.put("xs", List.of(1));
        values.put("y", 2);
        byte[] both = Pack.run(followed, values);
        expectEq("list next hex", "0101000102", PackbinTest.toHex(both));
        Packbin.UnpackResult back = Unpack.values(followed, both);
        expectTrue("list next ok", back.ok);
        expectEq("list next xs", 1, ((Number) ((List<?>) back.value.get("xs")).get(0)).intValue());
        expectEq("list next y", 2, ((Number) back.value.get("y")).intValue());

        values.clear();
        values.put("xs", List.of());
        expectEq("list empty", "010000", PackbinTest.toHex(Pack.run(two, values)));
        List<Integer> huge = new java.util.ArrayList<>();
        for (int i = 0; i < 65536; i++) {
            huge.add(1);
        }
        values.put("xs", huge);
        boolean failed = false;
        try {
            Pack.run(two, values);
        } catch (IllegalArgumentException ex) {
            failed = true;
        }
        expectTrue("list too long", failed);
    }

    private static void dictionary() throws Exception {
        String userHex =
                "0107007a7873616e6e7902000400757365720a0064697370617463686572030007006368616e6e656c010004007265616403006d6170040004007265616407006770735f6669780300736574040065646974050073746f7265020004007265616405007772697465";
        Scheme<MapRow> layout = new Scheme<>(1, MapRow.class,
                Packbin.utf8("username"),
                Packbin.list("roles", Packbin.utf8("role")),
                Packbin.dict("access", Packbin.list("actions", Packbin.utf8("action"))));
        Map<String, Object> access = new java.util.LinkedHashMap<>();
        access.put("store", List.of("read", "write"));
        access.put("channel", List.of("read"));
        access.put("map", List.of("read", "gps_fix", "set", "edit"));
        Map<String, Object> values = new HashMap<>();
        values.put("username", "zxsanny");
        values.put("roles", List.of("user", "dispatcher"));
        values.put("access", access);
        byte[] raw = Pack.run(layout, values);
        expectEq("dict hex", userHex, PackbinTest.toHex(raw));
        expectEq("dict len", 104, raw.length);
        expectEq("dict twice", 0, PackbinTest.mismatchedBytes(raw, Pack.run(layout, values)));
        byte[][] parallel = new byte[2][];
        Thread first = new Thread(() -> parallel[0] = Pack.run(layout, values));
        Thread second = new Thread(() -> parallel[1] = Pack.run(layout, values));
        first.start();
        second.start();
        first.join();
        second.join();
        expectEq("dict parallel", 0, PackbinTest.mismatchedBytes(parallel[0], parallel[1]));
        Packbin.UnpackResult got = Unpack.values(layout, raw);
        expectTrue("dict ok", got.ok);
        expectEq("dict user", "zxsanny", got.value.get("username"));
        List<?> roles = (List<?>) got.value.get("roles");
        expectEq("dict roles", 2, roles.size());
        expectEq("dict role 0", "user", roles.get(0));
        expectEq("dict role 1", "dispatcher", roles.get(1));
        Map<?, ?> back = (Map<?, ?>) got.value.get("access");
        expectEq("dict access", 3, back.size());
        expectEq("dict channel", "read", ((List<?>) back.get("channel")).get(0));
        expectEq("dict map", "gps_fix", ((List<?>) back.get("map")).get(1));
        expectEq("dict store", "write", ((List<?>) back.get("store")).get(1));

        Scheme<MapRow> empty = new Scheme<>(1, MapRow.class,
                Packbin.utf8("s"), Packbin.list("xs", Packbin.u8("n")), Packbin.dict("m", Packbin.utf8("v")));
        Map<String, Object> emptyVals = new HashMap<>();
        emptyVals.put("s", "");
        emptyVals.put("xs", List.of());
        emptyVals.put("m", Map.of());
        expectEq("dict empty", "01000000000000", PackbinTest.toHex(Pack.run(empty, emptyVals)));

        Scheme<MapRow> dup = new Scheme<>(1, MapRow.class, Packbin.dict("access", Packbin.utf8("v")));
        Packbin.UnpackResult bad = Unpack.values(dup, PackbinTest.parseHex("010200010061010078010061010079"));
        expectTrue("dict dup", !bad.ok);
        expectEq("dict dup values", 0, bad.value.size());

        Map<String, Object> huge = new HashMap<>();
        for (int i = 0; i < 65536; i++) {
            huge.put(Integer.toString(i), "x");
        }
        Map<String, Object> longVals = new HashMap<>();
        longVals.put("access", huge);
        boolean failed = false;
        try {
            Pack.run(dup, longVals);
        } catch (IllegalArgumentException ex) {
            failed = true;
        }
        expectTrue("dict too long", failed);
    }

    private static void u2Kinds() {
        Scheme<MapRow> kinds = new Scheme<>(1, MapRow.class, Packbin.u2("a", "b", "c", "d"));
        Map<String, Object> values = new HashMap<>();
        values.put("a", 0);
        values.put("b", 1);
        values.put("c", 2);
        values.put("d", 3);
        byte[] raw = Pack.run(kinds, values);
        expectEq("u2 hex", "01e4", PackbinTest.toHex(raw));
        Packbin.UnpackResult got = Unpack.values(kinds, raw);
        expectTrue("u2 ok", got.ok);
        expectEq("u2 a", 0, ((Number) got.value.get("a")).intValue());
        expectEq("u2 b", 1, ((Number) got.value.get("b")).intValue());
        expectEq("u2 c", 2, ((Number) got.value.get("c")).intValue());
        expectEq("u2 d", 3, ((Number) got.value.get("d")).intValue());
        Map<String, Object> oneValues = new HashMap<>();
        oneValues.put("a", 1);
        byte[] one = Pack.run(new Scheme<>(1, MapRow.class, Packbin.u2("a")), oneValues);
        expectEq("u2 one", "0101", PackbinTest.toHex(one));
    }

    private static void bitsSegs() {
        Scheme<MapRow> layout = new Scheme<>(1, MapRow.class, Packbin.u8("n"), Packbin.bits("segs", "n"));
        Map<String, Object> eightValues = new HashMap<>();
        eightValues.put("n", 8);
        eightValues.put("segs", List.of(1, 1, 1, 1, 1, 1, 1, 1));
        byte[] eight = Pack.run(layout, eightValues);
        expectEq("bits eight payload", "ff", PackbinTest.toHex(java.util.Arrays.copyOfRange(eight, 2, eight.length)));
        expectEq("bits eight adds", 1, eight.length - 2);
        Map<String, Object> nineValues = new HashMap<>();
        nineValues.put("n", 9);
        nineValues.put("segs", List.of(1, 1, 1, 1, 1, 1, 1, 1, 1));
        byte[] nine = Pack.run(layout, nineValues);
        expectEq("bits nine adds", 2, nine.length - 2);
        expectEq("bits nine lo", 0xFF, nine[2] & 0xFF);
        expectEq("bits nine hi masked", 0, nine[3] & 0xFE);
        Packbin.UnpackResult shortRead = Unpack.values(layout, new byte[] {0x01, 9, 0x01});
        expectEq("bits short values", 0, shortRead.value.size());
        expectTrue("bits short error", shortRead.error instanceof Packbin.ShortPacket);
        Packbin.ShortPacket missing = (Packbin.ShortPacket) shortRead.error;
        expectEq("bits short field", "segs", missing.field);
        expectEq("bits short needed", 2, missing.needed);
        expectEq("bits short left", 1, missing.left);
    }

    private static void expectEq(String label, Object expected, Object actual) {
        if (expected == null ? actual != null : !expected.equals(actual)) {
            failures++;
            System.err.println("FAIL " + label + ": expected " + expected + ", got " + actual);
        }
    }

    private static void expectTrue(String label, boolean condition) {
        if (!condition) {
            failures++;
            System.err.println("FAIL " + label + ": expected true");
        }
    }
}
