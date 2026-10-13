package packbin

import (
	"fmt"
	"runtime"
	"testing"
)

// allocBound is what one Unpack of a packet of about 64 KB may allocate: the measured cost is about
// 30 MB, the preallocation by the declared width of a row was 1.2 GB at 256 members.
const allocBound = 100 << 20

// wideElement is a Nested row of one u8 and members-1 optional u8s: with a selector of 0 a row reads one
// byte whatever its width.
func wideElement(members int) Field {
	row := []Field{U8(0, "sel")}
	for i := 1; i < members; i++ {
		row = append(row, When(i, Eq(0, 1), U8(i, fmt.Sprintf("m%d", i))))
	}
	return Nested("row", row...)
}

// allocatedBy is the bytes allocated while f runs.
func allocatedBy(f func()) uint64 {
	var before, after runtime.MemStats
	runtime.GC()
	runtime.ReadMemStats(&before)
	f()
	runtime.ReadMemStats(&after)
	return after.TotalAlloc - before.TotalAlloc
}

// F41: the memory of a list or dict of rows follows the bytes read, not the members the scheme declares.
func TestF41ElementRowsAreNotSizedByTheScheme(t *testing.T) {
	const members = 256
	list := mustScheme(t, 1, List("items", wideElement(members)))
	dict := mustScheme(t, 1, Dict("items", wideElement(members)))
	// One byte per item: a selector of 0, so no when holds.
	const listItems, dictItems = 65_535, 10_000
	listPacket := []byte{1, 0xFF, 0xFF}
	listPacket = append(listPacket, make([]byte, listItems)...)
	dictPacket := []byte{1, byte(dictItems & 0xFF), byte(dictItems >> 8)}
	for i := range dictItems {
		dictPacket = append(dictPacket, 4, 0, 'a'+byte(i>>12&15), 'a'+byte(i>>8&15), 'a'+byte(i>>4&15), 'a'+byte(i&15), 0)
	}
	cases := []struct {
		name   string
		scheme *Scheme
		packet []byte
		items  int
	}{{"a list", list, listPacket, listItems}, {"a dict", dict, dictPacket, dictItems}}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Arrange
			var got map[string]any
			var err error

			// Act
			grown := allocatedBy(func() { got, err = UnpackMap(c.packet, c.scheme) })

			// Assert
			if err != nil {
				t.Fatalf("unpack: %v", err)
			}
			t.Logf("%s of %d rows of %d members, %d bytes: %d MB allocated", c.name, c.items, members, len(c.packet), grown>>20)
			if grown > allocBound {
				t.Fatalf("%d MB allocated for a %d-byte packet, bound %d MB", grown>>20, len(c.packet), allocBound>>20)
			}
			var n int
			switch items := got["items"].(type) {
			case []any:
				n = len(items)
			case map[string]any:
				n = len(items)
			}
			if n != c.items {
				t.Fatalf("%d rows read, want %d", n, c.items)
			}
		})
	}
}
