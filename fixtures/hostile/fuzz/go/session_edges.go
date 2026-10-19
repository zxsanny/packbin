package main

import (
	"bytes"
	"errors"
	"fmt"
	"strings"

	pb "github.com/zxsanny/packbin/go"
)

// (d) the session check order and receive-index moves.

func sessionOrder() (string, error) {
	var log []string
	opener, _ := pb.LoadSession(bytes.Repeat([]byte{5}, pb.SeedSize))
	waiter, _ := pb.LoadSession(bytes.Repeat([]byte{5}, pb.SeedSize))
	_, _, err := waiter.UnpackMapRepair([]byte{1, 2, 3}, 99)
	var pe *pb.Error
	if !errors.As(err, &pe) || pe.Kind != pb.ShortPacket || pe.Needed != 1 || pe.Left != 0 {
		return "", fmt.Errorf("not open: %v", err)
	}
	log = append(log, "not-open first")
	nonce, _ := opener.StartWith(bytes.Repeat([]byte{2}, pb.NonceSize))
	if err := waiter.Join(nonce); err != nil {
		return "", err
	}
	const n = 8
	next := byte(0)
	send := func() ([]byte, []byte) {
		next++
		body := bytes.Repeat([]byte{next}, 20)
		return sessionPack(opener, body, n), body
	}
	scheme := rawScheme(1, 20, n)
	reads := func(wire, body []byte) bool {
		row, _, err := waiter.UnpackMapRepair(wire, 0, scheme)
		got, _ := row["b"].([]byte)
		return err == nil && bytes.Equal(got, body)
	}
	w0, b0 := send()
	refusals := []func() error{
		func() error { _, _, err := waiter.UnpackMapRepair(bytes.Repeat([]byte{1}, 30), 0); return err },
		func() error {
			_, _, err := waiter.UnpackMapRepair(bytes.Repeat([]byte{1}, 30), 99, scheme, rawScheme(1, 20, 4))
			return err
		},
		func() error {
			_, _, err := waiter.UnpackMapRepair(bytes.Repeat([]byte{1}, 30), 99, scheme, rawScheme(2, 20, 4))
			return err
		},
		func() error { _, _, err := waiter.UnpackMapRepair(bytes.Repeat([]byte{1}, 30), 5, scheme); return err },
		func() error { _, _, err := waiter.UnpackMapRepair(bytes.Repeat([]byte{1}, 30), 0, nil); return err },
	}
	for i, call := range refusals {
		if call() == nil {
			return "", fmt.Errorf("refusal %d accepted", i)
		}
	}
	if !reads(w0, b0) {
		return "", errors.New("a refused call moved the receive index")
	}
	log = append(log, "5 call refusals keep the index")
	hostile := []struct {
		name string
		make func([]byte) []byte
		ty   int
	}{
		{"too_long 300 bytes", func([]byte) []byte { return make([]byte, 300) }, 1},
		{"short below n", func([]byte) []byte { return bytes.Repeat([]byte{1}, 5) }, 1},
		{"empty", func([]byte) []byte { return nil }, 1},
		{"uncorrectable (t 0, 1 wrong)", func(w []byte) []byte { v := clone(w); v[3] ^= 1; return v }, 1},
		{"unknown type after the pad", func(w []byte) []byte { return clone(w) }, 2},
	}
	for _, h := range hostile {
		w, _ := send()
		if _, _, err := waiter.UnpackMapRepair(h.make(w), 0, rawScheme(h.ty, 20, n)); err == nil {
			return "", fmt.Errorf("%s accepted", h.name)
		}
		w2, b2 := send()
		if !reads(w2, b2) {
			return "", fmt.Errorf("after %s the next payload did not read", h.name)
		}
	}
	log = append(log, "5 hostile payloads use one index each")
	w, b := send()
	cw := clone(w)
	cw[2] ^= 0xff
	row, rep, err := waiter.UnpackMapRepair(cw, 1, scheme)
	got, _ := row["b"].([]byte)
	if err != nil || rep != 1 || !bytes.Equal(got, b) {
		return "", fmt.Errorf("session repair: %d %v", rep, err)
	}
	if !bytes.Equal(cw[:2], w[:2]) || cw[2] == w[2] {
		return "", errors.New("the caller's payload was written")
	}
	log = append(log, "session repair 1 byte, payload not written")
	return strings.Join(log, "; "), nil
}
