package packbin

import (
	"encoding/hex"
	"testing"
)

// These buffers are not within t wrong bytes of a code word, yet the locator has `count` roots among
// the sent positions and the evaluator gives a value for each, so fixing those bytes does not make a code
// word. Found by a seeded search of random buffers with the re-verify taken out; only the re-verify
// refuses them.
var reverifyCases = []struct {
	name string
	hex  string
	n, t int
}{
	{"n4_t1_13_bytes", "a0d9a39d753edd405b01e23923", 4, 1},
	{"n4_t2_10_bytes", "74fee0ce9393f2efc4ba", 4, 2},
	{"n4_t2_12_bytes", "9f079ddc735948b71b6b82f2", 4, 2},
	{"n6_t2_12_bytes", "3064be1b784579317feab3b6", 6, 2},
	{"n6_t3_18_bytes", "8fc70a7d13312fe2e8ceb62ee33ec711f3e8", 6, 3},
}

func TestEccRepairAFixedWordThatIsNotACodeWordIsRefusedNotReturned(t *testing.T) {
	for _, c := range reverifyCases {
		t.Run(c.name, func(t *testing.T) {
			// Arrange
			received, err := hex.DecodeString(c.hex)
			if err != nil {
				t.Fatalf("hex: %v", err)
			}

			// Act
			clear, count, err := repair(received, c.n, c.t)

			// Assert
			if e, ok := err.(*Error); !ok || e.Kind != Uncorrectable {
				t.Fatalf("got clear=%x count=%d err=%v, want Uncorrectable", clear, count, err)
			}
		})
	}
}

func TestEccRepairAWordItReturnsIsOneThePackerCouldHaveSent(t *testing.T) {
	// Arrange: random buffers at n = 4, t = 2; the ones the decoder accepts must repack to themselves.
	rng := newRand(20261018)
	accepted := 0

	// Act
	for range 300_000 {
		received := make([]byte, 5+rng.IntN(15))
		for k := range received {
			received[k] = byte(rng.IntN(256))
		}
		clear, count, err := repair(received, 4, 2)
		if err != nil || count == 0 {
			continue
		}
		accepted++

		// Assert: the repaired word differs from received in exactly count bytes, and every syndrome of
		// clear followed by its own parity is zero.
		word, perr := protect(clear, 4)
		if perr != nil {
			t.Fatalf("protect: %v", perr)
		}
		wrong := 0
		for k := range word {
			if word[k] != received[k] {
				wrong++
			}
		}
		if wrong != count {
			t.Fatalf("received %x: repaired %d bytes but the code word of %x differs in %d", received, count, clear, wrong)
		}
	}
	if accepted == 0 {
		t.Fatal("no buffer was repaired: the sweep proved nothing")
	}
}
