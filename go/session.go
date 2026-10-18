package packbin

import (
	"crypto/hkdf"
	"crypto/rand"
	"crypto/sha256"
	"encoding/binary"
	"fmt"
	"sync"

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
// A PackSession is safe for concurrent use: Pack, Unpack and UnpackMap take a lock only to pad and
// advance the counter of their direction. Payloads are numbered in the order the Pack calls take that
// lock, so the receiver must Unpack them in that order: concurrent senders serialise their sending in
// the same order, or send the position themselves.
type PackSession struct {
	mu        sync.Mutex
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
	if s == nil {
		return nil, sessionErr("the session is nil")
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
// an *Error and the position does not advance. A scheme with parity bytes (WithParity) has them appended
// after the pad, so the payload is the clear packet plus their count and the parity covers the padded
// bytes.
func (s *PackSession) Pack(sc *Scheme, row any) ([]byte, error) {
	if !s.isOpen() {
		return nil, &Error{Kind: PackRefused, Field: NoField, Reason: "the session is not open: call Start or Join first"}
	}
	plain, err := packClear(sc, row)
	if err != nil {
		return nil, err
	}
	if err := checkRoom(len(plain), sc.parity); err != nil {
		return nil, err
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	if err := pad(s.send, s.sendCount, plain); err != nil {
		return nil, err
	}
	s.sendCount++
	return protect(plain, sc.parity)
}

// isOpen is true once the session is open.
func (s *PackSession) isOpen() bool {
	if s == nil {
		return false
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	return s.send != nil
}

// Unpack removes the pad of the next position of the receive direction from a copy of payload and
// reads it as Unpack does, so a payload that cannot be read returns the *Error clear Unpack returns.
// The position advances for every payload, readable or not; the caller's slice is not changed. Before
// Join or Start it returns an *Error of kind ShortPacket (needed 1, left 0), and a call with a nil or
// repeated scheme, or none, returns an *Error of kind InvalidScheme without using a position.
func (s *PackSession) Unpack(payload []byte, schemes ...*Scheme) (any, error) {
	row, _, err := s.UnpackRepair(payload, 0, schemes...)
	return row, err
}

// UnpackRepair is Unpack with the correction limit and the repaired count of UnpackRepair: the payload
// is repaired before the pad is removed, because the parity covers the padded bytes. A limit outside
// 0..n/2 returns an *Error of kind InvalidScheme without using a position; a payload that is refused as
// Uncorrectable uses one.
func (s *PackSession) UnpackRepair(payload []byte, limit int, schemes ...*Scheme) (any, int, error) {
	plain, repaired, err := s.receive(payload, limit, schemes)
	if err != nil {
		return nil, 0, err
	}
	match, r, err := readPacket(plain, schemes)
	if err != nil {
		return nil, 0, err
	}
	return rowOf(match, r), repaired, nil
}

// UnpackMap is Unpack with the row as a map keyed by field name, as UnpackMap gives it.
func (s *PackSession) UnpackMap(payload []byte, schemes ...*Scheme) (map[string]any, error) {
	row, _, err := s.UnpackMapRepair(payload, 0, schemes...)
	return row, err
}

// UnpackMapRepair is UnpackRepair with the row as a map, as UnpackMap gives it.
func (s *PackSession) UnpackMapRepair(payload []byte, limit int, schemes ...*Scheme) (map[string]any, int, error) {
	plain, repaired, err := s.receive(payload, limit, schemes)
	if err != nil {
		return nil, 0, err
	}
	_, r, err := readPacket(plain, schemes)
	if err != nil {
		return nil, 0, err
	}
	return r.values, repaired, nil
}

// receive is the clear packet of a payload: a copy repaired and with its parity dropped, the receive pad
// removed and the position advanced, and the count of bytes repaired.
func (s *PackSession) receive(payload []byte, limit int, schemes []*Scheme) ([]byte, int, error) {
	if !s.isOpen() {
		return nil, 0, shortErr(NoField, "", 1, 0)
	}
	// An unusable scheme list or limit is the caller's mistake, not the packet's: no position is spent on it.
	n, err := checkSchemes(schemes)
	if err != nil {
		return nil, 0, err
	}
	if err := checkLimit(limit, n); err != nil {
		return nil, 0, err
	}
	fixed, repaired, repairErr := repair(payload, n, limit)
	s.mu.Lock()
	defer s.mu.Unlock()
	if repairErr != nil {
		s.recvCount++
		return nil, 0, repairErr
	}
	plain := append([]byte(nil), fixed...)
	if err := pad(s.recv, s.recvCount, plain); err != nil {
		return nil, 0, err
	}
	s.recvCount++
	return plain, repaired, nil
}

// canOpen is called with the lock held.
func (s *PackSession) canOpen() error {
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
	if s == nil {
		return sessionErr("the session is nil")
	}
	s.mu.Lock()
	defer s.mu.Unlock()
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
