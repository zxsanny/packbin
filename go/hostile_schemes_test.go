package packbin

import (
	"fmt"
	"regexp"
)

// fixtures/hostile/cases.txt, unpack stage: each builder returns the scheme the case names, or the
// construction error (a package that refuses the scheme answers scheme_error, which several cases accept).
type hostileBuild func() (*Scheme, error)

func hostileDictOfU8() (*Scheme, error) { return NewScheme(1, Dict("m", U8(0, "v"))) }

func hostileClearFlag() Field { return Flags(0, U8(0, "n")) }

var hostileUnpackSchemes = map[string]hostileBuild{
	"zero_progress_repeat_bool": func() (*Scheme, error) { return NewScheme(1, Repeat(0, Bool(0, "on"))) },
	"zero_progress_repeat_when": func() (*Scheme, error) {
		return NewScheme(1, U8(0, "mode"), Repeat(1, When(1, Eq(0, 1), U8(1, "v"))))
	},
	"negative_count":            func() (*Scheme, error) { return NewScheme(1, I8(0, "n"), Sized(1, "payload", 0)) },
	"oversize_count":            func() (*Scheme, error) { return NewScheme(1, U32(0, "n"), Sized(1, "payload", 0)) },
	"oversize_count_times":      func() (*Scheme, error) { return NewScheme(1, U32(0, "n"), Times(1, 0, U8(1, "v"))) },
	"oversize_list_count":       func() (*Scheme, error) { return NewScheme(1, List("xs", U8(0, "x"))) },
	"invalid_utf8":              func() (*Scheme, error) { return NewScheme(1, Utf8(0, "name")) },
	"invalid_utf8_dict_key":     func() (*Scheme, error) { return NewScheme(1, Dict("m", U8(0, "v"))) },
	"dict_keys_out_of_order":    hostileDictOfU8,
	"dict_keys_repeated":        hostileDictOfU8,
	"dict_keys_repeated_forms":  hostileDictOfU8,
	"dict_keys_prefix_descends": hostileDictOfU8,
	"dict_keys_utf16_order":     hostileDictOfU8,
	"count_behind_clear_flag": func() (*Scheme, error) {
		return NewScheme(1, hostileClearFlag(), Sized(1, "payload", 0))
	},
	"count_behind_clear_flag_bits": func() (*Scheme, error) {
		return NewScheme(1, hostileClearFlag(), Bits(1, "segs", 0))
	},
}

// fixtures/hostile/cases.txt, limit stage: MaxRounds 3, the other limits at their defaults.
func hostileMaxRounds3(s *Scheme, err error) (*Scheme, error) {
	if err != nil {
		return nil, err
	}
	l := DefaultLimits()
	l.MaxRounds = 3
	return s.WithLimits(l)
}

var hostileLimitSchemes = map[string]hostileBuild{
	"repeat_rounds_over_limit": func() (*Scheme, error) { return hostileMaxRounds3(NewScheme(1, Repeat(0, U8(0, "v")))) },
	"times_rounds_over_limit": func() (*Scheme, error) {
		return hostileMaxRounds3(NewScheme(1, U8(0, "n"), Times(1, 0, U8(1, "v"))))
	},
}

func hostileNineU8() []Field {
	out := make([]Field, 9)
	for i := range out {
		out[i] = U8(i, fmt.Sprintf("f%d", i))
	}
	return out
}

func hostileSplitNine() (*Scheme, error) {
	fb := FlagByte("fb")
	fields := []Field{fb}
	for _, f := range hostileNineU8() {
		fields = append(fields, fb.Bit(f))
	}
	return NewScheme(1, fields...)
}

