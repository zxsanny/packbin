package packbin

import (
	"bytes"
	"errors"
	"fmt"
	"runtime"
	"strings"
	"testing"
	"time"
)

// Repair and refusal of a protected position message: AZ-2685 AC-3 (EC-5), AC-4 (EC-6, EC-7, EC-8, EC-14),
// AC-5 (EC-4) and AC-7 (EC-13).

func TestEccRepairN2EveryPositionAndEveryWrongValueIsRepaired(t *testing.T) {
	// Arrange
	message, err := Pack(positionParity(t, 2), goldenMap())
	if err != nil || len(message) != 15 {
		t.Fatalf("pack: %d bytes, %v", len(message), err)
	}
	cases, failures := 0, 0

	// Act
	for p := range message {
		for v := 1; v <= 255; v++ {
			row, repaired, err := readPosition(t, corrupt(message, []int{p}, []byte{byte(v)}), 2, 1)
			cases++
			if err != nil || repaired != 1 || !isPosition(row) {
				failures++
			}
		}
	}

	// Assert
	if cases != 15*255 || failures != 0 {
		t.Fatalf("%d cases, %d failures", cases, failures)
	}
}

func TestEccRepairSeededCasesUpToTWrongBytesAreRepaired(t *testing.T) {
	for _, n := range []int{4, 8, 16} {
		t.Run(fmt.Sprintf("n=%d", n), func(t *testing.T) {
			// Arrange
			rng := newRand(uint64(n))
			message := packedPosition(t, n)
			limit, failures := n/2, 0

			// Act
			for i := range 1000 {
				count := 1 + i%limit
				positions, values := pickWrong(rng, len(message), count)
				row, repaired, err := readPosition(t, corrupt(message, positions, values), n, limit)
				if err != nil || repaired != count || !isPosition(row) {
					failures++
				}
			}

			// Assert
			if failures != 0 {
				t.Fatalf("%d of 1000 cases not repaired", failures)
			}
		})
	}
}

func TestEccRepairTypedRowIsRecoveredAsTheStruct(t *testing.T) {
	// Arrange
	s := withParity(t, positionTypedScheme(t), 4)
	message, err := Pack(s, goldenRow())
	if err != nil {
		t.Fatal(err)
	}

	// Act
	row, repaired, err := UnpackRepair(corrupt(message, []int{1, 8}, []byte{0x44, 0x02}), 2, s)

	// Assert
	got, ok := row.(*Position)
	if err != nil || repaired != 2 || !ok || *got != *goldenRow() {
		t.Fatalf("got %v, %d, %v", row, repaired, err)
	}
}

func TestEccRepairAWrongByteCountsOnceHoweverManyBitsDiffer(t *testing.T) {
	// Arrange
	message := packedPosition(t, 2)

	// Act
	row, repaired, err := readPosition(t, corrupt(message, []int{6}, []byte{0xff}), 2, 1)

	// Assert
	if err != nil || repaired != 1 || !isPosition(row) {
		t.Fatalf("got %v, %d, %v", row, repaired, err)
	}
}

func TestEccRepairLeavesTheCallersBufferAsItWas(t *testing.T) {
	// Arrange
	message := packedPosition(t, 4)
	wrong := corrupt(message, []int{3, 9}, []byte{0x55, 0x01})
	before := append([]byte(nil), wrong...)

	// Act
	_, repaired, err := readPosition(t, wrong, 4, 2)

	// Assert
	if err != nil || repaired != 2 || !bytes.Equal(wrong, before) {
		t.Fatalf("repaired %d, %v; buffer %x was %x", repaired, err, wrong, before)
	}
}

// refusedCases unpacks `cases` corruptions of the n = 4 message with the limit and counts the accepted
// ones and the errors that are not Uncorrectable.
func refusedCases(t *testing.T, seed uint64, limit, cases int, wrongBytes func(i int) int) (accepted, otherErrors int) {
	t.Helper()
	rng := newRand(seed)
	message := packedPosition(t, 4)
	for i := range cases {
		positions, values := pickWrong(rng, len(message), wrongBytes(i))
		row, _, err := readPosition(t, corrupt(message, positions, values), 4, limit)
		if err == nil || row != nil {
			accepted++
		} else if e, ok := err.(*Error); !ok || e.Kind != Uncorrectable {
			otherErrors++
		}
	}
	return accepted, otherErrors
}

