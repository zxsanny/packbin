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
        Scheme<Map> empty = Maps.scheme(1, Packbin.flags(
                Packbin.boolField(0, Access.get("mark"), Access.set("mark"))));
        Map<String, Object> present = Maps.map("mark", Boolean.TRUE);
        byte[] setBit = BinaryPacker.pack(empty, present);
        expectEq("mark set length", 2, setBit.length);
        expectEq("mark set byte", 0x01, setBit[1] & 0xFF);
        expectEq("mark set adds", 0, setBit.length - 2);
        byte[] clear = BinaryPacker.pack(empty, new HashMap<>());
        expectEq("mark clear length", 2, clear.length);
        expectEq("mark clear byte", 0x00, clear[1] & 0xFF);
    }

    private static void flagGroupWideBit() {
        Scheme<Map> one = Maps.scheme(1, Packbin.flags(
                Packbin.u8(0, Access.get("a"), Access.set("a")),
                Packbin.u8(1, Access.get("b"), Access.set("b")),
                Packbin.u8(2, Access.get("c"), Access.set("c")),
                Packbin.u8(3, Access.get("d"), Access.set("d")),
                Packbin.u8(4, Access.get("e"), Access.set("e")),
                Packbin.u16(5, Access.get("b5"), Access.set("b5"))));
        expectEq("wide a length", 3, BinaryPacker.pack(one, Maps.map("a", 1)).length);
        byte[] wide = BinaryPacker.pack(one, Maps.map("b5", 1));
        expectEq("wide flags", 0x20, wide[1] & 0xFF);
        expectEq("wide adds", 2, wide.length - BinaryPacker.pack(one, new HashMap<>()).length);
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private static void flagGroupSession() {
        Scheme<Map> two = Maps.scheme(1, Packbin.flags(
                Packbin.group(
                        Packbin.u16(0, Access.get("login"), Access.set("login")),
                        Packbin.u32(1, Access.get("ts"), Access.set("ts")))));
        byte[] raw = BinaryPacker.pack(two, Maps.map("login", 7, "ts", 1000));
        expectEq("session payload", "0700e8030000", PackbinTest.toHex(java.util.Arrays.copyOfRange(raw, 2, raw.length)));
        expectEq("session adds", 6, raw.length - 2);
        byte[] absent = BinaryPacker.pack(two, new HashMap<>());
        expectEq("session absent", "0100", PackbinTest.toHex(absent));
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(absent, two.on(row -> got[0] = row));
        expectTrue("session absent ok", err == null);
        expectTrue("session no login", !got[0].containsKey("login"));
        expectTrue("session no ts", !got[0].containsKey("ts"));
    }

    private static void flagGroupStoredZero() {
        Scheme<Map> zero = Maps.scheme(1, Packbin.flags(
                Packbin.group(Packbin.u8(0, Access.get("b"), Access.set("b")))));
        byte[] stored = BinaryPacker.pack(zero, Maps.map("b", 0));
        expectEq("group zero", "010100", PackbinTest.toHex(stored));
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private static void flagGroupShortLogin() {
        Scheme<Map> two = Maps.scheme(1, Packbin.flags(
                Packbin.group(
                        Packbin.u16(0, Access.get("login"), Access.set("login")),
                        Packbin.u32(1, Access.get("ts"), Access.set("ts")))));
        Map[] shortGot = new Map[1];
        Object shortRead = BinaryPacker.unpack(new byte[] {0x01, 0x01, 0x07}, two.on(row -> shortGot[0] = row));
        expectTrue("short login handler did not run", shortGot[0] == null);
        expectTrue("short login error", shortRead instanceof Packbin.ShortPacket);
        Packbin.ShortPacket missing = (Packbin.ShortPacket) shortRead;
        expectEq("short login field", "0", missing.field);
        expectEq("short login needed", 2, missing.needed);
        expectEq("short login left", 1, missing.left);
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private static void sizedPayload() {
        Scheme<Map> layout = Maps.scheme(1,
                Packbin.u16(0, Access.get("n"), Access.set("n")),
                Packbin.sized(1, Access.get("payload"), Access.set("payload"), 0));
        Map<String, Object> values = Maps.map("n", 3, "payload", PackbinTest.parseHex("756176"));
        byte[] raw = BinaryPacker.pack(layout, values);
        expectEq("sized hex", "010300756176", PackbinTest.toHex(raw));
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(raw, layout.on(row -> got[0] = row));
        expectTrue("sized ok", err == null);
        expectEq("sized payload", 0, PackbinTest.mismatchedBytes((byte[]) got[0].get("payload"), PackbinTest.parseHex("756176")));
        byte[] empty = BinaryPacker.pack(layout, Maps.map("n", 0, "payload", new byte[0]));
        expectEq("sized empty hex", "010000", PackbinTest.toHex(empty));
        Map[] emptyGot = new Map[1];
        Object emptyErr = BinaryPacker.unpack(empty, layout.on(row -> emptyGot[0] = row));
        expectTrue("sized empty ok", emptyErr == null);
        expectEq("sized empty length", 0, ((byte[]) emptyGot[0].get("payload")).length);
        Map[] shortGot = new Map[1];
        Object shortRead = BinaryPacker.unpack(PackbinTest.parseHex("01030075"), layout.on(row -> shortGot[0] = row));
        expectTrue("sized short handler did not run", shortGot[0] == null);
        expectTrue("sized short error", shortRead instanceof Packbin.ShortPacket);
        Packbin.ShortPacket missing = (Packbin.ShortPacket) shortRead;
        expectEq("sized short field", "1", missing.field);
        expectEq("sized short needed", 3, missing.needed);
        expectEq("sized short left", 1, missing.left);
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private static void utf8String() {
        Scheme<Map> layout = Maps.scheme(1, Packbin.utf8(0, Access.get("name"), Access.set("name")));
        byte[] raw = BinaryPacker.pack(layout, Maps.map("name", "zxsanny"));
        expectEq("utf8 hex", "0107007a7873616e6e79", PackbinTest.toHex(raw));
        expectEq("utf8 len", 10, raw.length);
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(raw, layout.on(row -> got[0] = row));
        expectTrue("utf8 ok", err == null);
        expectEq("utf8 text", "zxsanny", got[0].get("name"));

        byte[] empty = BinaryPacker.pack(layout, Maps.map("name", ""));
        expectEq("utf8 empty", "010000", PackbinTest.toHex(empty));
        Map[] emptyGot = new Map[1];
        Object emptyErr = BinaryPacker.unpack(empty, layout.on(row -> emptyGot[0] = row));
        expectTrue("utf8 empty ok", emptyErr == null);
        expectEq("utf8 empty text", "", emptyGot[0].get("name"));

        boolean failed = false;
        try {
            BinaryPacker.pack(layout, Maps.map("name", "a".repeat(65536)));
        } catch (IllegalArgumentException ex) {
            failed = true;
        }
        expectTrue("utf8 too long", failed);

        Map[] shortGot = new Map[1];
        Object shortErr = BinaryPacker.unpack(new byte[] {0x01, 0x07, 0x00, 0x7a, 0x78}, layout.on(row -> shortGot[0] = row));
        expectTrue("utf8 short", shortErr != null);
        expectTrue("utf8 short handler did not run", shortGot[0] == null);
        Packbin.ShortPacket missing = (Packbin.ShortPacket) shortErr;
        expectEq("utf8 short field", "0", missing.field);
        expectEq("utf8 short needed", 7, missing.needed);
        expectEq("utf8 short left", 2, missing.left);
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private static void countedList() {
        Scheme<Map> two = Maps.scheme(1, Packbin.list(
                Access.get("xs"), Access.set("xs"),
                Packbin.u16(0, Access.identity(), Access.ignore())));
        byte[] raw = BinaryPacker.pack(two, Maps.map("xs", List.of(1, 2)));
        expectEq("list hex", "01020001000200", PackbinTest.toHex(raw));
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(raw, two.on(row -> got[0] = row));
        expectTrue("list ok", err == null);
        expectEq("list 0", 1, ((Number) ((List<?>) got[0].get("xs")).get(0)).intValue());
        expectEq("list 1", 2, ((Number) ((List<?>) got[0].get("xs")).get(1)).intValue());

        Scheme<Map> beOne = Maps.scheme(1, Packbin.list(
                Access.get("xs"), Access.set("xs"),
                Packbin.be(Packbin.u16(0, Access.identity(), Access.ignore()))));
        expectEq("list be", "0101000001", PackbinTest.toHex(BinaryPacker.pack(beOne, Maps.map("xs", List.of(1)))));

        Scheme<Map> followed = Maps.scheme(1,
                Packbin.list(Access.get("xs"), Access.set("xs"), Packbin.u8(0, Access.identity(), Access.ignore())),
                Packbin.u8(0, Access.get("y"), Access.set("y")));
        byte[] both = BinaryPacker.pack(followed, Maps.map("xs", List.of(1), "y", 2));
        expectEq("list next hex", "0101000102", PackbinTest.toHex(both));
        Map[] back = new Map[1];
        Object backErr = BinaryPacker.unpack(both, followed.on(row -> back[0] = row));
        expectTrue("list next ok", backErr == null);
        expectEq("list next xs", 1, ((Number) ((List<?>) back[0].get("xs")).get(0)).intValue());
        expectEq("list next y", 2, ((Number) back[0].get("y")).intValue());

        expectEq("list empty", "010000", PackbinTest.toHex(BinaryPacker.pack(two, Maps.map("xs", List.of()))));
        List<Integer> huge = new java.util.ArrayList<>();
        for (int i = 0; i < 65536; i++) {
            huge.add(1);
        }
        boolean failed = false;
        try {
            BinaryPacker.pack(two, Maps.map("xs", huge));
        } catch (IllegalArgumentException ex) {
            failed = true;
        }
        expectTrue("list too long", failed);
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private static void dictionary() throws Exception {
        String userHex =
                "0107007a7873616e6e7902000400757365720a0064697370617463686572030007006368616e6e656c010004007265616403006d6170040004007265616407006770735f6669780300736574040065646974050073746f7265020004007265616405007772697465";
        Scheme<Map> layout = Maps.scheme(1,
                Packbin.utf8(0, Access.get("username"), Access.set("username")),
                Packbin.list(Access.get("roles"), Access.set("roles"),
                        Packbin.utf8(0, Access.identity(), Access.ignore())),
                Packbin.dict(Access.get("access"), Access.set("access"),
                        Packbin.list(Access.identity(), Access.ignore(),
                                Packbin.utf8(0, Access.identity(), Access.ignore()))));
        Map<String, Object> access = new java.util.LinkedHashMap<>();
        access.put("store", List.of("read", "write"));
        access.put("channel", List.of("read"));
        access.put("map", List.of("read", "gps_fix", "set", "edit"));
        Map<String, Object> values = Maps.map(
                "username", "zxsanny",
                "roles", List.of("user", "dispatcher"),
                "access", access);
        byte[] raw = BinaryPacker.pack(layout, values);
        expectEq("dict hex", userHex, PackbinTest.toHex(raw));
        expectEq("dict len", 104, raw.length);
        expectEq("dict twice", 0, PackbinTest.mismatchedBytes(raw, BinaryPacker.pack(layout, values)));
        byte[][] parallel = new byte[2][];
        Thread first = new Thread(() -> parallel[0] = BinaryPacker.pack(layout, values));
        Thread second = new Thread(() -> parallel[1] = BinaryPacker.pack(layout, values));
        first.start();
        second.start();
        first.join();
        second.join();
        expectEq("dict parallel", 0, PackbinTest.mismatchedBytes(parallel[0], parallel[1]));
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(raw, layout.on(row -> got[0] = row));
        expectTrue("dict ok", err == null);
        expectEq("dict user", "zxsanny", got[0].get("username"));
        List<?> roles = (List<?>) got[0].get("roles");
        expectEq("dict roles", 2, roles.size());
        expectEq("dict role 0", "user", roles.get(0));
        expectEq("dict role 1", "dispatcher", roles.get(1));
        Map<?, ?> back = (Map<?, ?>) got[0].get("access");
        expectEq("dict access", 3, back.size());
        expectEq("dict channel", "read", ((List<?>) back.get("channel")).get(0));
        expectEq("dict map", "gps_fix", ((List<?>) back.get("map")).get(1));
        expectEq("dict store", "write", ((List<?>) back.get("store")).get(1));

        Scheme<Map> empty = Maps.scheme(1,
                Packbin.utf8(0, Access.get("s"), Access.set("s")),
                Packbin.list(Access.get("xs"), Access.set("xs"), Packbin.u8(0, Access.identity(), Access.ignore())),
                Packbin.dict(Access.get("m"), Access.set("m"), Packbin.utf8(0, Access.identity(), Access.ignore())));
        expectEq("dict empty", "01000000000000", PackbinTest.toHex(BinaryPacker.pack(empty, Maps.map("s", "", "xs", List.of(), "m", Map.of()))));

        Scheme<Map> dup = Maps.scheme(1, Packbin.dict(
                Access.get("access"), Access.set("access"),
                Packbin.utf8(0, Access.identity(), Access.ignore())));
        Map[] badGot = new Map[1];
        Object bad = BinaryPacker.unpack(PackbinTest.parseHex("010200010061010078010061010079"), dup.on(row -> badGot[0] = row));
        expectTrue("dict dup", bad != null);
        expectTrue("dict dup handler did not run", badGot[0] == null);

        Map<String, Object> huge = new HashMap<>();
        for (int i = 0; i < 65536; i++) {
            huge.put(Integer.toString(i), "x");
        }
        boolean failed = false;
        try {
            BinaryPacker.pack(dup, Maps.map("access", huge));
        } catch (IllegalArgumentException ex) {
            failed = true;
        }
        expectTrue("dict too long", failed);
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private static void u2Kinds() {
        Scheme<Map> kinds = Maps.scheme(1, Packbin.u2(
                Packbin.u2Slot(0, Access.get("a"), Access.set("a")),
                Packbin.u2Slot(1, Access.get("b"), Access.set("b")),
                Packbin.u2Slot(2, Access.get("c"), Access.set("c")),
                Packbin.u2Slot(3, Access.get("d"), Access.set("d"))));
        byte[] raw = BinaryPacker.pack(kinds, Maps.map("a", 0, "b", 1, "c", 2, "d", 3));
        expectEq("u2 hex", "01e4", PackbinTest.toHex(raw));
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(raw, kinds.on(row -> got[0] = row));
        expectTrue("u2 ok", err == null);
        expectEq("u2 a", 0, ((Number) got[0].get("a")).intValue());
        expectEq("u2 b", 1, ((Number) got[0].get("b")).intValue());
        expectEq("u2 c", 2, ((Number) got[0].get("c")).intValue());
        expectEq("u2 d", 3, ((Number) got[0].get("d")).intValue());
        byte[] one = BinaryPacker.pack(Maps.scheme(1, Packbin.u2(Packbin.u2Slot(0, Access.get("a"), Access.set("a")))), Maps.map("a", 1));
        expectEq("u2 one", "0101", PackbinTest.toHex(one));
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private static void bitsSegs() {
        Scheme<Map> layout = Maps.scheme(1,
                Packbin.u8(0, Access.get("n"), Access.set("n")),
                Packbin.bits(1, Access.get("segs"), Access.set("segs"), 0));
        byte[] eight = BinaryPacker.pack(layout, Maps.map("n", 8, "segs", List.of(1, 1, 1, 1, 1, 1, 1, 1)));
        expectEq("bits eight payload", "ff", PackbinTest.toHex(java.util.Arrays.copyOfRange(eight, 2, eight.length)));
        expectEq("bits eight adds", 1, eight.length - 2);
        byte[] nine = BinaryPacker.pack(layout, Maps.map("n", 9, "segs", List.of(1, 1, 1, 1, 1, 1, 1, 1, 1)));
        expectEq("bits nine adds", 2, nine.length - 2);
        expectEq("bits nine lo", 0xFF, nine[2] & 0xFF);
        expectEq("bits nine hi masked", 0, nine[3] & 0xFE);
        Map[] shortGot = new Map[1];
        Object shortRead = BinaryPacker.unpack(new byte[] {0x01, 9, 0x01}, layout.on(row -> shortGot[0] = row));
        expectTrue("bits short handler did not run", shortGot[0] == null);
        expectTrue("bits short error", shortRead instanceof Packbin.ShortPacket);
        Packbin.ShortPacket missing = (Packbin.ShortPacket) shortRead;
        expectEq("bits short field", "1", missing.field);
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
