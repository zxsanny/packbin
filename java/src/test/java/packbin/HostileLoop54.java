package packbin;

import java.util.List;
import java.util.Map;
import java.util.function.Supplier;

/**
 * AZ-2816 (loop 54): the Java schemes and rows of the cases added to fixtures/hostile/cases.txt in loops 54 and 55,
 * replayed by HostileVectorTest. A {@code when} whose source sits inside a clear {@code when} is false: the source
 * is absent, not 0.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class HostileLoop54 {
    private HostileLoop54() {}

    /** The ids this file supplies; HostileVectorTest requires each to be present in cases.txt. */
    static final List<String> IDS = List.of("pack_when_of_skipped_source", "pack_when_of_skipped_source_zero",
            "pack_when_of_skipped_bool_source", "pack_when_of_held_bool_source", "pack_when_of_held_bool_source_clear");

    static Supplier<byte[]> packFor(String id) {
        return switch (id) {
            case "pack_when_of_skipped_source" -> () -> BinaryPacker.pack(skippedSource(2),
                    Maps.map("mode", 0, "a", 7, "k", 2, "b", 5));
            case "pack_when_of_skipped_source_zero" -> () -> BinaryPacker.pack(skippedSource(0),
                    Maps.map("mode", 0, "a", 7, "k", 0, "b", 5));
            // AZ-3133 (loop 55): the source is a bool inside flags inside a when that may be clear.
            case "pack_when_of_skipped_bool_source" -> () -> BinaryPacker.pack(boolSource(),
                    Maps.map("mode", 0, "on", true, "a", 7, "b", 5));
            case "pack_when_of_held_bool_source" -> () -> BinaryPacker.pack(boolSource(),
                    Maps.map("mode", 1, "on", true, "a", 7, "b", 5));
            case "pack_when_of_held_bool_source_clear" -> () -> BinaryPacker.pack(boolSource(),
                    Maps.map("mode", 1, "on", false, "a", 7, "b", 5));
            default -> null;
        };
    }

    /** u8 mode; when mode == 1 { u16 a; u8 k }; when k == {@code kValue} { u8 b }: k sits inside the first when. */
    private static Scheme<Map> skippedSource(int kValue) {
        return Maps.scheme(1, u8(0, "mode"),
                Packbin.when(1, Packbin.eq(0, 1), Packbin.u16(1, Access.get("a"), Access.set("a")), u8(2, "k")),
                Packbin.when(3, Packbin.eq(2, kValue), u8(3, "b")));
    }

    /** u8 mode; when mode == 1 { flags { bool on }; u8 a }; when on == true { u8 b }: on sits inside the first when. */
    private static Scheme<Map> boolSource() {
        return Maps.scheme(1, u8(0, "mode"),
                Packbin.when(1, Packbin.eq(0, 1),
                        Packbin.flags(1, Packbin.boolField(1, Access.get("on"), Access.set("on"))), u8(2, "a")),
                Packbin.when(3, Packbin.eq(1, true), u8(3, "b")));
    }

    private static Field u8(int id, String name) {
        return Packbin.u8(id, Access.get(name), Access.set(name));
    }
}
