import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import packbin.Access;
import packbin.BinaryPacker;
import packbin.Field;
import packbin.PackSession;
import packbin.Packbin;
import packbin.Scheme;

public final class Handoff {
    private static final byte[] SESSION_SEED = seed();
    private static final byte[] SESSION_NONCE = parse("01000000000000000000000000000000");

    public static void main(String[] args) {
        if (args.length < 1) {
            System.exit(2);
        }
        String cmd = args[0];
        switch (cmd) {
            case "pack-user" -> System.out.println(hex(BinaryPacker.pack(userScheme(), userValues())));
            case "pack-nested" -> System.out.println(hex(BinaryPacker.pack(nestedScheme(), nestedValues())));
            case "pack-boolflag" -> System.out.println(hex(BinaryPacker.pack(boolFlagScheme(), boolFlagValues(false))));
            case "pack-booltrue" -> System.out.println(hex(BinaryPacker.pack(boolFlagScheme(), boolFlagValues(true))));
            case "pack-bitwhen" -> System.out.println(hex(BinaryPacker.pack(bitWhenScheme(), bitWhenValues())));
            case "pack-session" -> System.exit(packSession());
            case "unpack-user" -> System.exit(userOk(requireHex(args)) ? 0 : 1);
            case "unpack-nested" -> System.exit(nestedOk(requireHex(args)) ? 0 : 1);
            case "unpack-boolflag" -> System.exit(boolFlagOk(requireHex(args), false) ? 0 : 1);
            case "unpack-booltrue" -> System.exit(boolFlagOk(requireHex(args), true) ? 0 : 1);
            case "unpack-bitwhen" -> System.exit(bitWhenOk(requireHex(args)) ? 0 : 1);
            case "unpack-session" -> System.exit(sessionOk(requireHex(args)) ? 0 : 1);
            default -> System.exit(2);
        }
    }

    private static byte[] seed() {
        byte[] bytes = new byte[32];
        for (int i = 0; i < 32; i++) {
            bytes[i] = (byte) (i + 1);
        }
        return bytes;
    }

