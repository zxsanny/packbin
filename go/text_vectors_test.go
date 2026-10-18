package packbin

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"os"
	"os/exec"
	"strings"
	"testing"
)

// The compact text vectors (fixtures/text/vectors.txt, AZ-2647) replayed by Go: AZ-2653 AC-1 (pack),
// AC-2 (unpack), AC-3 (the ring packets), AC-4 (bad rows and bit flips) and AC-6 (invalid UTF-8).

type textRow struct {
	kind string
	id   string
	cols []string
}

func textRows(t testing.TB) []textRow {
	t.Helper()
	raw, err := os.ReadFile("../fixtures/text/vectors.txt")
	if err != nil {
		t.Fatalf("read vectors.txt: %v", err)
	}
	var out []textRow
	for _, line := range strings.Split(string(raw), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		f := strings.Fields(line)
		out = append(out, textRow{kind: f[0], id: f[1], cols: f[2:]})
	}
	return out
}

func textRowsOf(t testing.TB, kind string) []textRow {
	var out []textRow
	for _, r := range textRows(t) {
		if r.kind == kind {
			out = append(out, r)
		}
	}
	if len(out) == 0 {
		t.Fatalf("vectors.txt has no %s rows", kind)
	}
	return out
}

// rowText is the text of a row: the hex of its UTF-8 bytes, "-" for the empty text.
func rowText(t testing.TB, hexText string) string {
	t.Helper()
	if hexText == "-" {
		return ""
	}
	return string(mustHex(t, hexText))
}

func stringScheme(t testing.TB) *Scheme { return mustScheme(t, 1, Utf8(0, "s"), U8(1, "after")) }

// unpackField unpacks a field followed by the byte 5a; it reports a panic as a failure.
func unpackField(t testing.TB, field []byte) (text string, after any, err error) {
	t.Helper()
	defer func() {
		if r := recover(); r != nil {
			t.Fatalf("unpack of %x panicked: %v", field, r)
		}
	}()
	row, err := UnpackMap(append(append([]byte{1}, field...), 0x5a), stringScheme(t))
	if err != nil {
		return "", nil, err
	}
	return row["s"].(string), row["after"], nil
}

func TestACTextEncRowsPack(t *testing.T) {
	bad := 0
	rows := textRowsOf(t, "enc")
	for _, r := range rows {
		// Arrange
		text := rowText(t, r.cols[0])

		// Act
		got := mustPack(t, mustScheme(t, 1, Utf8(0, "s")), gm("s", text))

		// Assert
		if want := "01" + r.cols[1]; got != want {
			bad++
			t.Errorf("%s: got %s, want %s", r.id, got, want)
		}
	}
	t.Logf("%d enc rows, %d mismatches", len(rows), bad)
}

func TestACTextEncAndAltRowsUnpack(t *testing.T) {
	for _, kind := range []string{"enc", "alt"} {
		for _, r := range textRowsOf(t, kind) {
			// Act
			text, after, err := unpackField(t, mustHex(t, r.cols[1]))

			// Assert
			if err != nil || text != rowText(t, r.cols[0]) || after != uint8(0x5a) {
				t.Errorf("%s: got %q after %v err %v, want %q and the byte 5a", r.id, text, after, err, rowText(t, r.cols[0]))
			}
		}
	}
}

var refusalKinds = map[string]textRefusal{
	"short": textShort, "varint": textVarint, "mode": textBadMode, "pad": textPad, "code": textCode,
	"cap": textCap, "esc": textEsc, "utf8": textUtf8, "raw": textRaw, "length": textLength,
}

func TestACTextBadRowsAreRefused(t *testing.T) {
	seen := map[string]bool{}
	for _, r := range textRowsOf(t, "bad") {
		// Arrange
		var buf []byte
		if len(r.cols) > 1 {
			buf = mustHex(t, r.cols[1])
		}

		// Act
		_, _, got := decodeText(buf, 0)
		text, _, err := unpackField(t, buf)

		// Assert
		seen[r.cols[0]] = true
		if got.kind != refusalKinds[r.cols[0]] {
			t.Errorf("%s: decoder kind %d, want %s", r.id, got.kind, r.cols[0])
		}
		e := asError(t, err, ShortPacket)
		if text != "" || e.Field != 0 || e.Name != "s" {
			t.Errorf("%s: got %q and %+v", r.id, text, e)
		}
	}
	for kind := range refusalKinds {
		if !seen[kind] {
			t.Errorf("no bad row of kind %s", kind)
		}
	}
}

