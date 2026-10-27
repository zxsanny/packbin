package packbin

import (
	"sync"
	"sync/atomic"
)

// Sizes of frame mode.
const (
	// FrameKeySize is the length of the key a session or a MacKey is derived from.
	FrameKeySize = 32
	// FrameMaxBody is the longest frame body (clear part, ciphertext and tag), the longest associated data, and the
	// longest clear part.
	FrameMaxBody = 255
)

// FrameSession is frame mode of the session (pack-session.md 3.0.0): sealed, authenticated frames for links that
// lose, reorder and duplicate messages. A frame body is clear || ciphertext || tag: ChaCha20 under a key per
// (key, epoch, direction), a nonce built from the caller's msg_id, the kind, the direction and the epoch, and a tag
// that is the first 4, 8 or 16 bytes of HMAC-SHA256 over the nonce, the associated data, the clear part and the
// ciphertext. It is the only session of the package (ADR-009).
//
// Seal is deterministic and safe to call from any number of goroutines, and so is Open (the ReplayWindow it
// updates is the caller's and is not safe for concurrent use). SetPrevious, ClearPrevious and Close take the
// session's lock for writing: they wait for the calls in flight and later calls see the new state, so the contract's
// rule (call them while no seal or open runs) holds without the caller's help.
//
// Limits of the runtime: Close overwrites the key slices this object owns, but Go does not promise that. The
// standard library's HKDF and HMAC keep their own copies of a key in hash states the library cannot reach, the
// garbage collector and the stack growth may copy a slice before it is overwritten, and the compiler is free to
// drop a write it sees as dead (the wipe keeps the slice alive to prevent that). The wipe and the constant-time tag
// compare (crypto/subtle) are best effort. A FrameSession must come from LoadFrameSession.
type FrameSession struct {
	tagLength  int
	directions FrameDirections
	epoch      uint32

	mu       sync.RWMutex
	current  *frameKeys
	previous *frameKeys
	closed   bool

	// macs counts the HMAC computations seal and open ran (test access: a refusal before the tag computes none).
	macs atomic.Int64
}

// LoadFrameSession derives the keys of each loaded direction from a 32-byte key and an epoch of at most 0xFFFFFF.
// A key that is not 32 bytes, an epoch above 0xFFFFFF, a tag length that is not 4, 8 or 16, or a direction bit
// outside FrameDirectionsAll is a BadValue. With FrameDirectionsNone it returns a session that refuses every Seal
// and Open as a BadValue.
func LoadFrameSession(key []byte, epoch uint32, config FrameConfig) (*FrameSession, error) {
	if len(key) != FrameKeySize {
		return nil, frameBad("the key is %d bytes, not %d", len(key), FrameKeySize)
	}
	if epoch > frameMaxEpoch {
		return nil, frameBad("the epoch %d is above 0xFFFFFF", epoch)
	}
	if t := config.TagLength; t != 4 && t != 8 && t != 16 {
		return nil, frameBad("the tag length %d is not 4, 8 or 16", t)
	}
	if config.Directions&^FrameDirectionsAll != 0 {
		return nil, frameBad("the directions %d name a direction outside up, down and group", config.Directions)
	}
	keys, err := deriveFrameKeys(key, epoch, config.Directions)
	if err != nil {
		return nil, err
	}
	return &FrameSession{tagLength: config.TagLength, directions: config.Directions, epoch: epoch, current: keys}, nil
}

// TagLength is the tag length the session was loaded with.
func (s *FrameSession) TagLength() int { return s.tagLength }

// Epoch is the epoch of the key the session was loaded with.
func (s *FrameSession) Epoch() uint32 { return s.epoch }

