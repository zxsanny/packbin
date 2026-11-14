package packbin

import (
	"bytes"
	"errors"
	"fmt"
	"testing"
	"time"
)

// AZ-4299: a scheme nested deeper than 256 levels is refused when it is built (contract scheme-depth.md).
// Every chain is built by a loop, innermost first, so the tests never recurse either.

const depthText = "packbin: invalid scheme: scheme nested too deep: more than 256 levels; the limit is 256"

// depthChain is one kind of nesting: its scheme at a depth, and a row for it that packs a value at the innermost level.
type depthChain struct {
	name   string
	scheme func(depth int) (*Scheme, error)
	row    func(depth int) hostileRow
}

func whenChain(depth int) (*Scheme, error) {
	inner := U8(1, "b")
	for i := 0; i < depth; i++ {
		inner = When(1, Eq(0, 1), inner)
	}
	return NewScheme(1, U8(0, "a"), inner)
}

func groupChain(depth int) (*Scheme, error) {
	inner := U8(0, "b")
	for i := 0; i < depth; i++ {
		inner = Nested("m", inner)
	}
	return NewScheme(1, inner)
}

func nestedRow(depth int) hostileRow {
	row := hostileRow{"b": 7}
	for i := 0; i < depth; i++ {
		row = hostileRow{"m": row}
	}
	return row
}

// listChain nests depth lists, each holding one item, around one u8; dictChain does the same with dicts.
func listChain(depth int) (*Scheme, error) {
	inner := U8(0, "x")
	for i := 0; i < depth; i++ {
		inner = List("l", inner)
	}
	return NewScheme(1, inner)
}

func listRow(depth int) hostileRow {
	var item any = 7
	for i := 1; i < depth; i++ {
		item = []any{item}
	}
	return hostileRow{"l": []any{item}}
}

func dictChain(depth int) (*Scheme, error) {
	inner := U8(0, "x")
	for i := 0; i < depth; i++ {
		inner = Dict("d", inner)
	}
	return NewScheme(1, inner)
}

func dictRow(depth int) hostileRow {
	var item any = 7
	for i := 1; i < depth; i++ {
		item = map[string]any{"k": item}
	}
	return hostileRow{"d": map[string]any{"k": item}}
}

// listGroupChain nests depth/2 pairs of list(nested(...)): each pair is two levels.
func listGroupChain(depth int) (*Scheme, error) {
	inner := U8(0, "x")
	for i := 0; i < depth/2; i++ {
		inner = List("l", Nested("m", inner))
	}
	if depth%2 == 1 {
		inner = List("l", inner)
	}
	return NewScheme(1, inner)
}

// flagsChain nests depth flags, each the only member of the one around it, around one bool.
func flagsChain(depth int) (*Scheme, error) {
	inner := Bool(0, "on")
	for i := 0; i < depth; i++ {
		inner = Flags(0, inner)
	}
	return NewScheme(1, inner)
}

// roundChain puts one repeat or times at the top and a chain of groups in its body: depth levels in all.
func roundChain(top func(body Field) []Field) func(int) (*Scheme, error) {
	return func(depth int) (*Scheme, error) {
		inner := U8(0, "b")
		for i := 1; i < depth; i++ {
			inner = Nested("m", inner)
		}
		return NewScheme(1, top(inner)...)
	}
}

func repeatTop(body Field) []Field { return []Field{Repeat(0, body)} }

func timesTop(body Field) []Field { return []Field{U8(0, "n"), Times(1, 0, body)} }

func depthChains() []depthChain {
	return []depthChain{
		{"when", whenChain, func(int) hostileRow { return hostileRow{"a": 1, "b": 7} }},
		{"group", groupChain, nestedRow},
		{"list", listChain, listRow},
		{"dict", dictChain, dictRow},
		{"repeat body", roundChain(repeatTop), func(d int) hostileRow {
			return hostileRow{"m": []any{nestedRow(d - 2)}}
		}},
		{"times body", roundChain(timesTop), func(d int) hostileRow {
			return hostileRow{"n": 1, "m": []any{nestedRow(d - 2)}}
		}},
	}
}

