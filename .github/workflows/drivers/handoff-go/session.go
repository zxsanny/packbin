package main

import (
	"encoding/hex"
	"fmt"
	"os"

	packbin "github.com/zxsanny/packbin/go"
)

// position is the AC-1 scheme: the session ring and the position program both pack it.
func position() *packbin.Scheme {
	s, err := packbin.NewScheme(0x40,
		packbin.U16(0, "sid"),
		packbin.I32(1, "lat"),
		packbin.I32(2, "lon"),
		packbin.U8(3, "profile"),
		packbin.Flags(4,
			packbin.U16(4, "heading"),
			packbin.U8(5, "speed"),
			packbin.I16(6, "altitude")))
	if err != nil {
		fmt.Fprintf(os.Stderr, "position scheme: %v\n", err)
		os.Exit(1)
	}
	return s
}

// positionEcc is the position scheme with 4 parity bytes: the scheme of the session-ecc payload (EC-10).
func positionEcc() *packbin.Scheme {
	s, err := position().WithParity(4)
	if err != nil {
		fmt.Fprintf(os.Stderr, "position scheme with parity: %v\n", err)
		os.Exit(1)
	}
	return s
}

// sessionSession loads the session of the ring: seed bytes 1..32.
func sessionSession() *packbin.PackSession {
	seed := make([]byte, packbin.SeedSize)
	for i := range seed {
		seed[i] = byte(i + 1)
	}
	s, err := packbin.LoadSession(seed)
	if err != nil {
		fmt.Fprintf(os.Stderr, "session: %v\n", err)
		os.Exit(1)
	}
	return s
}

// nonce is 01 followed by 15 zero bytes.
func nonce() []byte {
	n := make([]byte, packbin.NonceSize)
	n[0] = 1
	return n
}

// packSession prints the position row under the session, packed with scheme (the command name is cmd).
func packSession(cmd string, scheme *packbin.Scheme) int {
	opener := sessionSession()
	if _, err := opener.StartWith(nonce()); err != nil {
		fmt.Fprintf(os.Stderr, "%s: %v\n", cmd, err)
		return 1
	}
	payload, err := opener.Pack(scheme, map[string]any{
		"sid": 1, "lat": 500000000, "lon": 300000000, "profile": 1,
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "%s: %v\n", cmd, err)
		return 1
	}
	fmt.Println(hex.EncodeToString(payload))
	return 0
}

// unpackSession joins the session and exits 0 only if the position row comes back from raw read with scheme.
func unpackSession(cmd, raw string, scheme *packbin.Scheme) int {
	payload, err := hex.DecodeString(raw)
	if err != nil {
		fmt.Fprintf(os.Stderr, "%s: bad hex: %v\n", cmd, err)
		return 1
	}
	waiter := sessionSession()
	if err := waiter.Join(nonce()); err != nil {
		fmt.Fprintf(os.Stderr, "%s: %v\n", cmd, err)
		return 1
	}
	row, err := waiter.UnpackMap(payload, scheme)
	if err != nil {
		fmt.Fprintf(os.Stderr, "%s: %v\n", cmd, err)
		return 1
	}
	want := map[string]any{"sid": uint16(1), "lat": int32(500000000), "lon": int32(300000000), "profile": uint8(1)}
	if !sameRow(row, want) {
		fmt.Fprintf(os.Stderr, "%s: read %#v, expected %#v\n", cmd, row, want)
		return 1
	}
	return 0
}
