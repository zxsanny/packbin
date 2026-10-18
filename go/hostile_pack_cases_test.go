package packbin

import "strings"

// fixtures/hostile/cases.txt, pack stage: the scheme and row each case id names, written from
// fixtures/hostile/README.md. Each entry builds the scheme and packs the row; the case file says whether
// bytes or a refusal is expected.
var hostilePacks = map[string]func() ([]byte, error){
	"pack_lone_utf8_under_times_over_budget": hostilePackOf(
		hostileScheme(1, U32(0, "n"), Times(1, 0, Utf8(1, "s"))),
		func() hostileRow { return hostileRow{"n": 65535, "s": strings.Repeat(ctrl, 65535)} }),
	"pack_element_times_over_budget": hostilePackOf(
		hostileScheme(1, List("items", Nested("item", U32(0, "n"), Times(1, 0, U64(1, "k"))))),
		func() hostileRow { return hostileItems(40, hostileRow{"n": 65535, "k": 5}) }),
	"pack_slots_over_limit": hostilePackOf(hostileSlotsScheme, hostileSlotsRow),
	"pack_repeat_over_limit": hostilePackOf(
		hostileScheme(1, Repeat(0, U8(0, "k"))),
		func() hostileRow { return hostileRow{"k": hostileRepeatedList(65536, 7)} }),
	"pack_split_count_zero_after_byte_list": hostilePackOf(hostileSplitCount(),
		func() hostileRow { return hostileRow{"n": 0, "pt": []any{5, 6}} }),
	"pack_split_count_zero_after_byte_scalar": hostilePackOf(hostileSplitCount(),
		func() hostileRow { return hostileRow{"n": 0, "pt": 5} }),
	"pack_flags_skipped_count_with_values": hostilePackOf(
		hostileScheme(1, Flags(0, U8(0, "n"), Times(1, 0, U8(1, "pt")))),
		func() hostileRow { return hostileRow{"pt": []any{5, 6}} }),
	"pack_out_of_range_integer": hostilePackOf(hostileScheme(1, U8(0, "a")),
		func() hostileRow { return hostileRow{"a": 300} }),
	"pack_missing_required_value": hostilePackOf(hostileScheme(1, U8(0, "a"), U8(1, "b")),
		func() hostileRow { return hostileRow{"a": 1} }),
	"pack_times_list_too_long": hostilePackOf(hostileTimesScheme(),
		func() hostileRow { return hostileRow{"a": 2, "x": []any{1, 2, 3}} }),
	"pack_times_list_too_short": hostilePackOf(hostileTimesScheme(),
		func() hostileRow { return hostileRow{"a": 2, "x": []any{1}} }),
	"pack_aligned_round_row": hostilePackOf(
		hostileScheme(1, Repeat(0, Flags(0, Bool(0, "on"), U8(1, "n")))),
		func() hostileRow { return hostileRow{"on": []any{true, false, true}, "n": []any{1, 2, 3}} }),
	"pack_times_count_over_limit": hostilePackOf(
		hostileScheme(1, U32(0, "n"), Times(1, 0, U8(1, "x"))),
		func() hostileRow { return hostileRow{"n": 65536, "x": 7} }),
	"pack_times_zero_with_values": hostilePackOf(hostileTimesScheme(),
		func() hostileRow { return hostileRow{"a": 0, "x": []any{5}} }),
	"pack_split_when_source_after_byte": hostilePackOf(
		hostileSplitWhen(false, func() Field { return When(1, Eq(0, 1), U8(1, "speed")) }),
		func() hostileRow { return hostileRow{"mode": 1, "speed": 7} }),
	"pack_split_times_count_after_byte": hostilePackOf(hostileSplitCount(),
		func() hostileRow { return hostileRow{"n": 2, "pt": []any{5, 6}} }),
	"pack_split_times_count_skipped": hostilePackOf(func() (*Scheme, error) {
		fb := FlagByte("fb")
		return NewScheme(1, U8(0, "sel"), fb, When(1, Eq(0, 1), U8(1, "n")), fb.Bit(Times(2, 1, U8(2, "pt"))))
	}, func() hostileRow { return hostileRow{"sel": 0, "pt": []any{5}} }),
	"pack_lone_bytes_in_round": hostilePackOf(
		hostileScheme(1, U8(0, "n"), Times(1, 0, Bytes(1, "d", 2))),
		func() hostileRow { return hostileRow{"n": 2, "d": []byte{1, 2}} }),
	"pack_split_false_condition_silent": hostilePackOf(
		hostileSplitWhen(true, func() Field { return When(1, Eq(0, 1), U8(1, "speed")) },
			func(fb *FlagByteHandle) Field { return fb.Bit(U16(2, "heading")) }),
		func() hostileRow { return hostileRow{"mode": 0, "speed": 7, "heading": 90} }),
	"pack_round_slots_at_limit": hostilePackOf(hostileMixedRounds,
		func() hostileRow { return hostileRow{"n": 1, "a": []any{1}, "b": []any{2, 3}} }),
	"pack_round_slots_over_limit": hostilePackOf(hostileMixedRounds,
		func() hostileRow { return hostileRow{"n": 1, "a": []any{1}, "b": []any{2, 3, 4}} }),
	"pack_round_slots_flags_at_limit": hostilePackOf(hostileFlagsRound,
		func() hostileRow { return hostileRow{"on": []any{true, true}, "v": []any{5, 6}} }),
	"pack_round_slots_flags_over_limit": hostilePackOf(hostileFlagsRound,
		func() hostileRow { return hostileRow{"on": []any{true, true, true}, "v": []any{5, 6, 7}} }),
	"pack_flags_short_list": hostilePackOf(hostileOptionalRepeat,
		func() hostileRow { return hostileRow{"w": []any{1, 2}, "v": []any{5}} }),
	"pack_flags_short_list_filled": hostilePackOf(hostileOptionalRepeat,
		func() hostileRow { return hostileRow{"w": []any{1, 2}, "v": []any{5, nil}} }),
	"pack_split_times_absent_body": hostilePackOf(
		hostileSplitCount(func(fb *FlagByteHandle) Field { return fb.Bit(U16(2, "heading")) }),
		func() hostileRow { return hostileRow{"n": 2, "heading": 90} }),
	"pack_late_when_in_bit_body": hostilePackOf(
		hostileSplitWhen(false, func() Field {
			return Group(1, "g", U8(1, "d"), When(2, Eq(0, 1), U8(2, "a")), When(3, Eq(0, 2), U8(3, "b")))
		}),
		func() hostileRow { return hostileRow{"mode": 1, "g": hostileRow{"d": 5, "a": 9}} }),
	"pack_count_one_clear_when": hostilePackOf(func() (*Scheme, error) {
		fb := FlagByte("fb")
		return NewScheme(1, U8(0, "mode"), When(1, Eq(0, 1), U8(1, "c")), fb,
			fb.Bit(Times(2, 1, U8(2, "pt"))), fb.Bit(U16(3, "heading")))
	}, func() hostileRow { return hostileRow{"mode": 0, "c": 1, "heading": 90} }),
	"pack_bits_count_clear_when":   hostilePackOf(hostileClearWhenCount(Bits(2, "v", 1)), clearWhenRow),
	"pack_packed_count_clear_when": hostilePackOf(hostileClearWhenCount(Packed(1, 2, "v", 1, 0)), clearWhenRow),
	"pack_sized_count_clear_when": hostilePackOf(hostileClearWhenCount(Sized(2, "v", 1)),
		func() hostileRow { return hostileRow{"mode": 0, "c": 3, "v": []byte{1, 2, 3}} }),
	"pack_novalue_count_clear_when_bits":   hostilePackOf(hostileNovalueCount(Bits(2, "v", 1)), novalueRow),
	"pack_novalue_count_clear_when_packed": hostilePackOf(hostileNovalueCount(Packed(1, 2, "v", 1, 0)), novalueRow),
	"pack_novalue_count_clear_when_sized":  hostilePackOf(hostileNovalueCount(Sized(2, "v", 1)), novalueRow),
	"pack_repeat_unequal_lists_lone": hostilePackOf(
		hostileScheme(1, Repeat(0, U8(0, "a"), U8(1, "b"))),
		func() hostileRow { return hostileRow{"a": []any{1, 2}, "b": 7} }),
	"pack_repeat_unequal_lists_when": hostilePackOf(
		hostileScheme(1, Repeat(0, U8(0, "k"), When(1, Eq(0, 1), U8(1, "v")))),
		func() hostileRow { return hostileRow{"k": []any{1, 2}, "v": []any{9}} }),
	"pack_times_short_list_flags": hostilePackOf(
		hostileScheme(1, U8(0, "c"), Times(1, 0, Flags(1, U8(1, "v")))),
		func() hostileRow { return hostileRow{"c": 2, "v": []any{5}} }),
	"pack_element_times_over_bytes_budget": hostilePackOf(
		hostileScheme(1, List("items", Nested("item", U32(0, "n"), Times(1, 0, Utf8(1, "s"))))),
		func() hostileRow { return hostileItems(16, hostileRow{"n": 65535, "s": strings.Repeat(ctrl, 16)}) }),
}
