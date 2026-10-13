package packbin

import (
	"errors"
	"math"
	"strings"
	"testing"
)

type refusedCase struct {
	name   string
	build  func() (*Scheme, error)
	field  int
	reason string // the whole reason, or its start when it ends in "..."
}

func checkRefused(t *testing.T, cases []refusedCase) {
	t.Helper()
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Act
			s, err := c.build()

			// Assert
			e := asError(t, err, InvalidScheme)
			want, prefix := strings.CutSuffix(c.reason, "...")
			matched := e.Reason == want || (prefix && strings.HasPrefix(e.Reason, want))
			if s != nil || e.Field != c.field || !matched {
				t.Fatalf("got field %d reason %q", e.Field, e.Reason)
			}
			if !errors.Is(err, ErrInvalidScheme) {
				t.Fatalf("errors.Is: %v", err)
			}
		})
	}
}

func build(fields ...Field) func() (*Scheme, error) {
	return func() (*Scheme, error) { return NewScheme(1, fields...) }
}

func whenOn(src Field, value any) func() (*Scheme, error) {
	return build(src, When(1, Eq(0, value), U8(1, "v")))
}

// AC-1: the refusal rows of the TypeScript construct tests (scheme-constructor, reference-scope,
// flag-scope, duplicate-names, bool-flag) that need no round, list, dict or nested row.
func TestAC1ConstructionRefusals(t *testing.T) {
	inWhen, never, under, inside := FlagByte("fb"), FlagByte("fb"), FlagByte("fb"), FlagByte("fb")
	outer, inner, missing := FlagByte("outer"), FlagByte("inner"), FlagByte("missing")
	m := FlagByte("m")
	checkRefused(t, []refusedCase{
		{"bool outside flags", build(Bool(0, "on")), 0,
			"bool on: allowed only directly inside flags or a flag bit; move it into flags"},
		{"wrong field id", build(U8(1, "a")), 1, "field id: expected 0, got 1"},
		{"bool at the top level after a field", build(U8(0, "a"), Bool(1, "top")), 1, "bool top: allowed only..."},
		{"bool in a group", build(Group(0, "g", U8(0, "n"), Bool(1, "inGroup"))), 1, "bool inGroup: allowed only..."},
		{"bool in a group under flags", build(Flags(0, Group(0, "g", U8(0, "n"), Bool(1, "underFlags")))), 1,
			"bool underFlags: allowed only..."},
		{"bool in a when", build(U8(0, "k"), When(1, Eq(0, 1), Bool(1, "inWhen"))), 1, "bool inWhen: allowed only..."},
		{"empty group outside flags", build(U8(0, "n"), Group(1, "mark")), 1,
			"empty group mark: allowed only directly inside flags or a flag bit; move it into flags"},
		{"empty group in a group under a bit", build(m, m.Bit(Group(0, "g", U8(0, "n"), Group(1, "inner")))), 1,
			"empty group inner: allowed only..."},
		{"split bit with no byte", build(never.Bit(U8(0, "early"))), 0,
			"flag bit 0 (early): its flag byte is not read earlier in the same scope"},
		{"orphan bit after a byte read in a when", build(U8(0, "k"), When(1, Eq(0, 1), inWhen), inWhen.Bit(U8(1, "alpha"))),
			1, "flag bit 0 (alpha): ..."},
		{"bit under a when before its byte", build(When(0, Eq(0, 1), under.Bit(U8(0, "early"))), under), 0,
			"flag bit 0 (early): ..."},
		{"bit inside a when before its byte", build(U8(0, "k"), When(1, Eq(0, 1), inside.Bit(U8(1, "early")), inside)), 1,
			"flag bit 0 (early): ..."},
		{"byte inside a bit's group does not leak", build(outer, outer.Bit(Group(0, "g", inner)), inner.Bit(U8(0, "leaked"))),
			0, "flag bit 0 (leaked): ..."},
		{"split bit inside a combined flags member", build(outer, outer.Bit(Flags(0, missing.Bit(U8(0, "nested"))))), 0,
			"flag bit 0 (nested): ..."},
		{"when names an unknown id", build(U8(0, "k"), When(1, Eq(9, 5), U8(1, "a"))), 1,
			"when 1: eq names field id 9, which is not declared earlier in the same scope"},
		{"when names its own body", build(When(0, Eq(0, 1), U8(0, "a"))), 0,
			"when 0: eq names field id 0, which is not declared earlier in the same scope"},
		{"same name twice", build(U8(0, "a"), U8(1, "a")), 1,
			"member a: declared twice in one scope; a row holds one value per name, so one would be lost"},
		{"flags member named like a top-level field", build(U8(0, "a"), Flags(1, U8(1, "a"))), 1, "member a: declared twice..."},
		{"anchored group member named like an outer member", build(U8(0, "a"), Group(1, "g", U8(1, "a"))), 1,
			"member a: declared twice..."},
		{"group named like its member", build(Flags(0, Group(0, "session", U16(0, "session")))), 0,
			"member session: declared twice..."},
		{"twice outside every when after a when", build(U8(0, "kind"), When(1, Eq(0, 0), U8(1, "shape")),
			U8(2, "shape"), U8(3, "shape")), 3, "member shape: declared twice..."},
		{"group anchor", build(Group(1, "g", U8(1, "a"))), 1, "group anchor: expected 0, got 1"},
		{"nil group member", build(Group(0, "g", nil)), NoField, "a field is nil"},
	})
}

