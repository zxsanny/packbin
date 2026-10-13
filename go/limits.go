package packbin

// The defaults of a scheme's limits, the same in every package of this repository.
const (
	// DefaultMaxRounds is the most rounds one Repeat or Times field may start.
	DefaultMaxRounds = 65_535
	// DefaultMaxSlots is the most slots all the rounds of one call may create together.
	DefaultMaxSlots = 1_048_576
	// DefaultMaxBytes is the most bytes one Pack call may write, the type byte included (16 MiB).
	DefaultMaxBytes = 16_777_216
)

// Limits are what keeps the cost of one call from being set by its input. Unpack refuses a Repeat or
// Times field past MaxRounds rounds, and rounds that together would hold more than MaxSlots slots,
// when the round would start, before its bytes are read. Pack refuses the same rounds and slots (a
// Times count or a Repeat list above MaxRounds before any round is written), and a packet longer than
// MaxBytes. A slot is one name a round can hold: see the Rounds section of the README.
type Limits struct {
	MaxRounds int
	MaxSlots  int
	MaxBytes  int
}

// DefaultLimits are DefaultMaxRounds, DefaultMaxSlots and DefaultMaxBytes.
func DefaultLimits() Limits {
	return Limits{MaxRounds: DefaultMaxRounds, MaxSlots: DefaultMaxSlots, MaxBytes: DefaultMaxBytes}
}

// Limits are the limits of s: the defaults unless s was made by WithLimits.
func (s *Scheme) Limits() Limits { return s.limits }

// WithLimits is a copy of s that keeps the given limits; s is unchanged. Every field is the limit, not
// an override: a field left at 0 is refused (start from DefaultLimits to change one). A limit below 1
// returns an *Error of kind InvalidScheme and a nil scheme.
func (s *Scheme) WithLimits(l Limits) (*Scheme, error) {
	if s == nil {
		return nil, schemeErr(NoField, "", "the scheme is nil")
	}
	for _, c := range []struct {
		name  string
		value int
	}{{"MaxRounds", l.MaxRounds}, {"MaxSlots", l.MaxSlots}, {"MaxBytes", l.MaxBytes}} {
		if c.value < 1 {
			return nil, schemeErr(NoField, "", "%s: expected a positive integer, got %d", c.name, c.value)
		}
	}
	c := *s
	c.limits = l
	return &c, nil
}
