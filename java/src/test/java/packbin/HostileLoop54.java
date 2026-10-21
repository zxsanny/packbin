package packbin;

import java.util.List;
import java.util.Map;
import java.util.function.Supplier;

/**
 * AZ-2816 (loop 54): the Java schemes and rows of the two cases added to fixtures/hostile/cases.txt in loop 54,
 * replayed by HostileVectorTest. A {@code when} whose source sits inside a clear {@code when} is false: the source
 * is absent, not 0.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class HostileLoop54 {
    private HostileLoop54() {}

    /** The ids this file supplies; HostileVectorTest requires each to be present in cases.txt. */
    static final List<String> IDS = List.of("pack_when_of_skipped_source", "pack_when_of_skipped_source_zero");

    static Supplier<byte[]> packFor(String id) {
        return switch (id) {
            case "pack_when_of_skipped_source" -> () -> BinaryPacker.pack(skippedSource(2),
                    Maps.map("mode", 0, "a", 7, "k", 2, "b", 5));
            case "pack_when_of_skipped_source_zero" -> () -> BinaryPacker.pack(skippedSource(0),
                    Maps.map("mode", 0, "a", 7, "k", 0, "b", 5));
            default -> null;
        };
    }

    /** u8 mode; when mode == 1 { u16 a; u8 k }; when k == {@code kValue} { u8 b }: k sits inside the first when. */
    private static Scheme<Map> skippedSource(int kValue) {
        return Maps.scheme(1, u8(0, "mode"),
                Packbin.when(1, Packbin.eq(0, 1), Packbin.u16(1, Access.get("a"), Access.set("a")), u8(2, "k")),
                Packbin.when(3, Packbin.eq(2, kValue), u8(3, "b")));
    }

    private static Field u8(int id, String name) {
        return Packbin.u8(id, Access.get(name), Access.set(name));
    }
}
