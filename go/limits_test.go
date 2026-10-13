package packbin

import (
	"encoding/binary"
	"errors"
	"math"
	"reflect"
	"strings"
	"testing"
	"time"
)

// limited is s with the limits that f changes, from the defaults.
func limited(t testing.TB, s *Scheme, f func(*Limits)) *Scheme {
	t.Helper()
	l := DefaultLimits()
	f(&l)
	out, err := s.WithLimits(l)
	if err != nil {
		t.Fatalf("WithLimits: %v", err)
	}
	return out
}

func repeatK(t testing.TB) *Scheme { return mustScheme(t, 1, Repeat(0, U8(0, "k"))) }

func timesK(t testing.TB) *Scheme { return mustScheme(t, 1, U8(0, "n"), Times(1, 0, U8(1, "k"))) }

func timesK32(t testing.TB) *Scheme { return mustScheme(t, 1, U32(0, "n"), Times(1, 0, U8(1, "k"))) }

// roundsPacket is the type byte, then rounds bytes of 7.
func roundsPacket(rounds int) []byte {
	b := make([]byte, 1+rounds)
	for i := range b {
		b[i] = 7
	}
	b[0] = 1
	return b
}

// countedPacket is the type byte, a little-endian u32 count, then rounds bytes of 7.
func countedPacket(count uint32, rounds int) []byte {
	b := make([]byte, 5+rounds)
	for i := range b {
		b[i] = 7
	}
	b[0] = 1
	binary.LittleEndian.PutUint32(b[1:], count)
	return b
}

// refusedAt asserts a round limit refusal: kind TooMany, needed 0, the bytes left where the round starts.
func refusedAt(t testing.TB, err error, left int) *Error {
	t.Helper()
	e := asError(t, err, TooMany)
	if e.Needed != 0 || e.Left != left || !errors.Is(err, ErrTooMany) || errors.Is(err, ErrShortPacket) {
		t.Fatalf("got %+v, want too_many with needed 0 and left %d", e, left)
	}
	return e
}

func shortAt(t testing.TB, err error, name string, needed, left int) {
	t.Helper()
	e := asError(t, err, ShortPacket)
	if e.Name != name || e.Needed != needed || e.Left != left {
		t.Fatalf("got %+v, want short packet at %s needed %d left %d", e, name, needed, left)
	}
}

func TestAC1DefaultLimitsAndSurface(t *testing.T) {
	// Arrange
	base := repeatK(t)

	// Act
	lowered := limited(t, base, func(l *Limits) { l.MaxRounds = 10 })

	// Assert
	if got := base.Limits(); got != (Limits{MaxRounds: 65_535, MaxSlots: 1_048_576, MaxBytes: 16_777_216}) {
		t.Fatalf("defaults %+v", got)
	}
	if DefaultMaxRounds != 65_535 || DefaultMaxSlots != 1_048_576 || DefaultMaxBytes != 16_777_216 || DefaultLimits() != base.Limits() {
		t.Fatal("the default constants differ from the documented values")
	}
	if got := lowered.Limits(); got != (Limits{MaxRounds: 10, MaxSlots: 1_048_576, MaxBytes: 16_777_216}) {
		t.Fatalf("lowered %+v", got)
	}
	if base.Limits().MaxRounds != 65_535 {
		t.Fatal("WithLimits changed the receiver")
	}
}

func TestAC1WithLimitsKeepsTypeNumberAndPacksLikeItsSource(t *testing.T) {
	// Arrange
	base := mustScheme(t, 9, U8(0, "n"), Sized(1, "body", 0))
	derived := limited(t, base, func(l *Limits) { l.MaxRounds = 3 })
	row := map[string]any{"n": 2, "body": []byte{5, 6}}

	// Act
	want := mustPack(t, base, row)
	got := mustPack(t, derived, row)
	back, err := UnpackMap(mustHex(t, got), derived)

	// Assert
	if derived.TypeNumber() != 9 || got != want || got != "09020506" {
		t.Fatalf("type %d, %s vs %s", derived.TypeNumber(), got, want)
	}
	if err != nil || !reflect.DeepEqual(back, map[string]any{"n": uint8(2), "body": []byte{5, 6}}) {
		t.Fatalf("row %v, %v", back, err)
	}
}

func TestAC1WithLimitsRefusesAnythingBelowOne(t *testing.T) {
	// Arrange
	base := repeatK(t)
	for _, c := range []struct {
		name string
		edit func(*Limits)
	}{
		{"MaxRounds", func(l *Limits) { l.MaxRounds = 0 }},
		{"MaxRounds", func(l *Limits) { l.MaxRounds = -1 }},
		{"MaxSlots", func(l *Limits) { l.MaxSlots = 0 }},
		{"MaxSlots", func(l *Limits) { l.MaxSlots = math.MinInt }},
		{"MaxBytes", func(l *Limits) { l.MaxBytes = 0 }},
		{"MaxBytes", func(l *Limits) { l.MaxBytes = -64 }},
	} {
		l := DefaultLimits()
		c.edit(&l)

		// Act
		got, err := base.WithLimits(l)

		// Assert
		e := asError(t, err, InvalidScheme)
		if got != nil || !errors.Is(err, ErrInvalidScheme) || !strings.Contains(e.Reason, c.name) {
			t.Fatalf("%+v: scheme %v, error %+v", l, got, e)
		}
	}
	if got, err := base.WithLimits(Limits{}); got != nil || err == nil {
		t.Fatalf("the zero Limits is not a limit: %v, %v", got, err)
	}
	if got, err := (*Scheme)(nil).WithLimits(DefaultLimits()); got != nil || err == nil {
		t.Fatalf("a nil scheme: %v, %v", got, err)
	}
}

