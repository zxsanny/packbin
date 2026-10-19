package packbin

import (
	"errors"
	"fmt"
	"os"
	"regexp"
	"strings"
	"testing"
	"time"
)

// The shared hostile vectors (fixtures/hostile/cases.txt) replayed by Go. Each scheme is written by hand
// from fixtures/hostile/README.md (ADR-001: no shared walker). The four stages are unpack, construct,
// limit and pack; a refusal must name the rule the table gives, so a refusal by some other rule does
// not pass.

type hostileCase struct {
	id       string
	stage    string
	expected []string
	hex      string
}

func hostileCases(t testing.TB) []hostileCase {
	t.Helper()
	raw, err := os.ReadFile("../fixtures/hostile/cases.txt")
	if err != nil {
		t.Fatalf("read cases.txt: %v", err)
	}
	var out []hostileCase
	for _, line := range strings.Split(string(raw), "\n") {
		line = strings.TrimSpace(line)
		if line == "" || strings.HasPrefix(line, "#") {
			continue
		}
		f := strings.Fields(line)
		if len(f) != 4 {
			t.Fatalf("cases.txt line %q: want 4 fields", line)
		}
		out = append(out, hostileCase{id: f[0], stage: f[1], expected: strings.Split(f[2], "|"), hex: f[3]})
	}
	return out
}

func hostileStage(cases []hostileCase, stage string) []hostileCase {
	var out []hostileCase
	for _, c := range cases {
		if c.stage == stage {
			out = append(out, c)
		}
	}
	return out
}

func (c hostileCase) accepts(kind string) bool {
	for _, e := range c.expected {
		if e == kind {
			return true
		}
	}
	return false
}

// hostileKind is the outcome term of an error value. Unpack reports a value it cannot use as the
// interim bad-value shape of TypeScript (a short packet that needs 0 bytes, README "Outcome terms");
// a short packet that needs bytes is short_packet.
func hostileKind(err error) string {
	var e *Error
	if !errors.As(err, &e) || e == nil {
		return fmt.Sprintf("not an *Error: %v", err)
	}
	if e.Kind == ShortPacket && e.Needed == 0 {
		return BadValue.String()
	}
	return e.Kind.String()
}

// hostileGuard is how long one unpack or construction of a hostile case may take (README: 1 second).
const hostileGuard = time.Second

type hostileRun struct {
	err      error
	panicked any
	hung     bool
	elapsed  time.Duration
}

// guarded runs f in a goroutine with a 1 s timer, so a hang or a panic is a result, not the end of the run.
func guarded(f func() error) hostileRun {
	done := make(chan hostileRun, 1)
	go func() {
		var r hostileRun
		start := time.Now()
		defer func() {
			r.panicked = recover()
			r.elapsed = time.Since(start)
			done <- r
		}()
		r.err = f()
	}()
	select {
	case r := <-done:
		return r
	case <-time.After(hostileGuard):
		return hostileRun{hung: true, elapsed: hostileGuard}
	}
}

// checkHostileRefusal says what is wrong with a guarded run that must end in an error value of one of
// the case's outcome terms, or "".
func checkHostileRefusal(c hostileCase, r hostileRun) string {
	switch {
	case r.panicked != nil:
		return fmt.Sprintf("%s: panic %v", c.id, r.panicked)
	case r.hung:
		return fmt.Sprintf("%s: no result within %v (hang)", c.id, hostileGuard)
	case r.err == nil:
		return fmt.Sprintf("%s: expected %s, got no error", c.id, strings.Join(c.expected, "|"))
	case r.elapsed >= hostileGuard:
		return fmt.Sprintf("%s: took %v", c.id, r.elapsed)
	case !c.accepts(hostileKind(r.err)):
		return fmt.Sprintf("%s: returned %s (%v), vector accepts %s", c.id, hostileKind(r.err), r.err, strings.Join(c.expected, "|"))
	}
	return ""
}

func TestHostileUnpackVectors(t *testing.T) {
	cases := hostileStage(hostileCases(t), "unpack")
	if len(cases) == 0 {
		t.Fatal("no unpack vectors")
	}
	for _, c := range cases {
		t.Run(c.id, func(t *testing.T) {
			// Arrange
			build := hostileUnpackSchemes[c.id]
			if build == nil {
				t.Fatalf("no Go scheme for unpack case %s", c.id)
			}
			packet := mustHex(t, c.hex)
			var row map[string]any

			// Act
			r := guarded(func() error {
				s, err := build()
				if err != nil {
					return err
				}
				var uerr error
				row, uerr = UnpackMap(packet, s)
				return uerr
			})

			// Assert
			if msg := checkHostileRefusal(c, r); msg != "" {
				t.Fatal(msg)
			}
			if row != nil {
				t.Fatalf("%s: an error came with a row %v", c.id, row)
			}
		})
	}
}

