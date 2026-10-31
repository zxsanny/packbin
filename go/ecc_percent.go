package packbin

// MaxParityPercent is the most a scheme may declare as its parity percentage.
const MaxParityPercent = 100

// maxPercentLimit is the largest correction limit under a parity percentage (MaxParity / 2).
const maxPercentLimit = MaxParity / 2

// ParityPercent is the parity percentage s declares, 0 to 100; 0 (the default) means no percentage: the
// scheme has no parity bytes, or the fixed count of Parity. A nil scheme has none.
func (s *Scheme) ParityPercent() int {
	if s == nil {
		return 0
	}
	return s.percent
}

// WithParityPercent is a copy of s that declares a parity percentage p, 0 to 100; s is unchanged. Every
// packet carries min(32, ceil(p * L / 100)) parity bytes for its L clear bytes, and unpack finds L from
// the received length alone. Percentage 0 is a scheme without parity bytes. It replaces a fixed count
// (WithParity replaces a percentage); the limits of s are kept. Any other p returns an *Error of kind
// InvalidScheme naming p and 100, and a nil scheme.
func (s *Scheme) WithParityPercent(p int) (*Scheme, error) {
	if s.unusable() {
		return nil, schemeErr(NoField, "", "%s", s.notMade())
	}
	if err := checkPercent(p, 0); err != nil {
		return nil, err
	}
	c := *s
	c.percent = p
	c.parity = 0
	return &c, nil
}

// checkPercent refuses a percentage outside 0..100, and a percentage above 0 declared with a fixed count
// above 0, naming them and the limit.
func checkPercent(p, n int) error {
	if p < 0 || p > MaxParityPercent || (p > 0 && n > 0) {
		return schemeErr(NoField, "", "parity: expected a percentage 0..%d and no parity count with it, got %d percent and %d parity bytes",
			MaxParityPercent, p, n)
	}
	return nil
}

// percentCount is the parity bytes of a clear message of length bytes under percentage p, in integers.
func percentCount(p, length int) int {
	return min(MaxParity, (p*length+99)/100)
}

// largestClear is the longest clear message under percentage p, 1 to 100, whose sent length fits maxBlock.
func largestClear(p int) int {
	length := 0
	for length+1+percentCount(p, length+1) <= maxBlock {
		length++
	}
	return length
}

// clearLength is the one clear length whose sent length under percentage p (1 to 100) is sent, or -1.
func clearLength(p, sent int) int {
	for length := 0; length <= min(sent, maxBlock); length++ {
		if length+percentCount(p, length) == sent {
			return length
		}
	}
	return -1
}

// protectPercent is plain followed by the parity bytes percentage p gives; with p = 0 it is plain itself.
func protectPercent(plain []byte, p int) ([]byte, error) {
	if p == 0 {
		return plain, nil
	}
	if limit := largestClear(p); len(plain) > limit {
		return nil, packErr(NoField, "", "the message is %d bytes, above the limit of %d bytes for %d percent parity",
			len(plain), limit, p)
	}
	return protect(plain, percentCount(p, len(plain)))
}

// repairPercent is repair under percentage p: the count comes from the received length and a limit above
// half of it is lowered. A limit outside 0..16 is refused first; p = 0 has the rule of a count of 0.
func repairPercent(received []byte, p, limit int) ([]byte, int, error) {
	if p == 0 {
		if err := checkLimit(limit, 0); err != nil {
			return nil, 0, err
		}
		return received, 0, nil
	}
	if limit < 0 || limit > maxPercentLimit {
		return nil, 0, schemeErr(NoField, "", "correction limit: expected 0..%d under a parity percentage, got %d",
			maxPercentLimit, limit)
	}
	if len(received) > maxBlock {
		return repair(received, 1, 0)
	}
	length := clearLength(p, len(received))
	if length < 0 {
		return nil, 0, uncorrectable("no clear length gives the received length")
	}
	n := len(received) - length
	return repair(received, n, min(limit, n/2))
}
