package packbin

import (
	"fmt"
	"math/rand/v2"
	"reflect"
	"testing"
)

// skipN is p; when(p == 0) { n }; tail: tail names n, which the first when can skip.
func skipN(t testing.TB, tail Field) *Scheme {
	return mustScheme(t, 1, U8(0, "p"), When(1, Eq(0, 0), U8(1, "n")), tail)
}

// Ported from typescript/tests/when-on-written-values.test.ts.
func TestWhenOnAFieldAnotherWhenSkippedDoesNotMatch(t *testing.T) {
	// Arrange
	s := skipN(t, When(2, Eq(1, 0), U8(2, "v")))

	// Act
	miss := mustPack(t, s, map[string]any{"p": 1, "n": 0, "v": 4})
	hit := mustPack(t, s, map[string]any{"p": 0, "n": 0, "v": 4})
	absent := mustPack(t, s, map[string]any{"p": 1, "v": 4})

	// Assert
	if miss != "0101" || hit != "01000004" || absent != "0101" {
		t.Fatalf("miss %s hit %s absent %s", miss, hit, absent)
	}
	if back := mustUnpackMap(t, s, miss); !reflect.DeepEqual(back, map[string]any{"p": uint8(1)}) {
		t.Fatalf("got %v", back)
	}
	if back := mustUnpackMap(t, s, hit); !reflect.DeepEqual(back, map[string]any{"p": uint8(0), "n": uint8(0), "v": uint8(4)}) {
		t.Fatalf("got %v", back)
	}
}

func TestWhenOnASetFlagBitMatchesTrue(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1, Flags(0, Bool(0, "on")), When(1, Eq(0, true), U8(1, "v")))

	// Act
	wire := mustPack(t, s, map[string]any{"on": true, "v": 7})
	off := mustPack(t, s, map[string]any{"on": false, "v": 7})

	// Assert
	if wire != "010107" || off != "0100" {
		t.Fatalf("on %s off %s", wire, off)
	}
	if back := mustUnpackMap(t, s, wire); !reflect.DeepEqual(back, map[string]any{"on": true, "v": uint8(7)}) {
		t.Fatalf("got %v", back)
	}
}

func TestWhenOnAnUnwrittenFlagMemberNeverMatches(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1, Flags(0, U8(0, "a")), When(1, Eq(0, 0), U8(1, "b")))

	// Act
	wire := mustPack(t, s, map[string]any{"b": 7})

	// Assert
	if wire != "0100" {
		t.Fatalf("got %s", wire)
	}
	if back := mustUnpackMap(t, s, wire); len(back) != 0 {
		t.Fatalf("got %v", back)
	}
}

func TestWhenComparesByValueAcrossGoTypes(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1, U16(0, "k"), When(1, Eq(0, uint8(300%256)), U8(1, "v")), When(2, Eq(0, 44.0), U8(2, "w")))

	// Act
	wire := mustPack(t, s, map[string]any{"k": int64(44), "v": 1, "w": 2})

	// Assert
	if wire != "012c000102" {
		t.Fatalf("got %s", wire)
	}
}

// A seeded chain of whens over small values, so bodies are skipped and matched often: pack never
// writes what its own unpack cannot read, and the row unpack returns packs to the same bytes.
func TestWhenChainReadsBackWhatWasWritten(t *testing.T) {
	// Arrange
	rng := rand.New(rand.NewPCG(2197, 0))
	checked := 0

	for range 500 {
		names := []string{"n0"}
		fields := []Field{U8(0, "n0")}
		id := 1
		for range 2 + rng.IntN(4) {
			tested := rng.IntN(id)
			anchor := id
			var body []Field
			for j := range 1 + rng.IntN(2) {
				name := fmt.Sprintf("n%d", len(names))
				names = append(names, name)
				body = append(body, U8(id+j, name))
			}
			id += len(body)
			fields = append(fields, When(anchor, Eq(tested, rng.IntN(3)), body...))
		}
		s := mustScheme(t, 1, fields...)
		for range 20 {
			row := map[string]any{}
			for _, name := range names {
				row[name] = rng.IntN(3)
			}

			// Act
			raw, err := Pack(s, row)
			if err != nil {
				t.Fatal(err)
			}
			back, err := UnpackMap(raw, s)
			checked++

			// Assert
			if err != nil {
				t.Fatalf("%v -> %x: %v", row, raw, err)
			}
			if again := mustPack(t, s, back); again != hexOf(raw) {
				t.Fatalf("%v -> %x repacks as %s", row, raw, again)
			}
		}
	}
	if checked != 10_000 {
		t.Fatalf("checked %d", checked)
	}
}
