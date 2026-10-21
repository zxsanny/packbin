package packbin

import (
	"fmt"
	"strings"
	"testing"
	"time"
)

// AZ-3134 AC-1 and AC-2: one text of 65,535 characters (the longest a string holds) repeated in 200 rounds of
// times, packed and unpacked; the rounds equal the input and pack plus unpack stays within the 1 s nominal bound
// (scaled by the load factor). The text is parsed once, not once per round.

func TestACTextOneLongTextIn200RoundsIsFast(t *testing.T) {
	// Arrange
	const rounds, textLen = 200, 65535
	s := mustScheme(t, 1, U8(0, "n"), Times(1, 0, Utf8(1, "s")))
	text := strings.Repeat("q", textLen)
	factor := loadFactor()

	// Act
	start := time.Now()
	raw, packErr := Pack(s, gm("n", rounds, "s", text))
	packTook := time.Since(start)
	var row map[string]any
	var unpackErr error
	var unpackTook time.Duration
	if packErr == nil {
		start = time.Now()
		row, unpackErr = UnpackMap(raw, s)
		unpackTook = time.Since(start)
	}

	// Assert
	if packErr != nil || unpackErr != nil {
		t.Fatalf("pack: %v, unpack: %v", packErr, unpackErr)
	}
	t.Logf("AZ-3134 pack %.3f s, unpack %.3f s (%d bytes, load factor %.2f)",
		packTook.Seconds(), unpackTook.Seconds(), len(raw), factor)
	assertRoundsEqual(t, row, rounds, text)
	assertWithin(t, fmt.Sprintf("pack and unpack of %d rounds of %d characters", rounds, textLen),
		packTook+unpackTook, time.Second, factor)
}

func assertRoundsEqual(t *testing.T, row map[string]any, rounds int, text string) {
	t.Helper()
	got, ok := row["s"].([]any)
	if !ok || len(got) != rounds {
		t.Fatalf("s came back as %T of length %d, want %d rounds", row["s"], len(got), rounds)
	}
	for i, v := range got {
		if v != text {
			t.Fatalf("round %d differs from the input (%d characters)", i, len(fmt.Sprint(v)))
		}
	}
}