// AC-1: eq-source-kinds and the eq rows of reference-scope.
func TestAC1EqSourceKinds(t *testing.T) {
	on := Flags(0, Bool(0, "on"))
	m := FlagByte("m")
	cases := []refusedCase{
		{"eq bool false", whenOn(on, false), 1, "when 1: eq names bool field id 0 (on) and accepts only true, not false"},
		{"eq bool on a split bit", build(m, m.Bit(Bool(0, "on")), When(1, Eq(0, false), U8(1, "v"))), 1,
			"when 1: eq names bool field id 0 (on) and accepts only true, not false"},
		{"eq bool 1 (eq-value-checked)", whenOn(on, 1), 1, "when 1: eq names bool field id 0 (on) and accepts only true, not 1"},
		{"eq bool hostile struct", whenOn(on, struct{ S string }{"leaked"}), 1,
			"when 1: eq names bool field id 0 (on) and accepts only true, not a value of type struct { S string }"},
		{"eq f32 source", whenOn(F32(0, "x"), 1), 1, "when 1: eq names field id 0 (x), which is not an integer or a bool"},
		{"eq f64 source", whenOn(F64(0, "x"), 1), 1, "when 1: eq names field id 0 (x), which is not an integer or a bool"},
		{"eq bytes source", whenOn(Bytes(0, "x", 2), 1), 1, "when 1: eq names field id 0 (x), which is not an integer or a bool"},
		{"empty group mark has no id", build(Flags(0, Group(0, "mark")), When(0, Eq(0, true), U8(0, "v"))), 0,
			"when 0: eq names field id 0, which is not declared earlier in the same scope"},
	}
	for _, v := range []any{0, "yes", "true", nil, []bool{true}} {
		cases = append(cases, refusedCase{"eq bool " + describe(v), whenOn(on, v), 1,
			"when 1: eq names bool field id 0 (on) and accepts only true, not ..."})
	}
	for _, c := range []struct {
		value any
		shown string
	}{{true, "true"}, {"1", `"1"`}, {[]int{1}, "a value of type []int"}, {nil, "nil"}} {
		cases = append(cases, refusedCase{"eq " + c.shown + " on an integer", whenOn(U8(0, "k"), c.value), 1,
			"when 1 tests u8 field 0 ('k') against " + c.shown + "; the value must be a whole number from 0 to 255"})
	}
	checkRefused(t, cases)
}

// AC-1: eq-value-checked, without the u2 rows (u2 comes with AZ-2443).
func TestAC1EqValueChecked(t *testing.T) {
	sources := map[string]func() Field{
		"u8": func() Field { return U8(0, "mode") }, "i8": func() Field { return I8(0, "mode") },
		"u16": func() Field { return U16(0, "mode") }, "u32": func() Field { return U32(0, "mode") },
		"u64": func() Field { return U64(0, "mode") }, "i64": func() Field { return I64(0, "mode") },
	}
	scheme := func(kind string, value any) func() (*Scheme, error) {
		return build(sources[kind](), When(1, Eq(0, value), U8(1, "speed")))
	}
	refused := []struct {
		kind       string
		value      any
		shown, rng string
	}{
		{"u8", 300, "300", "0 to 255"}, {"u8", -1, "-1", "0 to 255"}, {"u8", "x", `"x"`, "0 to 255"},
		{"u8", math.NaN(), "NaN", "0 to 255"}, {"u8", 1.5, "1.5", "0 to 255"}, {"u8", true, "true", "0 to 255"},
		{"u8", 1e30, "1e+30", "0 to 255"}, {"u8", uint64(256), "256", "0 to 255"},
		{"i8", 128, "128", "-128 to 127"}, {"i8", -129, "-129", "-128 to 127"},
		{"u16", 65_536, "65536", "0 to 65535"}, {"u32", 4_294_967_296, "4294967296", "0 to 4294967295"},
		{"u64", -1, "-1", "0 to 18446744073709551615"}, {"u64", 1e20, "1e+20", "0 to 18446744073709551615"},
		{"u64", 0x1p64, "1.8446744073709552e+19", "0 to 18446744073709551615"},
		{"i64", 0x1p63, "9.223372036854776e+18", "-9223372036854775808 to 9223372036854775807"},
		{"i64", uint64(1) << 63, "9223372036854775808", "-9223372036854775808 to 9223372036854775807"},
	}
	var cases []refusedCase
	for _, r := range refused {
		cases = append(cases, refusedCase{r.kind + " " + r.shown, scheme(r.kind, r.value), 1,
			"when 1 tests " + r.kind + " field 0 ('mode') against " + r.shown + "; the value must be a whole number from " + r.rng})
	}
	cases = append(cases, refusedCase{"a source in a when body", build(U8(0, "mode"),
		When(1, Eq(0, 5), U8(1, "a"), When(2, Eq(1, 999), U8(2, "b")))), 2,
		"when 2 tests u8 field 1 ('a') against 999; the value must be a whole number from 0 to 255"})
	checkRefused(t, cases)

	built := []struct {
		kind  string
		value any
	}{
		{"u8", 5}, {"u8", 5.0}, {"u8", 255}, {"u8", 0}, {"u8", uint64(5)}, {"i8", -128}, {"i8", 127},
		{"u16", 65_535}, {"u32", 4_294_967_295}, {"u64", uint64(math.MaxUint64)}, {"u64", 0x1p53},
		{"i64", math.MinInt64}, {"i64", math.MaxInt64}, {"u64", 1<<53 - 1}, {"u8", float32(5)},
	}
	for _, b := range built {
		if _, err := scheme(b.kind, b.value)(); err != nil {
			t.Fatalf("eq(%s, %v): %v", b.kind, b.value, err)
		}
	}
}

