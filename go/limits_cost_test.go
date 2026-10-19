package packbin

import (
	"strconv"
	"testing"
	"time"
)

// AZ-2391 (F34): the cost of one round or one list item does not grow with the fields around it. The
// test compares two sizes in one run (a ratio), never an absolute time.

// withFill is u32 n, fill top-level u8 fields f0.., then the tail fields; every fill field is given once.
func withFill(t testing.TB, fill int, tail func(id int) []Field, row map[string]any) (*Scheme, map[string]any) {
	fields := []Field{U32(0, "n")}
	values := map[string]any{}
	for k, v := range row {
		values[k] = v
	}
	for i := range fill {
		fields = append(fields, U8(i+1, "f"+strconv.Itoa(i)))
		values["f"+strconv.Itoa(i)] = 1
	}
	return mustScheme(t, 1, append(fields, tail(fill+1)...)...), values
}

// best is the fastest of a few packs after one warm-up, so a collector pause does not decide the ratio.
func best(t testing.TB, layout *Scheme, row map[string]any) (time.Duration, []byte) {
	raw, err := Pack(layout, row)
	if err != nil {
		t.Fatal(err)
	}
	fastest := time.Duration(1<<63 - 1)
	for range 5 {
		start := time.Now()
		if raw, err = Pack(layout, row); err != nil {
			t.Fatal(err)
		}
		fastest = min(fastest, time.Since(start))
	}
	return fastest, raw
}

func TestAC1ARoundCostsTheNamesItHoldsNotTheFieldsAroundIt(t *testing.T) {
	// Arrange
	times := func(fill int) (*Scheme, map[string]any) {
		return withFill(t, fill, func(id int) []Field { return []Field{Times(id, 0, U8(id, "k"))} },
			map[string]any{"n": 65_535, "k": listOf(65_535, 7)})
	}
	list := func(fill int) (*Scheme, map[string]any) {
		return withFill(t, fill, func(int) []Field { return []Field{List("xs", U8(0, "e"))} },
			map[string]any{"n": 0, "xs": listOf(65_535, 7)})
	}

	for _, c := range []struct {
		name  string
		make  func(int) (*Scheme, map[string]any)
		extra int
	}{{"times of u8", times, 4}, {"list of u8", list, 4 + 2}} {
		t.Run(c.name, func(t *testing.T) {
			// Act
			factor := loadFactor()
			smallScheme, smallRow := c.make(100)
			largeScheme, largeRow := c.make(1000)
			small, smallRaw := best(t, smallScheme, smallRow)
			large, largeRaw := best(t, largeScheme, largeRow)

			// Assert
			if len(smallRaw) != 1+c.extra+100+65_535 || len(largeRaw) != 1+c.extra+1000+65_535 {
				t.Fatalf("lengths %d, %d", len(smallRaw), len(largeRaw))
			}
			if slack := scaled(10*time.Millisecond, factor); large > 2*small+slack {
				t.Fatalf("100 fields %v, 1000 fields %v (slack %v = 10ms x load factor %.2f)", small, large, slack, factor)
			}
		})
	}
}
