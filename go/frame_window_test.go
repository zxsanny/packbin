package packbin

import "testing"

// AZ-3293: the replay window state machine of the contract, beside the 17-step sequence of the fixture rows.

func TestReplayWindowEmptyAndRestored(t *testing.T) {
	// Arrange
	var empty ReplayWindow
	restoredEmpty := NewReplayWindow(1000, 0)
	restored := NewReplayWindow(100, 1)

	// Act and Assert
	if empty.Check(0) != FreshnessFresh || empty.Check(^uint64(0)) != FreshnessFresh {
		t.Fatal("an empty window says Fresh to every counter")
	}
	if restoredEmpty.Check(5) != FreshnessFresh {
		t.Fatal("bits 0 is empty whatever top is")
	}
	if restored.Check(100) != FreshnessDuplicate || restored.Check(36) != FreshnessTooOld || restored.Check(37) != FreshnessFresh {
		t.Fatal("a restored window")
	}
	if restored.Top() != 100 || restored.Bits() != 1 {
		t.Fatal("check changed the state")
	}
}

func TestReplayWindowCommitShiftsSetsAndIgnoresTheTooOld(t *testing.T) {
	// Arrange
	w := &ReplayWindow{}

	// Act
	w.Commit(10)
	w.Commit(12)
	w.Commit(11)
	afterThree := [2]uint64{w.Top(), w.Bits()}
	w.Commit(200)
	afterJump := [2]uint64{w.Top(), w.Bits()}
	w.Commit(100)
	afterOld := [2]uint64{w.Top(), w.Bits()}
	w.Commit(137)
	edge := [2]uint64{w.Top(), w.Bits()}

	// Assert
	if afterThree != [2]uint64{12, 0b111} {
		t.Fatalf("%v", afterThree)
	}
	if afterJump != [2]uint64{200, 1} {
		t.Fatalf("a jump of 64 or more empties the history: %v", afterJump)
	}
	if afterOld != afterJump {
		t.Fatalf("a counter 64 or more behind is ignored: %v", afterOld)
	}
	if edge != [2]uint64{200, 1 | 1<<63} {
		t.Fatalf("the oldest counter the window holds: %x", edge)
	}
}

func TestReplayWindowAtTheTopOfTheCounterRange(t *testing.T) {
	// Arrange
	max := ^uint64(0)
	w := &ReplayWindow{}

	// Act
	w.Commit(max)
	w.Commit(max - 1)
	w.Commit(0)

	// Assert
	if w.Top() != max || w.Bits() != 0b11 {
		t.Fatalf("%d:%b", w.Top(), w.Bits())
	}
	if w.Check(max) != FreshnessDuplicate || w.Check(max-63) != FreshnessFresh || w.Check(0) != FreshnessTooOld {
		t.Fatal("check near 2^64 - 1")
	}
}

func TestFreshnessAndSlotNames(t *testing.T) {
	// Act and Assert
	if FreshnessFresh.String() != "Fresh" || FreshnessDuplicate.String() != "Duplicate" || FreshnessTooOld.String() != "TooOld" {
		t.Fatal("freshness names")
	}
	if FrameSlotCurrent.String() != "current" || FrameSlotPrevious.String() != "previous" {
		t.Fatal("slot names")
	}
}
