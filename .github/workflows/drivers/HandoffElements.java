import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import packbin.Access;
import packbin.BinaryPacker;
import packbin.Field;
import packbin.Packbin;
import packbin.Scheme;

/**
 * The listgroup, dictgroup and listflags commands of {@link Handoff} (AZ-2102, AZ-2239): a list of group, a
 * dict of group and a list of flags. An absent value is a clear flag bit, so the flags item {@code {b=2}}
 * packs its flag byte as 02.
 */
final class HandoffElements {
    private static final List<String> KINDS = List.of("listgroup", "dictgroup", "listflags");

    private HandoffElements() {
    }

    /** Runs {@code pack-<kind>}, {@code unpack-<kind> <hex>} or {@code unpack-<kind>-short <hex>}; 2 for any other command. */
    @SuppressWarnings({"unchecked", "rawtypes"})
    static int run(String cmd, String[] args) {
        for (String kind : KINDS) {
            if (cmd.equals("pack-" + kind)) {
                System.out.println(Handoff.hex(BinaryPacker.pack(scheme(kind), values(kind))));
                return 0;
            }
            boolean shortCase = cmd.equals("unpack-" + kind + "-short");
            if (!shortCase && !cmd.equals("unpack-" + kind)) {
                continue;
            }
            if (args.length < 2 || args[1].isEmpty()) {
                return 2;
            }
            Map[] got = new Map[1];
            Object err = BinaryPacker.unpack(Handoff.parse(args[1]), scheme(kind).on(row -> got[0] = row));
            if (shortCase) {
                // A short element is refused and no row reaches the handler.
                if (err != null && got[0] == null) {
                    return 0;
                }
                System.err.println(cmd + ": error " + err + ", row " + got[0] + "; expected a refusal and no row");
                return 1;
            }
            if (err != null || !values(kind).equals(got[0])) {
                System.err.println(cmd + ": error " + err + ", read " + got[0] + ", expected " + values(kind));
                return 1;
            }
            return 0;
        }
        return 2;
    }

    private static Field point() {
        return Packbin.group(0,
                Packbin.u8(0, Access.get("a"), Access.set("a")),
                Packbin.u8(1, Access.get("b"), Access.set("b")));
    }

    @SuppressWarnings({"unchecked", "rawtypes"})
    private static Scheme<Map> scheme(String kind) {
        Field element = switch (kind) {
            case "listgroup" -> Packbin.list(Access.get("pts"), Access.set("pts"), point());
            case "dictgroup" -> Packbin.dict(Access.get("m"), Access.set("m"), point());
            default -> Packbin.list(Access.get("pts"), Access.set("pts"),
                    Packbin.flags(0, Packbin.u8(0, Access.get("a"), Access.set("a")),
                            Packbin.u16(1, Access.get("b"), Access.set("b"))));
        };
        return new Scheme<>(1, (Class) Map.class, element);
    }

    private static Map<String, Object> values(String kind) {
        Map<String, Object> row = new HashMap<>();
        switch (kind) {
            case "listgroup" -> row.put("pts", List.of(Map.of("a", 1, "b", 2), Map.of("a", 3, "b", 4)));
            case "dictgroup" -> {
                Map<String, Object> items = new LinkedHashMap<>();
                items.put("y", Map.of("a", 3, "b", 4));
                items.put("x", Map.of("a", 1, "b", 2));
                row.put("m", items);
            }
            default -> row.put("pts", List.of(Map.of("a", 1), Map.of(), Map.of("b", 2)));
        }
        return row;
    }
}