func TestEccRepairN4T1TenThousandSeededCasesOfTwoOrThreeWrongBytesAreRefused(t *testing.T) {
	// Act
	accepted, other := refusedCases(t, 61, 1, 10_000, func(i int) int { return 2 + i%2 })

	// Assert
	if accepted != 0 || other != 0 {
		t.Fatalf("%d accepted, %d other errors", accepted, other)
	}
}

func TestEccRepairN4T0TenThousandSeededCasesOfOneToFourWrongBytesAreRefused(t *testing.T) {
	// Act
	accepted, other := refusedCases(t, 60, 0, 10_000, func(i int) int { return 1 + i%4 })

	// Assert
	if accepted != 0 || other != 0 {
		t.Fatalf("%d accepted, %d other errors", accepted, other)
	}
}

func TestEccRepairN2T0GarbageIsAcceptedAtMostTwelveTimesIn200000(t *testing.T) {
	// Arrange
	rng := newRand(7)
	buffer := make([]byte, 15)
	accepted := 0

	// Act
	for range 200_000 {
		for k := range buffer {
			buffer[k] = byte(rng.IntN(256))
		}
		if _, _, err := repair(buffer, 2, 0); err == nil {
			accepted++
		}
	}

	// Assert
	if accepted > 12 {
		t.Fatalf("accepted %d of 200000, want at most 12", accepted)
	}
}

func TestEccRepairReportRowsSevenToTwelve(t *testing.T) {
	for _, c := range []struct {
		name     string
		message  string
		n, limit int
		repaired int
		kind     Kind
	}{
		{"row 7: one wrong byte, n 2, t 1", "4001000065cc1d00a3e111010016bd", 2, 1, 1, 0},
		{"row 8: two wrong bytes, n 4, t 2", "40015a0065cd1d00a322110100ca856682", 4, 2, 2, 0},
		{"row 9: two wrong bytes beyond t 1", "40015a0065cd1d00a322110100ca856682", 4, 1, 0, Uncorrectable},
		{"row 10: two wrong bytes beyond t 0", "40015a0065cd1d00a322110100ca856682", 4, 0, 0, Uncorrectable},
		{"row 11: intact", "4001000065cd1d00a3e1110100ca856682", 4, 2, 0, 0},
		{"row 12: shorter than n", "400100", 4, 2, 0, ShortPacket},
	} {
		t.Run(c.name, func(t *testing.T) {
			// Act
			row, repaired, err := readPosition(t, mustHex(t, c.message), c.n, c.limit)

			// Assert
			if c.kind != 0 {
				e := asError(t, err, c.kind)
				if row != nil || repaired != 0 || (c.kind == ShortPacket && (e.Name != "parity" || e.Needed != 4 || e.Left != 3)) {
					t.Fatalf("row %v, repaired %d, error %+v", row, repaired, e)
				}
				return
			}
			if err != nil || repaired != c.repaired || !isPosition(row) {
				t.Fatalf("got %v, %d, %v", row, repaired, err)
			}
		})
	}
}

func TestEccRepairAnEmptyBufferIsShortNamingTheParity(t *testing.T) {
	// Act
	row, _, err := readPosition(t, []byte{}, 1, 0)

	// Assert
	e := asError(t, err, ShortPacket)
	if row != nil || e.Name != "parity" || e.Needed != 1 || e.Left != 0 {
		t.Fatalf("row %v, error %+v", row, e)
	}
}

func TestEccRepairTenThousandSeededRemovedOrAddedTailBytesAreRefused(t *testing.T) {
	// Arrange
	rng := newRand(14)
	message := packedPosition(t, 4)
	accepted := 0

	// Act
	for i := range 10_000 {
		k := 1 + i%3
		changed := append([]byte(nil), message[:len(message)-k]...)
		if i%2 == 1 {
			changed = append([]byte(nil), message...)
			for range k {
				changed = append(changed, byte(rng.IntN(256)))
			}
		}
		if row, _, err := readPosition(t, changed, 4, 0); err == nil || row != nil {
			accepted++
		}
	}

	// Assert
	if accepted != 0 {
		t.Fatalf("%d changed-length messages accepted", accepted)
	}
}

