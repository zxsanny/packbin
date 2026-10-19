package packbin

import (
	"errors"
	"fmt"
	"math/rand"
	"strings"
	"testing"
	"time"
)

// AZ-2653 AC-3 (every string position), AC-5 (limits and headers), AC-7 (dictionary keys), AC-8 (speed)
// and seeded random texts and buffers.

// ctrl is a control character: it costs more as a symbol than as a raw byte, so a text of it is raw.
const ctrl = "\x01"

func packsTo(t *testing.T, label string, s *Scheme, row map[string]any, wire string) {
	t.Helper()
	// Act
	got := mustPack(t, s, row)
	back := mustUnpackMap(t, s, wire)

	// Assert
	if got != wire {
		t.Errorf("%s: packed %s, want %s", label, got, wire)
	}
	if again := mustPack(t, s, back); again != wire {
		t.Errorf("%s: the unpacked row %v repacks to %s", label, back, again)
	}
}

func TestACTextEveryStringPosition(t *testing.T) {
	// Arrange
	flags := mustScheme(t, 1, Flags(0, Utf8(0, "note")))

	// Act and assert
	packsTo(t, "list element", mustScheme(t, 1, List("xs", Utf8(0, "x"))),
		gm("xs", anys("a", "привіт")), "01"+"0200"+"021061"+"05a37aa424e0")
	packsTo(t, "dictionary key and value list", mustScheme(t, 1, Dict("m", List("l", Utf8(0, "x")))),
		gm("m", gm("b", anys("x"))), "01"+"0100"+"021062"+"0100"+"021078")
	packsTo(t, "times string", mustScheme(t, 1, U8(0, "n"), Times(1, 0, Utf8(1, "s"))),
		gm("n", 2, "s", "a"), "01"+"02"+"021061"+"021061")
	packsTo(t, "times string list", mustScheme(t, 1, U8(0, "n"), Times(1, 0, Utf8(1, "s"))),
		gm("n", 2, "s", anys("a", "b")), "01"+"02"+"021061"+"021062")
	packsTo(t, "repeat string", mustScheme(t, 1, Repeat(0, Utf8(0, "s"))),
		gm("s", anys("a", "b")), "01"+"021061"+"021062")
	packsTo(t, "optional string under flags", flags, gm("note", "a"), "01"+"01"+"021061")
	packsTo(t, "optional string under flags after a count", mustScheme(t, 1, U8(0, "n"), Flags(1, Utf8(1, "note"))),
		gm("n", 7, "note", "привіт"), "01"+"07"+"01"+"05a37aa424e0")
}

func TestACTextAbsentOptionalAddsNothingAndEmptyAddsOneByte(t *testing.T) {
	// Arrange
	flags := mustScheme(t, 1, Flags(0, Utf8(0, "note")))

	// Act
	absent := mustPack(t, flags, gm())
	empty := mustPack(t, flags, gm("note", ""))
	back := mustUnpackMap(t, flags, empty)
	none := mustUnpackMap(t, flags, absent)

	// Assert
	if absent != "0100" || empty != "010100" {
		t.Fatalf("absent %s, empty %s", absent, empty)
	}
	if v, ok := back["note"]; !ok || v != "" {
		t.Errorf("the empty string came back as %v", back)
	}
	if _, ok := none["note"]; ok {
		t.Errorf("the absent string came back as %v", none)
	}
}

func TestACTextLimitsAndHeaders(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1, Utf8(0, "s"))
	atLimit := strings.Repeat(ctrl, 65535)

	// Act
	packed, err := Pack(s, gm("s", atLimit))
	_, refused := Pack(s, gm("s", strings.Repeat(ctrl, 65536)))

	// Assert
	if err != nil || hexOf(packed[:5]) != "01808004"+"10" || len(packed) != 1+3+65536 {
		t.Fatalf("65535 bytes: err %v, %d bytes", err, len(packed))
	}
	if got := mustUnpackMap(t, s, hexOf(packed))["s"]; got != atLimit {
		t.Error("65535 bytes did not round trip")
	}
	if e := asError(t, refused, PackRefused); e.Name != "s" || !strings.Contains(e.Reason, "utf-8 length 65536") {
		t.Errorf("65536 bytes: %v", e)
	}
	for _, c := range []struct {
		chars  int
		header string
	}{{126, "7f10"}, {127, "800110"}} {
		raw := mustPack(t, s, gm("s", strings.Repeat(ctrl, c.chars)))
		if raw[2:2+len(c.header)] != c.header {
			t.Errorf("%d characters: header %s, want %s", c.chars, raw[2:2+len(c.header)], c.header)
		}
	}
	long := strings.Repeat("a", 65535)
	if got := mustUnpackMap(t, s, mustPack(t, s, gm("s", long)))["s"]; got != long {
		t.Error("65535 compressible bytes did not round trip")
	}
}

