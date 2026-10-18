package packbin

import (
	"bytes"
	"errors"
	"fmt"
	"strings"
	"testing"
)

// The shared ECC vectors (fixtures/ecc/vectors.txt, AZ-2679) replayed by Go: AZ-2685 AC-2 (EC-2, EC-3),
// AC-4 (EC-8 rows) and AC-5 (EC-4).

func TestEccVectorsCoverEveryRowKind(t *testing.T) {
	// Arrange
	kinds := map[string]bool{}

	// Act
	for _, r := range eccRows(t) {
		kinds[r.kind] = true
	}

	// Assert
	for _, k := range []string{"enc", "fix", "bad", "lim", "par", "lmt"} {
		if !kinds[k] {
			t.Errorf("no %s rows", k)
		}
	}
	if len(kinds) != 6 {
		t.Errorf("row kinds %v, want 6", kinds)
	}
}

func TestEccVectorsEncProtectAppendsExactlyTheVectorParity(t *testing.T) {
	for _, row := range eccRowsOf(t, "enc") {
		t.Run(row.id, func(t *testing.T) {
			// Arrange
			n, plain, want := atoi(t, row.cols[0]), bytesOfHex(t, row.cols[1]), bytesOfHex(t, row.cols[2])

			// Act
			got, err := protect(plain, n)

			// Assert
			if err != nil || !bytes.Equal(got, want) {
				t.Fatalf("protect n=%d: got %x, %v; want %x", n, got, err, want)
			}
		})
	}
}

func TestEccVectorsFixRepairReturnsTheClearMessageAndTheCount(t *testing.T) {
	for _, row := range eccRowsOf(t, "fix") {
		t.Run(row.id, func(t *testing.T) {
			// Arrange
			n, limit := atoi(t, row.cols[0]), atoi(t, row.cols[1])
			received, want, count := bytesOfHex(t, row.cols[2]), bytesOfHex(t, row.cols[3]), atoi(t, row.cols[4])
			before := append([]byte(nil), received...)

			// Act
			got, repaired, err := repair(received, n, limit)

			// Assert
			if err != nil || !bytes.Equal(got, want) || repaired != count {
				t.Fatalf("repair n=%d t=%d: got %x, %d, %v; want %x, %d", n, limit, got, repaired, err, want, count)
			}
			if !bytes.Equal(received, before) {
				t.Fatalf("repair wrote the caller's buffer: %x, was %x", received, before)
			}
		})
	}
}

func TestEccVectorsBadRepairIsRefusedWithTheNamedKind(t *testing.T) {
	for _, row := range eccRowsOf(t, "bad") {
		t.Run(row.id, func(t *testing.T) {
			// Arrange
			n, limit := atoi(t, row.cols[0]), atoi(t, row.cols[1])
			received, kind := bytesOfHex(t, row.cols[2]), row.cols[3]

			// Act
			got, repaired, err := repair(received, n, limit)

			// Assert
			if got != nil || repaired != 0 {
				t.Fatalf("a refused repair returned %x, %d", got, repaired)
			}
			switch kind {
			case "uncorrectable":
				if e := asError(t, err, Uncorrectable); e.Field != NoField || e.Name != "" {
					t.Fatalf("uncorrectable names a field: %+v", e)
				}
			case "short":
				e := asError(t, err, ShortPacket)
				if e.Name != "parity" || e.Needed != n || e.Left != len(received) {
					t.Fatalf("short error %+v, want parity needed %d left %d", e, n, len(received))
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

func TestEccVectorsLimProtectAndPackAtTheSizeLimit(t *testing.T) {
	for _, row := range eccRowsOf(t, "lim") {
		t.Run(row.id, func(t *testing.T) {
			// Arrange: the packet is the type byte and a Bytes field, so the clear length is length.
			n, length, outcome := atoi(t, row.cols[0]), atoi(t, row.cols[1]), row.cols[2]
			s := withParity(t, mustScheme(t, 0, Bytes(0, "b", length-1)), n)
			wantMessage := fmt.Sprintf("%d bytes, above the limit of %d", length, 254-n)

			// Act
			viaProtect, protectFail := protect(make([]byte, length), n)
			viaPack, packFail := Pack(s, map[string]any{"b": make([]byte, length-1)})

			// Assert
			if outcome == "ok" {
				if protectFail != nil || len(viaProtect) != length+n || packFail != nil || len(viaPack) != length+n {
					t.Fatalf("n=%d clear %d: protect %d, %v; pack %d, %v", n, length, len(viaProtect), protectFail, len(viaPack), packFail)
				}
				return
			}
			if viaProtect != nil || viaPack != nil {
				t.Fatalf("a refused message wrote bytes: %x %x", viaProtect, viaPack)
			}
			for _, err := range []error{protectFail, packFail} {
				if e := asError(t, err, PackRefused); !strings.Contains(e.Reason, wantMessage) {
					t.Fatalf("reason %q does not say %q", e.Reason, wantMessage)
				}
			}
		})
	}
}

func TestEccVectorsParSchemeWithTooManyParityBytesIsNotBuilt(t *testing.T) {
	for _, row := range eccRowsOf(t, "par") {
		t.Run(row.id, func(t *testing.T) {
			// Arrange
			n := atoi(t, row.cols[0])

			// Act
			s, err := positionMapScheme(t).WithParity(n)

			// Assert
			e := asError(t, err, InvalidScheme)
			if s != nil || !strings.Contains(e.Reason, fmt.Sprint(n)) || !strings.Contains(e.Reason, "32") {
				t.Fatalf("scheme %v, reason %q: want nil and a reason naming %d and 32", s, e.Reason, n)
			}
		})
	}
}

func TestEccVectorsLmtLimitAboveHalfIsRefusedBeforeAnyByteIsRead(t *testing.T) {
	for _, row := range eccRowsOf(t, "lmt") {
		t.Run(row.id, func(t *testing.T) {
			// Arrange
			n, limit := atoi(t, row.cols[0]), atoi(t, row.cols[1])
			s := positionParity(t, n)
			message, err := Pack(s, goldenMap())
			if err != nil {
				t.Fatal(err)
			}

			// Act
			row1, repaired, rerr := UnpackRepair(message, limit, s)
			row2, _, merr := UnpackMapRepair(message, limit, s)

			// Assert
			for _, err := range []error{rerr, merr} {
				asError(t, err, InvalidScheme)
				if errors.Is(err, ErrUncorrectable) {
					t.Fatalf("a bad limit is an uncorrectable message: %v", err)
				}
			}
			if row1 != nil || row2 != nil || repaired != 0 {
				t.Fatalf("a refused limit returned rows %v %v and %d repaired", row1, row2, repaired)
			}
		})
	}
}
