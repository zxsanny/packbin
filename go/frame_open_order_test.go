package packbin

import (
	"bytes"
	"errors"
	"testing"
)

// AZ-3293 AC-3: the order of open (contract pack-session.md): argument checks, the replay check (no tag computed
// for Duplicate and TooOld), the tag with the current key then the previous key, decrypt, commit. A refusal leaves
// the output buffer and the window as they were.

var (
	frameTestKey      = bytes.Repeat([]byte{0x11}, 32)
	frameTestOtherKey = bytes.Repeat([]byte{0x22}, 32)
	frameTestID       = []byte{1, 2, 3, 4, 5, 6, 7, 8}
	frameTestAD       = []byte{9, 8, 7}
)

func newFrameSession(t testing.TB, key []byte, epoch uint32, tag int) *FrameSession {
	t.Helper()
	s, err := LoadFrameSession(key, epoch, FrameConfig{TagLength: tag, Directions: FrameDirectionsAll})
	if err != nil {
		t.Fatal(err)
	}
	t.Cleanup(s.Close)
	return s
}

// sealFrame seals "hello, relay" with a 3-byte clear part and returns the body.
func sealFrame(t testing.TB, s *FrameSession) []byte {
	t.Helper()
	out := make([]byte, 255)
	n, err := s.Seal(FrameUp, NewMsgContext(frameTestID, 4), frameTestAD, []byte{7, 7, 7}, []byte("hello, relay"), out)
	if err != nil {
		t.Fatal(err)
	}
	return out[:n]
}

func openFrame(s *FrameSession, body []byte, out []byte, w *ReplayWindow, counter uint64) (FrameOpened, error) {
	return s.Open(FrameUp, NewMsgContext(frameTestID, 4), frameTestAD, body, 3, out, w, counter)
}

func TestAC3AForgedTagIsATagMismatchWithTheBufferAndTheWindowUnchanged(t *testing.T) {
	// Arrange
	s := newFrameSession(t, frameTestKey, 1, 8)
	body := sealFrame(t, s)
	body[len(body)-1] ^= 1
	window := NewReplayWindow(5, 0b11)
	out := sentinels(64)
	macs := s.macs.Load()

	// Act
	opened, err := openFrame(s, body, out, window, 9)

	// Assert
	if !errors.Is(err, ErrTagMismatch) || frameKindName(err) != "TagMismatch" {
		t.Fatalf("err %v", err)
	}
	if !untouched(out) || window.Top() != 5 || window.Bits() != 0b11 || opened != (FrameOpened{}) {
		t.Fatalf("out %x window %d:%b opened %+v", out, window.Top(), window.Bits(), opened)
	}
	if got := s.macs.Load() - macs; got != 1 {
		t.Fatalf("%d MACs computed, want 1 (no previous key)", got)
	}
}

func TestAC3ADuplicateIsRefusedBeforeAnyMacIsComputed(t *testing.T) {
	// Arrange
	s := newFrameSession(t, frameTestKey, 1, 8)
	body := sealFrame(t, s)
	window := &ReplayWindow{}
	out := make([]byte, 64)
	if _, err := openFrame(s, body, out, window, 7); err != nil {
		t.Fatal(err)
	}
	again := sentinels(64)
	macs := s.macs.Load()

	// Act
	_, err := openFrame(s, body, again, window, 7)

	// Assert
	if !errors.Is(err, ErrDuplicate) {
		t.Fatalf("err %v", err)
	}
	if s.macs.Load() != macs {
		t.Fatal("a MAC was computed for a duplicate")
	}
	if !untouched(again) || window.Top() != 7 || window.Bits() != 1 {
		t.Fatalf("out %x window %d:%b", again, window.Top(), window.Bits())
	}
}

func TestAC3ACounter64OrMoreBelowTheTopIsTooOldWithNoMacComputed(t *testing.T) {
	// Arrange
	s := newFrameSession(t, frameTestKey, 1, 8)
	body := sealFrame(t, s)
	window := NewReplayWindow(100, 1)
	out := sentinels(64)
	macs := s.macs.Load()

	// Act
	_, err := openFrame(s, body, out, window, 36)
	_, edge := openFrame(s, body, out, window, 37)

	// Assert
	if !errors.Is(err, ErrTooOld) {
		t.Fatalf("counter 36: %v", err)
	}
	if edge != nil || window.Bits()&(1<<63) == 0 {
		t.Fatalf("counter 37 is the oldest the window holds: %v, bits %b", edge, window.Bits())
	}
	if got := s.macs.Load() - macs; got != 1 {
		t.Fatalf("%d MACs computed: only counter 37 may compute one", got)
	}
}

