package packbin;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;
import java.util.function.Supplier;

/**
 * AZ-2417 (loop 22): the Java schemes and rows of the ten cases added to fixtures/hostile/cases.txt in loop 22,
 * replayed by HostileVectorTest. Java runs all ten (the README's "Not run by" lines name only Rust and C++).
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class HostileLoop22 {
    private HostileLoop22() {}

    /** The ids this file supplies; HostileVectorTest requires each to be present in cases.txt. */
    static final List<String> IDS = List.of(
            "pack_novalue_count_clear_when_bits", "pack_novalue_count_clear_when_packed",
            "pack_novalue_count_clear_when_sized", "pack_repeat_unequal_lists_lone", "pack_repeat_unequal_lists_when",
            "pack_times_short_list_flags", "pack_element_times_over_bytes_budget", "construct_empty_when_times_body",
            "construct_empty_when_repeat_body", "construct_empty_nested_when_body");

    static Supplier<byte[]> packFor(String id) {
        return switch (id) {
            case "pack_novalue_count_clear_when_bits" -> () -> BinaryPacker.pack(
                    noValue(Packbin.bits(2, Access.get("v"), Access.set("v"), 1)), Maps.map("mode", 0, "c", 3));
            case "pack_novalue_count_clear_when_packed" -> () -> BinaryPacker.pack(
                    noValue(Packbin.packed(1, 2, Access.get("v"), Access.set("v"), 1, 0)), Maps.map("mode", 0, "c", 3));
            case "pack_novalue_count_clear_when_sized" -> () -> BinaryPacker.pack(
                    noValue(Packbin.sized(2, Access.get("v"), Access.set("v"), 1)), Maps.map("mode", 0, "c", 3));
            case "pack_repeat_unequal_lists_lone" -> () -> BinaryPacker.pack(
                    Maps.scheme(1, Packbin.repeat(0, u8(0, "a"), u8(1, "b"))), Maps.map("a", List.of(1, 2), "b", 7));
            case "pack_repeat_unequal_lists_when" -> () -> BinaryPacker.pack(
                    Maps.scheme(1, Packbin.repeat(0, u8(0, "k"), Packbin.when(1, Packbin.eq(0, 1), u8(1, "v")))),
                    Maps.map("k", List.of(1, 2), "v", List.of(9)));
            case "pack_times_short_list_flags" -> () -> BinaryPacker.pack(
                    Maps.scheme(1, u8(0, "c"), Packbin.times(1, 0, Packbin.flags(1, u8(1, "v")))),
                    Maps.map("c", 2, "v", List.of(5)));
            case "pack_element_times_over_bytes_budget" -> () -> {
                List<Object> items = new ArrayList<>();
                for (int i = 0; i < 16; i++) {
                    items.add(Maps.map("n", 65_535, "s", String.valueOf((char) 1).repeat(16)));
                }
                return BinaryPacker.pack(Maps.scheme(1, Packbin.list(Access.get("items"), Access.set("items"),
                        Packbin.group(0, Packbin.u32(0, Access.get("n"), Access.set("n")),
                                Packbin.times(1, 0, Packbin.utf8(1, Access.get("s"), Access.set("s")))))),
                        Maps.map("items", items));
            };
            default -> null;
        };
    }

    static Supplier<Scheme<Map>> constructFor(String id) {
        return switch (id) {
            case "construct_empty_when_times_body" -> () -> Maps.scheme(1, u8(0, "mode"), u8(1, "c"),
                    Packbin.times(2, 1, Packbin.when(2, Packbin.eq(0, 1))));
            case "construct_empty_when_repeat_body" -> () -> Maps.scheme(1, u8(0, "mode"),
                    Packbin.repeat(1, Packbin.when(1, Packbin.eq(0, 1))));
            case "construct_empty_nested_when_body" -> () -> Maps.scheme(1, u8(0, "mode"), u8(1, "c"),
                    Packbin.times(2, 1, Packbin.when(2, Packbin.eq(0, 1), Packbin.when(2, Packbin.eq(0, 1)))));
            default -> null;
        };
    }

    /** u8 mode; when mode == 1 { u8 c }; split-form flag byte, bit 0 holds {@code member}, counted by c. */
    private static Scheme<Map> noValue(Field member) {
        Field fb = Packbin.flagByte();
        return Maps.scheme(1, u8(0, "mode"), Packbin.when(1, Packbin.eq(0, 1), u8(1, "c")), fb, fb.bit(member));
    }

    private static Field u8(int id, String name) {
        return Packbin.u8(id, Access.get(name), Access.set(name));
    }
}
