package packbin

import (
	"strings"
	"testing"
)

func nameScheme(t testing.TB) *Scheme { return mustScheme(t, 1, Utf8(0, "name")) }

func TestUtf8Pack(t *testing.T) {
	runPacks(t, []packCase{
		{"a string is its byte count then its bytes", nameScheme, gm("name", "zxsanny"), "0107007a7873616e6e79"},
		{"an empty string", nameScheme, gm("name", ""), "010000"},
		{"the count is bytes, not characters", nameScheme, gm("name", "é€"), "010500c3a9e282ac"},
		{"a pointer to a string", nameScheme, gm("name", func() *string { s := "a"; return &s }()), "01010061"},
		{"a named string type", nameScheme, gm("name", namedString("a")), "01010061"},
		{"65535 bytes", nameScheme, gm("name", strings.Repeat("a", 65535)), "01ffff" + strings.Repeat("61", 65535)},
		{"a lone string goes to every round", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "n"), Times(1, 0, Utf8(1, "s")))
		}, gm("n", 2, "s", "ab"), "01020200616202006162"},
		{"a list of strings is one string a round", func(t testing.TB) *Scheme {
			return mustScheme(t, 1, U8(0, "n"), Times(1, 0, Utf8(1, "s")))
		}, gm("n", 2, "s", []string{"a", "bc"}), "010201006102006263"},
	})
}

type namedString string

func TestUtf8Refusals(t *testing.T) {
	runRefusals(t, []refusalCase{
		{"65536 bytes", nameScheme, gm("name", strings.Repeat("a", 65536)), 0, "name", "utf-8 length 65536"},
		{"not valid UTF-8", nameScheme, gm("name", "a\xffb"), 0, "name", "not valid UTF-8"},
		{"a truncated sequence", nameScheme, gm("name", "\xe2\x82"), 0, "name", "not valid UTF-8"},
		{"a surrogate", nameScheme, gm("name", "\xed\xa0\x80"), 0, "name", "not valid UTF-8"},
		{"not a string", nameScheme, gm("name", 5), 0, "name", "expected a string for utf8"},
		{"bytes are not a string", nameScheme, gm("name", []byte("a")), 0, "name", "expected a string for utf8"},
		{"absent", nameScheme, gm(), 0, "name", "missing name"},
		{"a nil pointer is no value", nameScheme, gm("name", (*string)(nil)), 0, "name", "missing name"},
	})
}

func TestUtf8Unpack(t *testing.T) {
	cases := []struct {
		name string
		wire string
		want string
	}{
		{"a string", "0107007a7873616e6e79", "zxsanny"},
		{"empty", "010000", ""},
		{"a byte order mark is kept", "010600efbbbf616263", "\ufeffabc"},
		{"multi-byte", "010500c3a9e282ac", "é€"},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Act
			got := mustUnpackMap(t, nameScheme(t), c.wire)
			again := mustPack(t, nameScheme(t), got)

			// Assert
			if got["name"] != c.want || again != strings.ReplaceAll(c.wire, " ", "") {
				t.Fatalf("got %#v, repacked %s", got, again)
			}
		})
	}
}

func TestUtf8UnpackRefusals(t *testing.T) {
	cases := []struct {
		name         string
		wire         string
		needed, left int
	}{
		{"short body", "0107007a78", 7, 2},
		{"short count", "0107", 2, 1},
		{"no count", "01", 2, 0},
		{"invalid UTF-8", "010200ff fe", 0, 4},
		{"an overlong sequence", "010200c080", 0, 4},
		{"a surrogate", "010300eda080", 0, 5},
		{"above U+10FFFF", "010400f4908080", 0, 6},
	}
	for _, c := range cases {
		t.Run(c.name, func(t *testing.T) {
			// Act
			row, err := Unpack(mustHex(t, c.wire), nameScheme(t))

			// Assert
			e := asError(t, err, ShortPacket)
			if row != nil || e.Field != 0 || e.Name != "name" || e.Needed != c.needed || e.Left != c.left {
				t.Fatalf("row %v err %+v", row, e)
			}
		})
	}
}

type userRow struct {
	Name  string
	Alias *string
}

func TestUtf8TypedRow(t *testing.T) {
	// Arrange
	s := mustScheme(t, 1,
		Bind(Utf8(0, "name"), func(r *userRow) string { return r.Name }, func(r *userRow, v string) { r.Name = v }),
		Flags(1, Bind(Utf8(1, "alias"), func(r *userRow) *string { return r.Alias }, func(r *userRow, v *string) { r.Alias = v })),
	)
	alias := "ab"

	// Act
	both := mustPack(t, s, &userRow{Name: "x", Alias: &alias})
	one := mustPack(t, s, &userRow{Name: "x"})
	back, err := Unpack(mustHex(t, both), s)

	// Assert
	if both != "010100780102006162" || one != "01010078"+"00" {
		t.Fatalf("both %s one %s", both, one)
	}
	if got := back.(*userRow); err != nil || got.Name != "x" || got.Alias == nil || *got.Alias != "ab" {
		t.Fatalf("back %#v %v", back, err)
	}
}

func TestUtf8TypedMemberTypes(t *testing.T) {
	// Act
	_, err := NewScheme(1, Bind(Utf8(0, "name"), func(r *userRow) int { return 0 }, func(r *userRow, v int) {}))

	// Assert
	if e := asError(t, err, InvalidScheme); !strings.Contains(e.Reason, "cannot hold every utf8 value") {
		t.Fatalf("got %v", e)
	}
}