func TestAC3AFrameUnderThePreviousKeyOpensWithSlotPrevious(t *testing.T) {
	// Arrange
	old := newFrameSession(t, frameTestOtherKey, 1, 8)
	body := sealFrame(t, old)
	s := newFrameSession(t, frameTestKey, 2, 8)
	if err := s.SetPrevious(frameTestOtherKey, 1); err != nil {
		t.Fatal(err)
	}
	window := &ReplayWindow{}
	out := make([]byte, 64)
	macs := s.macs.Load()

	// Act
	opened, err := openFrame(s, body, out, window, 3)

	// Assert
	if err != nil || opened.Slot != FrameSlotPrevious || opened.ClearLength != 3 || opened.PlainLength != 12 {
		t.Fatalf("opened %+v err %v", opened, err)
	}
	if string(out[:12]) != "hello, relay" {
		t.Fatalf("plain %q", out[:12])
	}
	if got := s.macs.Load() - macs; got != 2 {
		t.Fatalf("%d MACs: the current key then the previous key make 2", got)
	}
	if window.Top() != 3 || window.Bits() != 1 {
		t.Fatalf("a frame under the previous key commits into the window: %d:%b", window.Top(), window.Bits())
	}
}

func TestAC3WithoutThePreviousKeyOrAfterClearingItTheOldFrameIsATagMismatch(t *testing.T) {
	// Arrange
	old := newFrameSession(t, frameTestOtherKey, 1, 8)
	body := sealFrame(t, old)
	s := newFrameSession(t, frameTestKey, 2, 8)
	if err := s.SetPrevious(frameTestOtherKey, 1); err != nil {
		t.Fatal(err)
	}
	s.ClearPrevious()
	window := &ReplayWindow{}
	out := sentinels(64)

	// Act
	_, err := openFrame(s, body, out, window, 3)

	// Assert
	if !errors.Is(err, ErrTagMismatch) || !untouched(out) || window.Bits() != 0 {
		t.Fatalf("err %v out %x window %d:%b", err, out, window.Top(), window.Bits())
	}
}

func TestAC3ASuccessfulOpenCommitsTheCounterOnlyAfterTheDecrypt(t *testing.T) {
	// Arrange
	s := newFrameSession(t, frameTestKey, 1, 4)
	body := sealFrame(t, s)
	window := NewReplayWindow(10, 1)
	out := make([]byte, 64)

	// Act
	opened, err := openFrame(s, body, out, window, 12)

	// Assert
	if err != nil || opened.Slot != FrameSlotCurrent || string(out[:opened.PlainLength]) != "hello, relay" {
		t.Fatalf("opened %+v err %v", opened, err)
	}
	if window.Top() != 12 || window.Bits() != 0b101 {
		t.Fatalf("window %d:%b", window.Top(), window.Bits())
	}
}

func TestAC3AMessageSealedForOneDirectionKindOrEpochDoesNotOpenForAnother(t *testing.T) {
	// Arrange
	s := newFrameSession(t, frameTestKey, 1, 8)
	body := sealFrame(t, s)
	other := newFrameSession(t, frameTestKey, 2, 8)
	out := sentinels(64)

	// Act
	_, direction := s.Open(FrameDown, NewMsgContext(frameTestID, 4), frameTestAD, body, 3, out, nil, 0)
	_, kind := s.Open(FrameUp, NewMsgContext(frameTestID, 5), frameTestAD, body, 3, out, nil, 0)
	_, id := s.Open(FrameUp, NewMsgContext([]byte{1, 2, 3, 4, 5, 6, 7, 9}, 4), frameTestAD, body, 3, out, nil, 0)
	_, epoch := openFrame(other, body, out, nil, 0)
	_, ad := s.Open(FrameUp, NewMsgContext(frameTestID, 4), []byte{9, 8}, body, 3, out, nil, 0)
	_, clearLength := s.Open(FrameUp, NewMsgContext(frameTestID, 4), frameTestAD, body, 4, out, nil, 0)

	// Assert
	for name, err := range map[string]error{"direction": direction, "kind": kind, "msg_id": id, "epoch": epoch, "ad": ad,
		"clear length": clearLength} {
		if !errors.Is(err, ErrTagMismatch) {
			t.Fatalf("%s: %v", name, err)
		}
	}
	if !untouched(out) {
		t.Fatalf("out %x", out)
	}
}
