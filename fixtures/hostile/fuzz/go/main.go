// Command packbinprobe is the Go hostile-input probe of AZ-2666 (loop 41): the compact text decoder and the
// message ECC unpack path, through the public API of github.com/zxsanny/packbin/go.
//
// How to run: sh run.sh <packbin checkout> <work dir> <command> [args] (see run.sh; on a Mac without Go,
// in the golang:1.27 image). The binary takes the checkout first and reads fixtures/text/vectors.txt,
// fixtures/ecc/vectors.txt, fixtures/hostile/fuzz/corpus.txt and the frozen code lengths in go/text_tables.go.
//
//	random  <seed> <calls>  (a) seeded random and mutated inputs: text unpack (lone string, list, dict), ECC
//	                        unpack (random buffers, code words with k wrong bytes, vector seeds), strings in
//	                        protected messages
//	ecctime <calls>         (b) repair time at n = 32, N = 254 for the inputs that make the most work
//	textamp <case>          (c) decoded bytes per payload byte, time and peak RSS: one|list1m|list8m|controls|short|dictpre
//	edges                   (d) the AC-1 / AC-2 edge cases a random run is unlikely to reach
//	allocs                  allocations and bytes per unpack call on the ECC paths (contract: a few arrays of n+1)
//
// Exit status 1 when an invariant is broken (a panic, a call above 1 s, a wrong repair).
package main

import (
	"fmt"
	"os"
	"strconv"
	"strings"
)

func main() {
	if len(os.Args) < 3 {
		fmt.Fprintln(os.Stderr, "usage: probe <checkout> random <seed> <calls> | ecctime <calls> | textamp <case> | edges | allocs")
		os.Exit(2)
	}
	checkout := os.Args[1]
	arg := func(i int, def string) string {
		if len(os.Args) > i {
			return os.Args[i]
		}
		return def
	}
	var ok bool
	switch os.Args[2] {
	case "random":
		seed, err := strconv.ParseUint(strings.TrimPrefix(arg(3, "5eed"), "0x"), 16, 64)
		if err != nil {
			panic(err)
		}
		calls, _ := strconv.Atoi(arg(4, "20000"))
		ok = random(checkout, seed, calls)
	case "ecctime":
		calls, _ := strconv.Atoi(arg(3, "20000"))
		ok = ecctime(calls)
	case "textamp":
		ok = textamp(checkout, arg(3, "one"))
	case "edges":
		ok = edges(checkout)
	case "allocs":
		ok = allocs()
	default:
		panic("unknown command " + os.Args[2])
	}
	if !ok {
		os.Exit(1)
	}
}
