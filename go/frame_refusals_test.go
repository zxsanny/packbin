package packbin

import (
	"bytes"
	"errors"
	"testing"
)

// AZ-3293: what load, seal, open, the previous slot and the MAC-only call refuse, and that a refusal writes nothing.

func frameKindOf(err error) Kind {
	var e *Error
	if errors.As(err, &e) {
		return e.Kind
	}
	return 0
}

func TestLoadRefusesWhatTheContractCallsBadValue(t *testing.T) {
	key := frameTestKey
	all := FrameConfig{TagLength: 4, Directions: FrameDirectionsAll}
	cases := []struct {
		name   string
		key    []byte
		epoch  uint32
		config FrameConfig
		ok     bool
	}{
		{"largest epoch", key, 0xFFFFFF, all, true},
		{"epoch above", key, 0x1000000, all, false},
		{"tag 0", key, 1, FrameConfig{0, FrameDirectionsAll}, false},
		{"tag 1", key, 1, FrameConfig{1, FrameDirectionsAll}, false},
		{"tag 5", key, 1, FrameConfig{5, FrameDirectionsAll}, false},
		{"tag 12", key, 1, FrameConfig{12, FrameDirectionsAll}, false},
		{"tag 17", key, 1, FrameConfig{17, FrameDirectionsAll}, false},
		{"tag 32", key, 1, FrameConfig{32, FrameDirectionsAll}, false},
		{"tag negative", key, 1, FrameConfig{-4, FrameDirectionsAll}, false},
		{"tag 8", key, 1, FrameConfig{8, FrameDirectionsAll}, true},
		{"tag 16", key, 1, FrameConfig{16, FrameDirectionsAll}, true},
		{"key 31", key[:31], 1, all, false},
		{"key 33", append(bytes.Clone(key), 0), 1, all, false},
		{"nil key", nil, 1, all, false},
		{"direction bit 8", key, 1, FrameConfig{4, 8}, false},
		{"all and bit 8", key, 1, FrameConfig{4, FrameDirectionsAll | 8}, false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Act
			s, err := LoadFrameSession(c.key, c.epoch, c.config)

			// Assert
			if c.ok {
				if err != nil || s == nil {
					t.Fatalf("err %v", err)
				}
				s.Close()
				return
			}
			if s != nil || !errors.Is(err, ErrBadValue) {
				t.Fatalf("session %v err %v", s, err)
			}
		})
	}
}

func TestLoadWithNoDirectionGivesASessionThatRefusesEverySealAndOpen(t *testing.T) {
	for _, tag := range []int{4, 8, 16} {
		// Arrange
		none, err := LoadFrameSession(frameTestKey, 0, FrameConfig{TagLength: tag, Directions: FrameDirectionsNone})
		if err != nil {
			t.Fatal(err)
		}
		all := newFrameSession(t, frameTestKey, 0, tag)
		for _, d := range []FrameDirection{FrameUp, FrameDown, FrameGroup} {
			message := NewMsgContext(frameTestID, 1)
			body := make([]byte, 64)
			n, err := all.Seal(d, message, nil, nil, make([]byte, 4), body)
			if err != nil {
				t.Fatal(err)
			}
			out, plain := sentinels(64), sentinels(64)
			window := NewReplayWindow(5, 1)

			// Act
			sealed, sealErr := none.Seal(d, message, nil, nil, make([]byte, 4), out)
			opened, openErr := none.Open(d, message, nil, body[:n], 0, plain, window, 6)

			// Assert
			if !errors.Is(sealErr, ErrBadValue) || !errors.Is(openErr, ErrBadValue) || sealed != 0 || opened.PlainLength != 0 {
				t.Fatalf("tag %d dir %d: seal %v open %v", tag, d, sealErr, openErr)
			}
			if !untouched(out) || !untouched(plain) || window.Top() != 5 || window.Bits() != 1 {
				t.Fatal("a refusal changed a buffer or the window")
			}
		}
		none.Close()
	}
}

