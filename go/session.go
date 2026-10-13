package packbin

import (
	"crypto/hkdf"
	"crypto/rand"
	"crypto/sha256"
	"encoding/binary"
	"errors"
	"fmt"

	"golang.org/x/crypto/chacha20"
)

const (
	// SeedSize is the length of the seed LoadSession takes.
	SeedSize = 32
	// NonceSize is the length of the value the opener sends once and the waiter joins with.
	NonceSize = 16
)

// maxPadBytes is 2^32 blocks of 64 bytes: what one nonce's stream holds.
const maxPadBytes = 1 << 38

// sessionInfo is the HKDF info of the contract: the ASCII bytes "packbin".
const sessionInfo = "packbin"

// PackSession is one optional encrypted connection beside clear Pack and Unpack (contract
// _docs/02_document/contracts/library/pack-session.md v1.0.0). The opener calls Start and sends the
// 16 bytes once; the waiter calls Join with them. A payload keeps the length of the clear packet.
// There is no tag: a flipped bit is not detected.
//
// A PackSession is for one goroutine at a time: Pack and Unpack advance a counter.
type PackSession struct {
	seed      []byte
	send      []byte
	recv      []byte
	sendCount uint64
	recvCount uint64
}

// LoadSession keeps a copy of the 32-byte seed until Start or Join. A seed of any other length makes
// no session and returns an *Error of kind BadValue. The caller's slice is not changed.
func LoadSession(seed []byte) (*PackSession, error) {
	if len(seed) != SeedSize {
		return nil, sessionErr("the seed is %d bytes, not %d", len(seed), SeedSize)
	}
	return &PackSession{seed: append([]byte(nil), seed...)}, nil
}

// Start opens the session as the opener with 16 bytes drawn from crypto/rand, and returns them: send
// them to the waiter once, in the clear. It fails (an *Error of kind BadValue) when the session is
// already open.
func (s *PackSession) Start() ([]byte, error) {
	if err := s.canOpen(); err != nil {
		return nil, err
	}
	nonce := make([]byte, NonceSize)
	if _, err := rand.Read(nonce); err != nil {
		return nil, sessionErr("no random bytes for the session value: %v", err)
	}
	if err := s.open(nonce, true); err != nil {
		return nil, err
	}
	return nonce, nil
}

// StartWith opens the session as the opener with 16 bytes the caller already has, and returns a copy
// of them. A length other than 16 opens nothing and leaves the seed in place. It is for tests and for a
// caller that draws the value from a cryptographic source itself: the value must be fresh and unique for
// every connection of one seed. Two sessions of one seed that start with the same value share their
// keystream, and because there is no tag the XOR of two payloads is then the XOR of their packets.
func (s *PackSession) StartWith(nonce []byte) ([]byte, error) {
	if err := s.open(nonce, true); err != nil {
		return nil, err
	}
	return append([]byte(nil), nonce...), nil
}

// Join opens the session as the waiter with the 16 bytes the opener sent. A length other than 16
// joins nothing and leaves the seed in place.
func (s *PackSession) Join(nonce []byte) error {
	return s.open(nonce, false)
}

// Pack packs row with scheme s as Pack does, then pads the bytes with the next position of this
// session's send direction. Before Start or Join, or when the row is refused, it returns nil bytes and
// an *Error and the position does not advance.
func (s *PackSession) Pack(sc *Scheme, row any) ([]byte, error) {
	if s == nil || s.send == nil {
		return nil, &Error{Kind: PackRefused, Field: NoField, Reason: "the session is not open: call Start or Join first"}
	}
	plain, err := Pack(sc, row)
	if err != nil {
		return nil, err
	}
	if err := pad(s.send, s.sendCount, plain); err != nil {
		return nil, err
	}
	s.sendCount++
	return plain, nil
}

// Unpack removes the pad of the next position of the receive direction from a copy of payload and
// reads it as Unpack does, so a payload that cannot be read returns the *Error clear Unpack returns.
// The position advances for every payload, readable or not; the caller's slice is not changed. Before
// Join or Start it returns an *Error of kind ShortPacket (needed 1, left 0), and a call with a nil or
// repeated scheme, or none, returns an *Error of kind InvalidScheme without using a position.
func (s *PackSession) Unpack(payload []byte, schemes ...*Scheme) (any, error) {
	plain, err := s.receive(payload, schemes)
	if err != nil {
		return nil, err
	}
	return Unpack(plain, schemes...)
}

// UnpackMap is Unpack with the row as a map keyed by field name, as UnpackMap gives it.
func (s *PackSession) UnpackMap(payload []byte, schemes ...*Scheme) (map[string]any, error) {
	plain, err := s.receive(payload, schemes)
	if err != nil {
		return nil, err
	}
	return UnpackMap(plain, schemes...)
}

// receive is a copy of payload with the receive pad removed and the position advanced.
func (s *PackSession) receive(payload []byte, schemes []*Scheme) ([]byte, error) {
	if s == nil || s.recv == nil {
		return nil, shortErr(NoField, "", 1, 0)
	}
	// An unusable scheme list is the caller's mistake, not the packet's: no position is spent on it.
	var bad *Error
	if _, _, err := dispatch(nil, schemes); errors.As(err, &bad) && bad.Kind == InvalidScheme {
		return nil, bad
	}
	plain := append([]byte(nil), payload...)
	if err := pad(s.recv, s.recvCount, plain); err != nil {
		return nil, err
	}
	s.recvCount++
	return plain, nil
}

func (s *PackSession) canOpen() error {
	if s == nil {
		return sessionErr("the session is nil")
	}
	if s.send != nil {
		return sessionErr("the session is already open")
	}
	if s.seed == nil {
		return sessionErr("the session has no seed")
	}
	return nil
}

// open derives both directions from the seed and the 16 bytes, then wipes the seed. The opener sends
// with the first 32 bytes and receives with the second 32; the waiter swaps them.
func (s *PackSession) open(nonce []byte, opener bool) error {
	if err := s.canOpen(); err != nil {
		return err
	}
	if len(nonce) != NonceSize {
		return sessionErr("the session value is %d bytes, not %d", len(nonce), NonceSize)
	}
	both, err := hkdf.Key(sha256.New, s.seed, nonce, sessionInfo, 2*SeedSize)
	if err != nil {
		return sessionErr("key derivation failed: %v", err)
	}
	first := append([]byte(nil), both[:SeedSize]...)
	second := append([]byte(nil), both[SeedSize:]...)
	clear(both)
	if opener {
		s.send, s.recv = first, second
	} else {
		s.send, s.recv = second, first
	}
	clear(s.seed)
	s.seed = nil
	return nil
}

// pad XORs data with the ChaCha20 (RFC 8439) stream of key: the 12-byte nonce is the packet position
// as a little-endian integer, the block counter starts at 0.
func pad(key []byte, position uint64, data []byte) error {
	// The 32-bit block counter of ChaCha20 covers 256 GiB; a longer packet is refused, not panicked on.
	if uint64(len(data)) > maxPadBytes {
		return sessionErr("a packet of %d bytes is longer than one ChaCha20 stream", len(data))
	}
	var nonce [12]byte
	binary.LittleEndian.PutUint64(nonce[:], position)
	c, err := chacha20.NewUnauthenticatedCipher(key, nonce[:])
	if err != nil {
		return sessionErr("cipher failed: %v", err)
	}
	c.XORKeyStream(data, data)
	return nil
}

func sessionErr(format string, args ...any) *Error {
	return &Error{Kind: BadValue, Field: NoField, Reason: "session: " + fmt.Sprintf(format, args...)}
}
