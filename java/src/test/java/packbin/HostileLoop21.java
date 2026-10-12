package packbin;

import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.function.Supplier;

/**
 * AZ-2394 (loop 21): the Java schemes and rows of the fifteen cases added to fixtures/hostile/cases.txt in loop 21,
 * replayed by HostileVectorTest. Java ids: a flag byte takes no order id; an anchored group takes its own anchor.
 */
@SuppressWarnings({"unchecked", "rawtypes"})
final class HostileLoop21 {
    private HostileLoop21() {}

    /** The ids this file supplies; HostileVectorTest requires each to be present in cases.txt. */
    static final List<String> IDS = List.of(
            "pack_round_slots_at_limit", "pack_round_slots_over_limit", "pack_round_slots_flags_at_limit",
            "pack_round_slots_flags_over_limit", "pack_flags_short_list", "pack_flags_short_list_filled",
            "pack_split_times_absent_body", "pack_late_when_in_bit_body", "pack_count_one_clear_when",
            "pack_bits_count_clear_when", "pack_packed_count_clear_when", "pack_sized_count_clear_when",
            "construct_empty_times_body", "construct_empty_repeat_body", "construct_empty_round_body_list_element");

    private static final int MAX_ROUNDS = Scheme.DEFAULT_MAX_ROUNDS;

    static Supplier<byte[]> packFor(String id) {
        return switch (id) {
            case "pack_round_slots_at_limit" -> () -> BinaryPacker.pack(timesThenRepeat(),
                    Maps.map("n", 1, "a", List.of(1), "b", List.of(2, 3)));
            case "pack_round_slots_over_limit" -> () -> BinaryPacker.pack(timesThenRepeat(),
                    Maps.map("n", 1, "a", List.of(1), "b", List.of(2, 3, 4)));
            case "pack_round_slots_flags_at_limit" -> () -> BinaryPacker.pack(repeatFlags(),
                    Maps.map("on", List.of(true, true), "v", List.of(5, 6)));
            case "pack_round_slots_flags_over_limit" -> () -> BinaryPacker.pack(repeatFlags(),
                    Maps.map("on", List.of(true, true, true), "v", List.of(5, 6, 7)));
            case "pack_flags_short_list" -> () -> BinaryPacker.pack(shortListScheme(),
                    Maps.map("w", List.of(1, 2), "v", List.of(5)));
            case "pack_flags_short_list_filled" -> () -> BinaryPacker.pack(shortListScheme(),
                    Maps.map("w", List.of(1, 2), "v", Arrays.asList(5, null)));
            case "pack_split_times_absent_body" -> () -> BinaryPacker.pack(splitTimes(),
                    Maps.map("n", 2, "heading", 90));
            case "pack_late_when_in_bit_body" -> () -> {
                Field fb = Packbin.flagByte();
                return BinaryPacker.pack(Maps.scheme(1, fb, u8(0, "mode"), fb.bit(Packbin.group(1, u8(1, "d"),
                        Packbin.when(2, Packbin.eq(0, 1), u8(2, "a")), Packbin.when(3, Packbin.eq(0, 2), u8(3, "b"))))),
                        Maps.map("mode", 1, "d", 5, "a", 9));
            };
            case "pack_count_one_clear_when" -> () -> {
                Field fb = Packbin.flagByte();
                return BinaryPacker.pack(Maps.scheme(1, u8(0, "mode"), countWhen(), fb,
                        fb.bit(Packbin.times(2, 1, u8(2, "pt"))), fb.bit(Packbin.u16(3, Access.get("heading"),
                                Access.set("heading")))), Maps.map("mode", 0, "c", 1, "heading", 90));
            };
            case "pack_bits_count_clear_when" -> () -> BinaryPacker.pack(
                    clearWhen(Packbin.bits(2, Access.get("v"), Access.set("v"), 1)),
                    Maps.map("mode", 0, "c", 3, "v", List.of(1, 0, 1)));
            case "pack_packed_count_clear_when" -> () -> BinaryPacker.pack(
                    clearWhen(Packbin.packed(1, 2, Access.get("v"), Access.set("v"), 1, 0)),
                    Maps.map("mode", 0, "c", 3, "v", List.of(1, 0, 1)));
            case "pack_sized_count_clear_when" -> () -> BinaryPacker.pack(
                    clearWhen(Packbin.sized(2, Access.get("v"), Access.set("v"), 1)),
                    Maps.map("mode", 0, "c", 3, "v", new byte[] {1, 2, 3}));
            default -> null;
        };
    }

    static Supplier<Scheme<Map>> constructFor(String id) {
        return switch (id) {
            case "construct_empty_times_body" -> () -> Maps.scheme(1, u8(0, "n"), Packbin.times(1, 0));
            case "construct_empty_repeat_body" -> () -> Maps.scheme(1, Packbin.repeat(0));
            case "construct_empty_round_body_list_element" -> () -> Maps.scheme(1, Packbin.list(
                    Access.get("items"), Access.set("items"),
                    Packbin.group(0, Packbin.u32(0, Access.get("n"), Access.set("n")), Packbin.times(1, 0))));
            default -> null;
        };
    }

    /** id0 u8 n; times (count id0) { u8 a }; repeat { u8 b }: maxSlots 3, one slot per round. */
    private static Scheme<Map> timesThenRepeat() {
        return Maps.scheme(1, u8(0, "n"), Packbin.times(1, 0, u8(1, "a")), Packbin.repeat(2, u8(2, "b")))
                .withLimits(MAX_ROUNDS, 3);
    }

    /** repeat { flags { bool on; u8 v } }: a round is two slots, maxSlots 4. */
    private static Scheme<Map> repeatFlags() {
        return Maps.scheme(1, Packbin.repeat(0, Packbin.flags(0,
                Packbin.boolField(0, Access.get("on"), Access.set("on")), u8(1, "v")))).withLimits(MAX_ROUNDS, 4);
    }

    private static Scheme<Map> shortListScheme() {
        return Maps.scheme(1, Packbin.repeat(0, u8(0, "w"), Packbin.flags(1, u8(1, "v"))));
    }

    private static Scheme<Map> splitTimes() {
        Field fb = Packbin.flagByte();
        return Maps.scheme(1, fb, u8(0, "n"), fb.bit(Packbin.times(1, 0, u8(1, "pt"))),
                fb.bit(Packbin.u16(2, Access.get("heading"), Access.set("heading"))));
    }

    private static Field countWhen() {
        return Packbin.when(1, Packbin.eq(0, 1), u8(1, "c"));
    }

    /** u8 mode; when mode == 1 { u8 c }; member counted by c. */
    private static Scheme<Map> clearWhen(Field member) {
        return Maps.scheme(1, u8(0, "mode"), countWhen(), member);
    }

    private static Field u8(int id, String name) {
        return Packbin.u8(id, Access.get(name), Access.set(name));
    }
}