func TestAC1RaisedToTheLargestIntUnpacksPastTheDefault(t *testing.T) {
	// Arrange
	layout := limited(t, repeatK(t), func(l *Limits) { l.MaxRounds, l.MaxSlots, l.MaxBytes = math.MaxInt, math.MaxInt, math.MaxInt })

	// Act
	row, err := UnpackMap(roundsPacket(DefaultMaxRounds+1), layout)

	// Assert
	if err != nil || len(row["k"].([]any)) != DefaultMaxRounds+1 {
		t.Fatalf("%d rounds, %v", len(row["k"].([]any)), err)
	}
}

func TestAC1RepeatAtTheDefaultLimit(t *testing.T) {
	// Arrange
	layout := repeatK(t)

	// Act
	row, okErr := UnpackMap(roundsPacket(DefaultMaxRounds), layout)
	_, overErr := UnpackMap(roundsPacket(DefaultMaxRounds+1), layout)

	// Assert
	if okErr != nil || len(row["k"].([]any)) != DefaultMaxRounds {
		t.Fatalf("%d rounds, %v", len(row["k"].([]any)), okErr)
	}
	e := refusedAt(t, overErr, 1)
	if e.Name != "k" || e.Field != 0 {
		t.Fatalf("got %+v", e)
	}
}

func TestAC1RepeatUnderALoweredLimit(t *testing.T) {
	// Arrange
	layout := limited(t, repeatK(t), func(l *Limits) { l.MaxRounds = 3 })

	// Act
	ok, okErr := Unpack(mustHex(t, "01aabbcc"), layout)
	row, err := Unpack(mustHex(t, "01aabbccdd"), layout)

	// Assert
	if okErr != nil || !reflect.DeepEqual(ok, map[string]any{"k": []any{uint8(170), uint8(187), uint8(204)}}) {
		t.Fatalf("%v, %v", ok, okErr)
	}
	if row != nil {
		t.Fatalf("a refused unpack gave a row: %v", row)
	}
	refusedAt(t, err, 1)
}

func TestAC1TimesUnderALoweredLimit(t *testing.T) {
	// Arrange
	layout := limited(t, timesK(t), func(l *Limits) { l.MaxRounds = 3 })

	// Act
	ok, okErr := UnpackMap(mustHex(t, "0103090909"), layout)
	_, withByte := UnpackMap(mustHex(t, "010409090909"), layout)
	_, beforeShort := UnpackMap(mustHex(t, "0104090909"), layout)
	_, hugeCount := UnpackMap(mustHex(t, "01ff09"), layout)
	_, fewRounds := UnpackMap(mustHex(t, "01030909"), layout)

	// Assert
	if okErr != nil || !reflect.DeepEqual(ok, map[string]any{"n": uint8(3), "k": []any{uint8(9), uint8(9), uint8(9)}}) {
		t.Fatalf("%v, %v", ok, okErr)
	}
	refusedAt(t, withByte, 1)
	refusedAt(t, beforeShort, 0) // round 4 is refused before the short read the unlimited walk gives
	shortAt(t, hugeCount, "k", 1, 0)
	shortAt(t, fewRounds, "k", 1, 0)
}

func TestAC1TimesAtTheDefaultLimit(t *testing.T) {
	// Arrange
	layout := timesK32(t)

	// Act
	row, okErr := UnpackMap(countedPacket(65_535, 65_535), layout)
	_, justOver := UnpackMap(countedPacket(65_536, 65_536), layout)
	_, hugeWithOver := UnpackMap(countedPacket(math.MaxUint32, 65_536), layout)
	_, hugeAtLimit := UnpackMap(countedPacket(math.MaxUint32, 65_535), layout)
	_, hugeShort := UnpackMap(mustHex(t, "01ffffffff00"), layout)

	// Assert
	if okErr != nil || len(row["k"].([]any)) != 65_535 {
		t.Fatalf("%v", okErr)
	}
	refusedAt(t, justOver, 1)
	refusedAt(t, hugeWithOver, 1)
	refusedAt(t, hugeAtLimit, 0)
	shortAt(t, hugeShort, "k", 1, 0)
}

func slotLayout(t testing.TB) *Scheme {
	s := mustScheme(t, 1, Repeat(0, U8(0, "k"), When(1, Eq(0, 1), U8(1, "a"), U8(2, "b"))))
	return limited(t, s, func(l *Limits) { l.MaxSlots = 6 })
}