// fixtures/hostile/cases.txt, construct stage: each builder must fail with an InvalidScheme error whose
// text matches rule, so an error from a typo in the builder does not pass the case.
var hostileConstructs = map[string]*hostileConstruct{
	"nine_flag_bits": {
		build: func() (*Scheme, error) { return NewScheme(1, Flags(0, hostileNineU8()...)) },
		rule:  lit(`packbin: invalid scheme at field 8 (f8): flags: ninth bit (f8); a flag byte holds 8 bits`),
	},
	"nine_flag_bits_split": {build: hostileSplitNine, rule: lit(`packbin: invalid scheme at field 8 (f8): flag byte "fb": ninth bit (f8); a flag byte holds 8 bits`)},
	"eq_bool_false": {
		build: func() (*Scheme, error) {
			return NewScheme(1, Flags(0, Bool(0, "on")), When(1, Eq(0, false), U8(1, "v")))
		},
		rule: lit(`packbin: invalid scheme at field 1: when 1: eq names bool field id 0 (on) and accepts only true, not false`),
	},
	"eq_out_of_range": {
		build: func() (*Scheme, error) { return NewScheme(1, U8(0, "a"), When(1, Eq(0, 300), U8(1, "v"))) },
		rule:  lit(`packbin: invalid scheme at field 1: when 1 tests u8 field 0 ('a') against 300; the value must be a whole number from 0 to 255`),
	},
	"when_names_later_field": {
		build: func() (*Scheme, error) {
			return NewScheme(1, U8(0, "a"), When(1, Eq(2, 1), U8(1, "b")), U8(2, "c"))
		},
		rule: lit(`packbin: invalid scheme at field 1: when 1: eq names field id 2, which is not declared earlier in the same scope`),
	},
	"count_names_later_field": {
		build: func() (*Scheme, error) { return NewScheme(1, Sized(0, "payload", 1), U16(1, "n")) },
		rule:  lit(`packbin: invalid scheme at field 0 (payload): sized 0: count names field id 1, which is not declared earlier in the same scope`),
	},
	"when_names_outer_field_in_repeat": {
		build: func() (*Scheme, error) {
			return NewScheme(1, U8(0, "mode"), Repeat(1, When(1, Eq(0, 1), U8(1, "v"))))
		},
		rule: lit(`packbin: invalid scheme at field 1: when 1: eq names field id 0, which is not declared earlier in the same scope`),
	},
	"bool_outside_flags": {
		build: func() (*Scheme, error) { return NewScheme(1, U8(0, "a"), Bool(1, "on")) },
		rule:  lit(`packbin: invalid scheme at field 1 (on): bool on: allowed only directly inside flags or a flag bit; move it into flags`),
	},
	"empty_group_outside_flags": {
		build: func() (*Scheme, error) { return NewScheme(1, U8(0, "a"), Group(1, "mark")) },
		rule:  lit(`packbin: invalid scheme at field 1 (mark): empty group mark: allowed only directly inside flags or a flag bit; move it into flags`),
	},
	"construct_empty_times_body": {
		build: func() (*Scheme, error) { return NewScheme(1, U8(0, "n"), Times(1, 0)) },
		rule:  lit(`packbin: invalid scheme at field 1: times 1: the body holds no member; a round of it would charge no slot and write nothing`),
	},
	"construct_empty_repeat_body": {
		build: func() (*Scheme, error) { return NewScheme(1, Repeat(0)) },
		rule:  lit(`packbin: invalid scheme at field 0: repeat 0: the body holds no member; a round of it would charge no slot and write nothing`),
	},
	"construct_empty_round_body_list_element": {
		build: func() (*Scheme, error) {
			return NewScheme(1, List("items", Nested("item", U32(0, "n"), Times(1, 0))))
		},
		rule: lit(`packbin: invalid scheme at field 1: times 1: the body holds no member; a round of it would charge no slot and write nothing`),
	},
	"construct_empty_when_times_body": {
		build: func() (*Scheme, error) {
			return NewScheme(1, U8(0, "mode"), U8(1, "c"), Times(2, 1, When(2, Eq(0, 1))))
		},
		rule: lit(`packbin: invalid scheme at field 2: times 2: the body holds no member; a round of it would charge no slot and write nothing`),
	},
	"construct_empty_when_repeat_body": {
		build: func() (*Scheme, error) {
			return NewScheme(1, U8(0, "mode"), Repeat(1, When(1, Eq(0, 1))))
		},
		rule: lit(`packbin: invalid scheme at field 1: repeat 1: the body holds no member; a round of it would charge no slot and write nothing`),
	},
	"construct_empty_nested_when_body": {
		build: func() (*Scheme, error) {
			return NewScheme(1, U8(0, "mode"), U8(1, "c"), Times(2, 1, When(2, Eq(0, 1), When(2, Eq(0, 1)))))
		},
		rule: lit(`packbin: invalid scheme at field 2: times 2: the body holds no member; a round of it would charge no slot and write nothing`),
	},
}

// lit matches exactly the text of one error, so the rule and the field id it names are both pinned.
func lit(text string) *regexp.Regexp { return regexp.MustCompile("^" + regexp.QuoteMeta(text) + "$") }
