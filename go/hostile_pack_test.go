package packbin

import (
	"fmt"
	"regexp"
	"strings"
	"testing"
)

type hostileRow = map[string]any

// hostilePackOf builds the scheme and packs the row; a scheme that does not build is an error of the case.
func hostilePackOf(s func() (*Scheme, error), row func() hostileRow) func() ([]byte, error) {
	return func() ([]byte, error) {
		layout, err := s()
		if err != nil {
			return nil, fmt.Errorf("the scheme of a pack case did not build: %w", err)
		}
		return Pack(layout, row())
	}
}

func hostileScheme(typeNumber int, fields ...Field) func() (*Scheme, error) {
	return func() (*Scheme, error) { return NewScheme(typeNumber, fields...) }
}

func hostileWith(s *Scheme, err error, f func(*Limits)) (*Scheme, error) {
	if err != nil {
		return nil, err
	}
	l := DefaultLimits()
	f(&l)
	return s.WithLimits(l)
}

func hostileRepeatedList(n int, v any) []any {
	out := make([]any, n)
	for i := range out {
		out[i] = v
	}
	return out
}

func hostileTimesScheme() func() (*Scheme, error) {
	return hostileScheme(1, U8(0, "a"), Times(1, 0, U8(1, "x")))
}

// split-form flag byte first; u8 n after it; bit 0 { times(n) { u8 pt } }
func hostileSplitCount(extra ...func(*FlagByteHandle) Field) func() (*Scheme, error) {
	return func() (*Scheme, error) {
		fb := FlagByte("fb")
		fields := []Field{fb, U8(0, "n"), fb.Bit(Times(1, 0, U8(1, "pt")))}
		for _, e := range extra {
			fields = append(fields, e(fb))
		}
		return NewScheme(1, fields...)
	}
}

func hostileSlotsScheme() (*Scheme, error) {
	members := make([]Field, 65)
	for i := range members {
		members[i] = U8(1+i, fmt.Sprintf("m%d", i))
	}
	return NewScheme(1, U32(0, "n"), Times(1, 0, members...))
}

func hostileSlotsRow() hostileRow {
	row := hostileRow{"n": 65535}
	for i := 0; i < 65; i++ {
		row[fmt.Sprintf("m%d", i)] = 1
	}
	return row
}

// u8 n; times(n) { u8 a }; repeat { u8 b }: each round of either container charges one slot (maxSlots 3).
func hostileMixedRounds() (*Scheme, error) {
	s, err := NewScheme(1, U8(0, "n"), Times(1, 0, U8(1, "a")), Repeat(2, U8(2, "b")))
	return hostileWith(s, err, func(l *Limits) { l.MaxSlots = 3 })
}

// repeat { flags { bool on; u8 v } }: a round holds the two names on and v (maxSlots 4).
func hostileFlagsRound() (*Scheme, error) {
	s, err := NewScheme(1, Repeat(0, Flags(0, Bool(0, "on"), U8(1, "v"))))
	return hostileWith(s, err, func(l *Limits) { l.MaxSlots = 4 })
}

// repeat { u8 w; flags { u8 v } }
func hostileOptionalRepeat() (*Scheme, error) {
	return NewScheme(1, Repeat(0, U8(0, "w"), Flags(1, U8(1, "v"))))
}

// u8 mode; when mode == 1 { u8 c }; then the counted member whose count is c.
func hostileClearWhenCount(member Field) func() (*Scheme, error) {
	return hostileScheme(1, U8(0, "mode"), When(1, Eq(0, 1), U8(1, "c")), member)
}

// u8 mode; when mode == 1 { u8 c }; split-form flag byte; bit 0 { member counted by c }; the row gives no value.
func hostileNovalueCount(member Field) func() (*Scheme, error) {
	return func() (*Scheme, error) {
		fb := FlagByte("fb")
		return NewScheme(1, U8(0, "mode"), When(1, Eq(0, 1), U8(1, "c")), fb, fb.Bit(member))
	}
}

var novalueRow = func() hostileRow { return hostileRow{"mode": 0, "c": 3} }

var clearWhenRow = func() hostileRow { return hostileRow{"mode": 0, "c": 3, "v": []any{1, 0, 1}} }

