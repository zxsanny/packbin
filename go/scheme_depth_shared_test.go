package packbin

import (
	"fmt"
	"testing"
	"time"
)

// AZ-4306: the depth check measures a node that stands in several places once (again only when it is reached deeper
// than before). A scheme that holds the next level twice on every level has two to the power of its depth paths, and
// the depth check runs before the field-id check that would refuse it.

const diamondLevels = 60

// buildNominal is about 20 times the best build of 250 nested whens on a Mac (0.13 ms measured).
const buildNominal = 20 * time.Millisecond

// groupBuildNominal is wider: building nested groups is not linear today. foreignNames copies the path from the top of the
// nested groups to the group at every level, and runs for every group, so 250 nested groups take about 30 ms (62 groups
// 0.2 ms, 125 groups 3 ms). The bound keeps that from growing; a linear build would sit at a fraction of a millisecond.
const groupBuildNominal = 150 * time.Millisecond

func whenDiamond(levels int) []Field {
	inner := U8(1, "b")
	for range levels {
		inner = When(1, Eq(0, 1), inner, inner)
	}
	return []Field{U8(0, "a"), inner}
}

func groupDiamond(levels int) []Field {
	inner := U8(0, "b")
	for range levels {
		inner = Nested("m", inner, inner)
	}
	return []Field{inner}
}

func TestAZ4306DiamondOf60LevelsIsRefusedQuickly(t *testing.T) {
	shapes := []struct {
		name   string
		fields []Field
	}{
		{"when", whenDiamond(diamondLevels)},
		{"group", groupDiamond(diamondLevels)},
	}
	for _, shape := range shapes {
		t.Run(shape.name, func(t *testing.T) {
			// Arrange
			start := time.Now()

			// Act
			s, err := NewScheme(1, shape.fields...)

			// Assert (AC-1)
			took := time.Since(start)
			if err == nil || s != nil {
				t.Fatalf("the diamond built: %v", err)
			}
			if took > time.Second {
				t.Fatalf("the diamond took %v", took)
			}
		})
	}
}

// sharedShallowThenDeep holds one when (a u8 inside) at the top, where it is one level deep, and again at the bottom of
// a chain of whens nested whens.
func sharedShallowThenDeep(whens int) []Field {
	shared := When(1, Eq(0, 1), U8(1, "b"))
	inner := shared
	for range whens {
		inner = When(1, Eq(0, 1), inner)
	}
	return []Field{U8(0, "a"), shared, inner}
}

func TestAZ4306FieldReachedShallowFirstAndDeeperLaterIsMeasuredAtItsDeepest(t *testing.T) {
	// Arrange: the shared when is met at depth 1 first; below 256 whens it is at depth 257.
	fields := sharedShallowThenDeep(256)

	// Act
	_, err := NewScheme(1, fields...)

	// Assert (AC-3)
	if err == nil || err.Error() != depthText {
		t.Fatalf("got %v, want %q", err, depthText)
	}
}

func TestAZ4306FieldReachedDeeperLaterAt256LevelsIsNotRefusedByDepth(t *testing.T) {
	// Arrange: 255 whens and the shared when below them make 256 levels; another rule may refuse the same field twice,
	// but not the depth rule.
	fields := sharedShallowThenDeep(255)

	// Act
	_, err := NewScheme(1, fields...)

	// Assert
	if err != nil && err.Error() == depthText {
		t.Fatalf("256 levels were refused as too deep: %v", err)
	}
}

// buildTime is the smallest of runs timed builds of the scheme.
func buildTime(fields []Field, runs int) time.Duration {
	best := time.Duration(1<<63 - 1)
	for range runs {
		start := time.Now()
		_, _ = NewScheme(1, fields...)
		best = min(best, time.Since(start))
	}
	return best
}

// AZ-4307: the whole build of a chain 250 levels deep (just under the limit) takes time in its size; a build step that
// looks at a node's whole subtree once per level would make it quadratic.
func TestAZ4307BuildOf250NestedLevelsIsLinearInTheDepth(t *testing.T) {
	chains := []struct {
		name    string
		nominal time.Duration
		fields  []Field
	}{
		{"nested whens", buildNominal, func() []Field {
			inner := U8(1, "b")
			for range 250 {
				inner = When(1, Eq(0, 1), inner)
			}
			return []Field{U8(0, "a"), inner}
		}()},
		{"nested groups", groupBuildNominal, func() []Field {
			inner := U8(0, "b")
			for range 250 {
				inner = Nested("m", inner)
			}
			return []Field{inner}
		}()},
	}
	for _, chain := range chains {
		t.Run(chain.name, func(t *testing.T) {
			// Arrange
			if _, err := NewScheme(1, chain.fields...); err != nil {
				t.Fatalf("250 levels did not build: %v", err)
			}
			factor := loadFactor()

			// Act
			took := buildTime(chain.fields, 9)

			// Assert
			t.Logf("%s: %v", chain.name, took)
			assertWithin(t, fmt.Sprintf("building 250 %s", chain.name), took, chain.nominal, factor)
		})
	}
}
