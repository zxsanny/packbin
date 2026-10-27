package packbin

import "sync"

// MacKey is the MAC-only call of frame mode: a tag without encryption, for a per-hop network check and for key
// fingerprints. K_label = HKDF(key, "packbin-frame" || epoch, 0x00 || label) and tag = the first n bytes of
// HMAC(K_label, message), with n of 4, 8, 16 or 32. The message is passed in parts and hashed piece by piece with
// no joined copy; the tag does not depend on how it is split.
//
// A MacKey holds the 32-byte K_label (the standard library's HMAC keeps its own pad states, which it does not
// expose), and Close overwrites it, best effort: the runtime may have copied it. Verification compares every byte
// with no early exit (crypto/subtle). Tag and Verify are safe from any number of goroutines; Close waits for the
// calls in flight. A MacKey must come from DeriveMacKey.
type MacKey struct {
	epoch uint32

	mu     sync.RWMutex
	key    []byte
	closed bool
}

// DeriveMacKey is the key of a label. A key that is not 32 bytes, an epoch above 0xFFFFFF or a label that is not
// 1 to 32 bytes is a BadValue. The leading 0x00 of the HKDF info keeps these keys apart from the frame keys.
func DeriveMacKey(key []byte, epoch uint32, label []byte) (*MacKey, error) {
	if len(key) != FrameKeySize {
		return nil, frameBad("the key is %d bytes, not %d", len(key), FrameKeySize)
	}
	if epoch > frameMaxEpoch {
		return nil, frameBad("the epoch %d is above 0xFFFFFF", epoch)
	}
	if len(label) < 1 || len(label) > 32 {
		return nil, frameBad("the label is %d bytes, not 1 to 32", len(label))
	}
	derived, err := hkdfSHA256(key, frameSalt(epoch), append([]byte{0}, label...), 32)
	if err != nil {
		return nil, err
	}
	return &MacKey{epoch: epoch, key: derived}, nil
}

// Epoch is the epoch the key was derived for.
func (m *MacKey) Epoch() uint32 { return m.epoch }

// Tag writes the first len(tag) bytes of the HMAC of the message (the parts joined, never copied) into tag. A tag
// length other than 4, 8, 16 or 32, or a closed key, is a BadValue and nothing is written.
func (m *MacKey) Tag(tag []byte, parts ...[]byte) error {
	m.mu.RLock()
	defer m.mu.RUnlock()
	if !macTagLengthAllowed(len(tag)) {
		return frameBad("the tag length %d is not 4, 8, 16 or 32", len(tag))
	}
	if m.closed {
		return frameBad("the key is closed")
	}
	full := hmacParts(m.key, parts...)
	copy(tag, full[:len(tag)])
	wipe(full[:])
	return nil
}

// Verify is true when tag (4, 8, 16 or 32 bytes) is the tag of the message. It is false for any other length and
// for a closed key.
func (m *MacKey) Verify(tag []byte, parts ...[]byte) bool {
	m.mu.RLock()
	defer m.mu.RUnlock()
	if !macTagLengthAllowed(len(tag)) || m.closed {
		return false
	}
	full := hmacParts(m.key, parts...)
	equal := tagsEqual(full[:len(tag)], tag)
	wipe(full[:])
	return equal
}

// Close overwrites the key (best effort). Every later call is refused. Closing twice is allowed.
func (m *MacKey) Close() {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.closed = true
	wipe(m.key)
}

func macTagLengthAllowed(length int) bool {
	return length == 4 || length == 8 || length == 16 || length == 32
}