// hostileSplitWhen is a split-form scheme with u8 mode and a flag byte; the mode is written before the byte
// when modeFirst, after it otherwise; bit 0 holds body, tail adds the bits after it.
func hostileSplitWhen(modeFirst bool, body func() Field, tail ...func(*FlagByteHandle) Field) func() (*Scheme, error) {
	return func() (*Scheme, error) {
		fb := FlagByte("fb")
		fields := []Field{U8(0, "mode"), fb}
		if !modeFirst {
			fields = []Field{fb, U8(0, "mode")}
		}
		fields = append(fields, fb.Bit(body()))
		for _, e := range tail {
			fields = append(fields, e(fb))
		}
		return NewScheme(1, fields...)
	}
}

func hostileItems(n int, row hostileRow) hostileRow {
	items := make([]any, n)
	for i := range items {
		items[i] = row
	}
	return hostileRow{"items": items}
}

// checkHostilePack runs the pack of a case and checks the bytes, or the refusal and the rule it names
// (rules is the refusal table). It returns what is wrong, or "".
func checkHostilePack(c hostileCase, run func() ([]byte, error), rules map[string]*regexp.Regexp) (msg string) {
	if run == nil {
		return fmt.Sprintf("no Go scheme for pack case %s", c.id)
	}
	defer func() {
		if p := recover(); p != nil {
			msg = fmt.Sprintf("%s: panic %v", c.id, p)
		}
	}()
	raw, err := run()
	if c.expected[0] == "bytes" {
		if err != nil {
			return fmt.Sprintf("%s: expected bytes, got %v", c.id, err)
		}
		if got := hexOf(raw); got != c.hex {
			return fmt.Sprintf("%s: packed %s, want %s", c.id, got, c.hex)
		}
		return ""
	}
	if len(c.expected) != 1 || c.expected[0] != "pack_error" {
		return fmt.Sprintf("%s: a pack case expects bytes or pack_error, got %v", c.id, c.expected)
	}
	if err == nil || raw != nil {
		return fmt.Sprintf("%s: expected a refusal, got bytes %x", c.id, raw)
	}
	if kind := hostileKind(err); kind != "pack_error" {
		return fmt.Sprintf("%s: returned %s (%v), want pack_error", c.id, kind, err)
	}
	rule := rules[c.id]
	if rule == nil {
		return fmt.Sprintf("%s: no rule is pinned for this refusal: %v", c.id, err)
	}
	if !rule.MatchString(err.Error()) {
		return fmt.Sprintf("%s: refused by another rule: %q does not match %v", c.id, err.Error(), rule)
	}
	return ""
}

func TestHostilePackVectors(t *testing.T) {
	cases := hostileStage(hostileCases(t), "pack")
	if len(cases) == 0 {
		t.Fatal("no pack vectors")
	}
	for _, c := range cases {
		name := c.id + " packs the bytes"
		if c.expected[0] != "bytes" {
			name = c.id + " packs nothing: pack refuses the row"
		}
		t.Run(name, func(t *testing.T) {
			if msg := checkHostilePack(c, hostilePacks[c.id], hostileRefusals); msg != "" {
				t.Fatal(msg)
			}
		})
	}
}

// AZ-2418 AC-1 as for the other packages: a rule table with one wrong entry cannot pass. The wrong
// entry is built here; nothing on disk changes.
func TestHostilePackWrongRuleEntryFailsNamingTheCase(t *testing.T) {
	// Arrange
	var c hostileCase
	for _, x := range hostileStage(hostileCases(t), "pack") {
		if x.id == "pack_slots_over_limit" {
			c = x
		}
	}
	wrong := map[string]*regexp.Regexp{}
	for k, v := range hostileRefusals {
		wrong[k] = v
	}
	wrong[c.id] = hostileRefusals["pack_repeat_over_limit"]

	// Act
	msg := checkHostilePack(c, hostilePacks[c.id], wrong)

	// Assert
	if !strings.HasPrefix(msg, "pack_slots_over_limit: refused by another rule") {
		t.Fatalf("a wrong rule entry passed or failed another way: %q", msg)
	}
}

func TestHostileEveryRefusalPinsOneRule(t *testing.T) {
	// Arrange
	var refused []string
	for _, c := range hostileStage(hostileCases(t), "pack") {
		if c.expected[0] == "pack_error" {
			refused = append(refused, c.id)
		}
	}

	// Act and assert
	if !sameSet(refused, keysOf(hostileRefusals)) {
		t.Fatalf("pack_error cases %v, pinned rules %v", refused, keysOf(hostileRefusals))
	}
}