// AC-6: escape bytes and a raw payload that are not UTF-8 are refused as utf8.
func TestACTextInvalidUtf8IsRefused(t *testing.T) {
	for _, id := range []string{
		"bad.raw_invalid_utf8", "bad.raw_bad_lead", "bad.esc_utf8_overlong", "bad.esc_utf8_surrogate",
		"bad.esc_utf8_above_10ffff", "bad.esc_utf8_stray_continuation", "bad.esc_utf8_bad_lead_ff",
		"bad.esc_utf8_bad_continuation", "bad.esc_utf8_overlong3",
	} {
		found := false
		for _, r := range textRowsOf(t, "bad") {
			if r.id != id {
				continue
			}
			found = true
			if _, _, got := decodeText(mustHex(t, r.cols[1]), 0); got.kind != textUtf8 {
				t.Errorf("%s: kind %d, want utf8", id, got.kind)
			}
		}
		if !found {
			t.Errorf("no bad row %s", id)
		}
	}
}

// AC-4: every bit of the payload of a flip row's field, flipped, gives a string or an error and never
// disturbs the byte after the field.
func TestACTextFlippedBitsNeverReadPastThePayload(t *testing.T) {
	fields := map[string][]byte{}
	for _, r := range textRowsOf(t, "enc") {
		fields[r.id] = mustHex(t, r.cols[1])
	}
	flips := textRowsOf(t, "flip")
	texts, errs := 0, 0
	for _, r := range flips {
		field := fields[r.cols[0]]
		if field == nil {
			t.Fatalf("%s: no enc row %s", r.id, r.cols[0])
		}
		_, header := decodeVarintLen(field)
		for bit := 0; bit < 8*(len(field)-header); bit++ {
			// Arrange
			flipped := append([]byte{}, field...)
			flipped[header+bit/8] ^= 0x80 >> (bit % 8)

			// Act
			_, after, err := unpackField(t, flipped)

			// Assert
			if err != nil {
				asError(t, err, ShortPacket)
				errs++
				continue
			}
			texts++
			if after != uint8(0x5a) {
				t.Errorf("%s bit %d: the byte after the string is %v", r.id, bit, after)
			}
		}
	}
	t.Logf("%d flip rows: %d bit flips gave a string, %d an error", len(flips), texts, errs)
}

func decodeVarintLen(field []byte) (count, size int) {
	for size < 3 {
		b := field[size]
		count |= int(b&0x7f) << (7 * size)
		size++
		if b&0x80 == 0 {
			break
		}
	}
	return count, size
}

func textUserScheme(t testing.TB) *Scheme {
	return mustScheme(t, 1, Utf8(0, "username"),
		List("roles", Utf8(0, "role")),
		Dict("access", List("actions", Utf8(0, "action"))))
}

func textNestedScheme(t testing.TB) *Scheme {
	return mustScheme(t, 1, Dict("access", List("rows", Dict("row", Utf8(0, "op")))))
}

func anys(items ...string) []any {
	out := make([]any, len(items))
	for i, s := range items {
		out[i] = s
	}
	return out
}

