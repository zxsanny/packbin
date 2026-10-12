package packbin;

import java.util.Map;

/**
 * AZ-2392: the rule each refused {@code pack} and {@code construct} case of fixtures/hostile/cases.txt must name, so a
 * refusal by some other rule does not pass (TypeScript's PACK_REFUSAL and CONSTRUCT tables). An entry is the exception
 * class Java throws and a message fragment that carries the rule and, where the message names one, the member.
 */
final class HostileRefusals {
    private HostileRefusals() {}

    record Rule(Class<? extends RuntimeException> type, String fragment) {}

    private static Rule bad(String fragment) {
        return new Rule(IllegalArgumentException.class, fragment);
    }

    private static Rule state(String fragment) {
        return new Rule(IllegalStateException.class, fragment);
    }

    private static final String BIT_DECIDED = ": its flag bit was decided before the value its condition or count reads"
            + " was written";
    private static final String NO_VALUE_COUNT = ": the count c is 3 in the row, but no field wrote it (the when that holds"
            + " it is clear), so the member reads nothing";
    private static final String NOT_EARLIER = ", which is not an earlier integer or bool field in its scope";
    private static final String EMPTY_BODY = ": the body holds no member; a round of it would charge no slot and write"
            + " nothing";

    static final Map<String, Rule> PACK = Map.ofEntries(
            Map.entry("pack_out_of_range_integer", bad("0: 300 does not fit")),
            Map.entry("pack_missing_required_value", bad("missing field 1")),
            Map.entry("pack_times_list_too_long", bad("1: list has 3 entries for a count of 2")),
            Map.entry("pack_times_list_too_short", bad("1: expected int, got null")),
            Map.entry("pack_times_count_over_limit", bad("times: count 65536 is above the limit of 65535 rounds")),
            Map.entry("pack_times_zero_with_values", bad("1: list has 1 entries for a count of 0")),
            Map.entry("pack_split_when_source_after_byte", bad("speed" + BIT_DECIDED)),
            Map.entry("pack_split_times_count_after_byte", bad("pt" + BIT_DECIDED)),
            Map.entry("pack_split_times_count_skipped", bad("pt: values given, but the count of its times was never written")),
            Map.entry("pack_lone_bytes_in_round", bad("d: a lone byte buffer is not a list of rounds")),
            Map.entry("pack_lone_utf8_under_times_over_budget",
                    bad("s: the packet would be 16777477 bytes, above the limit of 16777216 bytes")),
            Map.entry("pack_element_times_over_budget",
                    bad("k: the rounds would hold 1048577 slots, above the limit of 1048576 slots")),
            Map.entry("pack_slots_over_limit",
                    bad("m0: the rounds would hold 1048580 slots, above the limit of 1048576 slots")),
            Map.entry("pack_repeat_over_limit", bad("k: the repeat count is 65536, above the limit of 65535 rounds")),
            Map.entry("pack_split_count_zero_after_byte_list", bad("1: list has 2 entries for a count of 0")),
            Map.entry("pack_flags_skipped_count_with_values",
                    bad("pt: a value is given, but the count of its times is not written")),
            Map.entry("pack_round_slots_over_limit", bad("b: the rounds would hold 4 slots, above the limit of 3 slots")),
            Map.entry("pack_round_slots_flags_over_limit",
                    bad("on: the rounds would hold 6 slots, above the limit of 4 slots")),
            Map.entry("pack_flags_short_list",
                    bad("v: 1 items, repeat count 2; give one entry per round, null where the member is absent")),
            Map.entry("pack_count_one_clear_when",
                    bad("pt: the count c is 1 in the row, but no field wrote it (the when that holds it is clear)")),
            Map.entry("pack_bits_count_clear_when", state("2: count 1 is missing")),
            Map.entry("pack_packed_count_clear_when", state("2: count 1 is missing")),
            Map.entry("pack_sized_count_clear_when", state("2: count 1 is missing")),
            Map.entry("pack_novalue_count_clear_when_bits", bad("v" + NO_VALUE_COUNT)),
            Map.entry("pack_novalue_count_clear_when_packed", bad("v" + NO_VALUE_COUNT)),
            Map.entry("pack_novalue_count_clear_when_sized", bad("v" + NO_VALUE_COUNT)),
            Map.entry("pack_element_times_over_bytes_budget",
                    bad("s: the packet would be 16777233 bytes, above the limit of 16777216 bytes")));

    static final Map<String, Rule> CONSTRUCT = Map.ofEntries(
            Map.entry("nine_flag_bits", bad("flags already has 8 bits")),
            Map.entry("nine_flag_bits_split", bad("flags already has 8 bits")),
            Map.entry("when_names_later_field",
                    bad("when 1 tests field 2, which is not an earlier integer or bool field in its scope")),
            Map.entry("count_names_later_field",
                    bad("sized 0 takes its count from field 1, which is not an earlier integer field in its scope")),
            Map.entry("when_names_outer_field_in_repeat",
                    bad("when 1 tests field 0, which is not an earlier integer or bool field in its scope")),
            Map.entry("bool_outside_flags", bad("bool 1 is allowed only as a bit of flags or a flagByte")),
            Map.entry("empty_group_outside_flags", bad("empty group 1 has no fields and no accessor")),
            Map.entry("eq_bool_false", bad("when 1 tests bool field 0 against false; a bool is compared only with true")),
            Map.entry("eq_out_of_range", bad("when 1 tests field 0 against 300, which that field can not hold")),
            Map.entry("construct_empty_times_body", bad("times 1" + EMPTY_BODY)),
            Map.entry("construct_empty_repeat_body", bad("repeat 0" + EMPTY_BODY)),
            Map.entry("construct_empty_round_body_list_element", bad("times 1" + EMPTY_BODY)),
            // The README shapes name the when source outside the round, so Java's reference-scope rule fires before
            // the empty-body rule; that rule itself is pinned in EmptyRoundBodyTest rows 15, 16 and 25.
            Map.entry("construct_empty_when_times_body", bad("when 2 tests field 0" + NOT_EARLIER)),
            Map.entry("construct_empty_when_repeat_body", bad("when 1 tests field 0" + NOT_EARLIER)),
            Map.entry("construct_empty_nested_when_body", bad("when 2 tests field 0" + NOT_EARLIER)));

    /** Null when {@code ex} is the refusal {@code rule} names; otherwise what is wrong. */
    static String mismatch(String id, Rule rule, RuntimeException ex) {
        if (rule == null) {
            return id + ": no refusal rule in HostileRefusals";
        }
        if (!rule.type.isInstance(ex)) {
            return id + ": threw " + ex.getClass().getSimpleName() + ", expected " + rule.type.getSimpleName();
        }
        String message = ex.getMessage() == null ? "" : ex.getMessage();
        if (!message.contains(rule.fragment)) {
            return id + ": refused by another rule: \"" + message + "\", expected one with \"" + rule.fragment + "\"";
        }
        return null;
    }
}