// SetPrevious keeps a previous (key, epoch) that Open tries when the current key's tag does not match: the key just
// replaced, for frames sealed before the change. Seal never uses it. A key that is not 32 bytes, an epoch above
// 0xFFFFFF or a closed session is a BadValue. A frame that opens under it commits into the same replay window, so
// keep it only for the changeover and call ClearPrevious when that ends. A key already set is overwritten.
func (s *FrameSession) SetPrevious(key []byte, epoch uint32) error {
	if len(key) != FrameKeySize {
		return frameBad("the previous key is %d bytes, not %d", len(key), FrameKeySize)
	}
	if epoch > frameMaxEpoch {
		return frameBad("the previous epoch %d is above 0xFFFFFF", epoch)
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.closed {
		return frameBad("the session is closed")
	}
	keys, err := deriveFrameKeys(key, epoch, s.directions)
	if err != nil {
		return err
	}
	replaced := s.previous
	s.previous = keys
	replaced.wipe()
	return nil
}

// ClearPrevious drops the previous (key, epoch) and overwrites its keys.
func (s *FrameSession) ClearPrevious() {
	s.mu.Lock()
	defer s.mu.Unlock()
	replaced := s.previous
	s.previous = nil
	replaced.wipe()
}

// Close overwrites the keys of both slots (best effort, see the type's limits). Every later call is refused as a
// BadValue. Closing twice is allowed.
func (s *FrameSession) Close() {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.closed = true
	s.current.wipe()
	s.previous.wipe()
}

// Seal writes clear || ciphertext || tag for plain into out and returns the body length. The same inputs give the
// same bytes; the session does not change and the previous key is not used. A direction not loaded, a kind above
// 15, a MsgContext without an 8-byte id or a closed session is a BadValue; ad above 255 bytes, or
// len(clear)+len(plain)+tag above 255, is TooLong; an out shorter than the body is BufferFull. On any refusal
// nothing is written. The body is built apart and copied to out last, so ad, clear and plain may overlap out
// (sealing in place gives the same bytes).
//
// **For one (key, epoch, direction), never seal two different messages with the same msg_id.** Reuse breaks the
// confidentiality of both messages, and the library cannot check it (see MsgContext). A new epoch derives new keys
// and nonces.
func (s *FrameSession) Seal(direction FrameDirection, message MsgContext, ad, clearPart, plain, out []byte) (int, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if err := s.allowed(direction, message); err != nil {
		return 0, err
	}
	if len(ad) > FrameMaxBody {
		return 0, frameTooLong("the associated data", len(ad))
	}
	length := len(clearPart) + len(plain) + s.tagLength
	if length > FrameMaxBody {
		return 0, frameTooLong("the body", length)
	}
	if len(out) < length {
		return 0, &Error{Kind: BufferFull, Field: NoField, Needed: length}
	}

	keys := s.current
	nonce := frameNonce(message, direction, keys.epoch)
	// ad, clear and plain are read in full before the one write to out, so any overlap with it gives the same body.
	var buffer [FrameMaxBody]byte
	body := buffer[:length]
	copy(body, clearPart)
	cipher := body[len(clearPart) : len(clearPart)+len(plain)]
	text, err := chacha20XOR(keys.enc[direction-1], nonce[:], 0, plain)
	if err != nil {
		return 0, err
	}
	copy(cipher, text)
	full := s.tag(keys.mac[direction-1], &nonce, ad, body[:len(clearPart)], cipher)
	copy(body[len(clearPart)+len(plain):], full[:s.tagLength])
	wipe(full[:])
	copy(out, body)
	return length, nil
}

// Open opens body (clear || ciphertext || tag, the first clearLength bytes clear) in the contract's order:
// argument checks, the replay window (when given, with the message's counter: Duplicate or TooOld before any
// hashing), the tag with the current key and then once with the previous key (TagMismatch), decryption into plain,
// and only then the window commit. plain and the window are untouched unless the error is nil.
//
// A direction not loaded, a kind above 15, a MsgContext without an 8-byte id, a negative clearLength or a closed
// session is a BadValue; ad, body or clearLength above 255 is TooLong (before any hashing); a body shorter than
// clearLength plus the tag is ShortPacket; a plain shorter than the plaintext is BufferFull. window may be nil.
//
// The counter must come from bytes the tag covers, never from an unauthenticated wire field: it is not part of the
// tag.
func (s *FrameSession) Open(direction FrameDirection, message MsgContext, ad, body []byte, clearLength int,
	plain []byte, window *ReplayWindow, counter uint64) (FrameOpened, error) {
	s.mu.RLock()
	defer s.mu.RUnlock()
	if err := s.allowed(direction, message); err != nil {
		return FrameOpened{}, err
	}
	if clearLength < 0 {
		return FrameOpened{}, frameBad("the clear length %d is negative", clearLength)
	}
	if len(ad) > FrameMaxBody {
		return FrameOpened{}, frameTooLong("the associated data", len(ad))
	}
	if len(body) > FrameMaxBody {
		return FrameOpened{}, frameTooLong("the body", len(body))
	}
	if clearLength > FrameMaxBody {
		return FrameOpened{}, frameTooLong("the clear part", clearLength)
	}
	framing := clearLength + s.tagLength
	if len(body) < framing {
		return FrameOpened{}, &Error{Kind: ShortPacket, Field: NoField, Name: "body", Needed: framing, Left: len(body)}
	}
	plainLength := len(body) - framing
	if len(plain) < plainLength {
		return FrameOpened{}, &Error{Kind: BufferFull, Field: NoField, Needed: plainLength}
	}

	if window != nil {
		switch window.Check(counter) {
		case FreshnessDuplicate:
			return FrameOpened{}, &Error{Kind: Duplicate, Field: NoField}
		case FreshnessTooOld:
			return FrameOpened{}, &Error{Kind: TooOld, Field: NoField}
		}
	}

	// One read of the caller's buffer: the tag is checked and the text decrypted from the same bytes, even when the
	// buffer is a receive ring that changes under us.
	var frame [FrameMaxBody]byte
	copy(frame[:], body)
	clearPart := frame[:clearLength]
	cipher := frame[clearLength : clearLength+plainLength]
	tag := frame[clearLength+plainLength : len(body)]
	keys := s.current
	slot := FrameSlotCurrent
	nonce := frameNonce(message, direction, keys.epoch)
	if !s.matches(keys, direction, &nonce, ad, clearPart, cipher, tag) {
		keys = s.previous
		if keys == nil {
			return FrameOpened{}, &Error{Kind: TagMismatch, Field: NoField}
		}
		nonce = frameNonce(message, direction, keys.epoch)
		if !s.matches(keys, direction, &nonce, ad, clearPart, cipher, tag) {
			return FrameOpened{}, &Error{Kind: TagMismatch, Field: NoField}
		}
		slot = FrameSlotPrevious
	}

	text, err := chacha20XOR(keys.enc[direction-1], nonce[:], 0, cipher)
	if err != nil {
		return FrameOpened{}, err
	}
	copy(plain, text)
	wipe(text)
	if window != nil {
		window.Commit(counter)
	}
	return FrameOpened{Slot: slot, ClearLength: clearLength, PlainLength: plainLength}, nil
}

// allowed refuses a closed session, a message without an id or with a kind above 15, and a direction that is not
// loaded. The caller holds the lock.
func (s *FrameSession) allowed(direction FrameDirection, message MsgContext) error {
	switch {
	case s.closed:
		return frameBad("the session is closed")
	case !message.set:
		return frameBad("the message has no 8-byte msg_id")
	case message.kind < 0 || message.kind > 15:
		return frameBad("the kind %d is not 0 to 15", message.kind)
	case direction < FrameUp || direction > FrameGroup:
		return frameBad("the direction %d is not 1, 2 or 3", direction)
	case s.directions&(1<<(direction-1)) == 0:
		return frameBad("the direction %d was not loaded", direction)
	}
	return nil
}

// frameNonce is msg_id (8) || ((kind << 4) | direction) (1) || epoch as 24 bits (3).
func frameNonce(message MsgContext, direction FrameDirection, epoch uint32) [chachaNonceSize]byte {
	var nonce [chachaNonceSize]byte
	copy(nonce[:], message.id[:])
	nonce[8] = byte(message.kind<<4) | byte(direction)
	nonce[9] = byte(epoch)
	nonce[10] = byte(epoch >> 8)
	nonce[11] = byte(epoch >> 16)
	return nonce
}

// tag is the full HMAC over M = N || len(ad) || ad || len(clear) || clear || ciphertext.
func (s *FrameSession) tag(macKey []byte, nonce *[chachaNonceSize]byte, ad, clearPart, cipher []byte) [frameHashSize]byte {
	s.macs.Add(1)
	adLength := [1]byte{byte(len(ad))}
	clearLength := [1]byte{byte(len(clearPart))}
	return hmacParts(macKey, nonce[:], adLength[:], ad, clearLength[:], clearPart, cipher)
}

func (s *FrameSession) matches(keys *frameKeys, direction FrameDirection, nonce *[chachaNonceSize]byte,
	ad, clearPart, cipher, tag []byte) bool {
	full := s.tag(keys.mac[direction-1], nonce, ad, clearPart, cipher)
	equal := tagsEqual(full[:len(tag)], tag)
	wipe(full[:])
	return equal
}
