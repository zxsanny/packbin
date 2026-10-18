package packbin

import "regexp"

// The rule each pack refusal must name (the whole text of the error, field id included), so a refusal
// by some other rule does not pass.
const (
	hostileNovalue = "the count c is 3 in the row, but no field wrote it (the when that holds it is clear), so the member reads nothing; give the count 0, leave it out, or make the when hold"
	hostileLate    = "a value is given, but the condition or count of its when or times is not written before the flag byte, so its bit is clear; write that field before the flag byte"
)

var hostileRefusals = map[string]*regexp.Regexp{
	"pack_bits_count_clear_when":             lit("packbin: pack refused at field 2 (v): v: count c was not written"),
	"pack_count_one_clear_when":              lit("packbin: pack refused at field 2 (pt): pt: the count c is 1 in the row, but no field wrote it (the when that holds it is clear), so its times reads no round; give the count 0, leave it out, or make the when hold"),
	"pack_element_times_over_budget":         lit("packbin: pack refused at field 1 (k): k: the rounds would hold 1048577 slots, above the limit of 1048576 slots"),
	"pack_element_times_over_bytes_budget":   lit("packbin: pack refused at field 1 (s): s: the packet would be 16777233 bytes, above the limit of 16777216 bytes"),
	"pack_flags_short_list":                  lit("packbin: pack refused at field 1 (v): v: 1 items, repeat count 2; give one entry per round, nil where the member is absent"),
	"pack_flags_skipped_count_with_values":   lit("packbin: pack refused at field 1 (pt): pt: a value is given, but the count of its times is not written, so its bit is clear; write the count before the times"),
	"pack_lone_bytes_in_round":               lit("packbin: pack refused at field 1 (d): d: a byte buffer in a repeat or times round needs a list with one buffer per round"),
	"pack_lone_utf8_under_times_over_budget": lit("packbin: pack refused at field 1 (s): s: the packet would be 16777989 bytes, above the limit of 16777216 bytes"),
	"pack_missing_required_value":            lit("packbin: pack refused at field 1 (b): missing b"),
	"pack_novalue_count_clear_when_bits":     lit("packbin: pack refused at field 2 (v): v: " + hostileNovalue),
	"pack_novalue_count_clear_when_packed":   lit("packbin: pack refused at field 2 (v): v: " + hostileNovalue),
	"pack_novalue_count_clear_when_sized":    lit("packbin: pack refused at field 2 (v): v: " + hostileNovalue),
	"pack_out_of_range_integer":              lit("packbin: pack refused at field 0 (a): 300 does not fit in u8"),
	"pack_packed_count_clear_when":           lit("packbin: pack refused at field 2 (v): v: count c was not written"),
	"pack_repeat_over_limit":                 lit("packbin: pack refused at field 0 (k): k: the repeat count is 65536, above the limit of 65535 rounds"),
	"pack_round_slots_flags_over_limit":      lit("packbin: pack refused at field 0 (on): on: the rounds would hold 6 slots, above the limit of 4 slots"),
	"pack_round_slots_over_limit":            lit("packbin: pack refused at field 2 (b): b: the rounds would hold 4 slots, above the limit of 3 slots"),
	"pack_sized_count_clear_when":            lit("packbin: pack refused at field 2 (v): v: count c was not written"),
	"pack_slots_over_limit":                  lit("packbin: pack refused at field 1 (m0): m0: the rounds would hold 1048580 slots, above the limit of 1048576 slots"),
	"pack_split_count_zero_after_byte_list":  lit("packbin: pack refused at field 1 (pt): pt: 2 items, times count 0"),
	"pack_split_times_count_after_byte":      lit("packbin: pack refused at field 1 (pt): pt: " + hostileLate),
	"pack_split_times_count_skipped":         lit("packbin: pack refused at field 2 (pt): pt: " + hostileLate),
	"pack_split_when_source_after_byte":      lit("packbin: pack refused at field 1 (speed): speed: " + hostileLate),
	"pack_times_count_over_limit":            lit("packbin: pack refused at field 1 (x): x: the times count is 65536, above the limit of 65535 rounds"),
	"pack_times_list_too_long":               lit("packbin: pack refused at field 1 (x): x: 3 items, times count 2"),
	"pack_times_list_too_short":              lit("packbin: pack refused at field 1 (x): missing x"),
	"pack_times_zero_with_values":            lit("packbin: pack refused at field 1 (x): x: 1 items, times count 0"),
}
