package packbin

import (
	"bytes"
	"crypto/hmac"
	"crypto/sha256"
	"errors"
	"testing"
)

// AZ-3293: what the MAC-only call refuses, split from frame_refusals_test.go to stay under 500 lines.

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

func TestAZeroValueMacKeyRefusesTagAndVerify(t *testing.T) {
	// Arrange
	var m MacKey
	keyless := hmac.New(sha256.New, nil)
	keyless.Write([]byte("x"))
	keylessTag := keyless.Sum(nil)[:4]
	out := sentinels(4)

	// Act
	tagErr := m.Tag(out, []byte("x"))
	verified := m.Verify(keylessTag, []byte("x"))

	// Assert
	if !errors.Is(tagErr, ErrBadValue) || !untouched(out) {
		t.Fatalf("Tag of a zero MacKey: err %v, untouched %v", tagErr, untouched(out))
	}
	if verified {
		t.Fatal("a zero MacKey accepted the keyless tag")
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
