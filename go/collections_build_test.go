package packbin

import (
	"math/rand"
	"testing"
)

// randomField builds a field of any kind, with ids and counts that are often wrong, so schemes that
// are refused and schemes that are built both come out.
func randomField(rng *rand.Rand, depth int) Field {
	id := rng.Intn(3)
	name := string(rune('a' + rng.Intn(4)))
	kinds := 17
	if depth <= 0 {
		kinds = 6
	}
	members := func() []Field {
		out := make([]Field, rng.Intn(3))
		for i := range out {
			out[i] = randomField(rng, depth-1)
		}
		return out
	}
	switch rng.Intn(kinds) {
	case 0:
		return U8(id, name)
	case 1:
		return U16(id, name)
	case 2:
		return Utf8(id, name)
	case 3:
		return Bytes(id, name, rng.Intn(3))
	case 4:
		return Bool(id, name)
	case 5:
		return Be(U32(id, name))
	case 6:
		return List(name, randomField(rng, depth-1))
	case 7:
		return Dict(name, randomField(rng, depth-1))
	case 8:
		return Nested(name, members()...)
	case 9:
		return Group(id, name, members()...)
	case 10:
		return Flags(id, members()...)
	case 11:
		return When(id, Eq(rng.Intn(3), rng.Intn(3)), members()...)
	case 12:
		return Times(id, rng.Intn(3), members()...)
	case 13:
		return Repeat(id, members()...)
	case 14:
		return Sized(id, name, rng.Intn(3))
	case 15:
		return List(name, Flags(rng.Intn(2), members()...))
	}
	return nil
}

func randomValue(rng *rand.Rand, depth int) any {
	switch rng.Intn(9) {
	case 0:
		return nil
	case 1:
		return rng.Intn(4)
	case 2:
		return "s"
	case 3:
		return []byte{1}
	case 4:
		return true
	}
	if depth <= 0 {
		return 1
	}
	switch rng.Intn(3) {
	case 0:
		out := make([]any, rng.Intn(3))
		for i := range out {
			out[i] = randomValue(rng, depth-1)
		}
		return out
	default:
		out := map[string]any{}
		for i := rng.Intn(4); i > 0; i-- {
			out[string(rune('a'+rng.Intn(4)))] = randomValue(rng, depth-1)
		}
		return out
	}
}

// No scheme of any shape panics on NewScheme, Pack or Unpack: a refused scheme is an error, a built one
// packs or refuses each row, and what it packs unpacks.
func TestRandomSchemesNeverPanic(t *testing.T) {
	rng := rand.New(rand.NewSource(7))
	built, packed := 0, 0
	for range 30000 {
		fields := make([]Field, 1+rng.Intn(3))
		for i := range fields {
			fields[i] = randomField(rng, 3)
		}
		s, err := NewScheme(1, fields...)
		if err != nil {
			continue
		}
		built++
		for range 5 {
			row := randomValue(rng, 3)
			m, ok := row.(map[string]any)
			if !ok {
				continue
			}
			raw, err := Pack(s, m)
			if err != nil {
				continue
			}
			packed++
			_, _ = UnpackMap(raw, s)
		}
		buf := make([]byte, rng.Intn(24))
		rng.Read(buf)
		if len(buf) > 0 {
			buf[0] = 1
		}
		_, _ = UnpackMap(buf, s)
	}
	t.Logf("built %d, packed %d", built, packed)
	if built < 500 || packed < 50 {
		t.Fatalf("only %d schemes built, %d rows packed: the generator does not reach the walkers", built, packed)
	}
}
