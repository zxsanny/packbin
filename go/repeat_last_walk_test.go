package packbin

import (
	"fmt"
	"math/rand/v2"
	"testing"
	"time"
)

// AZ-4259 (F79 of the loop 113 audit): the repeat-last walk asked for the first writer under a container again at
// every level while a repeat was open, so a chain of nested whens cost O(depth squared). It keeps the first writer per
// node now. The old walk is kept below, only to compare decisions and texts with the new one.

func oldCheckRepeatLast(nodes []*node, open *node, inElement bool) (*node, error) {
	for _, n := range nodes {
		if open != nil {
			if w := oldFirstWriter(n); w != nil {
				return nil, schemeErr(open.id, "", "repeat %d: %s follows it; a repeat reads to the end of the packet, so nothing can follow it; use times",
					open.id, writerLabel(w))
			}
		}
		var err error
		switch n.kind {
		case kindRepeat:
			if inElement {
				return nil, schemeErr(n.id, "", "repeat %d is inside a list or dict element; a repeat reads to the end of the packet, so another element cannot follow it; use times",
					n.id)
			}
			if open == nil {
				open = n
			}
			_, err = oldCheckRepeatLast(n.fields, nil, false)
		case kindTimes:
			_, err = oldCheckRepeatLast(n.fields, nil, false)
		case kindWhen, kindFlags, kindGroup:
			open, err = oldCheckRepeatLast(n.fields, open, inElement)
		case kindFlagBit:
			open, err = oldCheckRepeatLast([]*node{n.field}, open, inElement)
		case kindList, kindDict:
			_, err = oldCheckRepeatLast([]*node{n.elem}, nil, true)
		}
		if err != nil {
			return nil, err
		}
	}
	return open, nil
}

func oldFirstWriter(n *node) *node {
	switch n.kind {
	case kindBool:
		return nil
	case kindBytes:
		if n.size == 0 {
			return nil
		}
	case kindFlagBit:
		return oldFirstWriter(n.field)
	case kindWhen, kindGroup:
		return oldFirstWriterIn(n.fields)
	case kindRepeat, kindTimes:
		if oldFirstWriterIn(n.fields) == nil {
			return nil
		}
	}
	return n
}

func oldFirstWriterIn(nodes []*node) *node {
	for _, n := range nodes {
		if w := oldFirstWriter(n); w != nil {
			return w
		}
	}
	return nil
}

func newRepeatLastWalk(nodes []*node) error {
	_, err := checkRepeatLast(nodes, nil, false, writerMemo{})
	return err
}

func oldRepeatLastWalk(nodes []*node) error {
	_, err := oldCheckRepeatLast(nodes, nil, false)
	return err
}

// randomTree is a small random tree of the kinds the walk looks at; every node has an id and a name of its own.
type randomTree struct {
	rng *rand.Rand
	ids int
}

func (g *randomTree) node(depth int) *node {
	g.ids++
	n := &node{id: g.ids, name: fmt.Sprintf("n%d", g.ids), size: 1}
	pick := g.rng.IntN(14)
	if depth == 0 {
		pick %= 5
	}
	switch pick {
	case 0:
		n.kind = kindBool
	case 1:
		n.kind, n.size = kindBytes, 0
	case 2:
		n.kind = kindBytes
	case 3:
		n.kind = kindInt
	case 4:
		n.kind = kindFlagByte
	case 5, 6:
		n.kind, n.fields = kindWhen, g.nodes(depth-1)
	case 7:
		n.kind, n.fields = kindGroup, g.nodes(depth-1)
	case 8:
		n.kind, n.fields = kindFlags, g.nodes(depth-1)
	case 9:
		n.kind, n.field = kindFlagBit, g.node(depth-1)
	case 10, 11:
		n.kind, n.fields = kindRepeat, g.nodes(depth-1)
	case 12:
		n.kind, n.fields = kindTimes, g.nodes(depth-1)
	default:
		n.kind, n.elem = kindList, g.node(depth-1)
		if g.rng.IntN(2) == 0 {
			n.kind = kindDict
		}
	}
	return n
}

