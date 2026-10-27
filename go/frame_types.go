package packbin

// The types of frame mode (pack-session.md 3.0.0). The names are those of the other packages; Go has no nested
// names, so a value of a type carries the type's name as a prefix (FrameUp, FrameSlotCurrent, FreshnessFresh).

// FrameDirection is the direction of a frame: the nonce and the keys depend on it.
type FrameDirection uint8

// The directions of a frame.
const (
	FrameUp    FrameDirection = 1
	FrameDown  FrameDirection = 2
	FrameGroup FrameDirection = 3
)

// FrameDirections is the set of directions a session loaded keys for; combine the values with |.
type FrameDirections uint8

// The directions a session can load.
const (
	FrameDirectionsNone  FrameDirections = 0
	FrameDirectionsUp    FrameDirections = 1
	FrameDirectionsDown  FrameDirections = 2
	FrameDirectionsGroup FrameDirections = 4
	FrameDirectionsAll   FrameDirections = 7
)

// FrameSlot says which loaded key opened a frame.
type FrameSlot uint8

const (
	// FrameSlotCurrent: the key the session was loaded with.
	FrameSlotCurrent FrameSlot = iota
	// FrameSlotPrevious: the key set by SetPrevious.
	FrameSlotPrevious
)

func (s FrameSlot) String() string {
	if s == FrameSlotPrevious {
		return "previous"
	}
	return "current"
}

// Freshness is what a ReplayWindow says about a counter. The values carry the type's name because Duplicate and
// TooOld are also the names of error kinds; their String forms are Fresh, Duplicate and TooOld.
type Freshness uint8

const (
	// FreshnessFresh: the counter was not committed and is inside the window or above it.
	FreshnessFresh Freshness = iota
	// FreshnessDuplicate: the counter was already committed.
	FreshnessDuplicate
	// FreshnessTooOld: the counter is 64 or more behind the highest committed counter.
	FreshnessTooOld
)

func (f Freshness) String() string {
	switch f {
	case FreshnessFresh:
		return "Fresh"
	case FreshnessDuplicate:
		return "Duplicate"
	case FreshnessTooOld:
		return "TooOld"
	}
	return "Freshness(?)"
}

// FrameConfig is what a frame session is loaded with besides the key. A TagLength other than 4, 8 or 16 makes
// LoadFrameSession fail with a BadValue.
type FrameConfig struct {
	TagLength  int
	Directions FrameDirections
}

// FrameOpened is what Open reports for a frame that opened: the slot of the key that opened it, the length of the
// clear part and the length of the plaintext written to the caller's buffer.
type FrameOpened struct {
	Slot        FrameSlot
	ClearLength int
	PlainLength int
}

// MsgContext is what the caller supplies per message: the 8-byte msg_id and the 4-bit kind (0 to 15).
//
// **For one (key, epoch, direction), a msg_id is never sealed twice with different contents.** Reuse breaks the
// confidentiality of both messages, and packbin cannot check it. A new epoch derives new keys and nonces. meshbell
// builds the id as source (2 bytes), id field (2 bytes) and creation wave (4 bytes), so it is unique by
// construction.
//
// The zero value, and a value built from a slice that is not 8 bytes long, is refused by Seal and Open as a
// BadValue. A MsgContext copies the id; it is immutable.
type MsgContext struct {
	id   [8]byte
	kind int
	set  bool
}

// MsgIDSize is the length of a msg_id.
const MsgIDSize = 8

// NewMsgContext is a MsgContext for msgID (8 bytes) and kind. It never fails: a wrong length or a kind outside
// 0 to 15 is reported by Seal and Open.
func NewMsgContext(msgID []byte, kind int) MsgContext {
	m := MsgContext{kind: kind}
	if len(msgID) == MsgIDSize {
		copy(m.id[:], msgID)
		m.set = true
	}
	return m
}

// Kind is the caller's nibble mixed into the nonce.
func (m MsgContext) Kind() int { return m.kind }
