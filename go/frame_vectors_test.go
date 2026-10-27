package packbin

import (
	"encoding/hex"
	"fmt"
	"os"
	"strconv"
	"strings"
	"testing"
)

// AZ-3293 AC-1: every row of fixtures/frame/vectors.txt (the row syntax is in fixtures/frame/README.md) through the
// public API. A row's input fields build the call and every output field of the row is compared with what the call
// gave; a refusal must write nothing and leave a window as it was.

const (
	frameVectorsPath = "../fixtures/frame/vectors.txt"
	frameSentinel    = 0xA5
)

type frameRow struct {
	op     string
	name   string
	fields map[string]string
}

func (r frameRow) has(name string) bool { _, ok := r.fields[name]; return ok }

func (r frameRow) text(name string) string { return r.fields[name] }

func (r frameRow) number(t testing.TB, name string) int {
	t.Helper()
	n, err := strconv.Atoi(r.fields[name])
	if err != nil {
		t.Fatalf("%s: %s=%q: %v", r.name, name, r.fields[name], err)
	}
	return n
}

func (r frameRow) bytes(t testing.TB, name string) []byte {
	t.Helper()
	return frameHex(t, r.fields[name])
}

func frameHex(t testing.TB, text string) []byte {
	t.Helper()
	if text == "-" {
		return []byte{}
	}
	b, err := hex.DecodeString(text)
	if err != nil {
		t.Fatalf("not hex %q: %v", text, err)
	}
	return b
}

func frameUnhex(b []byte) string {
	if len(b) == 0 {
		return "-"
	}
	return hex.EncodeToString(b)
}

func loadFrameRows(t testing.TB, path string) []frameRow {
	t.Helper()
	raw, err := os.ReadFile(path)
	if err != nil {
		t.Fatal(err)
	}
	var rows []frameRow
	for _, line := range strings.Split(string(raw), "\n") {
		if line == "" || line[0] == '#' {
			continue
		}
		fields := map[string]string{}
		for _, token := range strings.Split(line, " ") {
			name, value, ok := strings.Cut(token, "=")
			if !ok {
				t.Fatalf("token %q of %q has no =", token, line)
			}
			fields[name] = value
		}
		rows = append(rows, frameRow{op: fields["op"], name: fields["case"], fields: fields})
	}
	return rows
}

func frameRowNamed(t testing.TB, name string) frameRow {
	t.Helper()
	for _, r := range loadFrameRows(t, frameVectorsPath) {
		if r.name == name {
			return r
		}
	}
	t.Fatalf("no row %s", name)
	return frameRow{}
}

// frameKindName is the error kind name of the fixture, "Ok" for nil.
func frameKindName(err error) string {
	if err == nil {
		return "Ok"
	}
	e, ok := err.(*Error)
	if !ok {
		return "other:" + err.Error()
	}
	switch e.Kind {
	case BadValue:
		return "BadValue"
	case TooLong:
		return "TooLong"
	case BufferFull:
		return "BufferFull"
	case ShortPacket:
		return "ShortPacket"
	case TagMismatch:
		return "TagMismatch"
	case Duplicate:
		return "Duplicate"
	case TooOld:
		return "TooOld"
	}
	return "other:" + e.Kind.String()
}

func frameWindowText(w *ReplayWindow) string { return fmt.Sprintf("%x:%x", w.Top(), w.Bits()) }

func frameDirs(r frameRow) FrameDirections {
	var set FrameDirections
	dirs := "123"
	if r.has("dirs") {
		dirs = r.text("dirs")
	}
	for _, c := range dirs {
		set |= 1 << (c - '1')
	}
	return set
}

func frameLoad(t testing.TB, r frameRow) (*FrameSession, error) {
	tag := 4
	if r.has("tag_len") {
		tag = r.number(t, "tag_len")
	}
	epoch, err := strconv.ParseUint(r.text("epoch"), 10, 32)
	if err != nil {
		t.Fatal(err)
	}
	return LoadFrameSession(r.bytes(t, "key"), uint32(epoch), FrameConfig{TagLength: tag, Directions: frameDirs(r)})
}

func frameContext(t testing.TB, r frameRow) MsgContext {
	return NewMsgContext(r.bytes(t, "msg_id"), r.number(t, "kind"))
}

func sentinels(n int) []byte {
	b := make([]byte, n)
	for i := range b {
		b[i] = frameSentinel
	}
	return b
}

func untouched(b []byte) bool {
	for _, v := range b {
		if v != frameSentinel {
			return false
		}
	}
	return true
}

// runFrameRow gives the output fields the call produced for the row.
func runFrameRow(t testing.TB, r frameRow) map[string]string {
	t.Helper()
	switch r.op {
	case "keys":
		return runFrameKeys(t, r)
	case "seal":
		return runFrameSeal(t, r)
	case "open":
		return runFrameOpen(t, r)
	case "mac":
		return runFrameMac(t, r)
	case "replay":
		return runFrameReplay(t, r)
	}
	t.Fatalf("unknown op %s", r.op)
	return nil
}

