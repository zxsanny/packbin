package packbin

import (
	"bytes"
	"encoding/hex"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"testing"
)

// AZ-3287 AC-2: every row of fixtures/crypto/vectors.txt (AZ-3201, PB-02; the row syntax is at the top of the
// file) through the unexported crypto helper, and copies of the file with one hex digit changed fail on that
// row only.

const cryptoVectorsPath = "../fixtures/crypto/vectors.txt"

type cryptoRow struct {
	primitive string
	id        string
	fields    map[string]string
}

func (r cryptoRow) bytes(t testing.TB, name string) []byte {
	t.Helper()
	value, ok := r.fields[name]
	if !ok {
		t.Fatalf("%s %s has no %s", r.primitive, r.id, name)
	}
	if value == "-" {
		return []byte{}
	}
	b, err := hex.DecodeString(value)
	if err != nil {
		t.Fatalf("%s %s: %s is not hex: %v", r.primitive, r.id, name, err)
	}
	return b
}

func (r cryptoRow) number(t testing.TB, name string) int {
	t.Helper()
	n, err := strconv.Atoi(r.fields[name])
	if err != nil {
		t.Fatalf("%s %s: %s is not a number: %v", r.primitive, r.id, name, err)
	}
	return n
}

func loadCryptoRows(t testing.TB, path string) []cryptoRow {
	t.Helper()
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatalf("read %s: %v", path, err)
	}
	var rows []cryptoRow
	for _, line := range strings.Split(string(raw), "\n") {
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		parts := strings.Split(line, " ")
		if len(parts) < 3 {
			t.Fatalf("short row %q", line)
		}
		row := cryptoRow{primitive: parts[0], id: parts[1], fields: map[string]string{}}
		for _, pair := range parts[2:] {
			name, value, ok := strings.Cut(pair, "=")
			if !ok {
				t.Fatalf("%s %s: field %q is not name=value", row.primitive, row.id, pair)
			}
			row.fields[name] = value
		}
		rows = append(rows, row)
	}
	return rows
}

// cryptoMismatch is "<primitive> <id>: expected X, got Y" when the helper's answer differs from the row, else "".
func cryptoMismatch(t testing.TB, row cryptoRow) string {
	t.Helper()
	var expected, got string
	switch row.primitive {
	case "sha256":
		var data []byte
		if _, ok := row.fields["msg"]; ok {
			data = row.bytes(t, "msg")
		} else {
			data = bytes.Repeat(row.bytes(t, "byte"), row.number(t, "repeat"))
		}
		digest := sha256Of(data)
		expected, got = row.fields["digest"], hexOf(digest[:])
	case "hmac256":
		mac := hmacSHA256(row.bytes(t, "key"), row.bytes(t, "data"))
		if _, ok := row.fields["truncate"]; ok {
			mac = mac[:row.number(t, "truncate")]
		}
		expected, got = row.fields["mac"], hexOf(mac)
	case "hkdf256":
		ikm, salt := row.bytes(t, "ikm"), row.bytes(t, "salt")
		prk, prkErr := hkdfExtract(salt, ikm)
		okm, okmErr := hkdfSHA256(ikm, salt, row.bytes(t, "info"), row.number(t, "len"))
		if prkErr != nil || okmErr != nil {
			return row.primitive + " " + row.id + ": " + errorText(prkErr) + " " + errorText(okmErr)
		}
		expected = "prk=" + row.fields["prk"] + " okm=" + row.fields["okm"]
		got = "prk=" + hexOf(prk) + " okm=" + hexOf(okm)
	case "chacha-block":
		block, err := chacha20Block(row.bytes(t, "key"), row.bytes(t, "nonce"), uint32(row.number(t, "counter")))
		if err != nil {
			return row.primitive + " " + row.id + ": " + err.Error()
		}
		expected, got = row.fields["block"], hexOf(block)
	case "chacha-xor":
		key, nonce, counter, plain := row.bytes(t, "key"), row.bytes(t, "nonce"), uint32(row.number(t, "counter")), row.bytes(t, "plain")
		cipher, err := chacha20XOR(key, nonce, counter, plain)
		if err != nil {
			return row.primitive + " " + row.id + ": " + err.Error()
		}
		back, err := chacha20XOR(key, nonce, counter, cipher)
		expected, got = row.fields["cipher"], hexOf(cipher)
		if err != nil || !bytes.Equal(back, plain) {
			got += " (decrypt differs)"
		}
	default:
		t.Fatalf("unknown primitive %q (row %s)", row.primitive, row.id)
	}
	if got == expected {
		return ""
	}
	return row.primitive + " " + row.id + ": expected " + expected + ", got " + got
}

func errorText(err error) string {
	if err == nil {
		return "-"
	}
	return err.Error()
}

func TestCryptoVectorsFileHolds27RowsOfTheFivePrimitives(t *testing.T) {
	// Arrange
	want := map[string]int{"sha256": 6, "hmac256": 8, "hkdf256": 3, "chacha-block": 6, "chacha-xor": 4}

	// Act
	rows := loadCryptoRows(t, cryptoVectorsPath)
	counts := map[string]int{}
	for _, row := range rows {
		counts[row.primitive]++
	}

	// Assert
	if len(rows) != 27 || len(counts) != len(want) {
		t.Fatalf("%d rows, counts %v; want 27, %v", len(rows), counts, want)
	}
	for primitive, n := range want {
		if counts[primitive] != n {
			t.Errorf("%s: %d rows, want %d", primitive, counts[primitive], n)
		}
	}
}