    private static int packSession() {
        PackSession opener = PackSession.load(SESSION_SEED);
        if (opener == null || opener.start(SESSION_NONCE) == null) {
            return 1;
        }
        byte[] payload = opener.pack(positionScheme(), positionValues());
        if (payload == null) {
            return 1;
        }
        System.out.println(hex(payload));
        return 0;
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private static boolean sessionOk(String hex) {
        PackSession waiter = PackSession.load(SESSION_SEED);
        if (waiter == null || !waiter.join(SESSION_NONCE)) {
            return false;
        }
        Map[] got = new Map[1];
        Object err = waiter.unpack(parse(hex), positionScheme().on(row -> got[0] = row));
        if (err != null || got[0] == null) {
            return false;
        }
        if (!Integer.valueOf(1).equals(asInt(got[0].get("sid")))) {
            return false;
        }
        if (!Integer.valueOf(500_000_000).equals(asInt(got[0].get("lat")))) {
            return false;
        }
        if (!Integer.valueOf(300_000_000).equals(asInt(got[0].get("lon")))) {
            return false;
        }
        if (!Integer.valueOf(1).equals(asInt(got[0].get("profile")))) {
            return false;
        }
        return got[0].get("heading") == null
                && got[0].get("speed") == null
                && got[0].get("altitude") == null;
    }

    private static Integer asInt(Object value) {
        if (value instanceof Number n) {
            return n.intValue();
        }
        return null;
    }

    private static String requireHex(String[] args) {
        if (args.length < 2) {
            System.exit(2);
        }
        return args[1];
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private static Scheme<Map> userScheme() {
        return new Scheme<>(
                1,
                (Class) Map.class,
                Packbin.utf8(0, Access.get("username"), Access.set("username")),
                Packbin.list(Access.get("roles"), Access.set("roles"),
                        Packbin.utf8(0, Access.identity(), Access.ignore())),
                Packbin.dict(Access.get("access"), Access.set("access"),
                        Packbin.list(Access.identity(), Access.ignore(),
                                Packbin.utf8(0, Access.identity(), Access.ignore()))));
    }

    private static Map<String, Object> userValues() {
        Map<String, Object> access = new LinkedHashMap<>();
        access.put("channel", List.of("read"));
        access.put("map", List.of("read", "gps_fix", "set", "edit"));
        access.put("store", List.of("read", "write"));
        Map<String, Object> values = new HashMap<>();
        values.put("username", "zxsanny");
        values.put("roles", List.of("user", "dispatcher"));
        values.put("access", access);
        return values;
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private static Scheme<Map> nestedScheme() {
        return new Scheme<>(
                1,
                (Class) Map.class,
                Packbin.dict(Access.get("access"), Access.set("access"),
                        Packbin.list(Access.identity(), Access.ignore(),
                                Packbin.dict(Access.identity(), Access.ignore(),
                                        Packbin.utf8(0, Access.identity(), Access.ignore())))));
    }

    private static Map<String, Object> nestedValues() {
        Map<String, Object> access = new LinkedHashMap<>();
        access.put("map", List.of(Map.of("op", "gps_fix")));
        access.put("store", List.of(Map.of("op", "read"), Map.of("op", "write")));
        Map<String, Object> values = new HashMap<>();
        values.put("access", access);
        return values;
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private static Scheme<Map> boolFlagScheme() {
        return new Scheme<>(
                1,
                (Class) Map.class,
                Packbin.flags(0, Packbin.boolField(0, Access.get("on"), Access.set("on"))));
    }

    private static Map<String, Object> boolFlagValues(boolean on) {
        Map<String, Object> values = new HashMap<>();
        values.put("on", on);
        return values;
    }

    /** Only true sets the bit: {@code on} comes back true for a set bit, and absent (never true) for a clear one. */
    @SuppressWarnings({"unchecked", "rawtypes"})
    private static boolean boolFlagOk(String hex, boolean on) {
        String cmd = on ? "unpack-booltrue" : "unpack-boolflag";
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(parse(hex), boolFlagScheme().on(row -> got[0] = row));
        if (err != null || got[0] == null) {
            System.err.println(cmd + ": not ok (" + (err == null ? "no row" : err.getClass().getSimpleName()) + ")");
            return false;
        }
        if (Boolean.TRUE.equals(got[0].get("on")) != on) {
            System.err.println(cmd + ": on is " + got[0].get("on") + ", expected " + (on ? "true" : "absent or false"));
            return false;
        }
        return true;
    }

    /** u8 k, split flag byte m, when(k == 1) { m.bit(u8 v) }: the bit follows the row even when the when is not taken. */
    @SuppressWarnings({"unchecked", "rawtypes"})
    private static Scheme<Map> bitWhenScheme() {
        Field m = Packbin.flagByte();
        return new Scheme<>(
                1,
                (Class) Map.class,
                Packbin.u8(0, Access.get("k"), Access.set("k")),
                m,
                Packbin.when(1, Packbin.eq(0, 1), m.bit(Packbin.u8(1, Access.get("v"), Access.set("v")))));
    }

    private static Map<String, Object> bitWhenValues() {
        Map<String, Object> values = new HashMap<>();
        values.put("k", 0);
        values.put("v", 5);
        return values;
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private static boolean bitWhenOk(String hex) {
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(parse(hex), bitWhenScheme().on(row -> got[0] = row));
        if (err != null || got[0] == null) {
            System.err.println("unpack-bitwhen: not ok (" + (err == null ? "no row" : err.getClass().getSimpleName()) + ")");
            return false;
        }
        if (!Integer.valueOf(0).equals(asInt(got[0].get("k")))) {
            System.err.println("unpack-bitwhen: k is " + got[0].get("k") + ", expected 0");
            return false;
        }
        if (got[0].get("v") != null) {
            System.err.println("unpack-bitwhen: v is " + got[0].get("v") + ", expected absent");
            return false;
        }
        return true;
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private static Scheme<Map> positionScheme() {
        return new Scheme<>(
                0x40,
                (Class) Map.class,
                Packbin.u16(0, Access.get("sid"), Access.set("sid")),
                Packbin.i32(1, Access.get("lat"), Access.set("lat")),
                Packbin.i32(2, Access.get("lon"), Access.set("lon")),
                Packbin.u8(3, Access.get("profile"), Access.set("profile")),
                Packbin.flags(
                        4,
                        Packbin.u16(4, Access.get("heading"), Access.set("heading")),
                        Packbin.u8(5, Access.get("speed"), Access.set("speed")),
                        Packbin.i16(6, Access.get("altitude"), Access.set("altitude"))));
    }

    private static Map<String, Object> positionValues() {
        Map<String, Object> values = new HashMap<>();
        values.put("sid", 1);
        values.put("lat", 500_000_000);
        values.put("lon", 300_000_000);
        values.put("profile", 1);
        return values;
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private static boolean userOk(String hex) {
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(parse(hex), userScheme().on(row -> got[0] = row));
        if (err != null || got[0] == null || got[0].size() != 3) {
            return false;
        }
        if (!"zxsanny".equals(got[0].get("username"))) {
            return false;
        }
        List<?> roles = (List<?>) got[0].get("roles");
        if (roles == null || roles.size() != 2 || !"user".equals(roles.get(0)) || !"dispatcher".equals(roles.get(1))) {
            return false;
        }
        Map<?, ?> access = (Map<?, ?>) got[0].get("access");
        return access != null
                && access.size() == 3
                && List.of("read").equals(access.get("channel"))
                && List.of("read", "gps_fix", "set", "edit").equals(access.get("map"))
                && List.of("read", "write").equals(access.get("store"));
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private static boolean nestedOk(String hex) {
        Map[] got = new Map[1];
        Object err = BinaryPacker.unpack(parse(hex), nestedScheme().on(row -> got[0] = row));
        if (err != null || got[0] == null) {
            return false;
        }
        Map<?, ?> access = (Map<?, ?>) got[0].get("access");
        if (access == null || access.size() != 2) {
            return false;
        }
        return oneOp(access.get("map"), "gps_fix")
                && twoOps(access.get("store"), "read", "write");
    }

    private static boolean oneOp(Object raw, String op) {
        if (!(raw instanceof List<?> rows) || rows.size() != 1) {
            return false;
        }
        if (!(rows.get(0) instanceof Map<?, ?> fields)) {
            return false;
        }
        return op.equals(fields.get("op")) && fields.size() == 1;
    }

    private static boolean twoOps(Object raw, String a, String b) {
        if (!(raw instanceof List<?> rows) || rows.size() != 2) {
            return false;
        }
        return oneOp(List.of(rows.get(0)), a) && oneOp(List.of(rows.get(1)), b);
    }

    private static String hex(byte[] raw) {
        StringBuilder out = new StringBuilder();
        for (byte b : raw) {
            out.append(String.format("%02x", b));
        }
        return out.toString();
    }

    private static byte[] parse(String hex) {
        byte[] out = new byte[hex.length() / 2];
        for (int i = 0; i < out.length; i++) {
            out[i] = (byte) Integer.parseInt(hex.substring(i * 2, i * 2 + 2), 16);
        }
        return out;
    }
}
