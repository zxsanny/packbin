package packbin

import "fmt"

// uncorrectable is the error of a message with more wrong bytes than the limit allows. It names no field.
func uncorrectable(reason string) *Error {
	return &Error{Kind: Uncorrectable, Field: NoField, Reason: reason}
}

// repair checks received against n parity bytes and repairs up to t wrong bytes (t is 0..n/2, checked by
// the caller). It returns the clear message and the count of bytes repaired. The clear message is a view
// of received when it is intact and a repaired copy otherwise; received is never written. It never panics
// on hostile bytes; with n = 0 it is the identity.
func repair(received []byte, n, t int) ([]byte, int, error) {
	if n == 0 {
		return received, 0, nil
	}
	size := len(received)
	if size > maxBlock {
		return nil, 0, &Error{Kind: TooLong, Field: NoField, Left: size,
			Reason: fmt.Sprintf("the message is %d bytes, above the limit of %d bytes", size, maxBlock)}
	}
	if size < n {
		return nil, 0, shortErr(NoField, "parity", n, size)
	}
	var buf [MaxParity]byte
	synd := buf[:n]
	if !syndromes(received, synd) {
		return received[:size-n], 0, nil
	}
	if t == 0 {
		return nil, 0, uncorrectable("the message does not match its parity bytes")
	}
	lam := locator(synd)
	deg := len(lam) - 1
	if deg == 0 || deg > t {
		return nil, 0, uncorrectable(fmt.Sprintf("more wrong bytes than the limit of %d", t))
	}
	// Position p (0 = first byte sent) has locator X = alpha^(size-1-p); the unsent length byte is one
	// place before it.
	var rootBuf [MaxParity]int
	roots := rootBuf[:0]
	for p := range size {
		if evaluate(lam, gf.exp[(255-(size-1-p))%255]) == 0 {
			if len(roots) == deg {
				return nil, 0, uncorrectable("the locator has more roots than its degree")
			}
			roots = append(roots, p)
		}
	}
	if len(roots) != deg {
		return nil, 0, uncorrectable("the locator has fewer roots than its degree")
	}
	// The error evaluator omega = (synd * lam) mod x^n, lowest degree first.
	omega := make([]byte, n)
	for i := range n {
		for j, c := range lam {
			if i+j < n {
				omega[i+j] ^= gf.mul(synd[i], c)
			}
		}
	}
	// The derivative in characteristic 2 keeps the odd-degree terms.
	dlam := make([]byte, len(lam)-1)
	for i := 1; i < len(lam); i += 2 {
		dlam[i-1] = lam[i]
	}
	word := append([]byte(nil), received...)
	for _, p := range roots {
		x := gf.exp[(size-1-p)%255]
		xi := gf.inv(x)
		den := evaluate(dlam, xi)
		if den == 0 {
			return nil, 0, uncorrectable("the locator derivative is zero")
		}
		word[p] ^= gf.mul(x, gf.mul(evaluate(omega, xi), gf.inv(den)))
	}
	if syndromes(word, synd) {
		return nil, 0, uncorrectable("the repaired message does not match its parity bytes")
	}
	return word[:size-n], deg, nil
}

// syndromes fills synd (n entries) with the syndromes of the code word: the clear length (word length
// minus n), then the word. It reports whether any is not zero.
func syndromes(word, synd []byte) bool {
	n := len(synd)
	length := byte(len(word) - n)
	var bad byte
	for i := range n {
		s := length
		for _, b := range word {
			if s != 0 {
				s = gf.exp[int(gf.log[s])+i]
			}
			s ^= b
		}
		synd[i] = s
		bad |= s
	}
	return bad != 0
}

// evaluate is p at x, p lowest degree first.
func evaluate(p []byte, x byte) byte {
	var y byte
	for i := len(p) - 1; i >= 0; i-- {
		y = gf.mul(y, x) ^ p[i]
	}
	return y
}

// locator is the error locator by Berlekamp-Massey, lowest degree first, trimmed.
func locator(synd []byte) []byte {
	lam := []byte{1}
	prev := []byte{1}
	l, m := 0, 1
	b := byte(1)
	for r := range synd {
		d := synd[r]
		for i := 1; i <= l; i++ {
			if i < len(lam) {
				d ^= gf.mul(lam[i], synd[r-i])
			}
		}
		if d == 0 {
			m++
			continue
		}
		before := append([]byte(nil), lam...)
		coef := gf.mul(d, gf.inv(b))
		for len(lam) < len(prev)+m {
			lam = append(lam, 0)
		}
		for i, c := range prev {
			lam[i+m] ^= gf.mul(coef, c)
		}
		if 2*l <= r {
			l, prev, b, m = r+1-l, before, d, 1
		} else {
			m++
		}
	}
	for len(lam) > 1 && lam[len(lam)-1] == 0 {
		lam = lam[:len(lam)-1]
	}
	return lam
}