func runFrameKeys(t testing.TB, r frameRow) map[string]string {
	epoch, err := strconv.ParseUint(r.text("epoch"), 10, 32)
	if err != nil {
		t.Fatal(err)
	}
	if r.has("label") {
		mac, err := DeriveMacKey(r.bytes(t, "key"), uint32(epoch), r.bytes(t, "label"))
		if err != nil {
			return map[string]string{"k_label": "BadValue"}
		}
		defer mac.Close()
		return map[string]string{"k_label": frameUnhex(mac.key)}
	}
	dir := FrameDirection(r.number(t, "dir"))
	session, err := LoadFrameSession(r.bytes(t, "key"), uint32(epoch),
		FrameConfig{TagLength: 4, Directions: FrameDirections(1 << (dir - 1))})
	if err != nil {
		return map[string]string{"k_enc": "BadValue", "k_mac": "BadValue"}
	}
	defer session.Close()
	return map[string]string{"k_enc": frameUnhex(session.current.enc[dir-1]), "k_mac": frameUnhex(session.current.mac[dir-1])}
}

func runFrameSeal(t testing.TB, r frameRow) map[string]string {
	session, err := frameLoad(t, r)
	if err != nil {
		return map[string]string{"result": frameKindName(err)}
	}
	defer session.Close()
	size := 300
	if r.has("out_len") {
		size = r.number(t, "out_len")
	}
	buffer := sentinels(size)
	n, err := session.Seal(FrameDirection(r.number(t, "dir")), frameContext(t, r), r.bytes(t, "ad"), r.bytes(t, "clear"),
		r.bytes(t, "plain"), buffer)
	if err == nil {
		return map[string]string{"body": frameUnhex(buffer[:n])}
	}
	result := frameKindName(err)
	if n != 0 || !untouched(buffer) {
		result += " (a refused seal wrote bytes)"
	}
	return map[string]string{"result": result}
}

func runFrameOpen(t testing.TB, r frameRow) map[string]string {
	var window *ReplayWindow
	before := ""
	if r.has("window") {
		top, bits, _ := strings.Cut(r.text("window"), ":")
		topValue, err1 := strconv.ParseUint(top, 16, 64)
		bitsValue, err2 := strconv.ParseUint(bits, 16, 64)
		if err1 != nil || err2 != nil {
			t.Fatalf("%s: window %q", r.name, r.text("window"))
		}
		window = NewReplayWindow(topValue, bitsValue)
		before = frameWindowText(window)
	}
	got := map[string]string{}
	session, err := frameLoad(t, r)
	if err == nil && r.has("prev_key") {
		prevEpoch, perr := strconv.ParseUint(r.text("prev_epoch"), 10, 32)
		if perr != nil {
			t.Fatal(perr)
		}
		if err = session.SetPrevious(r.bytes(t, "prev_key"), uint32(prevEpoch)); err != nil {
			session.Close()
		}
	}
	if err != nil {
		got["result"] = frameKindName(err)
	} else {
		defer session.Close()
		size := 300
		if r.has("out_len") {
			size = r.number(t, "out_len")
		}
		buffer := sentinels(size)
		var counter uint64
		if r.has("counter") {
			counter, _ = strconv.ParseUint(r.text("counter"), 10, 64)
		}
		opened, oerr := session.Open(FrameDirection(r.number(t, "dir")), frameContext(t, r), r.bytes(t, "ad"), r.bytes(t, "body"),
			r.number(t, "clear_len"), buffer, window, counter)
		got["result"] = frameKindName(oerr)
		if oerr == nil {
			got["slot"] = opened.Slot.String()
			got["plain"] = frameUnhex(buffer[:opened.PlainLength])
		} else {
			if !untouched(buffer) {
				got["result"] += " (a refused open wrote bytes)"
			}
			if window != nil && frameWindowText(window) != before {
				got["result"] += " (a refused open changed the window)"
			}
		}
	}
	if window != nil {
		got["window_after"] = frameWindowText(window)
	}
	return got
}

func runFrameMac(t testing.TB, r frameRow) map[string]string {
	epoch, err := strconv.ParseUint(r.text("epoch"), 10, 32)
	if err != nil {
		t.Fatal(err)
	}
	mac, err := DeriveMacKey(r.bytes(t, "key"), uint32(epoch), r.bytes(t, "label"))
	if err != nil {
		return map[string]string{"result": frameKindName(err)}
	}
	defer mac.Close()
	var parts [][]byte
	if r.has("parts") {
		for _, p := range strings.Split(r.text("parts"), "|") {
			parts = append(parts, frameHex(t, p))
		}
	} else {
		parts = [][]byte{r.bytes(t, "message")}
	}
	if r.has("verify") {
		return map[string]string{"valid": strconv.FormatBool(mac.Verify(r.bytes(t, "verify"), parts...))}
	}
	tag := make([]byte, r.number(t, "n"))
	if err := mac.Tag(tag, parts...); err != nil {
		return map[string]string{"result": frameKindName(err)}
	}
	return map[string]string{"tag": frameUnhex(tag)}
}

