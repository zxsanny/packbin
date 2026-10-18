package packbin

// Message error correction (contract _docs/02_document/contracts/library/message-ecc.md v1.0.0): a
// Reed-Solomon code over GF(256) with the field polynomial 0x11D, alpha = 2 and generator roots
// alpha^0 .. alpha^(n-1). The code covers one byte that is not sent, the clear length, placed before
// the clear message.

const (
	// MaxParity is the most parity bytes a scheme may declare.
	MaxParity = 32
	// maxBlock is the most bytes a protected message holds: the code word is 255, one byte of it (the
	// clear length) is not sent.
	maxBlock = 254
)

type eccField struct {
	exp [512]byte
	log [256]byte
	// gen[n] is the monic generator of n parity bytes, highest degree first.
	gen [MaxParity + 1][]byte
}

var gf = buildField()

func buildField() *eccField {
	f := &eccField{}
	x := 1
	for i := range 255 {
		f.exp[i] = byte(x)
		f.log[x] = byte(i)
		x <<= 1
		if x&0x100 != 0 {
			x ^= 0x11d
		}
	}
	for i := 255; i < len(f.exp); i++ {
		f.exp[i] = f.exp[i-255]
	}
	g := []byte{1}
	f.gen[0] = g
	for n := 1; n <= MaxParity; n++ {
		out := make([]byte, len(g)+1)
		for j, c := range g {
			out[j] ^= c
			out[j+1] ^= f.mul(c, f.exp[n-1])
		}
		g = out
		f.gen[n] = g
	}
	return f
}

func (f *eccField) mul(a, b byte) byte {
	if a == 0 || b == 0 {
		return 0
	}
	return f.exp[int(f.log[a])+int(f.log[b])]
}

// inv is the inverse of a, which must not be 0.
func (f *eccField) inv(a byte) byte {
	return f.exp[255-int(f.log[a])]
}

// Parity is the count of parity bytes s appends to every packet and checks on unpack: 0 (the default)
// to MaxParity. A nil scheme (an ignored NewScheme error) has none.
func (s *Scheme) Parity() int {
	if s == nil {
		return 0
	}
	return s.parity
}

// WithParity is a copy of s that declares n parity bytes, 0 to MaxParity; s is unchanged. Pack appends
// them to the packet (a packet of more than 254 - n bytes is refused) and Unpack checks them, and with
// UnpackRepair repairs up to n/2 wrong bytes. Both sides declare the same n, as they share the field
// list; the count is not written. Any other n returns an *Error of kind InvalidScheme naming n and
// MaxParity and a nil scheme. The limits of s are kept.
func (s *Scheme) WithParity(n int) (*Scheme, error) {
	if s.unusable() {
		return nil, schemeErr(NoField, "", "%s", s.notMade())
	}
	if err := checkParity(n); err != nil {
		return nil, err
	}
	c := *s
	c.parity = n
	return &c, nil
}

// checkParity refuses a count outside 0..MaxParity, naming it and the limit.
func checkParity(n int) error {
	if n < 0 || n > MaxParity {
		return schemeErr(NoField, "", "parity: expected 0..%d parity bytes, got %d", MaxParity, n)
	}
	return nil
}

// checkLimit refuses a correction limit outside 0..n/2 before any byte is read.
func checkLimit(t, n int) error {
	if t < 0 || t > n/2 {
		return schemeErr(NoField, "", "correction limit: expected 0..%d for %d parity bytes, got %d", n/2, n, t)
	}
	return nil
}

// checkRoom refuses a message of length bytes above 254 - n, naming the length and the limit.
func checkRoom(length, n int) error {
	if n > 0 && length > maxBlock-n {
		return packErr(NoField, "", "the packet would be %d bytes, above the limit of %d bytes for %d parity bytes",
			length, maxBlock-n, n)
	}
	return nil
}

// protect is the message followed by its n parity bytes; with n = 0 it is the message itself. A
// message above 254 - n bytes is refused, naming its length and the limit.
func protect(plain []byte, n int) ([]byte, error) {
	if n == 0 {
		return plain, nil
	}
	if err := checkRoom(len(plain), n); err != nil {
		return nil, err
	}
	out := make([]byte, len(plain)+n)
	copy(out, plain)
	// The parity is the remainder of the clear length and the message, shifted by n places, divided by the
	// generator: reg holds the n bytes still to be added into the places that follow.
	g := gf.gen[n]
	var buf [MaxParity]byte
	reg := buf[:n]
	step := func(m byte) {
		c := m ^ reg[0]
		copy(reg, reg[1:])
		reg[n-1] = 0
		if c == 0 {
			return
		}
		lc := int(gf.log[c])
		for j := range n {
			if gj := g[j+1]; gj != 0 {
				reg[j] ^= gf.exp[int(gf.log[gj])+lc]
			}
		}
	}
	step(byte(len(plain)))
	for _, b := range plain {
		step(b)
	}
	copy(out[len(plain):], reg)
	return out, nil
}