func TestAC1SlotLimitIsChargedPerRoundBeforeItsBytes(t *testing.T) {
	// Arrange
	layout := slotLayout(t)

	// Act
	row, okErr := UnpackMap(mustHex(t, "010000"), layout)
	_, third := UnpackMap(mustHex(t, "01000000"), layout)
	_, thirdWithRest := UnpackMap(mustHex(t, "0100000000"), layout)

	// Assert
	want := map[string]any{
		"k": []any{uint8(0), uint8(0)}, "a": []any{nil, nil}, "b": []any{nil, nil},
	}
	if okErr != nil || !reflect.DeepEqual(row, want) {
		t.Fatalf("%v, %v", row, okErr)
	}
	refusedAt(t, third, 1)
	refusedAt(t, thirdWithRest, 2)
}

func TestAC1OneSlotCounterForEveryRoundFieldOfACall(t *testing.T) {
	// Arrange
	base := mustScheme(t, 1, U8(0, "n"), Times(1, 0, U8(1, "k")), Times(2, 0, U8(2, "v")))
	wire := mustHex(t, "0102aabbccdd")

	// Act
	row, fitsErr := UnpackMap(wire, limited(t, base, func(l *Limits) { l.MaxRounds, l.MaxSlots = 3, 4 }))
	_, overErr := UnpackMap(wire, limited(t, base, func(l *Limits) { l.MaxRounds, l.MaxSlots = 3, 3 }))

	// Assert
	want := map[string]any{"n": uint8(2), "k": []any{uint8(170), uint8(187)}, "v": []any{uint8(204), uint8(221)}}
	if fitsErr != nil || !reflect.DeepEqual(row, want) {
		t.Fatalf("%v, %v", row, fitsErr)
	}
	if e := refusedAt(t, overErr, 1); e.Name != "v" {
		t.Fatalf("got %+v", e)
	}
}

func TestAC1MaxRoundsIsPerFieldAndMaxSlotsIsPerCall(t *testing.T) {
	// Arrange: two times fields of 3 rounds each, a limit of 3 rounds
	base := mustScheme(t, 1, U8(0, "n"), Times(1, 0, U8(1, "k")), Times(2, 0, U8(2, "v")))
	layout := limited(t, base, func(l *Limits) { l.MaxRounds = 3 })

	// Act
	row, err := UnpackMap(mustHex(t, "0103010203040506"), layout)

	// Assert
	if err != nil || len(row["k"].([]any)) != 3 || len(row["v"].([]any)) != 3 {
		t.Fatalf("%v, %v", row, err)
	}
}

func TestAC1AMillionByteRoundPacketIsRefusedFastWhereMaxSlotsIsReached(t *testing.T) {
	// Arrange: a round holds 37 names (k and the 36 behind the when); round 28,340 would hold 1,048,580 slots
	body := []Field{U8(0, "k")}
	var members []Field
	for i := range 36 {
		name := "f" + string(rune('a'+i/26)) + string(rune('a'+i%26))
		if i%2 == 0 {
			members = append(members, U8(1+i, name))
		} else {
			members = append(members, U16(1+i, name))
		}
	}
	layout := mustScheme(t, 1, Repeat(0, append(body, When(1, Eq(0, 1), members...))...))
	wire := make([]byte, 1+1_048_576)
	wire[0] = 1

	// Act
	start := time.Now()
	row, err := UnpackMap(wire, layout)
	elapsed := time.Since(start)

	// Assert
	if row != nil {
		t.Fatal("a refused unpack gave a row")
	}
	refusedAt(t, err, 1_020_237)
	if elapsed > time.Second {
		t.Fatalf("the refusal took %v", elapsed)
	}
}

func TestAC1LimitsBelongToTheSchemeThatMatches(t *testing.T) {
	// Arrange
	base := repeatK(t)
	strict := limited(t, base, func(l *Limits) { l.MaxRounds = 3 })
	other := limited(t, mustScheme(t, 2, Repeat(0, U8(0, "k"))), func(l *Limits) { l.MaxRounds = 2 })
	wire := mustHex(t, "01aabbccdd")

	// Act
	loose, looseErr := UnpackMap(wire, base)
	_, tightErr := UnpackMap(wire, strict)
	_, matchedErr := UnpackMap(mustHex(t, "02aabbcc"), base, other)

	// Assert
	if looseErr != nil || len(loose["k"].([]any)) != 4 {
		t.Fatalf("%v, %v", loose, looseErr)
	}
	refusedAt(t, tightErr, 1)
	refusedAt(t, matchedErr, 1)
}

func TestAC1TooManyIsAnErrorValueWithTheHostileName(t *testing.T) {
	// Arrange
	layout := limited(t, repeatK(t), func(l *Limits) { l.MaxRounds = 1 })

	// Act
	_, err := Unpack(mustHex(t, "010102"), layout)

	// Assert
	e := refusedAt(t, err, 1)
	if e.Kind.String() != "too_many" || e.Error() != "packbin: too many at field 0 (k): round 2 is above the limit of 1 rounds" {
		t.Fatalf("%q", e.Error())
	}
}
