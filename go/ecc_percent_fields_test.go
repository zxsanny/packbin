package packbin

import (
	"bytes"
	"strings"
	"testing"
)

// Parity percentage (AZ-3513; contract message-ecc 1.1.0): a message whose length varies by an optional field,
// a string field read after the repair, and the dispatch mix error that tells a percentage from a count.

// optionalScheme is a type byte, a u64 and an optional 3-byte field behind a flag byte: 13 clear bytes with it, 10 without.
func optionalScheme(t testing.TB) *Scheme {
	t.Helper()
	return mustScheme(t, 5, U64(0, "id"), Flags(1, Bytes(1, "extra", 3)))
}

func TestPercentOptionalFieldEachMessageCarriesItsOwnCount(t *testing.T) {
	// Arrange
	s := percentScheme(t, optionalScheme(t), 25)
	withField := map[string]any{"id": uint64(0x0102030405060708), "extra": []byte{9, 8, 7}}
	without := map[string]any{"id": uint64(0x0102030405060708)}

	// Act
	long, errLong := Pack(s, withField)
	short, errShort := Pack(s, without)
	backLong, repairedLong, rerrLong := UnpackMapRepair(long, 0, s)
	backShort, repairedShort, rerrShort := UnpackMapRepair(short, 0, s)

	// Assert
	if errLong != nil || errShort != nil || rerrLong != nil || rerrShort != nil {
		t.Fatal(errLong, errShort, rerrLong, rerrShort)
	}
	if len(long) != 17 || len(short) != 13 {
		t.Fatalf("sent lengths %d and %d, want 17 and 13", len(long), len(short))
	}
	if wantCount(25, 13) != 4 || wantCount(25, 10) != 3 {
		t.Fatal("the reference count is not 4 and 3")
	}
	if repairedLong != 0 || repairedShort != 0 {
		t.Fatalf("repaired %d and %d", repairedLong, repairedShort)
	}
	if backLong["id"] != uint64(0x0102030405060708) || !bytes.Equal(backLong["extra"].([]byte), []byte{9, 8, 7}) {
		t.Fatalf("with the field: %v", backLong)
	}
	if _, has := backShort["extra"]; has || backShort["id"] != uint64(0x0102030405060708) {
		t.Fatalf("without the field: %v", backShort)
	}
}

func TestPercentStringFieldIsReadAfterTheRepair(t *testing.T) {
	// Arrange
	s := percentScheme(t, mustScheme(t, 6, Utf8(0, "s")), 25)
	text := "hello packbin"
	sent, err := Pack(s, map[string]any{"s": text})
	if err != nil {
		t.Fatal(err)
	}

	for at := range sent {
		// Act
		row, repaired, rerr := UnpackMapRepair(corrupt(sent, []int{at}, []byte{0x5a}), 1, s)

		// Assert
		if rerr != nil || repaired != 1 || row["s"] != text {
			t.Fatalf("wrong byte at %d of %d: %v, repaired %d, %v", at, len(sent), row, repaired, rerr)
		}
	}
}

func TestPercentDispatchMixOfPercentAndCountNamesWhichIsThePercentage(t *testing.T) {
	// Arrange
	a, b := mustScheme(t, 1, U8(0, "x")), mustScheme(t, 2, U8(0, "y"))
	message, err := Pack(b, map[string]any{"y": 9})
	if err != nil {
		t.Fatal(err)
	}

	// Act
	_, _, percentFirst := UnpackRepair(message, 0, percentScheme(t, a, 25), withParity(t, b, 25))
	_, _, countFirst := UnpackRepair(message, 0, withParity(t, a, 25), percentScheme(t, b, 25))

	// Assert
	first := asError(t, percentFirst, InvalidScheme)
	if !strings.Contains(first.Reason, "0 parity bytes at 25 percent and 25 at 0 percent") {
		t.Fatalf("percentage first: %q", first.Reason)
	}
	second := asError(t, countFirst, InvalidScheme)
	if !strings.Contains(second.Reason, "25 parity bytes at 0 percent and 0 at 25 percent") {
		t.Fatalf("count first: %q", second.Reason)
	}
}
