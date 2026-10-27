package packbin

import (
	"encoding/hex"
	"errors"
	"os"
	"reflect"
	"strings"
	"testing"
)

const expectedHex = "4001000065cd1d00a3e1110100"

type Position struct {
	Sid      uint16
	Lat      int32
	Lon      int32
	Profile  uint8
	Heading  *uint16
	Speed    *uint8
	Altitude *int16
}

func hexOf(b []byte) string { return hex.EncodeToString(b) }

func mustHex(t testing.TB, s string) []byte {
	t.Helper()
	b, err := hex.DecodeString(strings.ReplaceAll(s, " ", ""))
	if err != nil {
		t.Fatalf("bad hex %q: %v", s, err)
	}
	return b
}

func mustScheme(t testing.TB, typeNumber int, fields ...Field) *Scheme {
	t.Helper()
	s, err := NewScheme(typeNumber, fields...)
	if err != nil {
		t.Fatalf("NewScheme: %v", err)
	}
	return s
}

func mustPack(t testing.TB, s *Scheme, row any) string {
	t.Helper()
	b, err := Pack(s, row)
	if err != nil {
		t.Fatalf("Pack: %v", err)
	}
	return hexOf(b)
}

func mustUnpackMap(t testing.TB, s *Scheme, wire string) map[string]any {
	t.Helper()
	row, err := UnpackMap(mustHex(t, wire), s)
	if err != nil {
		t.Fatalf("UnpackMap %s: %v", wire, err)
	}
	return row
}

func goldenHex(t testing.TB) string {
	t.Helper()
	raw, err := os.ReadFile("../fixtures/golden.hex")
	if err != nil {
		t.Fatalf("read golden: %v", err)
	}
	return strings.TrimSpace(string(raw))
}

func positionMapScheme(t testing.TB) *Scheme {
	return mustScheme(t, 0x40,
		U16(0, "sid"),
		I32(1, "lat"),
		I32(2, "lon"),
		U8(3, "profile"),
		Flags(4, U16(4, "heading"), U8(5, "speed"), I16(6, "altitude")),
	)
}

func positionTypedScheme(t testing.TB) *Scheme {
	return mustScheme(t, 0x40,
		Bind(U16(0, "sid"), func(r *Position) uint16 { return r.Sid }, func(r *Position, v uint16) { r.Sid = v }),
		Bind(I32(1, "lat"), func(r *Position) int32 { return r.Lat }, func(r *Position, v int32) { r.Lat = v }),
		Bind(I32(2, "lon"), func(r *Position) int32 { return r.Lon }, func(r *Position, v int32) { r.Lon = v }),
		Bind(U8(3, "profile"), func(r *Position) uint8 { return r.Profile }, func(r *Position, v uint8) { r.Profile = v }),
		Flags(4,
			Bind(U16(4, "heading"), func(r *Position) *uint16 { return r.Heading }, func(r *Position, v *uint16) { r.Heading = v }),
			Bind(U8(5, "speed"), func(r *Position) *uint8 { return r.Speed }, func(r *Position, v *uint8) { r.Speed = v }),
			Bind(I16(6, "altitude"), func(r *Position) *int16 { return r.Altitude }, func(r *Position, v *int16) { r.Altitude = v }),
		),
	)
}

func goldenRow() *Position {
	return &Position{Sid: 1, Lat: 500_000_000, Lon: 300_000_000, Profile: 1}
}

func goldenMap() map[string]any {
	return map[string]any{"sid": 1, "lat": 500_000_000, "lon": 300_000_000, "profile": 1}
}

// goldenFieldMismatches counts the fields of an unpacked map row that differ from goldenMap, and the
// flag fields it holds although the golden row has none.
func goldenFieldMismatches(row map[string]any) int {
	want := map[string]any{"sid": uint16(1), "lat": int32(500_000_000), "lon": int32(300_000_000), "profile": uint8(1)}
	bad := 0
	for k, v := range want {
		if !reflect.DeepEqual(row[k], v) {
			bad++
		}
	}
	for _, k := range []string{"heading", "speed", "altitude"} {
		if _, ok := row[k]; ok {
			bad++
		}
	}
	return bad
}

func mismatchedBytes(a, b []byte) int {
	n := max(len(a), len(b))
	bad := 0
	for i := range n {
		if i >= len(a) || i >= len(b) || a[i] != b[i] {
			bad++
		}
	}
	return bad
}

// asError returns err as an *Error of the given kind, or fails the test.
func asError(t testing.TB, err error, want Kind) *Error {
	t.Helper()
	var e *Error
	if !errors.As(err, &e) {
		t.Fatalf("expected *Error of kind %v, got %v", want, err)
	}
	if e.Kind != want {
		t.Fatalf("expected kind %v, got %v (%v)", want, e.Kind, e)
	}
	return e
}
