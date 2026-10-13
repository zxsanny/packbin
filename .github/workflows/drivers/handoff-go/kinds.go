package main

import (
	"fmt"
	"os"

	packbin "github.com/zxsanny/packbin/go"
)

// kind is one payload kind of the ring: the scheme, the row Go packs, the row Unpack must give
// (the Go types UnpackMap uses), and whether the unpacked row must repack to the same bytes.
type kind struct {
	scheme *packbin.Scheme
	pack   map[string]any
	want   map[string]any
	repack bool
}

// short names the kinds that also take unpack-<kind>-short: a packet cut short must be refused.
var short = map[string]bool{"listgroup": true, "dictgroup": true, "listflags": true}

// build writes every scheme by hand, as the README shows (ADR-001): no shared walker or generator.
func build(typeNumber int, fields ...packbin.Field) *packbin.Scheme {
	s, err := packbin.NewScheme(typeNumber, fields...)
	if err != nil {
		fmt.Fprintf(os.Stderr, "scheme %d: %v\n", typeNumber, err)
		os.Exit(1)
	}
	return s
}

func strs(items ...string) []any {
	out := make([]any, len(items))
	for i, s := range items {
		out[i] = s
	}
	return out
}

func point(a, b uint8) map[string]any { return map[string]any{"a": a, "b": b} }

// kinds returns the 15 kinds, built on first use of a command that names one.
func kinds() map[string]kind {
	userRow := map[string]any{
		"username": "zxsanny",
		"roles":    strs("user", "dispatcher"),
		"access": map[string]any{
			"channel": strs("read"),
			"map":     strs("read", "gps_fix", "set", "edit"),
			"store":   strs("read", "write"),
		},
	}
	nestedRow := map[string]any{"access": map[string]any{
		"map":   []any{map[string]any{"op": "gps_fix"}},
		"store": []any{map[string]any{"op": "read"}, map[string]any{"op": "write"}},
	}}
	// flags { bool on }: the bit is set only for true.
	boolFlag := build(1, packbin.Flags(0, packbin.Bool(0, "on")))
	// u8 k; split flag byte m; when(k == 1) { m.bit(u8 v) }: {k:0, v:5} sets the bit although the when
	// is not taken, and unpack never reads it.
	m := packbin.FlagByte("m")
	bitWhen := build(1, packbin.U8(0, "k"), m, packbin.When(1, packbin.Eq(0, 1), m.Bit(packbin.U8(1, "v"))))
	listGroup := build(1, packbin.List("pts", packbin.Nested("p", packbin.U8(0, "a"), packbin.U8(1, "b"))))
	dictGroup := build(1, packbin.Dict("m", packbin.Nested("p", packbin.U8(0, "a"), packbin.U8(1, "b"))))
	listFlags := build(1, packbin.List("pts", packbin.Flags(0, packbin.U8(0, "a"), packbin.U16(1, "b"))))
	return map[string]kind{
		"user": {
			scheme: build(1, packbin.Utf8(0, "username"),
				packbin.List("roles", packbin.Utf8(0, "role")),
				packbin.Dict("access", packbin.List("actions", packbin.Utf8(0, "action")))),
			pack: userRow, want: userRow,
		},
		"nested": {
			scheme: build(1, packbin.Dict("access", packbin.List("rows", packbin.Dict("row", packbin.Utf8(0, "op"))))),
			pack:   nestedRow, want: nestedRow,
		},
		"boolflag": {scheme: boolFlag, pack: map[string]any{"on": false}, want: map[string]any{}},
		"booltrue": {scheme: boolFlag, pack: map[string]any{"on": true}, want: map[string]any{"on": true}},
		"bitwhen": {
			scheme: bitWhen, pack: map[string]any{"k": 0, "v": 5}, want: map[string]any{"k": uint8(0)},
		},
		// Aligned rounds: one entry per round; a clear bit and a when not taken leave the entry nil.
		"roundflags": {
			scheme: build(1, packbin.Repeat(0, packbin.Flags(0, packbin.Bool(0, "on"), packbin.U8(1, "n")))),
			pack:   map[string]any{"on": []any{true, false, true}, "n": []any{1, 2, 3}},
			want:   map[string]any{"on": []any{true, nil, true}, "n": []any{uint8(1), uint8(2), uint8(3)}},
			repack: true,
		},
		"roundwhen": {
			scheme: build(1, packbin.Repeat(0, packbin.U8(0, "k"), packbin.When(1, packbin.Eq(0, 1), packbin.U8(1, "v")))),
			pack:   map[string]any{"k": []any{1, 2}, "v": []any{9}},
			want:   map[string]any{"k": []any{uint8(1), uint8(2)}, "v": []any{uint8(9), nil}},
			repack: true,
		},
		"listgroup": {
			scheme: listGroup,
			pack:   map[string]any{"pts": []any{point(1, 2), point(3, 4)}},
			want:   map[string]any{"pts": []any{point(1, 2), point(3, 4)}},
		},
		"dictgroup": {
			scheme: dictGroup,
			pack:   map[string]any{"m": map[string]any{"y": point(3, 4), "x": point(1, 2)}},
			want:   map[string]any{"m": map[string]any{"y": point(3, 4), "x": point(1, 2)}},
		},
		"listflags": {
			scheme: listFlags,
			pack: map[string]any{"pts": []any{
				map[string]any{"a": uint8(1)}, map[string]any{}, map[string]any{"b": uint16(2)}}},
			want: map[string]any{"pts": []any{
				map[string]any{"a": uint8(1)}, map[string]any{}, map[string]any{"b": uint16(2)}}},
		},
	}
}
