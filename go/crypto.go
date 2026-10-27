package packbin

import (
	"crypto/hkdf"
	"crypto/hmac"
	"crypto/sha256"
	"fmt"

	"golang.org/x/crypto/chacha20"
)

// SHA-256, HMAC-SHA256, HKDF-SHA256 (RFC 5869) and ChaCha20 (RFC 8439), kept unexported for the frame mode
// port (ADR-009, owner decision D2). Every function is checked on the rows of fixtures/crypto/vectors.txt
// (crypto_vectors_test.go). SHA-256, HMAC and HKDF come from the standard library, ChaCha20 from
// golang.org/x/crypto, the module's one dependency.

const (
	chachaKeySize   = chacha20.KeySize
	chachaNonceSize = chacha20.NonceSize
	chachaBlockSize = 64
)

func sha256Of(data []byte) [sha256.Size]byte { return sha256.Sum256(data) }

func hmacSHA256(key, data []byte) []byte {
	mac := hmac.New(sha256.New, key)
	mac.Write(data)
	return mac.Sum(nil)
}

// hkdfExtract is the pseudorandom key of RFC 5869 section 2.2; an empty salt is the RFC's 32 zero bytes.
func hkdfExtract(salt, ikm []byte) ([]byte, error) {
	return hkdf.Extract(sha256.New, ikm, salt)
}

// hkdfSHA256 is extract then expand: length bytes, at most 255 blocks of 32 (8160 bytes), else an error.
func hkdfSHA256(ikm, salt, info []byte, length int) ([]byte, error) {
	return hkdf.Key(sha256.New, ikm, salt, string(info), length)
}

// chacha20Block is the 64-byte block of a 32-byte key, a 12-byte nonce and a 32-bit block counter.
func chacha20Block(key, nonce []byte, counter uint32) ([]byte, error) {
	return chacha20XOR(key, nonce, counter, make([]byte, chachaBlockSize))
}

// chacha20XOR is a copy of data XOR the key stream that starts at block counter (it encrypts and decrypts).
// A wrong key or nonce length, or a stream that would pass the last block counter (a wrapped counter would
// repeat key stream), is an error and no bytes, not the panic of the x/crypto cipher.
func chacha20XOR(key, nonce []byte, counter uint32, data []byte) ([]byte, error) {
	if len(key) != chachaKeySize {
		return nil, fmt.Errorf("packbin: ChaCha20 key is %d bytes, not %d", len(key), chachaKeySize)
	}
	if len(nonce) != chachaNonceSize {
		return nil, fmt.Errorf("packbin: ChaCha20 nonce is %d bytes, not %d", len(nonce), chachaNonceSize)
	}
	blocks := (uint64(len(data)) + chachaBlockSize - 1) / chachaBlockSize
	if uint64(counter)+blocks > 1<<32 {
		return nil, fmt.Errorf("packbin: a ChaCha20 stream of %d blocks from counter %d passes the last counter", blocks, counter)
	}
	c, err := chacha20.NewUnauthenticatedCipher(key, nonce)
	if err != nil {
		return nil, fmt.Errorf("packbin: ChaCha20: %w", err)
	}
	c.SetCounter(counter)
	out := make([]byte, len(data))
	c.XORKeyStream(out, data)
	return out, nil
}
