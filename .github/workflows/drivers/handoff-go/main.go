// Command handoff-go is the Go member of the cross-language ring (.github/workflows/language-pair.sh).
//
// Commands, the same as the other drivers:
//
//	pack-<kind>                 prints the hex of the kind's row and a newline, exits 0
//	unpack-<kind> <hex>         exits 0 only if the packet unpacks to the kind's row (the round kinds
//	                            also repack to the same hex)
//	unpack-<kind>-short <hex>   listgroup, dictgroup and listflags only: exits 0 only if the packet is
//	                            refused and no row comes back
//	pack-session                prints the ciphertext of the position row (seed bytes 1..32, value 01
//	                            and 15 zero bytes)
//	unpack-session <hex>        joins and exits 0 only if the position row comes back
//
// Any other command exits 2. The position program is ./position in this module (it prints the golden
// hex of the AC-1 row); build either with ring-go.sh.
package main

import (
	"encoding/hex"
	"fmt"
	"os"
	"reflect"
	"strings"

	packbin "github.com/zxsanny/packbin/go"
)

// sameRow compares two rows by Go type and value.
func sameRow(got, want map[string]any) bool {
	return reflect.DeepEqual(got, want)
}

func fail(format string, args ...any) int {
	fmt.Fprintf(os.Stderr, format+"\n", args...)
	return 1
}

func run(args []string) int {
	if len(args) == 0 {
		return 2
	}
	cmd := args[0]
	if strings.HasPrefix(cmd, "ecc-") {
		return runEcc(args)
	}
	switch cmd {
	case "pack-session":
		return packSession()
	case "unpack-session":
		if len(args) < 2 {
			return 2
		}
		return unpackSession(args[1])
	}
	name, op, isShort := splitCommand(cmd)
	if op == "" {
		return 2
	}
	k, ok := kinds()[name]
	if !ok || (isShort && !short[name]) {
		return 2
	}
	switch {
	case op == "pack" && !isShort:
		raw, err := packbin.Pack(k.scheme, k.pack)
		if err != nil {
			return fail("%s: %v", cmd, err)
		}
		fmt.Println(hex.EncodeToString(raw))
		return 0
	case op == "unpack" && len(args) >= 2:
		return unpack(cmd, k, args[1], isShort)
	}
	return 2
}

// splitCommand reads "pack-user", "unpack-user" and "unpack-listgroup-short"; op is "" if it is none.
func splitCommand(cmd string) (name, op string, isShort bool) {
	rest, ok := strings.CutPrefix(cmd, "pack-")
	op = "pack"
	if !ok {
		rest, ok = strings.CutPrefix(cmd, "unpack-")
		op = "unpack"
	}
	if !ok {
		return "", "", false
	}
	if name, ok = strings.CutSuffix(rest, "-short"); ok {
		return name, op, true
	}
	return rest, op, false
}

func unpack(cmd string, k kind, raw string, isShort bool) int {
	buf, err := hex.DecodeString(raw)
	if err != nil {
		return fail("%s: bad hex: %v", cmd, err)
	}
	row, err := packbin.UnpackMap(buf, k.scheme)
	if isShort {
		// A short element is refused and no row comes back.
		if err != nil && row == nil {
			return 0
		}
		return fail("%s: read %#v (error %v), expected a refusal", cmd, row, err)
	}
	if err != nil {
		return fail("%s: %v", cmd, err)
	}
	if !sameRow(row, k.want) {
		return fail("%s: read %#v, expected %#v", cmd, row, k.want)
	}
	if k.repack {
		again, err := packbin.Pack(k.scheme, row)
		if err != nil {
			return fail("%s: repack: %v", cmd, err)
		}
		if got := hex.EncodeToString(again); got != raw {
			return fail("%s: repacked %s, expected %s", cmd, got, raw)
		}
	}
	return 0
}

func main() { os.Exit(run(os.Args[1:])) }
