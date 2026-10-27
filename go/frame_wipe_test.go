package packbin

import (
	"bytes"
	"os"
	"strings"
	"sync"
	"testing"
	"time"
)

// AZ-3293: the tag compare, the key wipes, and the concurrency rules of the session.

func TestTheCompareSeparatesEqualFirstByteAndLastByteDifferences(t *testing.T) {
	// Arrange
	tag := []byte{1, 2, 3, 4, 5, 6, 7, 8}
	first := bytes.Clone(tag)
	first[0] ^= 0x80
	last := bytes.Clone(tag)
	last[len(last)-1] ^= 1

	// Act and Assert
	if !tagsEqual(tag, bytes.Clone(tag)) || tagsEqual(tag, first) || tagsEqual(tag, last) {
		t.Fatal("equal, first byte and last byte")
	}
	if tagsEqual(tag, tag[:7]) || !tagsEqual(nil, []byte{}) {
		t.Fatal("different lengths are unequal, two empty tags are equal")
	}
}

// The compare is the standard library's constant-time compare, and no other compare touches a tag: no bytes.Equal,
// bytes.Compare, string conversion or == on slices in the frame sources.
func TestNoFrameSourceComparesATagWithAnEarlyExit(t *testing.T) {
	for _, file := range []string{"frame_session.go", "frame_mac.go", "frame_keys.go", "frame_crypto.go"} {
		// Arrange
		raw, err := os.ReadFile(file)
		if err != nil {
			t.Fatal(err)
		}
		source := string(raw)

		// Act and Assert
		for _, banned := range []string{"bytes.Equal", "bytes.Compare", "bytes.HasPrefix", "reflect.DeepEqual", "strings.Compare"} {
			if strings.Contains(source, banned) {
				t.Fatalf("%s uses %s", file, banned)
			}
		}
	}
	raw, err := os.ReadFile("frame_crypto.go")
	if err != nil {
		t.Fatal(err)
	}
	if !strings.Contains(string(raw), "subtle.ConstantTimeCompare") {
		t.Fatal("tagsEqual is not crypto/subtle")
	}
}

func TestAClosedMacKeyHasAZeroedKeyAndRefusesEveryCall(t *testing.T) {
	// Arrange
	m, err := DeriveMacKey(frameTestKey, 9, []byte("net"))
	if err != nil {
		t.Fatal(err)
	}
	array := m.key
	tag := make([]byte, 4)
	if err := m.Tag(tag, []byte("m")); err != nil || allZero(array) {
		t.Fatalf("err %v", err)
	}

	// Act
	m.Close()
	after := sentinels(4)
	err = m.Tag(after, []byte("m"))
	m.Close()

	// Assert
	if !allZero(array) || err == nil || !untouched(after) || m.Verify(tag, []byte("m")) {
		t.Fatal("a closed key")
	}
}

const (
	concurrencyGoroutines = 8
	concurrencyPerRoutine = 1000
)

func concurrencyInput(routine, i int) (MsgContext, []byte, []byte, []byte) {
	id := []byte{byte(routine), byte(routine >> 8), 0, 0, byte(i), byte(i >> 8), byte(i >> 16), 0}
	plain := make([]byte, i%80)
	for k := range plain {
		plain[k] = byte(routine*31 + i + k)
	}
	return NewMsgContext(id, i%16), []byte{byte(routine), byte(i)}, []byte{byte(i), 7}, plain
}

func concurrencySeal(t testing.TB, s *FrameSession, routine, i int) []byte {
	message, ad, clearPart, plain := concurrencyInput(routine, i)
	body := make([]byte, 255)
	n, err := s.Seal(FrameGroup, message, ad, clearPart, plain, body)
	if err != nil {
		t.Error(err)
		return nil
	}
	return body[:n]
}