func TestEccRepairATrailingZeroAndADroppedByteAreRefusedAndAZeroParityByteIsNot(t *testing.T) {
	// Arrange
	s := positionParity(t, 4)
	var zeroParity []byte
	for sid := 0; zeroParity == nil && sid < 65_536; sid++ {
		m, err := Pack(s, map[string]any{"sid": sid, "lat": 500_000_000, "lon": 300_000_000, "profile": 1})
		if err != nil {
			t.Fatal(err)
		}
		if m[len(m)-1] == 0 {
			zeroParity = m
		}
	}
	if zeroParity == nil {
		t.Fatal("no row with a last parity byte of 00")
	}

	// Act and assert
	for name, m := range map[string][]byte{
		"a trailing zero":     append(append([]byte(nil), zeroParity...), 0),
		"a dropped last byte": zeroParity[:len(zeroParity)-1],
	} {
		if row, _, err := UnpackMapRepair(m, 0, s); err == nil || row != nil {
			t.Errorf("%s accepted: %x", name, m)
		}
	}
	if row, repaired, err := UnpackMapRepair(zeroParity, 0, s); err != nil || repaired != 0 || row == nil {
		t.Errorf("a message whose last parity byte is 00 was refused: %v", err)
	}
}

func TestEccRepairTheUnprotectedMessageReadByAnN4SchemeIsRefused(t *testing.T) {
	// Arrange
	clear := packedPosition(t, 0)

	// Act
	detect, _, detectErr := readPosition(t, clear, 4, 0)
	repairing, _, repairErr := readPosition(t, clear, 4, 2)

	// Assert
	asError(t, detectErr, Uncorrectable)
	if detect != nil || repairing != nil || repairErr == nil {
		t.Fatalf("rows %v %v, repair error %v", detect, repairing, repairErr)
	}
}

func TestEccRepairAProtectedMessageReadByAnUnprotectedSchemeIsTrailingBytes(t *testing.T) {
	// Arrange
	message := packedPosition(t, 4)

	// Act
	row, err := UnpackMap(message, positionMapScheme(t))

	// Assert
	if e := asError(t, err, TrailingBytes); row != nil || e.Left != 4 {
		t.Fatalf("row %v, error %+v", row, e)
	}
}

func TestEccRepairABufferAbove254BytesIsTooLongNotTooManyWithNoRow(t *testing.T) {
	// Act
	row, _, err := readPosition(t, make([]byte, 255), 4, 2)

	// Assert
	e := asError(t, err, TooLong)
	if row != nil || e.Left != 255 || errors.Is(err, ErrTooMany) || !errors.Is(err, ErrTooLong) ||
		!strings.Contains(e.Reason, "255") || !strings.Contains(e.Reason, "254") {
		t.Fatalf("row %v, error %+v", row, e)
	}
}

func TestEccRepairAClearMessageAbove254MinusNIsPackRefusedNamingLengthAndLimit(t *testing.T) {
	// Arrange
	s := withParity(t, mustScheme(t, 0, Bytes(0, "b", 250)), 4)

	// Act
	packed, err := Pack(s, map[string]any{"b": bytes.Repeat([]byte{7}, 250)})

	// Assert
	e := asError(t, err, PackRefused)
	if packed != nil || errors.Is(err, ErrTooLong) || !strings.Contains(e.Reason, "251") || !strings.Contains(e.Reason, "250") {
		t.Fatalf("packed %x, error %+v", packed, e)
	}
}

func TestEccRepairN32AMessageOf222ClearBytesIsPackedAnd223IsRefusedNamingBoth(t *testing.T) {
	// Arrange
	big := func(size int) *Scheme { return withParity(t, mustScheme(t, 0, Bytes(0, "b", size-1)), 32) }

	// Act
	packed, okErr := Pack(big(222), map[string]any{"b": bytes.Repeat([]byte{7}, 221)})
	refused, refusedErr := Pack(big(223), map[string]any{"b": bytes.Repeat([]byte{7}, 222)})

	// Assert
	if okErr != nil || len(packed) != 254 {
		t.Fatalf("222: %d bytes, %v", len(packed), okErr)
	}
	e := asError(t, refusedErr, PackRefused)
	if refused != nil || e.Reason == "" || !strings.Contains(e.Reason, "223") || !strings.Contains(e.Reason, "222") {
		t.Fatalf("223: %x, %q", refused, e.Reason)
	}
}

