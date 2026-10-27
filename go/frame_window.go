package packbin

// ReplayWindowSize is how many counters below the highest one a ReplayWindow remembers.
const ReplayWindowSize = 64

// ReplayWindow is the replay window of frame mode: the highest counter a sender's frames reached (Top) and which of
// the 64 counters up to it were committed (Bits: bit i set means counter Top-i was committed; 0 is an empty
// window). The zero value is an empty window. The caller owns one per sender and passes it, with the message's
// counter, to FrameSession.Open. A ReplayWindow is not safe for concurrent use: the caller serializes the Open
// calls that share one.
//
// The counter must come from bytes the tag covers (for example the msg_id or the associated data), never from an
// unauthenticated field of the wire: it is an argument of Open and not part of the tag.
type ReplayWindow struct {
	top  uint64
	bits uint64
}

// NewReplayWindow is a window restored from stored state. bits 0 is empty whatever top is: a caller validates stored
// state (bit 0 set when the bits are not 0).
func NewReplayWindow(top, bits uint64) *ReplayWindow { return &ReplayWindow{top: top, bits: bits} }

// Top is the highest committed counter.
func (w *ReplayWindow) Top() uint64 { return w.top }

// Bits says which counters up to Top were committed.
func (w *ReplayWindow) Bits() uint64 { return w.bits }

// Check says what the window knows about counter. It never changes the state.
func (w *ReplayWindow) Check(counter uint64) Freshness {
	if w.bits == 0 || counter > w.top {
		return FreshnessFresh
	}
	behind := w.top - counter
	if behind >= ReplayWindowSize {
		return FreshnessTooOld
	}
	if (w.bits>>behind)&1 == 1 {
		return FreshnessDuplicate
	}
	return FreshnessFresh
}

// Commit records counter. Open calls it only after a frame opened; a counter 64 or more behind the highest is
// ignored.
func (w *ReplayWindow) Commit(counter uint64) {
	switch {
	case w.bits == 0:
		w.top = counter
		w.bits = 1
	case counter > w.top:
		shift := counter - w.top
		if shift >= ReplayWindowSize {
			w.bits = 1
		} else {
			w.bits = w.bits<<shift | 1
		}
		w.top = counter
	default:
		if behind := w.top - counter; behind < ReplayWindowSize {
			w.bits |= 1 << behind
		}
	}
}