func runFrameReplay(t testing.TB, r frameRow) map[string]string {
	window := &ReplayWindow{}
	var results, states []string
	for _, step := range strings.Split(r.text("steps"), ",") {
		verb, number, _ := strings.Cut(step, ":")
		n, err := strconv.ParseUint(number, 10, 64)
		if err != nil {
			t.Fatalf("%s: step %q", r.name, step)
		}
		if verb == "check" {
			results = append(results, window.Check(n).String())
		} else {
			window.Commit(n)
			states = append(states, frameWindowText(window))
		}
	}
	got := map[string]string{"results": strings.Join(results, ","), "states": "-"}
	if len(states) > 0 {
		got["states"] = strings.Join(states, ",")
	}
	return got
}

func frameOutputNames(op string) []string {
	switch op {
	case "keys":
		return []string{"k_enc", "k_mac", "k_label"}
	case "seal":
		return []string{"body", "result"}
	case "open":
		return []string{"result", "slot", "plain", "window_after"}
	case "mac":
		return []string{"tag", "valid", "result"}
	}
	return []string{"results", "states"}
}

// frameMismatches lists every output field of every row that differs, as "case field: expected X, got Y".
func frameMismatches(t testing.TB, rows []frameRow) []string {
	t.Helper()
	var problems []string
	for _, r := range rows {
		got := runFrameRow(t, r)
		for _, name := range frameOutputNames(r.op) {
			if !r.has(name) {
				continue
			}
			value, ok := got[name]
			switch {
			case !ok:
				problems = append(problems, fmt.Sprintf("%s %s: the row has it and the call gave none", r.name, name))
			case value != r.text(name):
				problems = append(problems, fmt.Sprintf("%s %s: expected %s, got %s", r.name, name, r.text(name), value))
			}
		}
	}
	return problems
}

func TestAC1EveryRowOfTheFrameFixtureMatches(t *testing.T) {
	// Arrange
	rows := loadFrameRows(t, frameVectorsPath)

	// Act
	problems := frameMismatches(t, rows)

	// Assert
	if len(problems) != 0 {
		t.Fatalf("%d of %d rows differ:\n%s", len(problems), len(rows), strings.Join(problems, "\n"))
	}
	if len(rows) < 157 {
		t.Fatalf("only %d rows", len(rows))
	}
	for _, op := range []string{"keys", "seal", "open", "mac", "replay"} {
		found := false
		for _, r := range rows {
			found = found || r.op == op
		}
		if !found {
			t.Fatalf("no %s row", op)
		}
	}
	t.Logf("frame vector rows: %d of %d pass", len(rows)-len(problems), len(rows))
}

func TestAC1TheWorkedExamplesAreInTheFileAndMatch(t *testing.T) {
	for _, name := range []string{"E1.seal", "E2.seal", "E3.seal", "E3.seal16", "E4.mac", "E5.mac", "E4.keys"} {
		t.Run(name, func(t *testing.T) {
			// Arrange
			row := frameRowNamed(t, name)

			// Act
			problems := frameMismatches(t, []frameRow{row})

			// Assert
			if len(problems) != 0 {
				t.Fatal(problems)
			}
		})
	}
}

func TestAC1TheLargestEpochWorksAndTheNextOneIsRefused(t *testing.T) {
	// Arrange
	var largest []frameRow
	for _, r := range loadFrameRows(t, frameVectorsPath) {
		if r.op == "keys" && r.text("epoch") == "16777215" {
			largest = append(largest, r)
		}
	}
	refused := frameRowNamed(t, "refuse.seal.epoch1000000")

	// Act
	problems := frameMismatches(t, largest)
	result := runFrameRow(t, refused)["result"]

	// Assert
	if len(largest) != 3 || len(problems) != 0 {
		t.Fatalf("%d rows, problems %v", len(largest), problems)
	}
	if refused.text("result") != "BadValue" || result != "BadValue" {
		t.Fatalf("row %s, call %s", refused.text("result"), result)
	}
}

// A copy of the file with one expected hex digit changed makes that row, and only that row, fail.
func TestAC1ACorruptedRowFailsAndNamesTheRow(t *testing.T) {
	for _, c := range []struct{ op, field string }{
		{"seal", "body"}, {"open", "plain"}, {"mac", "tag"}, {"keys", "k_enc"}, {"replay", "states"},
	} {
		t.Run(c.op, func(t *testing.T) {
			// Arrange
			rows := loadFrameRows(t, frameVectorsPath)
			at := -1
			for i, r := range rows {
				if r.op == c.op && r.has(c.field) && at < 0 {
					at = i
				}
			}
			if at < 0 {
				t.Fatalf("no %s row with %s", c.op, c.field)
			}
			value := rows[at].fields[c.field]
			flipped := '0'
			if value[0] == '0' {
				flipped = '1'
			}
			rows[at].fields[c.field] = string(flipped) + value[1:]

			// Act
			problems := frameMismatches(t, rows)

			// Assert
			if len(problems) != 1 || !strings.HasPrefix(problems[0], rows[at].name+" "+c.field) {
				t.Fatalf("problems %v", problems)
			}
		})
	}
}