// AC-3: the ring packets of the vectors file, packed from their rows and unpacked back to them.
func TestACTextRefRowsAreTheRingPackets(t *testing.T) {
	user := func(name string, roles []any, access map[string]any) map[string]any {
		return gm("username", name, "roles", roles, "access", access)
	}
	cases := map[string]struct {
		scheme *Scheme
		row    map[string]any
	}{
		"ref.user": {textUserScheme(t), user("zxsanny", anys("user", "dispatcher"), gm(
			"channel", anys("read"), "map", anys("read", "gps_fix", "set", "edit"), "store", anys("read", "write")))},
		"ref.nested": {textNestedScheme(t), gm("access", gm(
			"map", []any{gm("op", "gps_fix")}, "store", []any{gm("op", "read"), gm("op", "write")}))},
		"ref.user_ua": {textUserScheme(t), user("Олександр", anys("диспетчер", "Оператор"), gm(
			"карта", anys("читати", "правити"), "канал", anys("читати")))},
		"ref.nested_mixed": {textNestedScheme(t), gm("access", gm(
			"Карта", []any{gm("op", "gps_fix", "note", "увага 48.46, 35.04")}, "store", []any{gm("op", "ЧИТАТИ")}))},
	}
	for _, r := range textRowsOf(t, "ref") {
		c, ok := cases[r.id]
		if !ok {
			t.Errorf("no case for %s", r.id)
			continue
		}
		// Act
		packed := mustPack(t, c.scheme, c.row)
		back := mustUnpackMap(t, c.scheme, r.cols[0])

		// Assert
		if packed != r.cols[0] {
			t.Errorf("%s: packed %s, want %s", r.id, packed, r.cols[0])
		}
		again := mustPack(t, c.scheme, back)
		if again != r.cols[0] {
			t.Errorf("%s: the unpacked row repacks to %s", r.id, again)
		}
		delete(cases, r.id)
	}
	if len(cases) != 0 {
		t.Errorf("rows missing from vectors.txt: %v", cases)
	}
}

// The committed tables equal fixtures/text/tables.json: its sha256, its alphabets and every length.
func TestTextTablesMatchTheFrozenFile(t *testing.T) {
	// Arrange
	raw, err := os.ReadFile("../fixtures/text/tables.json")
	if err != nil {
		t.Fatal(err)
	}
	var tables struct {
		Alphabets map[string]string   `json:"alphabets"`
		Upper     map[string][]string `json:"upper"`
		Shared    string              `json:"shared"`
		Numset    string              `json:"numset"`
		Modes     map[string]struct {
			Lengths []int `json:"lengths"`
		} `json:"modes"`
	}
	if err := json.Unmarshal(raw, &tables); err != nil {
		t.Fatal(err)
	}

	// Assert
	if sum := sha256.Sum256(raw); hex.EncodeToString(sum[:]) != textTablesSHA256 {
		t.Errorf("tables.json sha256 %x, the Go constant says %s", sum, textTablesSHA256)
	}
	for i, name := range []string{"ua", "ru", "en", "num"} {
		got := textModes[i].length
		want := tables.Modes[name].Lengths
		if len(got) != len(want) {
			t.Fatalf("%s: %d lengths, want %d", name, len(got), len(want))
		}
		for j := range want {
			if int(got[j]) != want[j] {
				t.Errorf("%s: length %d is %d, want %d", name, j, got[j], want[j])
			}
		}
		if i < 3 {
			if string(textModes[i].letters) != tables.Alphabets[name] {
				t.Errorf("%s: alphabet differs from tables.json", name)
			}
			for j, up := range tables.Upper[name] {
				if string(textModes[i].upper[j]) != up && !(up == "" && textModes[i].upper[j] == 0) {
					t.Errorf("%s: capital %d is %q, want %q", name, j, textModes[i].upper[j], up)
				}
			}
		}
	}
	if string(textModes[0].chars) != tables.Shared || string(textModes[3].chars) != tables.Numset {
		t.Errorf("shared or number characters differ from tables.json")
	}
}

// The committed constants file is the emitter's output (the emitter ends it with one blank line more
// than gofmt keeps). Runs where python3 is on the PATH; the other tests check the values anyway.
func TestTextTablesFileIsTheEmitterOutput(t *testing.T) {
	py, err := exec.LookPath("python3")
	if err != nil {
		t.Skip("python3 is not installed; TestTextTablesMatchTheFrozenFile checks the values")
	}
	out, err := exec.Command(py, "-I", "../scripts/text/emit_tables.py", "go").Output()
	if err != nil {
		t.Fatalf("emit_tables.py: %v", err)
	}
	committed, err := os.ReadFile("text_tables.go")
	if err != nil {
		t.Fatal(err)
	}
	if !bytes.Equal(bytes.TrimRight(out, "\n"), bytes.TrimRight(committed, "\n")) {
		t.Fatal("go/text_tables.go differs from emit_tables.py go")
	}
}
