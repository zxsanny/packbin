package packbin

import (
	"sync"
	"testing"
)

// F43: a PackSession shared by goroutines numbers every payload once. 8 goroutines x 1 000 Packs on one
// session; each payload's position is found from its keystream, all positions must be distinct, and a
// second session unpacks the payloads in position order to the rows that were sent. Run under -race.
func TestSessionIsSafeForConcurrentPack(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1, U32(0, "w"), U32(1, "i"))
	opener, waiter := sessionPair(t, sessionNonce(t))
	const goroutines, packs, total = 8, 1_000, 8_000
	payloads := make([][]byte, total)
	var wg sync.WaitGroup

	// Act
	for g := range goroutines {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for i := range packs {
				p, err := opener.Pack(s, map[string]any{"w": uint32(g), "i": uint32(i)})
				if err != nil {
					t.Errorf("pack: %v", err)
					return
				}
				payloads[g*packs+i] = p
			}
		}()
	}
	wg.Wait()

	// Assert
	if t.Failed() {
		return
	}
	// The keystream of each position, over the 9 bytes of a payload, names the position.
	streamAt := make(map[string]int, total)
	for pos := range total {
		zeros := make([]byte, len(payloads[0]))
		if err := pad(waiter.recv, uint64(pos), zeros); err != nil {
			t.Fatalf("pad: %v", err)
		}
		streamAt[string(zeros)] = pos
	}
	order := make([]int, total)
	taken := make([]bool, total)
	for n, p := range payloads {
		g, i := n/packs, n%packs
		plain, err := Pack(s, map[string]any{"w": uint32(g), "i": uint32(i)})
		if err != nil {
			t.Fatalf("pack clear: %v", err)
		}
		stream := make([]byte, len(p))
		for k := range p {
			stream[k] = p[k] ^ plain[k]
		}
		pos, ok := streamAt[string(stream)]
		if !ok || taken[pos] {
			t.Fatalf("payload %d (goroutine %d, pack %d): position %d known=%v, already used=%v", n, g, i, pos, ok, ok && taken[pos])
		}
		taken[pos] = true
		order[pos] = n
	}
	for pos, n := range order {
		row, err := waiter.UnpackMap(payloads[n], s)
		if err != nil || row["w"] != uint32(n/packs) || row["i"] != uint32(n%packs) {
			t.Fatalf("position %d: row %v, %v, want goroutine %d pack %d", pos, row, err, n/packs, n%packs)
		}
	}
}

// F43: Unpack from several goroutines takes each position once and loses none.
func TestSessionIsSafeForConcurrentUnpack(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1, U8(0, "a"))
	opener, waiter := sessionPair(t, sessionNonce(t))
	const goroutines, each = 8, 500
	payloads := make([][]byte, goroutines*each)
	for n := range payloads {
		p, err := opener.Pack(s, map[string]any{"a": uint8(n)})
		if err != nil {
			t.Fatalf("pack: %v", err)
		}
		payloads[n] = p
	}
	var mu sync.Mutex
	rows := 0
	var wg sync.WaitGroup

	// Act
	for g := range goroutines {
		wg.Add(1)
		go func() {
			defer wg.Done()
			for i := range each {
				// Any payload of the right length unpacks: the pad only has to be taken once per call.
				if _, err := waiter.UnpackMap(payloads[g*each+i], s); err == nil {
					mu.Lock()
					rows++
					mu.Unlock()
				}
			}
		}()
	}
	wg.Wait()

	// Assert: every call spent a position, so a sender-side count of the same size reaches the same one.
	waiter.mu.Lock()
	spent := waiter.recvCount
	waiter.mu.Unlock()
	if spent != goroutines*each {
		t.Fatalf("%d positions spent, want %d (%d rows read)", spent, goroutines*each, rows)
	}
}