// AC-3 (U25 A for Go): a negative field id, eq id or anchor is refused, naming it.
func TestAC3NegativeIds(t *testing.T) {
	checkRefused(t, []refusedCase{
		{"field id", build(U8(-1, "a")), -1, "field id: expected 0, got -1"},
		{"eq id", build(U8(0, "k"), When(1, Eq(-1, 1), U8(1, "v"))), 1,
			"when 1: eq names field id -1, which is not declared earlier in the same scope"},
		{"flags anchor", build(Flags(-1, U8(0, "a"))), -1, "flags anchor: expected 0, got -1"},
		{"when anchor", build(U8(0, "k"), When(-1, Eq(0, 1), U8(1, "v"))), -1, "when anchor: expected 1, got -1"},
		{"group anchor", build(Group(-1, "g", U8(0, "a"))), -1, "group anchor: expected 0, got -1"},
		{"member of a group", build(Group(0, "g", U8(-1, "a"))), -1, "field id: expected 0, got -1"},
	})
}

// AC-1: the rows these tests expect to build, packed as TypeScript packs them.
func TestAC1BuiltRows(t *testing.T) {
	earlier, inWhen := FlagByte("earlier"), FlagByte("fb")
	cases := []struct {
		name   string
		fields []Field
		row    map[string]any
		wire   string
	}{
		{"eq bool true", []Field{Flags(0, Bool(0, "on")), When(1, Eq(0, true), U8(1, "v"))},
			map[string]any{"on": true, "v": 5}, "010105"},
		{"eq bool true, bool false", []Field{Flags(0, Bool(0, "on")), When(1, Eq(0, true), U8(1, "v"))},
			map[string]any{"on": false, "v": 5}, "0100"},
		{"eq whole float", []Field{U8(0, "mode"), When(1, Eq(0, 5.0), U8(1, "speed"))},
			map[string]any{"mode": 5, "speed": 9}, "010509"},
		{"eq whole float, other value", []Field{U8(0, "mode"), When(1, Eq(0, 5.0), U8(1, "speed"))},
			map[string]any{"mode": 4, "speed": 9}, "0104"},
		{"eq i16 -1", []Field{I16(0, "k"), When(1, Eq(0, -1), U8(1, "v"))}, map[string]any{"k": -1, "v": 2}, "01ffff02"},
		{"eq names a field in an earlier group", []Field{Group(0, "g", U8(0, "n")), When(1, Eq(0, 1), U8(1, "v"))},
			map[string]any{"g": map[string]any{"n": 1}, "v": 7}, "010107"},
		{"split bit in a flags member under the same byte", []Field{earlier, earlier.Bit(Flags(0, earlier.Bit(U8(0, "nested"))))},
			map[string]any{}, "0100"},
		{"byte and bit inside a when", []Field{U8(0, "k"), When(1, Eq(0, 1), inWhen, inWhen.Bit(U8(1, "a")))},
			map[string]any{"k": 1, "a": 5}, "01010105"},
		{"when branches share a name", []Field{U8(0, "kind"), When(1, Eq(0, 0), U8(1, "shape")), When(2, Eq(0, 1), U16(2, "shape"))},
			map[string]any{"kind": 1, "shape": 300}, "01012c01"},
		{"a name outside every when and once inside", []Field{U8(0, "kind"), U8(1, "shape"), When(2, Eq(0, 1), U16(2, "shape"))},
			map[string]any{"kind": 1, "shape": 7}, "0101070700"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Arrange
			s := mustScheme(t, 1, c.fields...)

			// Act
			wire := mustPack(t, s, c.row)

			// Assert
			if wire != c.wire {
				t.Fatalf("got %s, want %s", wire, c.wire)
			}
		})
	}
}
