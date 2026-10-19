package packbin

import (
	"strconv"
	"testing"
	"time"
)

// Hostile `limit` cases (fixtures/hostile/cases.txt, run by the loader of AZ-2446): the limit is MaxRounds 3.

func TestAC1HostileLimitRepeatRoundsOverLimit(t *testing.T) {
	// Arrange
	layout := limited(t, repeatK(t), func(l *Limits) { l.MaxRounds = 3 })

	// Act
	row, err := Unpack(mustHex(t, "0111223344"), layout)

	// Assert
	if row != nil {
		t.Fatal("a refused unpack gave a row")
	}
	refusedAt(t, err, 1)
}

func TestAC1HostileLimitTimesRoundsOverLimit(t *testing.T) {
	// Arrange
	layout := limited(t, timesK(t), func(l *Limits) { l.MaxRounds = 3 })

	// Act
	row, err := Unpack(mustHex(t, "010411223344"), layout)

	// Assert
	if row != nil {
		t.Fatal("a refused unpack gave a row")
	}
	refusedAt(t, err, 1)
}

func TestAC1HostilePackElementTimesOverBudgetIsRefusedBySlotsInItem17(t *testing.T) {
	// Arrange: 40 items, each n = 65 535 and one lone u64 per round
	layout := mustScheme(t, 1, List("items", Nested("item", U32(0, "n"), Times(1, 0, U64(1, "k")))))
	items := make([]any, 40)
	for i := range items {
		items[i] = map[string]any{"n": 65_535, "k": 5}
	}

	// Act / Assert
	refusedPack(t, layout, map[string]any{"items": items},
		"k: the rounds would hold 1048577 slots, above the limit of 1048576 slots")
}

// f10 is the old worst packet (loop 21 security report, F10): a list of 65 535 items, each a Nested row
// that holds u8 n and a times of n rounds of 64 u8 names; every n is 1, so each item charges one round of
// 64 slots and the whole packet 4 194 240 slots, in 4 259 778 bytes.
func f10(t testing.TB) (*Scheme, []byte) {
	body := make([]Field, 64)
	for i := range body {
		body[i] = U8(1+i, "k"+strconv.Itoa(i))
	}
	layout := mustScheme(t, 1, List("items", Nested("item", U8(0, "n"), Times(1, 0, body...))))
	packet := make([]byte, 3+65*65_535)
	for i := range packet {
		packet[i] = 1
	}
	packet[1], packet[2] = 0xff, 0xff
	return layout, packet
}

func TestAC3RaisedSlotLimitUnpacksTheOldWorstPacketAndTheDefaultRefusesIt(t *testing.T) {
	// Arrange
	layout, packet := f10(t)
	raised := limited(t, layout, func(l *Limits) { l.MaxSlots = 4_194_304 })

	// Act
	factor := loadFactor()
	start := time.Now()
	_, defaultErr := UnpackMap(packet, layout)
	refusedIn := time.Since(start)
	row, raisedErr := UnpackMap(packet, raised)

	// Assert
	refusedAt(t, defaultErr, 3_194_814) // refused at item 16 385, after 16 384 items hold 1 048 576 slots
	assertWithin(t, "the refusal", refusedIn, time.Second, factor)
	if raisedErr != nil {
		t.Fatal(raisedErr)
	}
	items := row["items"].([]any)
	if len(items) != 65_535 || items[65_534].(map[string]any)["n"] != uint8(1) {
		t.Fatalf("%d items", len(items))
	}
}

func TestAC3WideRoundPacketPacksAndUnpacksWithMaxSlotsRaisedAndTheDefaultRefusesIt(t *testing.T) {
	// Arrange
	layout, row := wideRound(t)
	raised := limited(t, layout, func(l *Limits) { l.MaxSlots = 4_259_775 })

	// Act
	raw, err := Pack(raised, row)
	back, unpackErr := UnpackMap(raw, raised)
	_, defaultErr := UnpackMap(raw, layout)

	// Assert
	if err != nil || len(raw) != 4_259_780 || hexOf(raw[:16]) != "01ffff00000101010101010101010101" {
		t.Fatalf("%d bytes: %v", len(raw), err)
	}
	if unpackErr != nil || len(back["m64"].([]any)) != 65_535 {
		t.Fatalf("%v", unpackErr)
	}
	if e := refusedAt(t, defaultErr, 3_211_260); e.Name != "m0" {
		t.Fatalf("got %+v", e)
	}
}

func TestAC1AZeroWidthBytesRoundNamesASlotSoMaxSlotsBoundsTheRounds(t *testing.T) {
	// Arrange
	layout := limited(t, mustScheme(t, 1, U8(0, "n"), Times(1, 0, Bytes(1, "v", 0))), func(l *Limits) { l.MaxSlots = 5 })
	empty := make([]any, 10)
	for i := range empty {
		empty[i] = []byte{}
	}

	// Act / Assert
	refusedPack(t, layout, map[string]any{"n": 10, "v": empty}, "v: the rounds would hold 6 slots, above the limit of 5 slots")
}
