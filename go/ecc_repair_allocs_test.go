package packbin

import (
	"bytes"
	"testing"
)

// F59 (AZ-2722): repair keeps its locator, evaluator and derivative in fixed buffers of n + 1 bytes made
// once per call, so the worst case (n 32, t 16, a 254-byte message) does not allocate once per step.
func TestEccRepairWorstCaseAllocatesAFewBuffersNotOnePerStep(t *testing.T) {
	// Arrange
	s := withParity(t, mustScheme(t, 0, Bytes(0, "b", 221)), 32)
	message, err := Pack(s, map[string]any{"b": bytes.Repeat([]byte{0x5a, 0x11, 0xc3}, 74)[:221]})
	if err != nil || len(message) != 254 {
		t.Fatalf("pack: %d bytes, %v", len(message), err)
	}
	positions := []int{0, 7, 15, 31, 44, 60, 77, 90, 101, 118, 130, 150, 177, 200, 230, 253}
	values := []byte{1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16}
	wrong := corrupt(message, positions, values)
	if clear, count, err := repair(wrong, 32, 16); err != nil || count != 16 || !bytes.Equal(clear, message[:222]) {
		t.Fatalf("repair: %d repaired, %v", count, err)
	}

	// Act
	allocs := testing.AllocsPerRun(50, func() {
		if _, _, err := repair(wrong, 32, 16); err != nil {
			t.Fatal(err)
		}
	})

	// Assert
	t.Logf("repair n=32 t=16 size=254: %v allocations", allocs)
	if allocs > 3 {
		t.Fatalf("%v allocations in one repair, above 3", allocs)
	}
}
