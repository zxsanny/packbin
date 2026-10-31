package packbin

import (
	"bytes"
	"fmt"
	"os"
	"strings"
	"testing"
)

// The shared percentage vectors (fixtures/ecc/percent-vectors.txt, loop 97) replayed by Go: AZ-3504 AC-7.

func percentRows(t testing.TB) []eccRow {
	t.Helper()
	raw, err := os.ReadFile("../fixtures/ecc/percent-vectors.txt")
	if err != nil {
		t.Fatalf("read percent-vectors.txt: %v", err)
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

func percentRowsOf(t testing.TB, kind string) []eccRow {
	t.Helper()
	var out []eccRow
	for _, r := range percentRows(t) {
		if r.kind == kind {
			out = append(out, r)
		}
	}
	if len(out) == 0 {
		t.Fatalf("percent-vectors.txt has no %s rows", kind)
	}
	return out
}

// signed is a number column that may be negative.
func signed(t testing.TB, s string) int {
	t.Helper()
	if strings.HasPrefix(s, "-") {
		return -atoi(t, s[1:])
	}
	return atoi(t, s)
}

func TestPercentVectorsCoverEveryRowKind(t *testing.T) {
	// Arrange
	kinds := map[string]bool{}

	// Act
	for _, r := range percentRows(t) {
		kinds[r.kind] = true
	}

	// Assert
	for _, k := range []string{"pct", "encp", "inv", "limp", "fixp", "badp", "parp", "lmtp"} {
		if !kinds[k] {
			t.Errorf("no %s rows", k)
		}
	}
	if len(kinds) != 8 {
		t.Errorf("row kinds %v, want 8", kinds)
	}
}

func TestPercentVectorsPctCountOfTheClearLength(t *testing.T) {
	for _, row := range percentRowsOf(t, "pct") {
		t.Run(row.id, func(t *testing.T) {
			p, length, want := atoi(t, row.cols[0]), atoi(t, row.cols[1]), atoi(t, row.cols[2])
			if got := percentCount(p, length); got != want {
				t.Fatalf("percentCount(%d, %d) = %d, want %d", p, length, got, want)
			}
		})
	}
}

func TestPercentVectorsEncpProtectAppendsExactlyTheVectorParity(t *testing.T) {
	for _, row := range percentRowsOf(t, "encp") {
		t.Run(row.id, func(t *testing.T) {
			p, plain, want := atoi(t, row.cols[0]), bytesOfHex(t, row.cols[1]), bytesOfHex(t, row.cols[2])
			got, err := protectPercent(plain, p)
			if err != nil || !bytes.Equal(got, want) {
				t.Fatalf("protectPercent p=%d: got %x, %v; want %x", p, got, err, want)
			}
		})
	}
}

func TestPercentVectorsInvFindsTheClearLengthOfASentLength(t *testing.T) {
	for _, row := range percentRowsOf(t, "inv") {
		t.Run(row.id, func(t *testing.T) {
			p, sent := atoi(t, row.cols[0]), atoi(t, row.cols[1])
			want := -1
			if row.cols[2] != "none" {
				want = atoi(t, row.cols[2])
			}
			got := sent
			if p > 0 {
				got = clearLength(p, sent)
			}
			if got != want {
				t.Fatalf("clear length of %d sent bytes at %d percent = %d, want %d", sent, p, got, want)
			}
		})
	}
}

func TestPercentVectorsLimpProtectAndPackAtTheSizeLimit(t *testing.T) {
	for _, row := range percentRowsOf(t, "limp") {
		t.Run(row.id, func(t *testing.T) {
			// Arrange: the packet is the type byte and a Bytes field, so the clear length is length.
			p, length, outcome := atoi(t, row.cols[0]), atoi(t, row.cols[1]), row.cols[2]
			s := percentScheme(t, mustScheme(t, 0, Bytes(0, "b", length-1)), p)

			// Act
			viaProtect, protectFail := protectPercent(make([]byte, length), p)
			viaPack, packFail := Pack(s, map[string]any{"b": make([]byte, length-1)})

			// Assert
			if outcome == "ok" {
				if protectFail != nil || packFail != nil || len(viaProtect) != length+percentCount(p, length) || len(viaPack) != len(viaProtect) {
					t.Fatalf("p=%d clear %d: protect %d, %v; pack %d, %v", p, length, len(viaProtect), protectFail, len(viaPack), packFail)
				}
				return
			}
			if viaProtect != nil || viaPack != nil {
				t.Fatalf("a refused message wrote bytes: %x %x", viaProtect, viaPack)
			}
			want := fmt.Sprintf("%d bytes, above the limit of %d", length, largestClear(p))
			for _, err := range []error{protectFail, packFail} {
				if e := asError(t, err, PackRefused); !strings.Contains(e.Reason, want) {
					t.Fatalf("reason %q does not say %q", e.Reason, want)
				}
			}
		})
	}
}

func TestPercentVectorsFixpRepairReturnsTheClearMessageAndTheCount(t *testing.T) {
	for _, row := range percentRowsOf(t, "fixp") {
		t.Run(row.id, func(t *testing.T) {
			p, limit := atoi(t, row.cols[0]), atoi(t, row.cols[1])
			received, want, count := bytesOfHex(t, row.cols[2]), bytesOfHex(t, row.cols[3]), atoi(t, row.cols[4])
			before := append([]byte(nil), received...)

			got, repaired, err := repairPercent(received, p, limit)

			if err != nil || !bytes.Equal(got, want) || repaired != count {
				t.Fatalf("repair p=%d t=%d: got %x, %d, %v; want %x, %d", p, limit, got, repaired, err, want, count)
			}
			if !bytes.Equal(received, before) {
				t.Fatalf("repair wrote the caller's buffer")
			}
		})
	}
}

func TestPercentVectorsBadpRepairIsRefusedWithTheNamedKind(t *testing.T) {
	for _, row := range percentRowsOf(t, "badp") {
		t.Run(row.id, func(t *testing.T) {
			p, limit := atoi(t, row.cols[0]), atoi(t, row.cols[1])
			received, kind := bytesOfHex(t, row.cols[2]), row.cols[3]

			got, repaired, err := repairPercent(received, p, limit)

			if got != nil || repaired != 0 {
				t.Fatalf("a refused repair returned %x, %d", got, repaired)
			}
			switch kind {
			case "uncorrectable":
				if e := asError(t, err, Uncorrectable); e.Field != NoField || e.Name != "" {
					t.Fatalf("uncorrectable names a field: %+v", e)
				}
			case "too_long":
				if e := asError(t, err, TooLong); e.Left != len(received) {
					t.Fatalf("too long error %+v, want left %d", e, len(received))
				}
			default:
				t.Fatalf("unknown refusal kind %q", kind)
			}
		})
	}
}

func TestPercentVectorsParpPercentageWithACountIsRefused(t *testing.T) {
	for _, row := range percentRowsOf(t, "parp") {
		t.Run(row.id, func(t *testing.T) {
			p, n := signed(t, row.cols[0]), atoi(t, row.cols[1])

			err := checkPercent(p, n)

			e := asError(t, err, InvalidScheme)
			if !strings.Contains(e.Reason, fmt.Sprint(p)) || !strings.Contains(e.Reason, "100") {
				t.Fatalf("reason %q does not name %d and 100", e.Reason, p)
			}
		})
	}
}

func TestPercentVectorsLmtpLimitOutsideSixteenIsRefusedBeforeAnyByteIsRead(t *testing.T) {
	for _, row := range percentRowsOf(t, "lmtp") {
		t.Run(row.id, func(t *testing.T) {
			limit := signed(t, row.cols[0])
			s := percentScheme(t, positionMapScheme(t), 25)
			message, err := Pack(s, goldenMap())
			if err != nil {
				t.Fatal(err)
			}

			row1, repaired, rerr := UnpackRepair(message, limit, s)
			row2, _, merr := UnpackMapRepair(message, limit, s)

			asError(t, rerr, InvalidScheme)
			asError(t, merr, InvalidScheme)
			if row1 != nil || row2 != nil || repaired != 0 {
				t.Fatalf("a refused limit returned rows %v %v and %d repaired", row1, row2, repaired)
			}
		})
	}
}
