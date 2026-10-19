package main

import (
	pb "github.com/zxsanny/packbin/go"
)

// The probe schemes, the unpack and repair wrappers, the mutator and the session helpers.

// ---------------------------------------------------------------- schemes and calls

func must(s *pb.Scheme, err error) *pb.Scheme {
	if err != nil {
		panic(err)
	}
	return s
}

var (
	sScheme = must(pb.NewScheme(1, pb.Utf8(0, "s")))
	lScheme = must(pb.NewScheme(1, pb.List("l", pb.Utf8(0, "e"))))
	dScheme = must(pb.NewScheme(1, pb.Dict("d", pb.U8(0, "v"))))
)

// bScheme is a scheme whose clear message is the type byte and clearLen-1 raw bytes, with n parity bytes.
func bScheme(ty byte, clearLen, n int) *pb.Scheme {
	s := must(pb.NewScheme(int(ty), pb.Bytes(0, "b", max(clearLen, 1)-1)))
	return must(s.WithParity(n))
}

func readText(f []byte) (string, error) {
	row, err := pb.UnpackMap(append([]byte{1}, f...), sScheme)
	if err != nil {
		return "", err
	}
	s, _ := row["s"].(string)
	return s, nil
}

func protect(clear []byte, n int) []byte {
	out, err := pb.Pack(bScheme(clear[0], len(clear), n), map[string]any{"b": clear[1:]})
	if err != nil {
		panic(err)
	}
	return out
}

func repairTyped(buf []byte, n, t int, ty byte) ([]byte, int, error) {
	clearLen := max(len(buf)-n, 1)
	row, rep, err := pb.UnpackMapRepair(buf, t, bScheme(ty, clearLen, n))
	if err != nil {
		return nil, 0, err
	}
	b, _ := row["b"].([]byte)
	return append([]byte{ty}, b...), rep, nil
}

func repairBytes(buf []byte, n, t int) ([]byte, int, error) {
	ty := byte(1)
	if len(buf) > 0 {
		ty = buf[0]
	}
	return repairTyped(buf, n, t, ty)
}

func hamming(a, b []byte) int {
	d := 0
	for i := range min(len(a), len(b)) {
		if a[i] != b[i] {
			d++
		}
	}
	return d
}

func corrupt(w []byte, k int, r *rng) {
	hit := map[int]bool{}
	for len(hit) < min(k, len(w)) {
		p := r.below(len(w))
		if !hit[p] {
			hit[p] = true
			w[p] ^= r.byte() | 1
		}
	}
}

var special = []byte{0x00, 0x10, 0x7f, 0x80, 0xff, 0xc0, 0xe0, 0xf0, 0xf4, 0xed, 0x1c, 0xfc}

func mutate(r *rng, data []byte, pool [][]byte) []byte {
	for range 1 + r.below(4) {
		l := len(data)
		switch r.below(9) {
		case 0:
			if l > 0 {
				data[r.below(l)] ^= 1 << uint(r.below(8))
			}
		case 1:
			if l > 0 {
				data[r.below(l)] = r.byte()
			}
		case 2:
			p := r.below(l + 1)
			data = append(data[:p], append([]byte{r.byte()}, data[p:]...)...)
		case 3:
			if l > 0 {
				p := r.below(l)
				data = append(data[:p], data[p+1:]...)
			}
		case 4:
			data = data[:r.below(l+1)]
		case 5:
			data = append(data, r.fill(1+r.below(16))...)
		case 6:
			if len(pool) > 0 {
				other := pool[r.below(len(pool))]
				cut, from := r.below(l+1), r.below(len(other)+1)
				data = append(data[:cut:cut], other[from:]...)
			}
		case 7:
			if l > 0 {
				data[r.below(l)] = special[r.below(len(special))]
			}
		case 8:
			drop := min(1+r.below(3), len(data))
			groups := 1 + r.below(3)
			c := r.below(1 << (7 * groups))
			data = append(varint(c), data[drop:]...)
		}
	}
	return data
}

func clone(b []byte) []byte { return append([]byte(nil), b...) }

func rawScheme(ty, l, n int) *pb.Scheme {
	s := must(pb.NewScheme(ty, pb.Bytes(0, "b", l)))
	return must(s.WithParity(n))
}

func sessionPack(s *pb.PackSession, body []byte, n int) []byte {
	out, err := s.Pack(rawScheme(1, len(body), n), map[string]any{"b": body})
	if err != nil {
		panic(err)
	}
	return out
}