func TestLoadWithNoDirectionStillRefusesABadKeyEpochTagLengthOrDirectionBit(t *testing.T) {
	none := FrameDirectionsNone
	for name, load := range map[string]func() (*FrameSession, error){
		"key 31":    func() (*FrameSession, error) { return LoadFrameSession(frameTestKey[:31], 0, FrameConfig{4, none}) },
		"epoch":     func() (*FrameSession, error) { return LoadFrameSession(frameTestKey, 0x1000000, FrameConfig{4, none}) },
		"tag 5":     func() (*FrameSession, error) { return LoadFrameSession(frameTestKey, 0, FrameConfig{5, none}) },
		"direction": func() (*FrameSession, error) { return LoadFrameSession(frameTestKey, 0, FrameConfig{4, 8}) },
	} {
		if s, err := load(); s != nil || !errors.Is(err, ErrBadValue) {
			t.Fatalf("%s: %v %v", name, s, err)
		}
	}
}

func TestSealRefusalsWriteNothing(t *testing.T) {
	cases := []struct {
		name  string
		dirs  FrameDirections
		tag   int
		d     FrameDirection
		msg   MsgContext
		ad    int
		clear int
		plain int
		out   int
		want  Kind
	}{
		{"kind 16", FrameDirectionsAll, 4, FrameUp, NewMsgContext(frameTestID, 16), 0, 0, 4, 64, BadValue},
		{"kind negative", FrameDirectionsAll, 4, FrameUp, NewMsgContext(frameTestID, -1), 0, 0, 4, 64, BadValue},
		{"zero message", FrameDirectionsAll, 4, FrameUp, MsgContext{}, 0, 0, 4, 64, BadValue},
		{"msg_id of 7 bytes", FrameDirectionsAll, 4, FrameUp, NewMsgContext(frameTestID[:7], 1), 0, 0, 4, 64, BadValue},
		{"msg_id of 9 bytes", FrameDirectionsAll, 4, FrameUp, NewMsgContext(append(bytes.Clone(frameTestID), 0), 1), 0, 0, 4, 64, BadValue},
		{"direction 0", FrameDirectionsAll, 4, 0, NewMsgContext(frameTestID, 1), 0, 0, 4, 64, BadValue},
		{"direction 4", FrameDirectionsAll, 4, 4, NewMsgContext(frameTestID, 1), 0, 0, 4, 64, BadValue},
		{"direction not loaded", FrameDirectionsUp, 4, FrameDown, NewMsgContext(frameTestID, 1), 0, 0, 4, 64, BadValue},
		{"ad 256", FrameDirectionsAll, 4, FrameUp, NewMsgContext(frameTestID, 1), 256, 0, 4, 400, TooLong},
		{"body 256", FrameDirectionsAll, 4, FrameUp, NewMsgContext(frameTestID, 1), 0, 100, 152, 400, TooLong},
		{"body 255 with tag 16", FrameDirectionsAll, 16, FrameUp, NewMsgContext(frameTestID, 1), 0, 0, 240, 400, TooLong},
		{"buffer one short", FrameDirectionsAll, 4, FrameUp, NewMsgContext(frameTestID, 1), 3, 2, 10, 15, BufferFull},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Arrange
			s, err := LoadFrameSession(frameTestKey, 3, FrameConfig{TagLength: c.tag, Directions: c.dirs})
			if err != nil {
				t.Fatal(err)
			}
			defer s.Close()
			out := sentinels(c.out)

			// Act
			n, err := s.Seal(c.d, c.msg, make([]byte, c.ad), make([]byte, c.clear), make([]byte, c.plain), out)

			// Assert
			if frameKindOf(err) != c.want || n != 0 || !untouched(out) {
				t.Fatalf("kind %v err %v n %d untouched %v", frameKindOf(err), err, n, untouched(out))
			}
		})
	}
}

func TestSealOfTheLargestBodyWorksAndTheBufferMayBeExact(t *testing.T) {
	// Arrange
	s := newFrameSession(t, frameTestKey, 3, 16)
	out := make([]byte, 255)

	// Act
	n, err := s.Seal(FrameUp, NewMsgContext(frameTestID, 15), make([]byte, 255), make([]byte, 10), make([]byte, 229), out)
	opened, openErr := s.Open(FrameUp, NewMsgContext(frameTestID, 15), make([]byte, 255), out[:n], 10, make([]byte, 229), nil, 0)

	// Assert
	if err != nil || n != 255 || openErr != nil || opened.PlainLength != 229 {
		t.Fatalf("n %d err %v open %v %+v", n, err, openErr, opened)
	}
}