func TestACTextMaxBytesBoundsThePacket(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1, Utf8(0, "s"))
	text := strings.Repeat(ctrl, 60)
	size := len(mustPack(t, s, gm("s", text))) / 2

	// Act
	exact, err := s.WithLimits(Limits{MaxRounds: 1, MaxSlots: 1, MaxBytes: size})
	if err != nil {
		t.Fatal(err)
	}
	less, err := s.WithLimits(Limits{MaxRounds: 1, MaxSlots: 1, MaxBytes: size - 1})
	if err != nil {
		t.Fatal(err)
	}
	_, atLimit := Pack(exact, gm("s", text))
	_, over := Pack(less, gm("s", text))

	// Assert
	if atLimit != nil {
		t.Errorf("a packet of exactly MaxBytes: %v", atLimit)
	}
	e := asError(t, over, PackRefused)
	if want := fmt.Sprintf("s: the packet would be %d bytes, above the limit of %d bytes", size, size-1); e.Reason != want {
		t.Errorf("got %q, want %q", e.Reason, want)
	}
}

func TestACTextDictionaryKeysAreSortedByBytes(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1, Dict("m", U8(0, "v")))
	keys := []string{"я", "a", "б", "Ж", "z", "ґ", "😀"}
	forward, backward := map[string]any{}, map[string]any{}
	for i, k := range keys {
		forward[k] = i
		backward[keys[len(keys)-1-i]] = len(keys) - 1 - i
	}

	// Act
	a, b := mustPack(t, s, gm("m", forward)), mustPack(t, s, gm("m", backward))
	back := mustUnpackMap(t, s, a)["m"].(map[string]any)

	// Assert
	if a != b {
		t.Errorf("two insertion orders gave %s and %s", a, b)
	}
	if len(back) != len(keys) || back["😀"] != uint8(6) || back["ґ"] != uint8(5) {
		t.Errorf("round trip %v", back)
	}
	if !strings.HasPrefix(a, "01"+"0700"+"021061"+"01") {
		t.Errorf("the first key is not a: %s", a)
	}
}

func TestACTextRepeatedDecodedKeyIsRefused(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1, Dict("m", U8(0, "v")))

	// Act
	row, err := UnpackMap(mustHex(t, "01"+"0200"+"021061"+"01"+"021061"+"02"), s)

	// Assert
	e := asError(t, err, ShortPacket)
	if row != nil || e.Name != "m" {
		t.Errorf("row %v err %v", row, e)
	}
}

// A lone string repeated under Times is written once per round: 2000 rounds of a 10,000-byte text pack
// in a fraction of the time that parsing the text 2000 times would take (the packer copies the field
// it wrote last).
func TestACTextLoneStringUnderTimesIsParsedOnce(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1, U16(0, "n"), Times(1, 0, Utf8(1, "s")))
	text := strings.Repeat("привіт, світе! ", 400)
	const rounds = 2000

	// Act
	factor := loadFactor()
	start := time.Now()
	raw, err := Pack(s, gm("n", rounds, "s", text))
	took := time.Since(start)

	// Assert
	if err != nil {
		t.Fatalf("pack: %v", err)
	}
	assertWithin(t, fmt.Sprintf("%d rounds of %d bytes", rounds, len(text)), took, 500*time.Millisecond, factor)
	t.Logf("%d rounds of a %d-byte text: %d bytes in %v", rounds, len(text), len(raw), took)
}

func randomText(rng *rand.Rand) string {
	pools := []string{
		"абвгґдеєжзиіїйклмнопрстуфхцчшщьюя'АБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯ",
		"абвгдеёжзийклмнопрстуфхцчшщъыьэюяАБВГДЕЁЖЗИЙКЛМНОПРСТУФХЦЧШЩЪЫЬЭЮЯ",
		"abcdefghijklmnopqrstuvwxyz'ABCDEFGHIJKLMNOPQRSTUVWXYZ",
		"0123456789.,-: ",
		" 0123456789,.-:!?;()\"%/@+=*#&_$\n",
		"éßżł中文😀\u0001\u007f\u0301\ufeff\U0010ffff",
	}
	var b strings.Builder
	for n := rng.Intn(60); n > 0; n-- {
		pool := []rune(pools[rng.Intn(len(pools))])
		for run := 1 + rng.Intn(8); run > 0 && n > 0; run, n = run-1, n-1 {
			b.WriteRune(pool[rng.Intn(len(pool))])
		}
	}
	return b.String()
}

func TestACTextRandomTextsRoundTrip(t *testing.T) {
	// Arrange
	rng := rand.New(rand.NewSource(35))
	s := mustScheme(t, 1, Utf8(0, "s"))

	for range 3000 {
		text := randomText(rng)

		// Act
		wire := mustPack(t, s, gm("s", text))
		back := mustUnpackMap(t, s, wire)["s"]

		// Assert
		if back != text {
			t.Fatalf("%q came back as %q (%s)", text, back, wire)
		}
		if len(wire)/2 > 1+3+len(text) {
			t.Fatalf("%q: %d bytes, more than the type, the count and the UTF-8", text, len(wire)/2)
		}
	}
}

func TestACTextRandomBuffersNeverPanic(t *testing.T) {
	// Arrange
	rng := rand.New(rand.NewSource(2653))
	for range 20000 {
		buf := make([]byte, rng.Intn(24))
		rng.Read(buf)
		if len(buf) > 0 && rng.Intn(2) == 0 {
			buf[0] = byte(len(buf) - 1)
		}

		// Act
		_, _, err := unpackField(t, buf)

		// Assert
		var e *Error
		if err != nil && (!errors.As(err, &e) || e.Kind != ShortPacket && e.Kind != TrailingBytes) {
			t.Fatalf("%x: %v", buf, err)
		}
	}
}