func TestCryptoVectorsEveryRowMatches(t *testing.T) {
	for _, row := range loadCryptoRows(t, cryptoVectorsPath) {
		t.Run(row.primitive+" "+row.id, func(t *testing.T) {
			// Act
			problem := cryptoMismatch(t, row)

			// Assert
			if problem != "" {
				t.Fatal(problem)
			}
		})
	}
}

// changedCryptoCopy writes a copy of the vectors with the last hex digit of field changed in the first row
// of primitive, and returns its path and the "<primitive> <id>" of that row.
func changedCryptoCopy(t *testing.T, primitive, field string) (string, string) {
	t.Helper()
	raw, err := os.ReadFile(cryptoVectorsPath)
	if err != nil {
		t.Fatal(err)
	}
	lines := strings.Split(string(raw), "\n")
	for i, line := range lines {
		parts := strings.Split(line, " ")
		if parts[0] != primitive {
			continue
		}
		for k, part := range parts {
			if !strings.HasPrefix(part, field+"=") {
				continue
			}
			last := part[len(part)-1]
			digit := "0"
			if last == '0' {
				digit = "1"
			}
			parts[k] = part[:len(part)-1] + digit
			lines[i] = strings.Join(parts, " ")
			path := filepath.Join(t.TempDir(), "vectors.txt")
			if err := os.WriteFile(path, []byte(strings.Join(lines, "\n")), 0o600); err != nil {
				t.Fatal(err)
			}
			return path, primitive + " " + parts[1]
		}
		t.Fatalf("%s %s has no %s", primitive, parts[1], field)
	}
	t.Fatalf("no %s row", primitive)
	return "", ""
}

func TestCryptoVectorsACopyWithOneHexDigitChangedFailsOnThatRowOnly(t *testing.T) {
	for _, c := range []struct{ primitive, field string }{
		{"sha256", "digest"}, {"hmac256", "mac"}, {"hkdf256", "prk"}, {"hkdf256", "okm"},
		{"chacha-block", "block"}, {"chacha-xor", "cipher"},
	} {
		t.Run(c.primitive+" "+c.field, func(t *testing.T) {
			// Arrange
			path, changed := changedCryptoCopy(t, c.primitive, c.field)

			// Act
			var failing []string
			for _, row := range loadCryptoRows(t, path) {
				if cryptoMismatch(t, row) != "" {
					failing = append(failing, row.primitive+" "+row.id)
				}
			}

			// Assert
			if len(failing) != 1 || failing[0] != changed {
				t.Fatalf("failing rows %v, want [%s]", failing, changed)
			}
		})
	}
}

func TestCryptoChaCha20RefusesAWrongKeyOrNonceLength(t *testing.T) {
	for name, c := range map[string]struct{ key, nonce []byte }{
		"key 31": {make([]byte, 31), make([]byte, 12)}, "key 33": {make([]byte, 33), make([]byte, 12)},
		"nonce 8": {make([]byte, 32), make([]byte, 8)}, "nonce 24 (XChaCha20)": {make([]byte, 32), make([]byte, 24)},
	} {
		// Act
		block, blockErr := chacha20Block(c.key, c.nonce, 0)
		out, xorErr := chacha20XOR(c.key, c.nonce, 0, []byte{1})

		// Assert
		if block != nil || blockErr == nil || out != nil || xorErr == nil {
			t.Errorf("%s: block %x %v, xor %x %v", name, block, blockErr, out, xorErr)
		}
	}
}

func TestCryptoChaCha20StreamThatWouldPassTheLastBlockCounterIsRefused(t *testing.T) {
	// Arrange
	key, nonce := make([]byte, 32), make([]byte, 12)
	const last = 1<<32 - 1

	// Act
	oneBlock, oneErr := chacha20XOR(key, nonce, last, make([]byte, 64))
	block, blockErr := chacha20Block(key, nonce, last)
	tooLong, longErr := chacha20XOR(key, nonce, last, make([]byte, 65))

	// Assert
	if oneErr != nil || blockErr != nil || !bytes.Equal(oneBlock, block) {
		t.Fatalf("the last block: %x %v, %x %v", oneBlock, oneErr, block, blockErr)
	}
	if tooLong != nil || longErr == nil {
		t.Fatalf("a stream past the last counter: %x, %v", tooLong, longErr)
	}
}

func TestCryptoHkdfGivesAtMost255Blocks(t *testing.T) {
	// Arrange
	ikm := bytes.Repeat([]byte{0x0b}, 22)

	// Act
	longest, err := hkdfSHA256(ikm, nil, nil, 255*32)
	over, overErr := hkdfSHA256(ikm, nil, nil, 255*32+1)

	// Assert
	if err != nil || len(longest) != 8160 {
		t.Fatalf("255 blocks: %d bytes, %v", len(longest), err)
	}
	if over != nil || overErr == nil {
		t.Fatalf("256 blocks: %d bytes, %v", len(over), overErr)
	}
}