func TestSealInPlaceGivesTheBytesOfASeparateBuffer(t *testing.T) {
	// Arrange
	s := newFrameSession(t, frameTestKey, 3, 8)
	clear, plain := []byte{1, 2, 3}, []byte("overlap")
	separate := make([]byte, 64)
	want, err := s.Seal(FrameUp, NewMsgContext(frameTestID, 2), frameTestAD, clear, plain, separate)
	if err != nil {
		t.Fatal(err)
	}
	shared := make([]byte, 64)
	copy(shared[10:], plain) // plain overlaps the output, shifted
	copy(shared[:3], clear)

	// Act
	n, err := s.Seal(FrameUp, NewMsgContext(frameTestID, 2), frameTestAD, shared[:3], shared[10:10+len(plain)], shared)

	// Assert
	if err != nil || n != want || !bytes.Equal(shared[:n], separate[:n]) {
		t.Fatalf("n %d err %v\n%x\n%x", n, err, shared[:n], separate[:n])
	}
}

func TestSealIsDeterministicAndLeavesTheSessionAsItWas(t *testing.T) {
	// Arrange
	s := newFrameSession(t, frameTestKey, 3, 8)
	a, b := sealFrame(t, s), sealFrame(t, s)

	// Act
	same := bytes.Equal(a, b)

	// Assert
	if !same {
		t.Fatal("two seals of the same inputs differ")
	}
}

func TestOpenRefusalsLeaveTheBufferAndTheWindowAlone(t *testing.T) {
	// Arrange
	s, err := LoadFrameSession(frameTestKey, 1, FrameConfig{TagLength: 8, Directions: FrameDirectionsUp | FrameDirectionsGroup})
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	body := sealFrame(t, s) // 3 + 12 + 8 = 23 bytes
	id := NewMsgContext(frameTestID, 4)
	cases := []struct {
		name      string
		d         FrameDirection
		msg       MsgContext
		ad        []byte
		body      []byte
		clear     int
		out       int
		want      Kind
		wantMACs  int64
		shortInfo [2]int
	}{
		{"direction not loaded", FrameDown, id, frameTestAD, body, 3, 64, BadValue, 0, [2]int{}},
		{"direction 0", 0, id, frameTestAD, body, 3, 64, BadValue, 0, [2]int{}},
		{"kind 16", FrameUp, NewMsgContext(frameTestID, 16), frameTestAD, body, 3, 64, BadValue, 0, [2]int{}},
		{"zero message", FrameUp, MsgContext{}, frameTestAD, body, 3, 64, BadValue, 0, [2]int{}},
		{"negative clear length", FrameUp, id, frameTestAD, body, -1, 64, BadValue, 0, [2]int{}},
		{"ad 256", FrameUp, id, make([]byte, 256), body, 3, 64, TooLong, 0, [2]int{}},
		{"body 256", FrameUp, id, frameTestAD, make([]byte, 256), 3, 64, TooLong, 0, [2]int{}},
		{"clear length 256", FrameUp, id, frameTestAD, body, 256, 64, TooLong, 0, [2]int{}},
		{"body shorter than clear and tag", FrameUp, id, frameTestAD, body[:10], 3, 64, ShortPacket, 0, [2]int{11, 10}},
		{"empty body", FrameUp, id, frameTestAD, nil, 0, 64, ShortPacket, 0, [2]int{8, 0}},
		{"buffer one short", FrameUp, id, frameTestAD, body, 3, 11, BufferFull, 0, [2]int{}},
		{"tag mismatch", FrameUp, id, frameTestAD, append(bytes.Clone(body[:22]), body[22]^1), 3, 64, TagMismatch, 1, [2]int{}},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			out := sentinels(c.out)
			window := NewReplayWindow(50, 0b1011)
			before := s.macs.Load()

			// Act
			opened, err := s.Open(c.d, c.msg, c.ad, c.body, c.clear, out, window, 51)

			// Assert
			if frameKindOf(err) != c.want {
				t.Fatalf("kind %v: %v", frameKindOf(err), err)
			}
			if !untouched(out) || window.Top() != 50 || window.Bits() != 0b1011 || opened != (FrameOpened{}) {
				t.Fatal("a refusal changed the buffer, the window or the result")
			}
			if got := s.macs.Load() - before; got != c.wantMACs {
				t.Fatalf("%d MACs computed, want %d", got, c.wantMACs)
			}
			var e *Error
			if c.want == ShortPacket && errors.As(err, &e) && (e.Needed != c.shortInfo[0] || e.Left != c.shortInfo[1]) {
				t.Fatalf("needed %d left %d", e.Needed, e.Left)
			}
		})
	}
}