func isDepthRefusal(err error) bool {
	var e *Error
	return errors.As(err, &e) && e.Kind == InvalidScheme && e.Error() == depthText
}

func TestDepthChainsBuildAt256AndAreRefusedAt257(t *testing.T) {
	for _, c := range depthChains() {
		t.Run(c.name, func(t *testing.T) {
			// AC-1, AC-2: the boundary of each kind.
			// Arrange and act
			s256, err256 := c.scheme(256)
			s257, err257 := c.scheme(257)

			// Assert
			if err256 != nil || s256 == nil {
				t.Fatalf("256 levels: want a scheme, got %v", err256)
			}
			if s257 != nil || !isDepthRefusal(err257) {
				t.Fatalf("257 levels: want the depth refusal, got %v (scheme %v)", err257, s257 != nil)
			}
		})
	}
}

func TestDepthChainsAt256PackAndUnpackAtTheDefaultStack(t *testing.T) {
	for _, c := range depthChains() {
		t.Run(c.name, func(t *testing.T) {
			// AC-2. Arrange
			s, err := c.scheme(256)
			if err != nil {
				t.Fatalf("build: %v", err)
			}

			// Act
			packed, err := Pack(s, c.row(256))
			if err != nil {
				t.Fatalf("pack: %v", err)
			}
			got, err := UnpackMap(packed, s)
			if err != nil {
				t.Fatalf("unpack: %v", err)
			}
			again, err := Pack(s, got)
			if err != nil {
				t.Fatalf("pack of the unpacked value: %v", err)
			}

			// Assert
			if !bytes.Equal(packed, again) {
				t.Fatalf("the unpacked value packs to %x, the first pack was %x", again, packed)
			}
		})
	}
}

func TestDepthChainsFarPastTheLimitAreRefusedQuicklyWithoutAStackError(t *testing.T) {
	for _, c := range depthChains() {
		for _, depth := range []int{1000, 50000} {
			t.Run(fmt.Sprintf("%s %d", c.name, depth), func(t *testing.T) {
				// AC-1. Arrange
				done := make(chan error, 1)
				start := time.Now()

				// Act
				go func() { _, err := c.scheme(depth); done <- err }()
				var err error
				select {
				case err = <-done:
				case <-time.After(10 * time.Second):
					t.Fatal("no result in 10 s")
				}

				// Assert
				if !isDepthRefusal(err) {
					t.Fatalf("want the depth refusal, got %v", err)
				}
				t.Logf("refused in %v", time.Since(start))
			})
		}
	}
}

func TestDepthMixedKindsCountTheirOwnKinds(t *testing.T) {
	// AC-1. A list counts one level plus its element's own kind; a flag bit adds none; u2 adds none.
	cases := []struct {
		name  string
		build func(depth int) (*Scheme, error)
	}{
		{"flags", flagsChain},
		{"list of nested", listGroupChain},
		{"alternating when and nested", func(depth int) (*Scheme, error) {
			inner := U8(1, "b")
			for i := 0; i < depth; i++ {
				if i%2 == 0 {
					inner = When(1, Eq(0, 1), inner)
				} else {
					inner = Group(1, "m", inner)
				}
			}
			return NewScheme(1, U8(0, "a"), inner)
		}},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Arrange and act
			_, err256 := c.build(256)
			_, err257 := c.build(257)

			// Assert
			if err256 != nil {
				t.Fatalf("256: %v", err256)
			}
			if !isDepthRefusal(err257) {
				t.Fatalf("257: want the depth refusal, got %v", err257)
			}
		})
	}
}

func TestDepthRefusalComesBeforeOtherSchemeChecks(t *testing.T) {
	// AC-1: the depth is checked first, so a deep scheme with a wrong id is refused for its depth.
	// Arrange
	inner := U8(5, "b")
	for i := 0; i < 300; i++ {
		inner = When(9, Eq(0, 1), inner)
	}

	// Act
	_, err := NewScheme(1, U8(0, "a"), inner)

	// Assert
	if !isDepthRefusal(err) {
		t.Fatalf("want the depth refusal, got %v", err)
	}
}