func TestEightGoroutinesSealingTheSameSessionGiveTheSingleGoroutineBodies(t *testing.T) {
	// Arrange
	s := newFrameSession(t, make([]byte, 32), 3, 8)
	expected := make([][][]byte, concurrencyGoroutines)
	for r := range expected {
		expected[r] = make([][]byte, concurrencyPerRoutine)
		for i := range expected[r] {
			expected[r][i] = concurrencySeal(t, s, r, i)
		}
	}
	actual := make([][][]byte, concurrencyGoroutines)
	factor := loadFactor()
	var group sync.WaitGroup
	start := time.Now()

	// Act
	for r := range actual {
		actual[r] = make([][]byte, concurrencyPerRoutine)
		group.Add(1)
		go func() {
			defer group.Done()
			for i := range actual[r] {
				actual[r][i] = concurrencySeal(t, s, r, i)
			}
		}()
	}
	group.Wait()
	elapsed := time.Since(start)

	// Assert
	differing := 0
	for r := range actual {
		for i := range actual[r] {
			if !bytes.Equal(expected[r][i], actual[r][i]) {
				differing++
			}
			message, ad, clearPart, plain := concurrencyInput(r, i)
			text := make([]byte, 255)
			opened, err := s.Open(FrameGroup, message, ad, actual[r][i], len(clearPart), text, nil, 0)
			if err != nil || !bytes.Equal(text[:opened.PlainLength], plain) || !bytes.Equal(actual[r][i][:len(clearPart)], clearPart) {
				t.Fatalf("goroutine %d message %d: %v", r, i, err)
			}
		}
	}
	if differing != 0 {
		t.Fatalf("%d bodies differ", differing)
	}
	assertWithin(t, "8 x 1000 seals on 8 goroutines", elapsed, 20*time.Second, factor)
}

// Open runs beside SetPrevious, ClearPrevious and Close: the session's lock orders them (run under -race), every open
// that sees a key opens with the right slot, and once the session is closed every call is a BadValue.
func TestOpenSetPreviousClearPreviousAndCloseFromManyGoroutinesDoNotRace(t *testing.T) {
	// Arrange
	old := newFrameSession(t, frameTestOtherKey, 1, 8)
	s, err := LoadFrameSession(frameTestKey, 2, FrameConfig{TagLength: 8, Directions: FrameDirectionsAll})
	if err != nil {
		t.Fatal(err)
	}
	current := newFrameSession(t, frameTestKey, 2, 8)
	oldBody, currentBody := sealFrame(t, old), sealFrame(t, current)
	var group sync.WaitGroup

	// Act
	for range 4 {
		group.Add(1)
		go func() {
			defer group.Done()
			for range 200 {
				out := make([]byte, 64)
				if _, err := openFrame(s, currentBody, out, nil, 0); err != nil && !isBadValue(err) {
					t.Errorf("current: %v", err)
				}
				if opened, err := openFrame(s, oldBody, out, nil, 0); err == nil && opened.Slot != FrameSlotPrevious {
					t.Errorf("old frame opened in slot %v", opened.Slot)
				} else if err != nil && !isBadValue(err) && frameKindOf(err) != TagMismatch {
					t.Errorf("old: %v", err)
				}
			}
		}()
	}
	group.Add(1)
	go func() {
		defer group.Done()
		for range 100 {
			if err := s.SetPrevious(frameTestOtherKey, 1); err != nil && !isBadValue(err) {
				t.Errorf("set: %v", err)
			}
			s.ClearPrevious()
		}
		s.Close()
	}()
	group.Wait()

	// Assert
	if _, err := openFrame(s, currentBody, make([]byte, 64), nil, 0); !isBadValue(err) {
		t.Fatalf("after Close: %v", err)
	}
}

func isBadValue(err error) bool { return frameKindOf(err) == BadValue }

func TestAMacKeyIsSafeFromManyGoroutines(t *testing.T) {
	// Arrange
	m, err := DeriveMacKey(frameTestKey, 3, []byte("net"))
	if err != nil {
		t.Fatal(err)
	}
	want := make([]byte, 8)
	if err := m.Tag(want, []byte("one"), []byte("two")); err != nil {
		t.Fatal(err)
	}
	var group sync.WaitGroup

	// Act
	for range 8 {
		group.Add(1)
		go func() {
			defer group.Done()
			for range 200 {
				tag := make([]byte, 8)
				if err := m.Tag(tag, []byte("one"), []byte("two")); err != nil || !bytes.Equal(tag, want) || !m.Verify(tag, []byte("onetwo")) {
					t.Errorf("tag %x err %v", tag, err)
				}
			}
		}()
	}
	group.Wait()
	m.Close()

	// Assert
	if m.Verify(want, []byte("onetwo")) {
		t.Fatal("verify after Close")
	}
}