func TestOpenDoesNotModifyTheCallersBody(t *testing.T) {
	// Arrange
	s := newFrameSession(t, frameTestKey, 1, 8)
	body := sealFrame(t, s)
	out := make([]byte, 64)

	// Act
	opened, err := openFrame(s, body, out, nil, 0)

	// Assert
	if err != nil || opened.PlainLength != 12 || !bytes.Equal(body, sealFrame(t, s)) {
		t.Fatalf("err %v", err)
	}
}

func TestAClosedSessionHasZeroedKeysAndRefusesEveryCall(t *testing.T) {
	// Arrange
	s, err := LoadFrameSession(frameTestKey, 9, FrameConfig{TagLength: 8, Directions: FrameDirectionsAll})
	if err != nil {
		t.Fatal(err)
	}
	if err := s.SetPrevious(frameTestKey, 8); err != nil {
		t.Fatal(err)
	}
	arrays := append(s.current.arrays(), s.previous.arrays()...)
	message := NewMsgContext(frameTestID, 1)
	body := make([]byte, 32)
	if _, err := s.Seal(FrameUp, message, nil, nil, make([]byte, 4), body); err != nil {
		t.Fatal(err)
	}
	nonZero := 0
	for _, a := range arrays {
		if !allZero(a) {
			nonZero++
		}
	}

	// Act
	s.Close()
	out, plain := sentinels(32), sentinels(32)
	n, sealErr := s.Seal(FrameUp, message, nil, nil, make([]byte, 4), out)
	_, openErr := s.Open(FrameUp, message, nil, body, 0, plain, nil, 0)
	setErr := s.SetPrevious(frameTestKey, 1)
	s.ClearPrevious()
	s.Close()

	// Assert
	if len(arrays) != 12 || nonZero != 12 {
		t.Fatalf("%d key slices, %d non-zero before Close; want 12 and 12", len(arrays), nonZero)
	}
	for _, a := range arrays {
		if !allZero(a) {
			t.Fatal("a key slice was not overwritten")
		}
	}
	if !errors.Is(sealErr, ErrBadValue) || !errors.Is(openErr, ErrBadValue) || !errors.Is(setErr, ErrBadValue) || n != 0 {
		t.Fatalf("seal %v open %v set %v", sealErr, openErr, setErr)
	}
	if !untouched(out) || !untouched(plain) {
		t.Fatal("a closed session wrote bytes")
	}
}

func allZero(b []byte) bool {
	for _, v := range b {
		if v != 0 {
			return false
		}
	}
	return true
}

func TestSetPreviousRefusesWhatItCannotUseAndKeepsTheOldSlot(t *testing.T) {
	// Arrange
	s := newFrameSession(t, frameTestKey, 2, 8)
	if err := s.SetPrevious(frameTestOtherKey, 1); err != nil {
		t.Fatal(err)
	}
	old := s.previous

	// Act
	short := s.SetPrevious(frameTestOtherKey[:31], 1)
	epoch := s.SetPrevious(frameTestOtherKey, 0x1000000)

	// Assert
	if !errors.Is(short, ErrBadValue) || !errors.Is(epoch, ErrBadValue) || s.previous != old {
		t.Fatalf("short %v epoch %v", short, epoch)
	}
}

func TestReplacingThePreviousSlotZeroesTheOldOne(t *testing.T) {
	// Arrange
	s, err := LoadFrameSession(frameTestKey, 9, FrameConfig{TagLength: 4, Directions: FrameDirectionsUp})
	if err != nil {
		t.Fatal(err)
	}
	defer s.Close()
	if err := s.SetPrevious(frameTestKey, 1); err != nil {
		t.Fatal(err)
	}
	old := s.previous.arrays()

	// Act
	err = s.SetPrevious(frameTestKey, 2)

	// Assert
	if err != nil || len(old) != 2 {
		t.Fatalf("err %v, %d slices", err, len(old))
	}
	for _, a := range old {
		if !allZero(a) {
			t.Fatal("the replaced key was not overwritten")
		}
	}
	for _, a := range s.previous.arrays() {
		if allZero(a) {
			t.Fatal("the new key is zero")
		}
	}
}

