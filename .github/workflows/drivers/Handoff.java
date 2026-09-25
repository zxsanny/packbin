import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import packbin.Access;
import packbin.BinaryPacker;
import packbin.Packbin;
import packbin.Scheme;

public final class Handoff {
    public static void main(String[] args) {
        if (args.length < 1) {
            System.exit(2);
        }
        String cmd = args[0];
        switch (cmd) {
            case "pack-user" -> System.out.println(hex(BinaryPacker.pack(userScheme(), userValues())));
            case "pack-nested" -> System.out.println(hex(BinaryPacker.pack(nestedScheme(), nestedValues())));
            case "unpack-user" -> System.exit(userOk(requireHex(args)) ? 0 : 1);
            case "unpack-nested" -> System.exit(nestedOk(requireHex(args)) ? 0 : 1);
            default -> System.exit(2);
        }
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
