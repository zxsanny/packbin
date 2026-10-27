package packbin

import (
	"crypto/hmac"
	"crypto/sha256"
	"crypto/subtle"
	"runtime"
)

// The helpers of frame mode over the verified primitives of crypto.go (HKDF and ChaCha20) and the standard
// library's HMAC.

const (
	frameMaxEpoch = 0xFFFFFF
	frameHashSize = sha256.Size
)

// frameSaltLabel is the first part of every HKDF salt of frame mode.
const frameSaltLabel = "packbin-frame"

// frameSalt is "packbin-frame" followed by the epoch as a 32-bit little-endian integer (17 bytes).
func frameSalt(epoch uint32) []byte {
	salt := make([]byte, 0, len(frameSaltLabel)+4)
	salt = append(salt, frameSaltLabel...)
	return append(salt, byte(epoch), byte(epoch>>8), byte(epoch>>16), byte(epoch>>24))
}

// hmacParts is HMAC-SHA256 of the parts in order, hashed piece by piece with no joined copy.
func hmacParts(key []byte, parts ...[]byte) [frameHashSize]byte {
	mac := hmac.New(sha256.New, key)
	for _, part := range parts {
		mac.Write(part)
	}
	var full [frameHashSize]byte
	mac.Sum(full[:0])
	return full
}

// tagsEqual compares every byte of both slices with no early exit and no secret-dependent branch: it is
// crypto/subtle.ConstantTimeCompare, the standard library's documented constant-time compare, whose result is
// 0 for slices of different lengths (the length of a tag is public: it is fixed per key).
func tagsEqual(left, right []byte) bool {
	return subtle.ConstantTimeCompare(left, right) == 1
}

// wipe overwrites b with zeros. Best effort: Go promises nothing about copies the runtime, the garbage collector
// or the standard library's hash states made, and KeepAlive only keeps the write from being dropped as dead.
func wipe(b []byte) {
	clear(b)
	runtime.KeepAlive(b)
}