func TestEccRepairN0LeavesTheBytesTheErrorsAndTheCountAsTheyWere(t *testing.T) {
	// Arrange
	s := positionMapScheme(t)
	clear := mustHex(t, expectedHex)

	// Act
	packed, packErr := Pack(s, goldenMap())
	row, repaired, err := UnpackMapRepair(clear, 0, s)
	_, _, trailing := UnpackMapRepair(append(append([]byte(nil), clear...), 0), 0, s)

	// Assert
	if packErr != nil || !bytes.Equal(packed, clear) || err != nil || repaired != 0 || !isPosition(row) {
		t.Fatalf("pack %x %v; unpack %v %d %v", packed, packErr, row, repaired, err)
	}
	asError(t, trailing, TrailingBytes)
	if s.Parity() != 0 {
		t.Fatalf("default parity %d", s.Parity())
	}
}

func TestEccRepairNeverPanicsOnHostileBytes(t *testing.T) {
	// Arrange
	rng := newRand(99)
	s := positionParity(t, 16)
	panics := 0

	// Act
	for i := range 20_000 {
		buffer := make([]byte, rng.IntN(300))
		for k := range buffer {
			buffer[k] = byte(rng.IntN(256))
		}
		func() {
			defer func() {
				if recover() != nil {
					panics++
				}
			}()
			UnpackMapRepair(buffer, i%9, s)
		}()
	}

	// Assert
	if panics != 0 {
		t.Fatalf("%d panics", panics)
	}
}

// EC-13 (AZ-2685 AC-7): unpacking a 254-byte message with 16 parity bytes and 8 wrong bytes 1,000 times, and
// packing it 1,000 times, each take at most 1 second on one core, times the load factor (timing_test.go). The
// fastest of up to three passes counts, as in TestAC7SpeedRoundTrips.
func TestEccSpeedRepairLoopAndPackLoopWithinOneSecond(t *testing.T) {
	// Arrange
	defer runtime.GOMAXPROCS(runtime.GOMAXPROCS(1))
	s := withParity(t, mustScheme(t, 0, Bytes(0, "b", 237)), 16)
	row := map[string]any{"b": bytes.Repeat([]byte{0x5a, 0x11, 0xc3}, 79)[:237]}
	message, err := Pack(s, row)
	if err != nil || len(message) != 254 {
		t.Fatalf("pack: %d bytes, %v", len(message), err)
	}
	wrong := corrupt(message, []int{0, 30, 60, 90, 120, 180, 220, 253}, []byte{1, 2, 3, 4, 5, 6, 7, 8})
	unpackFastest, packFastest := time.Duration(1<<63-1), time.Duration(1<<63-1)
	// factor is the one of the pass that came closest to the bound, for each loop
	unpackFactor, packFactor := 1.0, 1.0

	// Act
	for pass := 0; pass < 3 && (unpackFastest > scaled(time.Second, unpackFactor) || packFastest > scaled(time.Second, packFactor)); pass++ {
		factor := loadFactor()
		start := time.Now()
		for range 1000 {
			if _, repaired, err := UnpackMapRepair(wrong, 8, s); err != nil || repaired != 8 {
				t.Fatalf("repair: %d, %v", repaired, err)
			}
		}
		if took := time.Since(start); float64(took)/factor < float64(unpackFastest)/unpackFactor {
			unpackFastest, unpackFactor = took, factor
		}
		start = time.Now()
		for range 1000 {
			if _, err := Pack(s, row); err != nil {
				t.Fatal(err)
			}
		}
		if took := time.Since(start); float64(took)/factor < float64(packFastest)/packFactor {
			packFastest, packFactor = took, factor
		}
	}

	// Assert
	t.Logf("1000 repairs: %v (load factor %.2f), 1000 packs: %v (load factor %.2f) (race detector: %v)",
		unpackFastest, unpackFactor, packFastest, packFactor, raceEnabled)
	assertWithin(t, "1000 repairs", unpackFastest, time.Second, unpackFactor)
	assertWithin(t, "1000 packs", packFastest, time.Second, packFactor)
}