func (g *randomTree) nodes(depth int) []*node {
	out := make([]*node, g.rng.IntN(4))
	for i := range out {
		out[i] = g.node(depth)
	}
	return out
}

func TestAZ4259NewRepeatLastWalkDecidesAsTheOldWalkDid(t *testing.T) {
	// Arrange
	g := &randomTree{rng: rand.New(rand.NewPCG(4259, 1))}
	refused, built := 0, 0

	for i := range 20000 {
		tree := g.nodes(4)

		// Act
		want, got := oldRepeatLastWalk(tree), newRepeatLastWalk(tree)

		// Assert
		if fmt.Sprint(want) != fmt.Sprint(got) {
			t.Fatalf("tree %d: old walk %v, new walk %v", i, want, got)
		}
		if want != nil {
			refused++
		} else {
			built++
		}
	}
	if refused < 2000 || built < 2000 {
		t.Fatalf("the generated trees must reach both outcomes: %d refused, %d built", refused, built)
	}
}

// chainAfterRepeat is u8 k; repeat { u8 v }; then depth nested whens around an empty when: nothing after the repeat
// can write a byte, so the scheme builds, and every level of the chain is asked for its first writer.
func chainAfterRepeat(depth int) []Field {
	inner := When(2, Eq(0, 1))
	for range depth {
		inner = When(2, Eq(0, 1), inner)
	}
	return []Field{U8(0, "k"), Repeat(1, U8(1, "v")), inner}
}

// siblingsAfterRepeat is the same with width empty whens side by side.
func siblingsAfterRepeat(width int) []Field {
	fields := []Field{U8(0, "k"), Repeat(1, U8(1, "v"))}
	for range width {
		fields = append(fields, When(2, Eq(0, 1)))
	}
	return fields
}

func nodesOfFields(fields []Field) []*node {
	out := make([]*node, len(fields))
	for i, f := range fields {
		out[i] = nodeOf(f)
	}
	return out
}

// walkTime is the smallest of runs timed passes of walk over nodes.
func walkTime(walk func([]*node) error, nodes []*node, runs int) (time.Duration, error) {
	best := time.Duration(1<<63 - 1)
	var err error
	for range runs {
		start := time.Now()
		err = walk(nodes)
		best = min(best, time.Since(start))
	}
	return best, err
}

// AZ-4259: a chain of 4,000 nested whens and 16,000 sibling whens after a repeat, and the walk of four times
// that size takes a few milliseconds (1.9 ms and 4 ms measured; the old walk took 1.8 s on the 16,000 chain).
// The walk is timed on the nodes directly. Since AZ-4299 a scheme nested deeper than 256 levels is refused when it
// is built, so the chain is built through NewScheme at buildSize (250) levels and only the walk sees 16,000.
func TestAZ4259RepeatLastWalkIsLinearInTheDepthOfAChainAndTheWidthOfASiblingRun(t *testing.T) {
	shapes := []struct {
		name  string
		build func(n int) []Field
		size  int
		// buildSize is the size NewScheme must build.
		buildSize int
	}{
		{"a chain of nested whens", chainAfterRepeat, 4000, 250},
		{"sibling whens that write nothing", siblingsAfterRepeat, 16000, 16000},
	}
	for _, shape := range shapes {
		t.Run(shape.name, func(t *testing.T) {
			// Arrange: the scheme builds at its build size; the walk is timed on four times its size.
			if s, err := NewScheme(1, shape.build(shape.buildSize)...); err != nil || s == nil {
				t.Fatalf("scheme of %d did not build: %v", shape.buildSize, err)
			}
			large := nodesOfFields(shape.build(4 * shape.size))
			factor := loadFactor()

			// Act
			took, err := walkTime(newRepeatLastWalk, large, 5)

			// Assert
			if err != nil {
				t.Fatalf("walk refused: %v", err)
			}
			t.Logf("%s: %d took %v", shape.name, 4*shape.size, took)
			assertWithin(t, fmt.Sprintf("%s, %d", shape.name, 4*shape.size), took, 40*time.Millisecond, factor)
		})
	}
}
