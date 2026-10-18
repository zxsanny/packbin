package packbin

import (
	"math/rand/v2"
	"os"
	"strings"
	"testing"
)

// The message ECC tests (AZ-2685; contract message-ecc 1.0.0) share these helpers: the position fixture as
// a scheme with parity bytes, the rows of fixtures/ecc/vectors.txt, and seeded corruption.

type eccRow struct {
	kind string
	id   string
	cols []string
}

// eccRows are the rows of fixtures/ecc/vectors.txt (row syntax at the top of that file).
func eccRows(t testing.TB) []eccRow {
	t.Helper()
	raw, err := os.ReadFile("../fixtures/ecc/vectors.txt")
	if err != nil {
		t.Fatalf("read vectors.txt: %v", err)
	}
	var out []eccRow
	for _, line := range strings.Split(string(raw), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		f := strings.Fields(line)
		out = append(out, eccRow{kind: f[0], id: f[1], cols: f[2:]})
	}
	return out
}

func eccRowsOf(t testing.TB, kind string) []eccRow {
	t.Helper()
	var out []eccRow
	for _, r := range eccRows(t) {
		if r.kind == kind {
			out = append(out, r)
		}
	}
	if len(out) == 0 {
		t.Fatalf("vectors.txt has no %s rows", kind)
	}
	return out
}

// bytesOfHex is the bytes of a vector column: "-" is the empty buffer.
func bytesOfHex(t testing.TB, col string) []byte {
	t.Helper()
	if col == "-" {
		return []byte{}
	}
	return mustHex(t, col)
}

func atoi(t testing.TB, s string) int {
	t.Helper()
	n := 0
	for _, c := range s {
		if c < '0' || c > '9' {
			t.Fatalf("not a number: %q", s)
		}
		n = n*10 + int(c-'0')
	}
	return n
}

// withParity is s declaring n parity bytes.
func withParity(t testing.TB, s *Scheme, n int) *Scheme {
	t.Helper()
	p, err := s.WithParity(n)
	if err != nil {
		t.Fatalf("WithParity(%d): %v", n, err)
	}
	return p
}

// positionParity is the position fixture as a scheme with n parity bytes.
func positionParity(t testing.TB, n int) *Scheme { return withParity(t, positionMapScheme(t), n) }

// readPosition unpacks message with the position scheme of n parity bytes and the correction limit.
func readPosition(t testing.TB, message []byte, n, limit int) (map[string]any, int, error) {
	t.Helper()
	return UnpackMapRepair(message, limit, positionParity(t, n))
}

// isPosition is true when row is the position fixture row.
func isPosition(row map[string]any) bool { return row != nil && goldenFieldMismatches(row) == 0 }

func newRand(seed uint64) *rand.Rand { return rand.New(rand.NewPCG(seed, seed^0x9e3779b97f4a7c15)) }

// corrupt is a copy of message with the byte at each position XORed by the matching non-zero value.
func corrupt(message []byte, positions []int, values []byte) []byte {
	out := append([]byte(nil), message...)
	for i, p := range positions {
		out[p] ^= values[i]
	}
	return out
}

// pickWrong is count distinct positions below size and as many non-zero XOR values.
func pickWrong(rng *rand.Rand, size, count int) ([]int, []byte) {
	positions := make([]int, 0, count)
	for len(positions) < count {
		p := rng.IntN(size)
		dup := false
		for _, q := range positions {
			dup = dup || q == p
		}
		if !dup {
			positions = append(positions, p)
		}
	}
	values := make([]byte, count)
	for i := range values {
		values[i] = byte(1 + rng.IntN(255))
	}
	return positions, values
}

// packedPosition is the position fixture packed with n parity bytes.
func packedPosition(t testing.TB, n int) []byte {
	t.Helper()
	message, err := Pack(positionParity(t, n), goldenMap())
	if err != nil {
		t.Fatalf("Pack: %v", err)
	}
	return message
}