func TestHostileLimitVectors(t *testing.T) {
	cases := hostileStage(hostileCases(t), "limit")
	if len(cases) == 0 {
		t.Fatal("no limit vectors")
	}
	for _, c := range cases {
		t.Run(c.id, func(t *testing.T) {
			// Arrange
			build := hostileLimitSchemes[c.id]
			if build == nil {
				t.Fatalf("no Go scheme for limit case %s", c.id)
			}
			packet := mustHex(t, c.hex)

			// Act
			r := guarded(func() error {
				s, err := build()
				if err != nil {
					return err
				}
				row, uerr := UnpackMap(packet, s)
				if row != nil {
					return fmt.Errorf("an error came with a row %v", row)
				}
				return uerr
			})

			// Assert: the refusal comes when a round would start: no bytes needed, the byte of that round left.
			if msg := checkHostileRefusal(c, r); msg != "" {
				t.Fatal(msg)
			}
			var e *Error
			if !errors.As(r.err, &e) || e.Needed != 0 || e.Left != 1 {
				t.Fatalf("%s: %+v, want needed 0 and left 1", c.id, e)
			}
		})
	}
}

type hostileConstruct struct {
	build func() (*Scheme, error)
	rule  *regexp.Regexp
}

// checkHostileConstruct builds the scheme of a construct case: it must fail as an InvalidScheme error
// whose text matches entry.rule, within the guard. It returns what is wrong, or "".
func checkHostileConstruct(c hostileCase, entry *hostileConstruct) string {
	if entry == nil {
		return fmt.Sprintf("no Go scheme for construct case %s", c.id)
	}
	if !c.accepts("scheme_error") {
		return fmt.Sprintf("%s: vector expects %s", c.id, strings.Join(c.expected, "|"))
	}
	r := guarded(func() error {
		s, err := entry.build()
		if err == nil {
			return fmt.Errorf("built scheme %v", s != nil)
		}
		return err
	})
	if r.panicked != nil || r.hung {
		return checkHostileRefusal(c, r)
	}
	var e *Error
	if !errors.As(r.err, &e) || e.Kind != InvalidScheme {
		return fmt.Sprintf("%s: expected an InvalidScheme error, got %v", c.id, r.err)
	}
	if !entry.rule.MatchString(e.Error()) {
		return fmt.Sprintf("%s: wrong rule fired: %q does not match %v", c.id, e.Error(), entry.rule)
	}
	if r.elapsed >= hostileGuard {
		return fmt.Sprintf("%s: construction took %v", c.id, r.elapsed)
	}
	return ""
}

func TestHostileConstructVectors(t *testing.T) {
	for _, c := range hostileStage(hostileCases(t), "construct") {
		t.Run(c.id, func(t *testing.T) {
			if msg := checkHostileConstruct(c, hostileConstructs[c.id]); msg != "" {
				t.Fatal(msg)
			}
		})
	}
}

// AZ-2418 AC-1 as for the other packages: a rule table with one wrong entry cannot pass. The wrong
// entry is built here; nothing on disk changes.
func TestHostileConstructWrongRuleEntryFailsNamingTheCase(t *testing.T) {
	// Arrange
	var c hostileCase
	for _, x := range hostileStage(hostileCases(t), "construct") {
		if x.id == "construct_empty_times_body" {
			c = x
		}
	}
	wrong := &hostileConstruct{
		build: hostileConstructs[c.id].build,
		rule:  regexp.MustCompile(`repeat 0: the body holds no member`),
	}

	// Act
	msg := checkHostileConstruct(c, wrong)

	// Assert
	if !strings.HasPrefix(msg, "construct_empty_times_body: wrong rule fired") {
		t.Fatalf("a wrong rule entry passed or failed another way: %q", msg)
	}
}

func TestHostileTablesHoldNoCaseTwiceAndNoOther(t *testing.T) {
	// Arrange
	cases := hostileCases(t)
	tables := map[string][]string{
		"unpack":    keysOf(hostileUnpackSchemes),
		"limit":     keysOf(hostileLimitSchemes),
		"construct": keysOf(hostileConstructs),
		"pack":      keysOf(hostilePacks),
	}

	// Act and assert
	for stage, keys := range tables {
		var ids []string
		for _, c := range hostileStage(cases, stage) {
			ids = append(ids, c.id)
		}
		if len(ids) == 0 || !sameSet(ids, keys) {
			t.Errorf("%s: cases %v, Go schemes %v", stage, ids, keys)
		}
	}
	if len(cases) != 70 {
		t.Errorf("cases.txt holds %d cases, the loader was written for 70", len(cases))
	}
}

func keysOf[V any](m map[string]V) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	return out
}

func sameSet(a, b []string) bool {
	seen := map[string]int{}
	for _, x := range a {
		seen[x]++
	}
	for _, x := range b {
		seen[x]--
	}
	for _, n := range seen {
		if n != 0 {
			return false
		}
	}
	return true
}
