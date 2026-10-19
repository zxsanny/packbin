package packbin

import (
	"errors"
	"fmt"
	"runtime"
	"testing"
	"time"
)

// AZ-2713: a decoded dict key must be greater than the one before it, compared as UTF-8 bytes; a key
// given twice or out of order is refused with the dict-key error (a short packet with nothing needed).

// dictPacket is a type 1 packet of a Dict of U8 with the keys in the order given, each written in the
// raw text form (0x10, then the UTF-8 bytes) and holding the value 0.
func dictPacket(keys ...string) []byte {
	raw := []byte{1, byte(len(keys)), byte(len(keys) >> 8)}
	for _, k := range keys {
		if k == "" {
			raw = append(raw, 0)
		} else {
			raw = append(raw, byte(len(k)+1), 0x10)
			raw = append(raw, k...)
		}
		raw = append(raw, 0)
	}
	return raw
}

func TestDictKeysUnpackAcceptsAscendingUTF8BytesAndRefusesTheRest(t *testing.T) {
	s := mustScheme(t, 1, Dict("m", U8(0, "v")))
	cases := []struct {
		name string
		keys []string
		ok   bool
	}{
		{"ascending", []string{"a", "b", "c"}, true},
		{"empty key first", []string{"", "a"}, true},
		{"prefix first", []string{"a", "ab"}, true},
		{"U+FF5E then U+10000", []string{"～", "\U00010000"}, true},
		{"single key", []string{"z"}, true},
		{"no keys", nil, true},
		{"descending", []string{"b", "a"}, false},
		{"repeated", []string{"a", "a"}, false},
		{"repeated empty", []string{"", ""}, false},
		{"empty key last", []string{"a", ""}, false},
		{"prefix last", []string{"ab", "a"}, false},
		{"U+10000 then U+FF5E", []string{"\U00010000", "～"}, false},
		{"repeat after a gap", []string{"a", "b", "a"}, false},
		{"repeat of the last", []string{"a", "b", "b"}, false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Arrange
			raw := dictPacket(c.keys...)

			// Act
			row, err := UnpackMap(raw, s)

			// Assert
			if c.ok {
				if err != nil || len(row["m"].(map[string]any)) != len(c.keys) {
					t.Fatalf("got %v, %v", row, err)
				}
				return
			}
			var e *Error
			if row != nil || !errors.As(err, &e) || e.Kind != ShortPacket || e.Needed != 0 {
				t.Fatalf("got %v, %v; want a short packet needing 0", row, err)
			}
		})
	}
}

// AZ-2713 AC-3: 65,535 distinct ascending keys packed by the package and unpacked take at most 1 second.
// The fastest of up to three passes counts, as in TestAC7SpeedRoundTrips; the race detector run skips the
// bound.
func TestDictKeysSpeed65535AscendingKeysWithinOneSecond(t *testing.T) {
	// Arrange
	defer runtime.GOMAXPROCS(runtime.GOMAXPROCS(1))
	s := mustScheme(t, 1, Dict("m", U8(0, "v")))
	m := make(map[string]any, 65535)
	for i := range 65535 {
		m[fmt.Sprintf("key%05d", i)] = uint8(i)
	}
	row := map[string]any{"m": m}
	fastest := time.Duration(1<<63 - 1)

	// Act
	for pass := 0; pass < 3 && fastest > time.Second; pass++ {
		start := time.Now()
		raw, err := Pack(s, row)
		if err != nil {
			t.Fatal(err)
		}
		got, err := UnpackMap(raw, s)
		if err != nil || len(got["m"].(map[string]any)) != 65535 {
			t.Fatalf("unpack: %v", err)
		}
		fastest = min(fastest, time.Since(start))
	}

	// Assert
	t.Logf("pack and unpack of 65535 keys: %v (race detector: %v)", fastest, raceEnabled)
	if raceEnabled {
		t.Skipf("%v under the race detector; the 1 s bound is asserted without it", fastest)
	}
	if fastest > time.Second {
		t.Fatalf("fastest pass %v, above 1s", fastest)
	}
}
