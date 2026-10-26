package main

import (
	"bufio"
	"encoding/hex"
	"errors"
	"fmt"
	"os"
	"strconv"
	"strings"

	packbin "github.com/zxsanny/packbin/go"
)

// The message ECC commands of the handoff driver (AZ-2689; contract message-ecc.md).
//
//	ecc-protect <n> <clear hex>   prints the clear position message packed again with n parity bytes, or the error kind
//	ecc-repair <n> <t> <hex>      prints the position message repaired (hex, then the repaired count), or the error kind
//	ecc-batch <file>              one line per line of the file: `protect <n> <hex>` or `repair <n> <t> <hex>`
//
// "-" is the empty buffer. The kind names are the ones of fixtures/ecc/vectors.txt (uncorrectable, short, too_long,
// bad_parity, bad_limit) plus trailing, type_mismatch and unpack_failed for the walk of the unprotected fields.

// position is the AC-1 scheme, the clear message the ECC commands protect and repair.
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

func eccBytes(token string) ([]byte, error) {
	if token == "-" {
		return []byte{}, nil
	}
	return hex.DecodeString(token)
}

func eccKind(err error) string {
	var e *packbin.Error
	if !errors.As(err, &e) {
		return "unpack_failed"
	}
	switch {
	case e.Kind == packbin.Uncorrectable:
		return "uncorrectable"
	case e.Kind == packbin.TooLong:
		return "too_long"
	case e.Kind == packbin.ShortPacket && e.Name == "parity":
		return "short"
	case e.Kind == packbin.TrailingBytes:
		return "trailing"
	case e.Kind == packbin.UnknownType:
		return "type_mismatch"
	}
	return "unpack_failed"
}

func eccProtect(n int, clear []byte) string {
	pos := position()
	row, err := packbin.UnpackMap(clear, pos)
	if err != nil {
		return "unpack_failed"
	}
	protected, err := pos.WithParity(n)
	if err != nil {
		return "bad_parity"
	}
	raw, err := packbin.Pack(protected, row)
	if err != nil {
		return "pack_error"
	}
	return hex.EncodeToString(raw)
}

func eccRepair(n, t int, received []byte) string {
	pos := position()
	protected, err := pos.WithParity(n)
	if err != nil {
		return "bad_parity"
	}
	row, repaired, err := packbin.UnpackMapRepair(received, t, protected)
	if err != nil {
		var e *packbin.Error
		if errors.As(err, &e) && e.Kind == packbin.InvalidScheme {
			return "bad_limit"
		}
		return eccKind(err)
	}
	raw, err := packbin.Pack(pos, row)
	if err != nil {
		return "pack_error"
	}
	return fmt.Sprintf("%s %d", hex.EncodeToString(raw), repaired)
}

func eccLine(words []string) (string, error) {
	switch {
	case len(words) == 3 && words[0] == "protect":
		n, err := strconv.Atoi(words[1])
		clear, err2 := eccBytes(words[2])
		if err != nil || err2 != nil {
			return "", fmt.Errorf("ecc line: %s", strings.Join(words, " "))
		}
		return eccProtect(n, clear), nil
	case len(words) == 4 && words[0] == "repair":
		n, err := strconv.Atoi(words[1])
		t, err2 := strconv.Atoi(words[2])
		received, err3 := eccBytes(words[3])
		if err != nil || err2 != nil || err3 != nil {
			return "", fmt.Errorf("ecc line: %s", strings.Join(words, " "))
		}
		return eccRepair(n, t, received), nil
	}
	return "", fmt.Errorf("ecc line: %s", strings.Join(words, " "))
}

// runEcc runs one ecc command and returns the exit status.
func runEcc(args []string) int {
	var words []string
	switch {
	case args[0] == "ecc-protect" && len(args) == 3:
		words = []string{"protect", args[1], args[2]}
	case args[0] == "ecc-repair" && len(args) == 4:
		words = []string{"repair", args[1], args[2], args[3]}
	case args[0] == "ecc-batch" && len(args) == 2:
		file, err := os.Open(args[1])
		if err != nil {
			return fail("ecc-batch: %v", err)
		}
		defer file.Close()
		scan := bufio.NewScanner(file)
		scan.Buffer(make([]byte, 0, 1<<16), 1<<20)
		for scan.Scan() {
			if f := strings.Fields(scan.Text()); len(f) > 0 {
				out, err := eccLine(f)
				if err != nil {
					return fail("%v", err)
				}
				fmt.Println(out)
			}
		}
		if err := scan.Err(); err != nil {
			return fail("ecc-batch: %v", err)
		}
		return 0
	default:
		return 2
	}
	out, err := eccLine(words)
	if err != nil {
		return fail("%v", err)
	}
	fmt.Println(out)
	return 0
}