func TestClearPreviousZeroesTheSlot(t *testing.T) {
	// Arrange
	s := newFrameSession(t, frameTestKey, 9, 4)
	if err := s.SetPrevious(frameTestKey, 1); err != nil {
		t.Fatal(err)
	}
	old := s.previous.arrays()

	// Act
	s.ClearPrevious()

	// Assert
	if s.previous != nil || len(old) != 6 {
		t.Fatalf("previous %v, %d slices", s.previous, len(old))
	}
	for _, a := range old {
		if !allZero(a) {
			t.Fatal("the cleared key was not overwritten")
		}
	}
}

func TestMsgContextCopiesTheIdAndZeroIsInvalid(t *testing.T) {
	// Arrange
	id := bytes.Clone(frameTestID)
	m := NewMsgContext(id, 3)
	id[0] = 99

	// Act
	s := newFrameSession(t, frameTestKey, 1, 4)
	a, errA := s.Seal(FrameUp, m, nil, nil, []byte{1}, make([]byte, 16))
	b, errB := s.Seal(FrameUp, NewMsgContext(frameTestID, 3), nil, nil, []byte{1}, make([]byte, 16))

	// Assert
	if errA != nil || errB != nil || a != b || m.Kind() != 3 {
		t.Fatalf("%v %v", errA, errB)
	}
	if (MsgContext{}).Kind() != 0 {
		t.Fatal("zero kind")
	}
}

func TestMacOnlyRefusals(t *testing.T) {
	// Arrange
	long33 := bytes.Repeat([]byte{1}, 33)
	cases := []struct {
		name  string
		key   []byte
		epoch uint32
		label []byte
		ok    bool
	}{
		{"label 1", frameTestKey, 1, []byte{'a'}, true},
		{"label 32", frameTestKey, 1, long33[:32], true},
		{"label 0", frameTestKey, 1, nil, false},
		{"label 33", frameTestKey, 1, long33, false},
		{"epoch above", frameTestKey, 0x1000000, []byte("net"), false},
		{"largest epoch", frameTestKey, 0xFFFFFF, []byte("net"), true},
		{"key 31", frameTestKey[:31], 1, []byte("net"), false},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Act
			m, err := DeriveMacKey(c.key, c.epoch, c.label)

			// Assert
			if c.ok != (err == nil) || c.ok != (m != nil) || (!c.ok && !errors.Is(err, ErrBadValue)) {
				t.Fatalf("err %v", err)
			}
			if m != nil {
				m.Close()
			}
		})
	}
}

func TestMacOnlyTagLengthsAndSplitsAndAClosedKey(t *testing.T) {
	// Arrange
	m, err := DeriveMacKey(frameTestKey, 7, []byte("net"))
	if err != nil {
		t.Fatal(err)
	}
	message := bytes.Repeat([]byte{0xAB}, 119)
	whole := make([]byte, 32)
	if err := m.Tag(whole, message); err != nil {
		t.Fatal(err)
	}

	// Act
	var refused []int
	for _, n := range []int{0, 1, 2, 3, 5, 7, 9, 17, 33} {
		out := sentinels(n)
		if err := m.Tag(out, message); !errors.Is(err, ErrBadValue) || !untouched(out) {
			refused = append(refused, n)
		}
		probe := make([]byte, n)
		copy(probe, whole)
		if m.Verify(probe, message) {
			refused = append(refused, -n)
		}
	}
	split := make([]byte, 32)
	splitErr := m.Tag(split, message[:5], nil, message[5:60], message[60:])
	prefix := make([]byte, 8)
	prefixErr := m.Tag(prefix, message)
	m.Close()
	after := sentinels(4)
	closedErr := m.Tag(after, message)

	// Assert
	if len(refused) != 0 {
		t.Fatalf("lengths accepted or untouched wrongly: %v", refused)
	}
	if splitErr != nil || !bytes.Equal(split, whole) {
		t.Fatalf("a split message gives another tag: %v", splitErr)
	}
	if prefixErr != nil || !bytes.Equal(prefix, whole[:8]) {
		t.Fatal("a shorter tag is not the prefix of the longer")
	}
	if !errors.Is(closedErr, ErrBadValue) || !untouched(after) || m.Verify(whole[:4], message) {
		t.Fatalf("a closed key works: %v", closedErr)
	}
	for _, v := range m.key {
		if v != 0 {
			t.Fatal("the key was not overwritten")
		}
	}
}
