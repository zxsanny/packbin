package packbin;

import java.util.List;
import java.util.Map;
import java.util.function.Supplier;

/**
 * AC-3: the Java schemes and rows of the fifteen repeat-last cases of fixtures/hostile/cases.txt, replayed by
 * HostileVectorTest. They are R1 to R9, the two of AZ-4232 (a repeat in a nested row in a round) and K1 to K4 of the
 * contract repeat-last: a repeat that is not the last
 * thing its packet reads is refused when the scheme is built. Java writes all fifteen, with Map rows; a nested row
 * numbers its fields from 0, so {@code x} after the nested row of R4 is id 0.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class HostileLoop113 {
    private HostileLoop113() {}

    /** The ids this file supplies; HostileVectorTest requires each to be present in cases.txt. */
    static final List<String> IDS = List.of(
            "construct_repeat_then_field", "construct_repeat_in_when_then_field",
            "construct_repeat_in_flags_then_field", "construct_repeat_in_group_then_field",
            "construct_repeat_then_repeat", "construct_repeat_then_exclusive_when",
            "construct_repeat_in_list_element", "construct_repeat_in_dict_element", "construct_repeat_in_times_round",
            "construct_repeat_in_group_in_repeat_round", "construct_repeat_in_group_in_times_round",
            "pack_repeat_last", "pack_repeat_last_in_when", "pack_repeat_last_in_flags", "pack_times_then_field");

    static Supplier<byte[]> packFor(String id) {
        return switch (id) {
            case "pack_repeat_last" -> () -> BinaryPacker.pack(
                    Maps.scheme(1, u8(0, "x"), Packbin.repeat(1, u8(1, "v"))), Maps.map("x", 9, "v", List.of(5, 6)));
            case "pack_repeat_last_in_when" -> () -> BinaryPacker.pack(
                    Maps.scheme(1, u8(0, "k"), whenKIs(1, 1, rounds(1))), Maps.map("k", 1, "v", List.of(5, 6)));
            case "pack_repeat_last_in_flags" -> () -> BinaryPacker.pack(
                    Maps.scheme(1, Packbin.flags(0, u8(0, "x"), rounds(1))), Maps.map("x", 9, "v", List.of(5, 6)));
            case "pack_times_then_field" -> () -> BinaryPacker.pack(
                    Maps.scheme(1, u8(0, "k"), Packbin.times(1, 0, u8(1, "v")), u8(2, "x")),
                    Maps.map("k", 2, "v", List.of(5, 6), "x", 9));
            default -> null;
        };
    }

    static Supplier<Scheme<Map>> constructFor(String id) {
        return switch (id) {
            case "construct_repeat_then_field" -> () -> Maps.scheme(1, rounds(0), u8(1, "x"));
            case "construct_repeat_in_when_then_field" -> () -> Maps.scheme(1,
                    u8(0, "k"), whenKIs(1, 1, rounds(1)), u8(2, "x"));
            case "construct_repeat_in_flags_then_field" -> () -> Maps.scheme(1,
                    Packbin.flags(0, rounds(0)), u8(1, "x"));
            case "construct_repeat_in_group_then_field" -> () -> Maps.scheme(1,
                    Packbin.group(Access.get("m"), Access.set("m"), rounds(0)), u8(0, "x"));
            case "construct_repeat_then_repeat" -> () -> Maps.scheme(1, rounds(0), Packbin.repeat(1, u8(1, "w")));
            case "construct_repeat_then_exclusive_when" -> () -> Maps.scheme(1,
                    u8(0, "k"), whenKIs(1, 1, rounds(1)), whenKIs(2, 2, u8(2, "x")));
            case "construct_repeat_in_list_element" -> () -> Maps.scheme(1,
                    Packbin.list(Access.get("items"), Access.set("items"), elementRow()));
            case "construct_repeat_in_dict_element" -> () -> Maps.scheme(1,
                    Packbin.dict(Access.get("d"), Access.set("d"), elementRow()));
            case "construct_repeat_in_times_round" -> () -> Maps.scheme(1, u8(0, "k"), Packbin.times(1, 0, rounds(1)));
            case "construct_repeat_in_group_in_repeat_round" -> () -> Maps.scheme(1,
                    Packbin.repeat(0, nestedRepeat()));
            case "construct_repeat_in_group_in_times_round" -> () -> Maps.scheme(1,
                    u8(0, "k"), Packbin.times(1, 0, nestedRepeat()));
            default -> null;
        };
    }

    /** repeat anchor {@code id} { u8 v }: the body continues the ids of the place around it. */
    private static Field rounds(int id) {
        return Packbin.repeat(id, u8(id, "v"));
    }

    /** when anchor {@code anchor}, k (id 0) == {@code value}. */
    private static Field whenKIs(int anchor, int value, Field held) {
        return Packbin.when(anchor, Packbin.eq(0, value), held);
    }

    /** The element row (u8 mode, repeat(u8 v)) of R7 and R8, a nested row: each element is a Map of its own. */
    private static Field elementRow() {
        return Packbin.group(Access.identity(), Access.ignore(), u8(0, "mode"), rounds(1));
    }

    /** AZ-4232: a nested row m that holds repeat anchor 0 { u8 v }; the nested row numbers its own fields from 0. */
    private static Field nestedRepeat() {
        return Packbin.group(Access.get("m"), Access.set("m"), rounds(0));
    }

    private static Field u8(int id, String name) {
        return Packbin.u8(id, Access.get(name), Access.set(name));
    }
}
